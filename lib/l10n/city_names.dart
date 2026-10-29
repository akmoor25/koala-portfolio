/// サンプルなどでよく使う都市の日本語名。無い都市は、タイムゾーン ID の都市名（英語）を使う。
const _japaneseCityNames = <String, String>{
  'Asia/Tokyo': '東京',
  'Asia/Seoul': 'ソウル',
  'Asia/Taipei': '台北',
  'Asia/Bangkok': 'バンコク',
  'Europe/Paris': 'パリ',
  'Europe/Brussels': 'ブリュッセル',
  'America/New_York': 'ニューヨーク',
  'America/Toronto': 'トロント',
  'Australia/Sydney': 'シドニー',
  'Europe/London': 'ロンドン',
  'Europe/Berlin': 'ベルリン',
  'Europe/Amsterdam': 'アムステルダム',
  'Europe/Athens': 'アテネ',
  'America/Los_Angeles': 'ロサンゼルス',
  'Europe/Rome': 'ローマ',
  'Europe/Madrid': 'マドリード',
};

/// [zoneId] の都市名を、[languageCode]（`ja` か `en`）で返す。
///
/// `Asia/Tokyo` → `東京`（ja）、`Tokyo`（en）。日本語名が無い都市は英語名になる。
String cityNameFor(String zoneId, String languageCode) {
  if (languageCode == 'ja') {
    final name = _japaneseCityNames[zoneId];
    if (name != null) return name;
  }
  final raw = zoneId.contains('/') ? zoneId.split('/').last : zoneId;
  return raw.replaceAll('_', ' ');
}
