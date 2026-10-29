import 'dart:convert';

import 'package:crypto/crypto.dart';

/// キーの長さ（SHA-256 の 16 進数 64 文字のうち、先頭から使う文字数）。
///
/// 128 bit あれば、端末の数に対して衝突は実質起きない。ルールとサーバーも同じ長さを使う。
const deviceTokenKeyLength = 32;

/// 端末のトークンから、データベース（`users/{uid}/fcmTokens/{key}`）のキーを作る。
///
/// SHA-256 の先頭 [deviceTokenKeyLength] 文字（16 進数）。トークンの形式は保証された仕様ではないので、キーに使える
/// 文字だけになるよう、ハッシュにする。サーバー（`functions/src/handler.ts` の `tokenKey`）と同じ式。
/// ルールも、このキーの形（小文字の 16 進数 32 文字）を求める。
String deviceTokenKey(String token) {
  return sha256
      .convert(utf8.encode(token))
      .toString()
      .substring(0, deviceTokenKeyLength);
}
