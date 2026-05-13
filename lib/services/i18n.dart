import 'package:flutter/foundation.dart';

/// Minimal in-app translation layer. Add new keys to both maps as needed.
/// Wider Flutter i18n (gen_l10n + .arb files) is the proper long-term path;
/// this layer exists so we can ship Korean labels incrementally.
class AppLocale {
  static const en = 'en';
  static const ko = 'ko';
}

/// Shorthand for `Strings.instance.t(key)` so call-sites stay short.
String t(String key) => Strings.instance.t(key);

class Strings extends ChangeNotifier {
  Strings._();
  static final Strings instance = Strings._();

  String _locale = AppLocale.en;
  String get locale => _locale;

  void setLocale(String locale) {
    if (locale == _locale) return;
    _locale = locale;
    notifyListeners();
  }

  String t(String key) {
    final dict = _locale == AppLocale.ko ? _ko : _en;
    return dict[key] ?? _en[key] ?? key;
  }
}

// Keep keys lower-case dotted (`namespace.label`) to scale.
const Map<String, String> _en = {
  'common.save': 'Save',
  'common.cancel': 'Cancel',
  'common.reset': 'Reset',
  'common.clear': 'Clear',
  'nav.connect': 'Connect',
  'nav.scan': 'Scan',
  'nav.history': 'History',
  'nav.config': 'Config',
  'connect.initialize': 'INITIALIZE',
  'connect.online': 'ONLINE',
  'connect.connecting': 'CONNECTING...',
  'connect.findDevices': 'Find devices',
  'connect.searching': 'Searching for devices...',
  'connect.sensorConnected': 'Sensor Connected',
  'connect.readyToScan': 'Ready to scan',
  'connect.tapToLink': 'Tap to link with the spectrometer',
  'connect.lookingForDevice': 'Looking for your device',
  'scan.title': 'Scan',
  'scan.scanning': 'SCANNING...',
  'scan.scan': 'SCAN',
  'scan.setReference': 'Set reference',
  'scan.referenceSet': 'Reference set',
  'scan.material': 'Material name',
  'scan.sample': 'Sample name',
  'scan.batchMode': 'Batch mode',
  'scan.next': 'Next',
  'scan.materialHint': 'e.g. Pine',
  'scan.sampleHint': 'e.g. Sample A',
  'scan.sampleAuto': 'Auto-generated',
  'results.title': 'Results',
  'history.title': 'History',
  'history.searchHint': 'Search by device or session',
  'config.title': 'Config',
  'config.general': 'General',
  'config.advanced': 'Advanced',
  'config.theme': 'Theme',
  'config.themeLight': 'Light mode',
  'config.themeDark': 'Dark mode',
  'config.language': 'Language',
  'config.savedSensors': 'Saved sensors',
  'config.savedSensorsSubtitle': 'Clear stored device IPs from the picker.',
  'config.resetDefaults': 'Reset to defaults',
  'config.resetDefaultsSubtitle':
      'Restore all preferences. Saved sensors and history are kept.',
  'config.measurementSettings': 'Measurement settings',
  'config.measurementSubtitle': 'Capture, scan, and device parameters',
};

const Map<String, String> _ko = {
  'common.save': '저장',
  'common.cancel': '취소',
  'common.reset': '초기화',
  'common.clear': '지우기',
  'nav.connect': '연결',
  'nav.scan': '측정',
  'nav.history': '기록',
  'nav.config': '설정',
  'connect.initialize': '연결 시작',
  'connect.online': '연결됨',
  'connect.connecting': '연결 중...',
  'connect.findDevices': '기기 찾기',
  'connect.searching': '기기 검색 중...',
  'connect.sensorConnected': '센서 연결됨',
  'connect.readyToScan': '측정 준비 완료',
  'connect.tapToLink': '분광기와 연결하려면 탭하세요',
  'connect.lookingForDevice': '기기를 찾는 중',
  'scan.title': '측정',
  'scan.scanning': '측정 중...',
  'scan.scan': '측정',
  'scan.setReference': '레퍼런스 설정',
  'scan.referenceSet': '레퍼런스 설정됨',
  'scan.material': '재료 이름',
  'scan.sample': '샘플 이름',
  'scan.batchMode': '연속 측정 모드',
  'scan.next': '다음',
  'scan.materialHint': '예: 소나무',
  'scan.sampleHint': '예: 샘플 A',
  'scan.sampleAuto': '자동 생성',
  'results.title': '결과',
  'history.title': '기록',
  'history.searchHint': '기기 또는 세션으로 검색',
  'config.title': '설정',
  'config.general': '일반',
  'config.advanced': '고급',
  'config.theme': '테마',
  'config.themeLight': '라이트 모드',
  'config.themeDark': '다크 모드',
  'config.language': '언어',
  'config.savedSensors': '저장된 센서',
  'config.savedSensorsSubtitle': '저장된 기기 IP를 목록에서 지웁니다.',
  'config.resetDefaults': '기본값으로 초기화',
  'config.resetDefaultsSubtitle':
      '모든 설정을 기본값으로 되돌립니다. 저장된 센서와 기록은 유지됩니다.',
  'config.measurementSettings': '측정 설정',
  'config.measurementSubtitle': '캡처, 스캔 및 기기 파라미터',
};
