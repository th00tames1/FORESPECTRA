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
import 'i18n.dart';
import 'location_service.dart';
import 'mdns_discovery.dart';
import 'settings_keys.dart';

// AppState is large enough that it is split by concern across part files.
// Each part declares an `extension on AppState`; because parts share this
// library they have full access to AppState's (private) fields.
part 'app_state_connection.dart';
part 'app_state_scanning.dart';
part 'app_state_models.dart';
part 'app_state_settings.dart';

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
  bool onboardingSeen = false;
  String locale = AppLocale.en;
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
  final Map<String, DateTime> _referenceSetAt = <String, DateTime>{};
  Duration referenceMaxAge = const Duration(hours: 1);
  bool _mdnsAvailable = true;
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

  // Batch mode: keep material name across saves, auto-increment sample suffix.
  bool batchModeEnabled = false;
  String batchSamplePrefix = '';
  int batchSampleCounter = 1;

  /// Public wrapper around the `@protected` [notifyListeners] so the concern
  /// extensions in the part files can request a UI rebuild.
  void notifyUi() => notifyListeners();

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    await dataStore.init();
    await loadKnownDevices();
    await loadPersistedReferenceState();
    await loadPersistedSettings();
    await loadBundledModels(notify: false);
    notifyListeners();
    unawaited(discoverSensors());
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
        unawaited(disconnectForLifecycle());
      }
      return;
    }

    if (state == AppLifecycleState.resumed && _reconnectOnResume) {
      _reconnectOnResume = false;
      unawaited(reconnectAfterResume());
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
