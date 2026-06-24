/// Centralized keys used for persisting user settings via DataStore.
/// Kept as a class of static constants so the IDE flags typos.
class SettingsKeys {
  SettingsKeys._();

  static const themeMode = 'themeMode';
  static const spectrumAxisUnit = 'spectrumAxisUnit';
  static const showGhNhDiagnostics = 'showGhNhDiagnostics';
  static const sendLengthPrefix = 'sendLengthPrefix';

  // GH/NH diagnostic threshold overrides. Empty string = use model default.
  static const ghWarningThreshold = 'ghWarningThreshold';
  static const ghOutlierThreshold = 'ghOutlierThreshold';
  static const nhWarningThreshold = 'nhWarningThreshold';
  static const nhOutlierThreshold = 'nhOutlierThreshold';

  static const scanTimeMs = 'scanTimeMs';
  static const zeroPadding = 'zeroPadding';
  static const commonWavNum = 'commonWavNum';
  static const opticalGain = 'opticalGain';
  static const apodizationSel = 'apodizationSel';

  static const targetScanCount = 'targetScanCount';
  static const averagingMethod = 'averagingMethod';
  static const referenceMaxAgeMin = 'referenceMaxAgeMin';
  static const continuousMode = 'continuousMode';
  static const scanIntervalMs = 'scanIntervalMs';

  static const lampsCount = 'lampsCount';
  static const lampSelect = 'lampSelect';
  static const t1 = 't1';
  static const deltaT = 'deltaT';
  static const t2c1 = 't2c1';
  static const t2c2 = 't2c2';
  static const t2max = 't2max';
  static const opticalGainValue = 'opticalGainValue';

  static const onboardingSeen = 'onboardingSeen';
  static const locale = 'locale';
}
