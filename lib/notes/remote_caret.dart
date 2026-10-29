import 'dart:async';
import 'dart:ui';

/// [interval] ごとに最大 1 回だけ値を流す。最後には必ず最新値を届けるので、
/// 相手側のキャレットは最終位置に落ち着く。
class LatestValueThrottle<T> {
  LatestValueThrottle(this.interval, this.onFire);

  final Duration interval;
  final void Function(T value) onFire;
  Timer? _timer;
  bool _hasPending = false;
  late T _pending;

  void add(T value) {
    if (_timer != null) {
      _pending = value;
      _hasPending = true;
      return;
    }
    onFire(value);
    _timer = Timer(interval, _onTick);
  }

  void _onTick() {
    _timer = null;
    if (!_hasPending) return;
    _hasPending = false;
    add(_pending);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _hasPending = false;
  }
}

/// 共有ノート内の他メンバーのキャレット。`presence/notes/{leafletKey}/{uid}` に保存される。
class RemoteCaret {
  const RemoteCaret({
    required this.uid,
    required this.name,
    required this.index,
    this.generation,
    this.lineId,
  });

  final String uid;
  final String name;
  final int index;
  final String? generation;
  final String? lineId;

  Color get color => colorForUid(uid);

  /// 長さ [documentLength] の文書で有効な範囲に収めたキャレット位置
  /// （quill の文書は末尾が必ず改行で、キャレットはそれを越えられない）。
  int clampedIndex(int documentLength) =>
      index.clamp(0, documentLength > 0 ? documentLength - 1 : 0);

  @override
  bool operator ==(Object other) =>
      other is RemoteCaret &&
      other.uid == uid &&
      other.name == name &&
      other.index == index &&
      other.generation == generation &&
      other.lineId == lineId;

  @override
  int get hashCode => Object.hash(uid, name, index, generation, lineId);

  @override
  String toString() => 'RemoteCaret($uid, $name, $index)';
}

/// 自分のプレゼンスとして書き込む内容。エディタにフォーカスがない間は [index] が null。
Map<String, Object?> presencePayload({
  required Object at,
  required String name,
  int? index,
  String? generation,
  String? lineId,
}) {
  return {
    'at': at,
    'name': name,
    'index': ?index,
    'generation': ?generation,
    'lineId': ?lineId,
  };
}

/// プレゼンスのスナップショットから他ユーザーのキャレットを取り出す。
/// キャレットのないエントリ（未フォーカスや不正な形式）は読み飛ばす。
List<RemoteCaret> parseRemoteCarets(Object? value, String? myUid) {
  if (value is! Map) return const [];
  final carets = <RemoteCaret>[];
  value.forEach((key, entry) {
    if (key is! String || key == myUid || entry is! Map) return;
    final index = entry['index'];
    if (index is! int || index < 0) return;
    final name = entry['name'];
    carets.add(
      RemoteCaret(
        uid: key,
        name: name is String && name.isNotEmpty ? name : '?',
        index: index,
        generation: entry['generation'] is String
            ? entry['generation']! as String
            : null,
        lineId: entry['lineId'] is String ? entry['lineId']! as String : null,
      ),
    );
  });
  carets.sort((a, b) => a.uid.compareTo(b.uid));
  return carets;
}

/// ニックネームの先頭 1 文字を大文字にしたもの。キャレットのバッジに表示する。
String initialOf(String? name) {
  if (name == null || name.isEmpty) return '?';
  return String.fromCharCode(name.runes.first).toUpperCase();
}

const _caretPalette = <Color>[
  Color(0xFFE53935),
  Color(0xFF8E24AA),
  Color(0xFF1E88E5),
  Color(0xFF00897B),
  Color(0xFF43A047),
  Color(0xFFF4511E),
  Color(0xFF6D4C41),
  Color(0xFF3949AB),
];

/// ユーザーごとに固定の色。どの端末でも同じメンバーを同じ色で表示する。
/// String.hashCode は実行環境間で同じ値になる保証がないため、FNV-1a を使う。
Color colorForUid(String uid) {
  var hash = 0x811c9dc5;
  for (final unit in uid.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return _caretPalette[hash % _caretPalette.length];
}
