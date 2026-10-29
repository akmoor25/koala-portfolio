import 'package:characters/characters.dart';

/// ニックネームの最大の長さ（見た目の文字数）。サーバー（Cloud Functions）の切り詰めと同じ。
const nicknameMaxLength = 20;

/// 制御文字と、表示の向きを変える文字。
final _unsafe = RegExp(
  r'[\u0000-\u001F\u007F-\u009F\u202A-\u202E\u2066-\u2069]',
);

/// ニックネームを、保存できる形に整える。
///
/// 制御文字は空白にし、連続する空白は 1 つにして、前後の空白を除く。
/// 長さは切り詰めない（長すぎるかどうかは [isValidNickname] が決める）。
String normalizeNickname(String raw) {
  return raw.replaceAll(_unsafe, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// 整えたあとで、1 文字以上、[nicknameMaxLength] 文字以下か。
bool isValidNickname(String raw) {
  final name = normalizeNickname(raw);
  return name.isNotEmpty && name.characters.length <= nicknameMaxLength;
}

/// 端末の機種名などを、ニックネームの初期値にできる形にする。長すぎるときは切り詰める。
String nicknameFromDeviceName(String raw) {
  final name = normalizeNickname(raw);
  return name.characters.take(nicknameMaxLength).toString().trim();
}
