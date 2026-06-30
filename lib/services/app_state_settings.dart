part of 'app_state.dart';

// ── Settings / preferences concern ────────────────────────────────────
// Persisted preference load, theme/locale, and every user-tunable
// measurement / scan / source parameter setter.

const int _minScanCount = 1;
const int _maxScanCount = 20;

extension AppStateSettings on AppState {
  Future<void> loadPersistedSettings() async {
    try {
      final map = await dataStore.loadAllSettings();

      void readInt(String key, void Function(int) apply) {
        final v = int.tryParse(map[key] ?? '');
        if (v != null) apply(v);
      }

      void readString(String key, void Function(String) apply) {
        final v = map[key];
        if (v != null) apply(v);
      }

      void readBool(String key, void Function(bool) apply) {
        final v = map[key];
        if (v != null) apply(v == 'true');
      }

      readBool(SettingsKeys.onboardingSeen, (v) => onboardingSeen = v);
      readString(SettingsKeys.locale, (v) {
        if (v == AppLocale.ko || v == AppLocale.en) {
          locale = v;
          Strings.instance.setLocale(v);
        }
      });
      readString(SettingsKeys.themeMode, (v) {
        if (v == 'dark') themeMode = ThemeMode.dark;
        if (v == 'light') themeMode = ThemeMode.light;
      });
      readString(SettingsKeys.spectrumAxisUnit, (v) => spectrumAxisUnit = v);
      readBool(SettingsKeys.showGhNhDiagnostics,
          (v) => showGhNhDiagnostics = v);
      readString(SettingsKeys.ghWarningThreshold,
          (v) => ghWarningThreshold = _parseThreshold(v));
      readString(SettingsKeys.ghOutlierThreshold,
          (v) => ghOutlierThreshold = _parseThreshold(v));
      readString(SettingsKeys.nhWarningThreshold,
          (v) => nhWarningThreshold = _parseThreshold(v));
      readString(SettingsKeys.nhOutlierThreshold,
          (v) => nhOutlierThreshold = _parseThreshold(v));
      readBool(SettingsKeys.sendLengthPrefix, (v) {
        sendLengthPrefix = v;
        client.sendLengthPrefix = v;
      });

      readInt(SettingsKeys.scanTimeMs, (v) => scanParams.scanTimeMs = v);
      readInt(SettingsKeys.zeroPadding, (v) => scanParams.zeroPadding = v);
      readInt(SettingsKeys.commonWavNum, (v) => scanParams.commonWavNum = v);
      readInt(SettingsKeys.opticalGain, (v) => scanParams.opticalGain = v);
      readInt(SettingsKeys.apodizationSel,
          (v) => scanParams.apodizationSel = v);

      readInt(SettingsKeys.targetScanCount, (v) => targetScanCount = v);
      readString(SettingsKeys.averagingMethod,
          (v) => averagingMethod = AveragingMethodLabel.fromId(v));
      readInt(SettingsKeys.trimDropCount,
          (v) => trimDropCount = _clampTrimDrop(v));
      readInt(SettingsKeys.referenceMaxAgeMin,
          (v) => referenceMaxAge = Duration(minutes: v < 1 ? 1 : v));
      readBool(SettingsKeys.continuousMode, (v) => continuousMode = v);

      readInt(SettingsKeys.lampsCount, (v) => lampsCount = v);
      readInt(SettingsKeys.lampSelect, (v) => lampSelect = v);
      readInt(SettingsKeys.t1, (v) => t1 = v);
      readInt(SettingsKeys.deltaT, (v) => deltaT = v);
      readInt(SettingsKeys.t2c1, (v) => t2c1 = v);
      readInt(SettingsKeys.t2c2, (v) => t2c2 = v);
      readInt(SettingsKeys.t2max, (v) => t2max = v);
      readInt(SettingsKeys.opticalGainValue, (v) => opticalGainValue = v);
    } catch (_) {
      // Best-effort; defaults stay if any read fails.
    }
  }

  void _persist(String key, String value) {
    unawaited(dataStore.writeSetting(key, value));
  }

