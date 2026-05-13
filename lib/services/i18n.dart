import 'package:flutter/foundation.dart';

/// Minimal in-app translation layer. Add new keys to both maps as needed.
/// Wider Flutter i18n (gen_l10n + .arb files) is the proper long-term path;
/// this layer exists so we can ship Korean labels incrementally.
class AppLocale {
  static const en = 'en';
  static const ko = 'ko';
}

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
  'connect.initialize': 'INITIALIZE',
  'connect.online': 'ONLINE',
  'connect.connecting': 'CONNECTING...',
  'connect.findDevices': 'Find devices',
  'scan.title': 'Scan',
  'scan.scanning': 'SCANNING...',
  'scan.scan': 'SCAN',
  'scan.setReference': 'Set reference',
  'scan.referenceSet': 'Reference set',
  'scan.material': 'Material name',
  'scan.sample': 'Sample name',
  'scan.batchMode': 'Batch mode',
  'results.title': 'Results',
  'history.title': 'History',
  'config.title': 'Config',
  'config.general': 'General',
  'config.advanced': 'Advanced',
  'config.theme': 'Theme',
  'config.language': 'Language',
  'config.resetDefaults': 'Reset to defaults',
};

const Map<String, String> _ko = {
  'common.save': '저장',
  'common.cancel': '취소',
  'common.reset': '초기화',
  'common.clear': '지우기',
  'connect.initialize': '연결 시작',
  'connect.online': '연결됨',
  'connect.connecting': '연결 중...',
  'connect.findDevices': '기기 찾기',
  'scan.title': '측정',
  'scan.scanning': '측정 중...',
  'scan.scan': '측정',
  'scan.setReference': '레퍼런스 설정',
  'scan.referenceSet': '레퍼런스 설정됨',
  'scan.material': '재료 이름',
  'scan.sample': '샘플 이름',
  'scan.batchMode': '연속 측정 모드',
  'results.title': '결과',
  'history.title': '기록',
  'config.title': '설정',
  'config.general': '일반',
  'config.advanced': '고급',
  'config.theme': '테마',
  'config.language': '언어',
  'config.resetDefaults': '기본값으로 초기화',
};
