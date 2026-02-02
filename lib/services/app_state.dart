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

class AppState extends ChangeNotifier {
  final SiNirClient client = SiNirClient();
  final DataStore dataStore = DataStore();
  final LocationService locationService = LocationService();
  final Uuid _uuid = const Uuid();

  bool isConnecting = false;
  bool isConnected = false;
  String statusMessage = 'Disconnected';
  String? moduleId;
  String currentIp = '192.168.137.2';
  bool sendLengthPrefix = true;

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
  }

  Future<void> connect() async {
    isConnecting = true;
    statusMessage = 'Connecting...';
    notifyListeners();
    try {
      client.sendLengthPrefix = sendLengthPrefix;
      final attempts = <String>{
        currentIp,
        '192.168.144.2',
        '192.168.137.2',
      }.toList();

      Exception? lastError;
      for (final ip in attempts) {
        try {
          await client.disconnect();
          await client.connect(ip, timeout: const Duration(seconds: 6));
          final board = await client.checkBoard();
          moduleId = await client.readModuleId();
          isConnected = true;
          currentIp = ip;
          statusMessage = board == 1 ? 'Connected' : 'Connected (board status $board)';
          if (moduleId != null) {
            await dataStore.upsertDevice(id: moduleId!, name: 'Si-NIR', ip: currentIp);
          }
          notifyListeners();
          return;
        } catch (error) {
          lastError = error is Exception ? error : Exception(error.toString());
        }
      }
      throw lastError ?? Exception('Unable to connect');
    } catch (error) {
      statusMessage = 'Connection failed: $error';
      isConnected = false;
    } finally {
      isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    await client.disconnect();
    isConnected = false;
    statusMessage = 'Disconnected';
    notifyListeners();
  }

  Future<void> runBackground() async {
    if (!isConnected) return;
    statusMessage = 'Running background...';
    notifyListeners();
    try {
      final status = await client.runBackground(scanParams);
      statusMessage = status == 0 ? 'Background captured' : 'Background error $status';
    } catch (error) {
      statusMessage = 'Background failed: $error';
    }
    notifyListeners();
  }

  Future<void> runSpectrum() async {
    if (!isConnected) return;
    statusMessage = 'Scanning spectrum...';
    notifyListeners();
    try {
      latestSpectrum = await client.runSpectrum(scanParams);
      statusMessage = 'Spectrum ready';
    } catch (error) {
      statusMessage = 'Spectrum failed: $error';
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

  Future<void> requestStoragePermission() async {
    await Permission.storage.request();
  }

  void updateSendLengthPrefix(bool value) {
    sendLengthPrefix = value;
    client.sendLengthPrefix = value;
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
}