  /// Assign an int field, persist it, and notify - collapses the dozens of
  /// near-identical `update*` setters below.
  void _setInt(String key, int value, void Function(int) assign) {
    assign(value);
    _persist(key, '$value');
    notifyUi();
  }

  void updateTargetScanCount(int value) {
    final clamped = value < _minScanCount
        ? _minScanCount
        : (value > _maxScanCount ? _maxScanCount : value);
    if (clamped == targetScanCount) {
      return;
    }
    targetScanCount = clamped;
    _persist(SettingsKeys.targetScanCount, '$clamped');
    notifyUi();
  }

  void updateContinuousMode(bool value) {
    if (value == continuousMode) return;
    continuousMode = value;
    _persist(SettingsKeys.continuousMode, '$value');
    notifyUi();
  }

  // Max scans is 20, so at most 18 can be dropped while keeping 2 to average.
  int _clampTrimDrop(int v) => v < 0 ? 0 : (v > 18 ? 18 : v);

  void updateAveragingMethod(AveragingMethod method) {
    if (method == averagingMethod) {
      return;
    }
    averagingMethod = method;
    recomputeCombine();
    _persist(SettingsKeys.averagingMethod, method.id);
    notifyUi();
  }

  void updateTrimDropCount(int value) {
    final clamped = _clampTrimDrop(value);
    if (clamped == trimDropCount) return;
    trimDropCount = clamped;
    if (averagingMethod == AveragingMethod.trimmedMean) {
      recomputeCombine();
    }
    _persist(SettingsKeys.trimDropCount, '$clamped');
    notifyUi();
  }

  Future<void> markOnboardingSeen() async {
    onboardingSeen = true;
    _persist(SettingsKeys.onboardingSeen, 'true');
    notifyUi();
  }

  void setLocale(String value) {
    if (value == locale) return;
    locale = value;
    Strings.instance.setLocale(value);
    _persist(SettingsKeys.locale, value);
    notifyUi();
  }

  Future<void> requestStoragePermission() async {
    await Permission.storage.request();
  }

  void updateSendLengthPrefix(bool value) {
    sendLengthPrefix = value;
    client.sendLengthPrefix = value;
    _persist(SettingsKeys.sendLengthPrefix, '$value');
    notifyUi();
  }

  void updateShowGhNhDiagnostics(bool value) {
    showGhNhDiagnostics = value;
    _persist(SettingsKeys.showGhNhDiagnostics, '$value');
    notifyUi();
  }

  /// Parse a persisted threshold string. Empty/invalid/negative -> null
  /// (meaning "use the model's baked threshold").
  double? _parseThreshold(String raw) {
    final v = double.tryParse(raw.trim());
    if (v == null || !v.isFinite || v < 0) return null;
    return v;
  }

  void _setThreshold(String key, double? value, void Function(double?) assign) {
    assign(value);
    _persist(key, value == null ? '' : '$value');
    _runSelectedModelAnalysis(notify: false);
    notifyUi();
  }

  void updateGhWarningThreshold(double? v) =>
      _setThreshold(SettingsKeys.ghWarningThreshold, v,
          (x) => ghWarningThreshold = x);
  void updateGhOutlierThreshold(double? v) =>
      _setThreshold(SettingsKeys.ghOutlierThreshold, v,
          (x) => ghOutlierThreshold = x);
  void updateNhWarningThreshold(double? v) =>
      _setThreshold(SettingsKeys.nhWarningThreshold, v,
          (x) => nhWarningThreshold = x);
  void updateNhOutlierThreshold(double? v) =>
      _setThreshold(SettingsKeys.nhOutlierThreshold, v,
          (x) => nhOutlierThreshold = x);

