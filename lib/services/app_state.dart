import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../data/si_nir_client.dart';
import '../data/si_nir_protocol.dart';
import '../data/storage/data_store.dart';
import '../domain/analyzer.dart';
import '../domain/averaging.dart';
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

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  static const List<String> _defaultKnownIps = [
    '10.92.71.8',
    '10.13.199.8',
  ];
  static final RegExp _ipv4Pattern = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
  static const List<String> _bundledModelAssetPaths = [
    'assets/models/species_model.json',
    'assets/models/moisture_model.json',
  ];

  final SiNirClient client = SiNirClient();
  final DataStore dataStore = DataStore();
  final LocationService locationService = LocationService();
  final Uuid _uuid = const Uuid();

  bool isConnecting = false;
  bool isConnected = false;
  bool isVerifyingConnection = false;
  String statusMessage = 'Disconnected';
  String? moduleId;
  String currentIp = '10.92.71.8';
  bool sendLengthPrefix = false;
  bool showGhNhDiagnostics = false;
  bool hasBackground = false;
  bool isBackgrounding = false;
  bool isScanning = false;
  int captureCount = 0;
  int currentTab = 0;
  ThemeMode themeMode = ThemeMode.light;
  String spectrumAxisUnit = 'nm';
  bool showConnectScreen = true;
  Timer? _connectDelayTimer;
  String materialName = '';
  String sampleName = '';
  bool isDiscovering = false;
  List<DiscoveredSensor> discoveredSensors = const [];
  List<String> _recentIps = const [];
  int sensorPickerPromptSignal = 0;
  int _discoveryRunId = 0;
  Completer<void>? _activeDiscoveryCompletion;
  final Set<String> _referenceReadyIps = <String>{};
  bool _reconnectOnResume = false;
  bool _isLifecycleDisconnecting = false;
  bool _disposed = false;

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
  List<CalibrationModel> availableModels = const [];
  Set<String> selectedModelIds = <String>{};
  List<AnalysisResult> latestAnalysisResults = const [];

  int targetScanCount = 1;
  AveragingMethod averagingMethod = AveragingMethod.mean;
  List<Spectrum> acquiredSpectra = const [];
  int currentScanIndex = 0;

  static const int _minScanCount = 1;
  static const int _maxScanCount = 20;

  void updateTargetScanCount(int value) {
    final clamped = value < _minScanCount
        ? _minScanCount
        : (value > _maxScanCount ? _maxScanCount : value);
    if (clamped == targetScanCount) {
      return;
    }
    targetScanCount = clamped;
    notifyListeners();
  }

  void updateAveragingMethod(AveragingMethod method) {
    if (method == averagingMethod) {
      return;
    }
    averagingMethod = method;
    if (acquiredSpectra.length > 1) {
      latestSpectrum = averageSpectra(acquiredSpectra, method: averagingMethod);
      _runSelectedModelAnalysis(notify: false);
    }
    notifyListeners();
  }

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    await dataStore.init();
    await _loadKnownDevices();
    await _loadBundledModels(notify: false);
    notifyListeners();
    // Kick off discovery in the background so the picker already has live
    // sensors by the time the user taps INITIALIZE or "Find devices".
    unawaited(discoverSensors());
  }

  Future<void> forgetSavedSensors() async {
    try {
      await dataStore.clearDevices();
    } catch (_) {
      // Best-effort wipe — fall through to in-memory cleanup regardless.
    }
    _recentIps = const [];
    discoveredSensors = const [];
    statusMessage = 'Saved sensors cleared';
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) {
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (isConnected || isConnecting || isVerifyingConnection) {
        _reconnectOnResume = true;
        unawaited(_disconnectForLifecycle());
      }
      return;
    }

    if (state == AppLifecycleState.resumed && _reconnectOnResume) {
      _reconnectOnResume = false;
      unawaited(_reconnectAfterResume());
    }
  }

  Future<void> _disconnectForLifecycle() async {
    if (_isLifecycleDisconnecting || _disposed) {
      return;
    }
    _isLifecycleDisconnecting = true;

    _connectDelayTimer?.cancel();
    _cancelDiscovery(notify: false);
    try {
      await client.disconnect();
    } catch (_) {
      // Best-effort close only.
    }

    isConnected = false;
    isConnecting = false;
    isVerifyingConnection = false;
    isBackgrounding = false;
    isScanning = false;
    _syncReferenceFromCurrentIp();
    showConnectScreen = true;
    statusMessage = 'Paused. Reconnecting when app resumes...';

    _isLifecycleDisconnecting = false;
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> _reconnectAfterResume() async {
    if (_disposed || _isLifecycleDisconnecting) {
      return;
    }
    if (currentIp.trim().isEmpty) {
      return;
    }

    statusMessage = 'Reconnecting to sensor...';
    notifyListeners();
    await connect(preferredIp: currentIp, fallbackToKnown: true);
  }

  Future<void> connect({
    String? preferredIp,
    bool fallbackToKnown = false,
  }) async {
    _cancelDiscovery(notify: false);
    isConnecting = true;
    statusMessage = 'Connecting...';
    _connectDelayTimer?.cancel();
    showConnectScreen = true;
    notifyListeners();
    try {
      await _waitForDiscoveryDrain();
      client.sendLengthPrefix = sendLengthPrefix;
      final attempts = await _connectionAttempts(
        preferredIp: preferredIp,
        fallbackToKnown: fallbackToKnown,
      );

      Exception? lastError;
      for (final ip in attempts) {
        try {
          await client.disconnect();
          await client.connect(ip, timeout: const Duration(seconds: 4));
          isConnected = true;
          currentIp = ip;
          _syncReferenceFromCurrentIp();
          backgroundSpectrum = null;
          latestSpectrum = null;
          _cancelDiscovery(notify: false);
          statusMessage = 'Connected (verifying...)';
          isVerifyingConnection = true;
          setTab(0);
          _startConnectDelay();
          _registerDiscoveredSensor(
            DiscoveredSensor(ip: ip, verified: true, fromHistory: true),
            notify: false,
          );
          _reconnectOnResume = false;
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
    _connectDelayTimer = Timer(const Duration(seconds: 2), () {
      showConnectScreen = false;
      if (isConnected) {
        setTab(1);
        return;
      }
      notifyListeners();
    });
  }

  Future<void> _verifyDevice() async {
    const boardTimeout = Duration(seconds: 6);
    const idTimeout = Duration(seconds: 6);
    isVerifyingConnection = true;
    notifyListeners();
    try {
      try {
        final board = await client.checkBoard(timeout: boardTimeout);
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
        final id = (await client.readModuleId(timeout: idTimeout)).trim();
        moduleId = id.isEmpty ? null : id;
        if (moduleId != null) {
          await dataStore.upsertDevice(
            id: moduleId!,
            name: 'Si-NIR',
            ip: currentIp,
          );
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
      } catch (_) {
        statusMessage = 'Connected (ID unavailable)';
      }
    } finally {
      isVerifyingConnection = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _reconnectOnResume = false;
    _connectDelayTimer?.cancel();
    _cancelDiscovery(notify: false);
    await client.disconnect();
    isConnected = false;
    isVerifyingConnection = false;
    _syncReferenceFromCurrentIp();
    isBackgrounding = false;
    isScanning = false;
    showConnectScreen = true;
    setTab(0);
    statusMessage = 'Disconnected';
    notifyListeners();
  }

  void setCurrentIp(String value, {bool notify = true}) {
    final ip = value.trim();
    if (ip.isEmpty) {
      return;
    }
    currentIp = ip;
    _syncReferenceFromCurrentIp();
    _registerDiscoveredSensor(
      DiscoveredSensor(ip: ip, verified: false, fromHistory: true),
      notify: false,
    );
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> connectToSensor(DiscoveredSensor sensor) async {
    _cancelDiscovery(notify: false);
    setCurrentIp(sensor.ip, notify: false);
    await connect(preferredIp: sensor.ip, fallbackToKnown: false);
  }

  Future<void> discoverSensors() async {
    if (isDiscovering || isConnecting || isConnected) {
      return;
    }

    final scanId = ++_discoveryRunId;
    final completion = Completer<void>();
    _activeDiscoveryCompletion = completion;

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
        if (scanId != _discoveryRunId || isConnected || isConnecting) {
          return null;
        }
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
          if (scanId != _discoveryRunId || isConnected || isConnecting) {
            return;
          }
          if (probed == null) {
            continue;
          }

          final existing = foundByIp[ip];
          final shouldReplace =
              existing == null ||
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
      final newCount = discoveredSensors
          .where((sensor) => !sensor.fromHistory)
          .length;
      statusMessage = newCount == 0
          ? 'No new devices found. Select a known IP.'
          : 'Found $newCount device(s). Select one to connect.';
    } catch (error) {
      statusMessage = 'Device search failed: $error';
    } finally {
      if (!completion.isCompleted) {
        completion.complete();
      }
      if (identical(_activeDiscoveryCompletion, completion)) {
        _activeDiscoveryCompletion = null;
      }
      if (scanId == _discoveryRunId) {
        isDiscovering = false;
        notifyListeners();
      }
    }
  }

  Future<void> runBackground() async {
    if (!isConnected || isBackgrounding || isScanning) return;
    if (isVerifyingConnection) {
      statusMessage = 'Please wait for connection verification to finish.';
      notifyListeners();
      return;
    }
    _cancelDiscovery(notify: false);
    await _waitForDiscoveryDrain();
    statusMessage = 'Running background...';
    isBackgrounding = true;
    notifyListeners();
    try {
      final status = await client.runBackground(
        scanParams,
        timeout: const Duration(seconds: 20),
      );
      if (status == 0) {
        _rememberReferenceForCurrentIp(true);
        statusMessage = 'Reference captured';
      } else {
        _rememberReferenceForCurrentIp(false);
        statusMessage = 'Background error $status';
      }
    } catch (error) {
      _rememberReferenceForCurrentIp(false);
      final lost = await _handleConnectionLossIfNeeded(
        error,
        actionLabel: 'Background',
      );
      if (!lost) {
        if (error is TimeoutException) {
          statusMessage =
              'Background timeout. Check sensor power adapter/cable and try again.';
        } else {
          statusMessage = 'Background failed: $error';
        }
      }
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
    final scanTotal = targetScanCount < 1 ? 1 : targetScanCount;
    isScanning = true;
    currentScanIndex = 0;
    acquiredSpectra = const [];
    final collected = <Spectrum>[];
    statusMessage = scanTotal == 1
        ? 'Scanning spectrum...'
        : 'Scanning 1/$scanTotal...';
    notifyListeners();
    try {
      for (var i = 0; i < scanTotal; i++) {
        currentScanIndex = i + 1;
        if (scanTotal > 1) {
          statusMessage = 'Scanning $currentScanIndex/$scanTotal...';
          notifyListeners();
        }
        final spectrum = await client.runSpectrum(
          scanParams,
          timeout: const Duration(seconds: 20),
        );
        collected.add(spectrum);
        acquiredSpectra = List.unmodifiable(collected);
      }
      latestSpectrum = collected.length == 1
          ? collected.first
          : averageSpectra(collected, method: averagingMethod);
      _runSelectedModelAnalysis(notify: false);
      statusMessage = scanTotal == 1
          ? 'Ready to Scan'
          : 'Captured $scanTotal scans (${averagingMethod.label})';
      captureCount += 1;
    } catch (error) {
      acquiredSpectra = const [];
      final lost = await _handleConnectionLossIfNeeded(
        error,
        actionLabel: 'Spectrum',
      );
      if (!lost) {
        if (_isLikelyMissingReferenceError(error)) {
          _rememberReferenceForCurrentIp(false);
          statusMessage = 'Reference required. Tap Set reference.';
        } else {
          statusMessage = 'Spectrum failed: $error';
        }
      }
    } finally {
      isScanning = false;
      currentScanIndex = 0;
    }
    notifyListeners();
  }

  Future<void> runPsd() async {
    if (!isConnected) return;
    statusMessage = 'Scanning PSD...';
    notifyListeners();
    try {
      latestSpectrum = await client.runPsd(
        scanParams,
        timeout: const Duration(seconds: 20),
      );
      _runSelectedModelAnalysis(notify: false);
      statusMessage = 'PSD ready';
    } catch (error) {
      final lost = await _handleConnectionLossIfNeeded(
        error,
        actionLabel: 'PSD',
      );
      if (!lost) {
        statusMessage = 'PSD failed: $error';
      }
    }
    notifyListeners();
  }

  List<CalibrationModel> get selectedModels {
    return availableModels
        .where((model) => selectedModelIds.contains(model.id))
        .toList(growable: false);
  }

  bool isModelSelected(String modelId) => selectedModelIds.contains(modelId);

  void setSelectedModelIds(Set<String> modelIds) {
    selectedModelIds = Set<String>.from(modelIds);
    _runSelectedModelAnalysis(notify: false);
    notifyListeners();
  }

  void toggleModelSelection(String modelId, bool isSelected) {
    if (isSelected) {
      selectedModelIds.add(modelId);
    } else {
      selectedModelIds.remove(modelId);
    }
    _runSelectedModelAnalysis(notify: false);
    notifyListeners();
  }

  Future<void> analyze() async {
    _runSelectedModelAnalysis(notify: false);
    notifyListeners();
  }

  Future<void> saveSession() async {
    if (latestSpectrum == null) return;
    final measurementId = _uuid.v4();
    final position = await locationService.getCurrentPosition();
    final selectedResults = latestAnalysisResults;
    final selectedModelIdsOrdered = selectedResults
        .map((result) => result.modelId)
        .toList(growable: false);
    final resultPayload = selectedResults.isEmpty
        ? null
        : {
            'analyses': selectedResults
                .map((result) => result.toJson())
                .toList(),
            'summary': _buildAnalysisSummary(selectedResults),
          };
    final summary = resultPayload == null
        ? null
        : resultPayload['summary'] as String;

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
      modelId: selectedModelIdsOrdered.isEmpty
          ? null
          : selectedModelIdsOrdered.first,
      modelIdsJson: selectedModelIdsOrdered.isEmpty
          ? null
          : jsonEncode(selectedModelIdsOrdered),
      resultsJson: resultPayload == null ? null : jsonEncode(resultPayload),
      analysisSummary: summary,
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
    acquiredSpectra = const [];
    latestAnalysisResults = const [];
    statusMessage = 'Scan discarded';
    notifyListeners();
  }

  Future<void> _loadBundledModels({bool notify = true}) async {
    try {
      final parsed = <CalibrationModel>[];
      for (final assetPath in _bundledModelAssetPaths) {
        try {
          final jsonText = await rootBundle.loadString(assetPath);
          parsed.add(CalibrationModel.fromJson(jsonText));
        } catch (_) {
          // Ignore invalid bundled model payloads.
        }
      }

      availableModels = parsed;
      final availableIds = parsed.map((model) => model.id).toSet();
      selectedModelIds = selectedModelIds.where(availableIds.contains).toSet();
      _runSelectedModelAnalysis(notify: false);
    } catch (_) {
      availableModels = const [];
      selectedModelIds = <String>{};
      latestAnalysisResults = const [];
    }

    if (notify) {
      notifyListeners();
    }
  }

  void _runSelectedModelAnalysis({bool notify = true}) {
    final spectrum = latestSpectrum;
    if (spectrum == null ||
        selectedModelIds.isEmpty ||
        availableModels.isEmpty) {
      latestAnalysisResults = const [];
      if (notify) {
        notifyListeners();
      }
      return;
    }

    final outputs = <AnalysisResult>[];
    for (final model in availableModels) {
      if (!selectedModelIds.contains(model.id)) {
        continue;
      }
      try {
        outputs.add(runAnalysis(spectrum, model));
      } catch (_) {
        // Ignore model failures for this scan.
      }
    }

    latestAnalysisResults = outputs;
    if (notify) {
      notifyListeners();
    }
  }

  String _buildAnalysisSummary(List<AnalysisResult> results) {
    if (results.isEmpty) {
      return '';
    }
    return results.map((result) => result.summary).join(', ');
  }

  Future<bool> _handleConnectionLossIfNeeded(
    Object error, {
    required String actionLabel,
  }) async {
    if (!_isLikelyConnectionError(error)) {
      return false;
    }

    _reconnectOnResume = false;
    try {
      await client.disconnect();
    } catch (_) {
      // Best-effort close only.
    }

    isConnected = false;
    isConnecting = false;
    isVerifyingConnection = false;
    _syncReferenceFromCurrentIp();
    showConnectScreen = true;
    statusMessage = '$actionLabel failed: connection lost. Please reconnect.';
    return true;
  }

  bool _isLikelyConnectionError(Object error) {
    if (error is SocketException) {
      return true;
    }
    final text = error.toString().toLowerCase();
    return text.contains('not connected') ||
        text.contains('connection reset') ||
        text.contains('broken pipe') ||
        text.contains('socket') ||
        text.contains('connection aborted');
  }

  bool _isLikelyMissingReferenceError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('device returned status');
  }

  void _rememberReferenceForCurrentIp(bool ready) {
    final ip = currentIp.trim();
    if (ip.isNotEmpty) {
      if (ready) {
        _referenceReadyIps.add(ip);
      } else {
        _referenceReadyIps.remove(ip);
      }
    }
    hasBackground = ready;
  }

  void _syncReferenceFromCurrentIp() {
    final ip = currentIp.trim();
    if (ip.isEmpty) {
      hasBackground = false;
      return;
    }
    hasBackground = _referenceReadyIps.contains(ip);
  }

  Future<void> requestStoragePermission() async {
    await Permission.storage.request();
  }

  void updateSendLengthPrefix(bool value) {
    sendLengthPrefix = value;
    client.sendLengthPrefix = value;
    notifyListeners();
  }

  void updateShowGhNhDiagnostics(bool value) {
    showGhNhDiagnostics = value;
    notifyListeners();
  }

  void updateMaterialName(String value, {bool notify = true}) {
    materialName = value;
    if (notify) {
      notifyListeners();
    }
  }

  void updateSampleName(String value, {bool notify = true}) {
    sampleName = value;
    if (notify) {
      notifyListeners();
    }
  }

  void setTab(int value) {
    if (currentTab == value) return;
    currentTab = value;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    notifyListeners();
  }

  void updateSpectrumAxisUnit(String unit) {
    spectrumAxisUnit = unit;
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
      statusMessage = status == 0
          ? 'Source settings applied'
          : 'Source error $status';
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
      statusMessage = status == 0
          ? 'Optical gain applied'
          : 'Optical gain error $status';
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
    _syncReferenceFromCurrentIp();
    discoveredSensors = _sortedSensors(
      knownIps
          .map(
            (ip) =>
                DiscoveredSensor(ip: ip, verified: false, fromHistory: true),
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

  Future<List<String>> _connectionAttempts({
    String? preferredIp,
    bool fallbackToKnown = true,
  }) async {
    await _refreshKnownIps();
    final preferred = preferredIp?.trim() ?? currentIp;
    if (!fallbackToKnown) {
      return _orderedUnique([preferred]);
    }
    return _orderedUnique([preferred, ..._recentIps, ..._defaultKnownIps]);
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

    // 1. Auto-detect subnets from local non-cellular interfaces (highest priority).
    //    Handles the case where the phone is hosting a hotspot on an unknown
    //    subnet (e.g. 10.96.177.x) or has joined someone else's hotspot.
    for (final subnet in await _detectLocalSubnets()) {
      if (!subnets.contains(subnet)) {
        subnets.add(subnet);
      }
    }

    // 2. Add subnets from current/recent/known IPs, restricted to RFC1918 ranges.
    for (final ip in seeds) {
      final subnet = _subnetOf(ip);
      if (subnet == null || subnets.contains(subnet)) {
        continue;
      }
      if (_isPrivateIpv4(ip)) {
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

  Future<List<String>> _detectLocalSubnets() async {
    final detected = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      // Exclude cellular/PPP interfaces — we only want Wi-Fi / Wi-Fi tether / USB tether.
      final cellularPattern = RegExp(
        r'(rmnet|ccmni|pdp_ip|ppp|cellular)',
        caseSensitive: false,
      );
      for (final iface in interfaces) {
        if (cellularPattern.hasMatch(iface.name)) {
          continue;
        }
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (!_isValidIpv4(ip) || !_isPrivateIpv4(ip)) {
            continue;
          }
          final subnet = _subnetOf(ip);
          if (subnet != null && !detected.contains(subnet)) {
            detected.add(subnet);
          }
        }
      }
    } catch (_) {
      // Best-effort only; platform may restrict interface enumeration.
    }
    return detected;
  }

  bool _isPrivateIpv4(String value) {
    final ip = value.trim();
    if (!_isValidIpv4(ip)) {
      return false;
    }
    final parts = ip.split('.');
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) {
      return false;
    }
    if (a == 10) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    if (a == 192 && b == 168) return true;
    return false;
  }

  Future<DiscoveredSensor?> _probeSensor(String ip) async {
    final probe = SiNirClient()..sendLengthPrefix = sendLengthPrefix;
    try {
      await probe.connect(ip, timeout: const Duration(milliseconds: 280));
      return DiscoveredSensor(
        ip: ip,
        moduleId: null,
        verified: false,
        fromHistory: false,
      );
    } catch (_) {
      return null;
    } finally {
      await probe.disconnect();
    }
  }

  void _registerDiscoveredSensor(
    DiscoveredSensor sensor, {
    bool notify = true,
  }) {
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

  void _cancelDiscovery({bool notify = true}) {
    _discoveryRunId += 1;
    if (!isDiscovering) {
      return;
    }
    isDiscovering = false;
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _waitForDiscoveryDrain() async {
    final completion = _activeDiscoveryCompletion;
    if (completion == null) {
      return;
    }
    try {
      await completion.future.timeout(const Duration(milliseconds: 900));
    } catch (_) {
      // Best-effort wait only.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _connectDelayTimer?.cancel();
    unawaited(client.disconnect());
    super.dispose();
  }
}
