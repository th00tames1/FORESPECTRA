import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../data/si_nir_client.dart';
import '../data/si_nir_protocol.dart';
import '../data/storage/data_store.dart';
import '../domain/analyzer.dart';
import '../domain/calibration_model.dart';
import '../domain/measurement.dart';
import '../domain/spectrum.dart';
import 'location_service.dart';

class DiscoveredSensor {
  const DiscoveredSensor({
    required this.ip,
    this.moduleId,
    required this.verified,
    required this.fromHistory,
  });

  final String ip;
  final String? moduleId;
  final bool verified;
  final bool fromHistory;

  DiscoveredSensor copyWith({
    String? ip,
    String? moduleId,
    bool? verified,
    bool? fromHistory,
  }) {
    return DiscoveredSensor(
      ip: ip ?? this.ip,
      moduleId: moduleId ?? this.moduleId,
      verified: verified ?? this.verified,
      fromHistory: fromHistory ?? this.fromHistory,
    );
  }
}

class AppState extends ChangeNotifier {
  static const List<String> _defaultKnownIps = [
    '10.92.71.8',
    '10.13.199.8',
    '192.168.144.2',
    '192.168.137.2',
  ];
  static final RegExp _ipv4Pattern = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');

  final SiNirClient client = SiNirClient();
  final DataStore dataStore = DataStore();
  final LocationService locationService = LocationService();
  final Uuid _uuid = const Uuid();

  bool isConnecting = false;
  bool isConnected = false;
  String statusMessage = 'Disconnected';
  String? moduleId;
  String currentIp = '10.92.71.8';
  bool sendLengthPrefix = false;
  bool hasBackground = false;
  bool isBackgrounding = false;
  bool isScanning = false;
  int captureCount = 0;
  int currentTab = 0;
  ThemeMode themeMode = ThemeMode.dark;
  bool showConnectScreen = true;
  Timer? _connectDelayTimer;
  String materialName = '';
  String sampleName = '';
  bool isDiscovering = false;
  List<DiscoveredSensor> discoveredSensors = const [];
  List<String> _recentIps = const [];
  int sensorPickerPromptSignal = 0;

  int lampsCount = 2;
  int lampSelect = 0;
  int t1 = 14;
  int deltaT = 2;
  int t2c1 = 5;
  int t2c2 = 35;
  int t2max = 10;
  int opticalGainValue = 0;

  ScanParams scanParams = ScanParams();

  Spectrum? latestSpectrum;
  Spectrum? backgroundSpectrum;
  CalibrationModel? currentModel;
  AnalysisResult? lastResult;

  Future<void> initialize() async {
    await dataStore.init();
    await _loadKnownDevices();
  }

  Future<void> connect() async {
    isConnecting = true;
    statusMessage = 'Connecting...';
    _connectDelayTimer?.cancel();
    showConnectScreen = true;
    notifyListeners();
    try {
      client.sendLengthPrefix = sendLengthPrefix;
      final attempts = await _connectionAttempts();

      Exception? lastError;
      for (final ip in attempts) {
        try {
          await client.disconnect();
          await client.connect(ip, timeout: const Duration(seconds: 4));
          isConnected = true;
          currentIp = ip;
          hasBackground = false;
          backgroundSpectrum = null;
          latestSpectrum = null;
          statusMessage = 'Connected (verifying...)';
          setTab(0);
          _startConnectDelay();
          _registerDiscoveredSensor(
            DiscoveredSensor(
              ip: ip,
              verified: true,
              fromHistory: true,
            ),
            notify: false,
          );
          isConnecting = false;
          notifyListeners();
          unawaited(_verifyDevice());
          return;
        } catch (error) {
          lastError = error is Exception ? error : Exception(error.toString());
        }
      }
      throw lastError ?? Exception('Unable to connect');
    } catch (error) {
      statusMessage = 'Connection failed: $error';
      isConnected = false;
      showConnectScreen = true;
      _triggerSensorPickerPrompt(startDiscovery: true);
      setTab(0);
    } finally {
      if (isConnecting) {
        isConnecting = false;
        notifyListeners();
      }
    }
  }