  void setTab(int value) {
    if (currentTab == value) return;
    currentTab = value;
    notifyUi();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    _persist(
      SettingsKeys.themeMode,
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
    notifyUi();
  }

  /// Restore all user-tunable settings to their built-in defaults.
  /// Does not touch saved sensors, history, or models - only preferences.
  Future<void> resetSettings() async {
    themeMode = ThemeMode.light;
    showGhNhDiagnostics = false;
    ghWarningThreshold = null;
    ghOutlierThreshold = null;
    nhWarningThreshold = null;
    nhOutlierThreshold = null;
    spectrumAxisUnit = 'nm';

    sendLengthPrefix = false;
    client.sendLengthPrefix = false;

    scanParams = ScanParams();
    targetScanCount = 1;
    averagingMethod = AveragingMethod.mean;
    trimDropCount = 2;
    referenceMaxAge = const Duration(hours: 1);
    continuousMode = false;

    lampsCount = 2;
    lampSelect = 0;
    t1 = 14;
    deltaT = 2;
    t2c1 = 5;
    t2c2 = 35;
    t2max = 10;
    opticalGainValue = 0;

    _syncReferenceFromCurrentIp();
    // Re-derive the averaged spectrum + dropped scans for the reset combine
    // method, and refresh cached GH/NH levels for the cleared overrides.
    recomputeCombine();
    if (acquiredSpectra.length <= 1) {
      _runSelectedModelAnalysis(notify: false);
    }
    try {
      await dataStore.clearAllSettings();
    } catch (_) {
      // Best-effort; in-memory state is already reset.
    }
    // clearAllSettings wiped onboardingSeen/locale too, but reset deliberately
    // keeps those in memory; re-persist them so they survive the next launch.
    _persist(SettingsKeys.onboardingSeen, '$onboardingSeen');
    _persist(SettingsKeys.locale, locale);
    notifyUi();
  }

  void updateSpectrumAxisUnit(String unit) {
    spectrumAxisUnit = unit;
    _persist(SettingsKeys.spectrumAxisUnit, unit);
    notifyUi();
  }

  void updateScanTime(int v) =>
      _setInt(SettingsKeys.scanTimeMs, v, (x) => scanParams.scanTimeMs = x);
  void updateZeroPadding(int v) =>
      _setInt(SettingsKeys.zeroPadding, v, (x) => scanParams.zeroPadding = x);
  void updateCommonWavNum(int v) =>
      _setInt(SettingsKeys.commonWavNum, v, (x) => scanParams.commonWavNum = x);
  void updateOpticalGain(int v) =>
      _setInt(SettingsKeys.opticalGain, v, (x) => scanParams.opticalGain = x);
  void updateApodization(int v) => _setInt(
        SettingsKeys.apodizationSel,
        v,
        (x) => scanParams.apodizationSel = x,
      );

  void updateLampsCount(int v) =>
      _setInt(SettingsKeys.lampsCount, v, (x) => lampsCount = x);
  void updateLampSelect(int v) =>
      _setInt(SettingsKeys.lampSelect, v, (x) => lampSelect = x);
  void updateT1(int v) => _setInt(SettingsKeys.t1, v, (x) => t1 = x);
  void updateDeltaT(int v) =>
      _setInt(SettingsKeys.deltaT, v, (x) => deltaT = x);
  void updateT2C1(int v) => _setInt(SettingsKeys.t2c1, v, (x) => t2c1 = x);
  void updateT2C2(int v) => _setInt(SettingsKeys.t2c2, v, (x) => t2c2 = x);
  void updateT2Max(int v) => _setInt(SettingsKeys.t2max, v, (x) => t2max = x);
  void updateOpticalGainValue(int v) =>
      _setInt(SettingsKeys.opticalGainValue, v, (x) => opticalGainValue = x);

  void updateReferenceMaxAge(Duration value) {
    if (value == referenceMaxAge) return;
    referenceMaxAge = value;
    _persist(SettingsKeys.referenceMaxAgeMin, '${value.inMinutes}');
    _syncReferenceFromCurrentIp();
    notifyUi();
  }

  Future<void> applySourceSettings() async {
    if (!isConnected) return;
    statusMessage = 'Applying source settings...';
    notifyUi();
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
    notifyUi();
  }

  Future<void> applyOpticalSettings() async {
    if (!isConnected) return;
    statusMessage = 'Applying optical gain...';
    notifyUi();
    try {
      final status = await client.setOpticalSettings(opticalGainValue);
      statusMessage = status == 0
          ? 'Optical gain applied'
          : 'Optical gain error $status';
    } catch (error) {
      statusMessage = 'Optical gain failed: $error';
    }
    notifyUi();
  }
}