  void _startConnectDelay() {
    _connectDelayTimer?.cancel();
    _connectDelayTimer = Timer(const Duration(seconds: 3), () {
      showConnectScreen = false;
      notifyListeners();
    });
  }

  Future<void> _verifyDevice() async {
    const boardTimeout = Duration(seconds: 6);
    const idTimeout = Duration(seconds: 6);
    try {
      final board = await client.checkBoard().timeout(boardTimeout);
      statusMessage = board == 0 || board == 1
          ? 'Connected'
          : 'Connected (board status $board)';
      notifyListeners();
    } catch (_) {
      statusMessage = 'Connected (verify timeout)';
      notifyListeners();
      return;
    }

    try {
      final id = (await client.readModuleId().timeout(idTimeout)).trim();
      moduleId = id.isEmpty ? null : id;
      if (moduleId != null) {
        await dataStore.upsertDevice(id: moduleId!, name: 'Si-NIR', ip: currentIp);
        await _refreshKnownIps();
        _registerDiscoveredSensor(
          DiscoveredSensor(
            ip: currentIp,
            moduleId: moduleId,
            verified: true,
            fromHistory: true,
          ),
          notify: false,
        );
      }
      notifyListeners();
    } catch (_) {
      statusMessage = 'Connected (ID unavailable)';
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _connectDelayTimer?.cancel();
    await client.disconnect();
    isConnected = false;
    hasBackground = false;
    isBackgrounding = false;
    isScanning = false;
    showConnectScreen = true;
    setTab(0);
    statusMessage = 'Disconnected';
    notifyListeners();
  }

  void setCurrentIp(String value) {
    final ip = value.trim();
    if (ip.isEmpty) {
      return;
    }
    currentIp = ip;
    _registerDiscoveredSensor(
      DiscoveredSensor(ip: ip, verified: false, fromHistory: true),
      notify: false,
    );
    notifyListeners();
  }

  Future<void> connectToSensor(DiscoveredSensor sensor) async {
    setCurrentIp(sensor.ip);
    await connect();
  }

  Future<void> discoverSensors() async {
    if (isDiscovering || isConnecting) {
      return;
    }

    isDiscovering = true;
    statusMessage = 'Searching for hotspot devices...';
    notifyListeners();

    try {
      final targets = await _discoveryTargets();
      if (targets.isEmpty) {
        statusMessage = 'No subnet targets found';
        return;
      }

      final foundByIp = <String, DiscoveredSensor>{
        for (final sensor in discoveredSensors) sensor.ip: sensor,
      };

      var cursor = 0;
      String? nextTarget() {
        if (cursor >= targets.length) {
          return null;
        }
        final ip = targets[cursor];
        cursor += 1;
        return ip;
      }

      Future<void> worker() async {
        while (true) {
          final ip = nextTarget();
          if (ip == null) {
            return;
          }

          final probed = await _probeSensor(ip);
          if (probed == null) {
            continue;
          }

          final existing = foundByIp[ip];
          final shouldReplace = existing == null ||
              (!existing.verified && probed.verified) ||
              (existing.moduleId == null && probed.moduleId != null);

          if (!shouldReplace) {
            continue;
          }

          foundByIp[ip] = probed;
          discoveredSensors = _sortedSensors(foundByIp.values.toList());
          notifyListeners();
        }
      }

      final workerCount = targets.length < 24 ? targets.length : 24;
      if (workerCount > 0) {
        await Future.wait(List.generate(workerCount, (_) => worker()));
      }

      discoveredSensors = _sortedSensors(foundByIp.values.toList());
      final newCount = discoveredSensors.where((sensor) => !sensor.fromHistory).length;
      statusMessage = newCount == 0
          ? 'No new devices found. Select a known IP.'
          : 'Found $newCount device(s). Select one to connect.';
    } catch (error) {
      statusMessage = 'Device search failed: $error';
    } finally {
      isDiscovering = false;
      notifyListeners();
    }
  }

  Future<void> runBackground() async {
    if (!isConnected || isBackgrounding || isScanning) return;
    statusMessage = 'Running background...';
    isBackgrounding = true;
    notifyListeners();
    try {
      final status = await client
          .runBackground(scanParams)
          .timeout(const Duration(seconds: 12));
      if (status == 0) {
        hasBackground = true;
        statusMessage = 'Reference captured';
      } else {
        hasBackground = false;
        statusMessage = 'Background error $status';
      }
    } catch (error) {
      hasBackground = false;
      statusMessage = 'Background failed: $error';
    } finally {
      isBackgrounding = false;
    }
    notifyListeners();
  }

  Future<void> runSpectrum() async {
    if (!isConnected || isScanning || isBackgrounding) return;
    if (!hasBackground) {
      statusMessage = 'Background required. Tap Set reference.';
      notifyListeners();
      return;
    }
    statusMessage = 'Scanning spectrum...';
    isScanning = true;
    notifyListeners();
    try {
      latestSpectrum = await client
          .runSpectrum(scanParams)
          .timeout(const Duration(seconds: 20));
      statusMessage = 'Ready to Scan';
      captureCount += 1;
    } catch (error) {
      statusMessage = 'Spectrum failed: $error';
    } finally {
      isScanning = false;
    }
    notifyListeners();
  }

  Future<void> runPsd() async {
    if (!isConnected) return;
    statusMessage = 'Scanning PSD...';
    notifyListeners();
    try {
      latestSpectrum = await client.runPsd(scanParams);
      statusMessage = 'PSD ready';
    } catch (error) {
      statusMessage = 'PSD failed: $error';
    }
    notifyListeners();
  }

  Future<void> importModel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.bytes == null) {
      return;
    }
    final jsonText = utf8.decode(result.files.single.bytes!);
    currentModel = CalibrationModel.fromJson(jsonText);
    await dataStore.saveModel(id: currentModel!.id, name: currentModel!.name, json: jsonText);
    notifyListeners();
  }

  Future<void> analyze() async {
    if (latestSpectrum == null || currentModel == null) return;
    lastResult = runAnalysis(latestSpectrum!, currentModel!);
    notifyListeners();
  }

  Future<void> saveSession() async {
    if (latestSpectrum == null) return;
    final measurementId = _uuid.v4();
    final position = await locationService.getCurrentPosition();
    final measurement = Measurement(
      id: measurementId,
      timestamp: DateTime.now(),
      deviceId: moduleId ?? 'unknown',
      scanTimeMs: scanParams.scanTimeMs,
      paramsJson: jsonEncode({
        'scanTimeMs': scanParams.scanTimeMs,
        'zeroPadding': scanParams.zeroPadding,
        'commonWavNum': scanParams.commonWavNum,
        'opticalGain': scanParams.opticalGain,
        'apodizationSel': scanParams.apodizationSel,
      }),
      materialName: materialName.trim().isEmpty ? null : materialName.trim(),
      sampleName: sampleName.trim().isEmpty ? null : sampleName.trim(),
      latitude: position?.latitude,
      longitude: position?.longitude,
      modelId: currentModel?.id,
      resultsJson: lastResult == null ? null : jsonEncode(lastResult!.toJson()),
    );

    final spectrumId = _uuid.v4();
    final spectrumBlob = SpectrumBlob(
      id: spectrumId,
      measurementId: measurementId,
      kind: 'raw',
      length: latestSpectrum!.length,
      xBytes: latestSpectrum!.x.buffer.asUint8List(),
      yBytes: latestSpectrum!.y.buffer.asUint8List(),
    );

    await dataStore.saveMeasurement(measurement);
    await dataStore.saveSpectrum(spectrumBlob);
    statusMessage = 'Session saved';
    notifyListeners();
  }

  void discardLatest() {
    latestSpectrum = null;
    lastResult = null;
    statusMessage = 'Scan discarded';
    notifyListeners();
  }

  Future<void> requestStoragePermission() async {
    await Permission.storage.request();
  }

  void updateSendLengthPrefix(bool value) {
    sendLengthPrefix = value;
    client.sendLengthPrefix = value;
    notifyListeners();
  }

  void updateMaterialName(String value) {
    materialName = value;
    notifyListeners();
  }

  void updateSampleName(String value) {
    sampleName = value;
    notifyListeners();
  }

  void setTab(int value) {
    if (currentTab == value) return;
    currentTab = value;
    notifyListeners();
  }

  void setThemeMode(bool isDark) {
    themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void updateScanTime(int value) {
    scanParams.scanTimeMs = value;
    notifyListeners();
  }

  void updateZeroPadding(int value) {
    scanParams.zeroPadding = value;
    notifyListeners();
  }

  void updateCommonWavNum(int value) {
    scanParams.commonWavNum = value;
    notifyListeners();
  }

  void updateOpticalGain(int value) {
    scanParams.opticalGain = value;
    notifyListeners();
  }

  void updateApodization(int value) {
    scanParams.apodizationSel = value;
    notifyListeners();
  }

  Future<void> applySourceSettings() async {
    if (!isConnected) return;
    statusMessage = 'Applying source settings...';
    notifyListeners();
    try {
      final status = await client.setSourceSettings(
        lampsCount: lampsCount,
        lampSelect: lampSelect,
        t1: t1,
        deltaT: deltaT,
        t2c1: t2c1,
        t2c2: t2c2,
        t2max: t2max,
      );
      statusMessage = status == 0 ? 'Source settings applied' : 'Source error $status';
    } catch (error) {
      statusMessage = 'Source settings failed: $error';
    }
    notifyListeners();
  }

  Future<void> applyOpticalSettings() async {
    if (!isConnected) return;
    statusMessage = 'Applying optical gain...';
    notifyListeners();
    try {
      final status = await client.setOpticalSettings(opticalGainValue);
      statusMessage = status == 0 ? 'Optical gain applied' : 'Optical gain error $status';
    } catch (error) {
      statusMessage = 'Optical gain failed: $error';
    }
    notifyListeners();
  }

  Future<void> _loadKnownDevices() async {
    await _refreshKnownIps();
    final knownIps = _orderedUnique([..._recentIps, ..._defaultKnownIps]);
    if (knownIps.isEmpty) {
      return;
    }

    currentIp = knownIps.first;
    discoveredSensors = _sortedSensors(
      knownIps
          .map(
            (ip) => DiscoveredSensor(
              ip: ip,
              verified: false,
              fromHistory: true,
            ),
          )
          .toList(),
    );
    notifyListeners();
  }

  Future<void> _refreshKnownIps() async {
    try {
      _recentIps = await dataStore.listRecentDeviceIps(limit: 20);
    } catch (_) {
      _recentIps = const [];
    }
  }

  Future<List<String>> _connectionAttempts() async {
    await _refreshKnownIps();
    return _orderedUnique([
      currentIp,
      ..._recentIps,
      ..._defaultKnownIps,
    ]);
  }

  Future<List<String>> _discoveryTargets() async {
    await _refreshKnownIps();
    final seeds = _orderedUnique([
      currentIp,
      ..._recentIps,
      ..._defaultKnownIps,
    ]);

    final targets = _orderedUnique(seeds);
    final subnets = <String>[];
    for (final ip in seeds) {
      final subnet = _subnetOf(ip);
      if (subnet == null || subnets.contains(subnet)) {
        continue;
      }
      if (subnet.startsWith('10.')) {
        subnets.add(subnet);
      }
    }

    if (subnets.isEmpty) {
      final currentSubnet = _subnetOf(currentIp);
      if (currentSubnet != null) {
        subnets.add(currentSubnet);
      }
    }

    final cappedSubnets = subnets.take(3).toList();
    for (final subnet in cappedSubnets) {
      for (var host = 1; host <= 254; host += 1) {
        targets.add('$subnet.$host');
      }
    }

    return _orderedUnique(targets);
  }

  Future<DiscoveredSensor?> _probeSensor(String ip) async {
    final probe = SiNirClient()..sendLengthPrefix = sendLengthPrefix;
    try {
      await probe.connect(ip, timeout: const Duration(milliseconds: 280));

      int? boardStatus;
      try {
        boardStatus = await probe.checkBoard().timeout(
              const Duration(milliseconds: 1200),
            );
      } catch (_) {
        boardStatus = null;
      }

      String? discoveredId;
      try {
        final rawId = await probe.readModuleId().timeout(
              const Duration(milliseconds: 1200),
            );
        final trimmed = rawId.trim();
        if (trimmed.isNotEmpty) {
          discoveredId = trimmed;
        }
      } catch (_) {
        discoveredId = null;
      }

      final verified = boardStatus == 0 || boardStatus == 1 || discoveredId != null;
      if (!verified) {
        return null;
      }

      return DiscoveredSensor(
        ip: ip,
        moduleId: discoveredId,
        verified: true,
        fromHistory: false,
      );
    } catch (_) {
      return null;
    } finally {
      await probe.disconnect();
    }
  }

  void _registerDiscoveredSensor(DiscoveredSensor sensor, {bool notify = true}) {
    final byIp = <String, DiscoveredSensor>{
      for (final item in discoveredSensors) item.ip: item,
    };
    final existing = byIp[sensor.ip];
    if (existing == null) {
      byIp[sensor.ip] = sensor;
    } else {
      byIp[sensor.ip] = DiscoveredSensor(
        ip: sensor.ip,
        moduleId: sensor.moduleId ?? existing.moduleId,
        verified: existing.verified || sensor.verified,
        fromHistory: existing.fromHistory && sensor.fromHistory,
      );
    }
    discoveredSensors = _sortedSensors(byIp.values.toList());
    if (notify) {
      notifyListeners();
    }
  }

  List<DiscoveredSensor> _sortedSensors(List<DiscoveredSensor> sensors) {
    final sorted = [...sensors];
    sorted.sort((a, b) {
      if (a.verified != b.verified) {
        return a.verified ? -1 : 1;
      }
      if (a.fromHistory != b.fromHistory) {
        return a.fromHistory ? 1 : -1;
      }
      return a.ip.compareTo(b.ip);
    });
    return sorted;
  }

  String? _subnetOf(String ip) {
    if (!_isValidIpv4(ip)) {
      return null;
    }
    final parts = ip.split('.');
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  bool _isValidIpv4(String value) {
    final ip = value.trim();
    if (!_ipv4Pattern.hasMatch(ip)) {
      return false;
    }
    final parts = ip.split('.');
    if (parts.length != 4) {
      return false;
    }
    for (final part in parts) {
      final octet = int.tryParse(part);
      if (octet == null || octet < 0 || octet > 255) {
        return false;
      }
    }
    return true;
  }

  List<String> _orderedUnique(Iterable<String> values) {
    final seen = <String>{};
    final ordered = <String>[];
    for (final raw in values) {
      final ip = raw.trim();
      if (!_isValidIpv4(ip)) {
        continue;
      }
      if (seen.add(ip)) {
        ordered.add(ip);
      }
    }
    return ordered;
  }

  void requestSensorPicker({bool startDiscovery = false}) {
    _triggerSensorPickerPrompt(startDiscovery: startDiscovery);
    notifyListeners();
  }

  void _triggerSensorPickerPrompt({bool startDiscovery = false}) {
    sensorPickerPromptSignal += 1;
    if (startDiscovery) {
      Future.microtask(() {
        unawaited(discoverSensors());
      });
    }
  }
}
