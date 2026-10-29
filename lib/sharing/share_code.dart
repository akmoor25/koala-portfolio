import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// 読み間違えやすい文字（I、L、O、U）を除いた Crockford Base32 の文字。
const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// 公開用しおり ID の長さ（60 bit）。
const leafletIdLength = 12;

/// あいことばの最小の長さ。
const passphraseMinLength = 8;

/// あいことばの最大の長さ。
const passphraseMaxLength = 64;

/// 自動生成するあいことばの長さ（50 bit）。
const _generatedPassphraseLength = 10;

/// あいことばのハッシュを求める反復回数。
const _hashRounds = 10000;

/// QR コードに入れる URL のスキームとホスト。
const _linkScheme = 'koala-portfolio';
const _linkHost = 'join';

/// 公開用しおり ID を作る。しおりのキーとしても使う。
String generateLeafletId([Random? random]) =>
    _randomText(leafletIdLength, random ?? Random.secure());

/// あいことばを自動生成する。
String generatePassphrase([Random? random]) =>
    _randomText(_generatedPassphraseLength, random ?? Random.secure());

String _randomText(int length, Random random) {
  return String.fromCharCodes([
    for (var i = 0; i < length; i++)
      _alphabet.codeUnitAt(random.nextInt(_alphabet.length)),
  ]);
}

/// [character]（1 文字）が、公開用しおり ID に使える文字か。
///
/// 大文字だけを認める。小文字や、読み間違えやすい `I` `L` `O` `U` は含まない。
bool isLeafletIdCharacter(String character) =>
    character.length == 1 && _alphabet.contains(character);

/// 手入力された ID を正規化する。形式が正しくなければ null。
///
/// 大文字小文字、空白、ハイフンを無視し、読み間違えやすい文字を読み替える
/// （I と L は 1、O は 0）。
String? normalizeLeafletId(String input) {
  final text = input
      .toUpperCase()
      .replaceAll(RegExp(r'[\s-]'), '')
      .replaceAll(RegExp('[IL]'), '1')
      .replaceAll('O', '0');
  if (text.length != leafletIdLength) return null;
  if (text.split('').any((c) => !_alphabet.contains(c))) return null;
  return text;
}

/// あいことばとして使える長さか。
bool isValidPassphrase(String passphrase) =>
    passphrase.length >= passphraseMinLength &&
    passphrase.length <= passphraseMaxLength;

/// あいことばのハッシュ（64 文字の 16 進数）。
///
/// しおり ID を salt にして SHA-256 を反復する。サーバーには平文を送らず、
/// データベースのルールがこのハッシュ同士を比べて参加を認める。
String hashPassphrase(String leafletId, String passphrase) {
  final salt = utf8.encode(leafletId);
  var digest = sha256.convert([...salt, 0, ...utf8.encode(passphrase)]);
  for (var i = 1; i < _hashRounds; i++) {
    digest = sha256.convert([...digest.bytes, ...salt]);
  }
  return digest.toString();
}

/// QR コードに入れる、参加用の URL を作る。ID とあいことばを含む。
String buildJoinLink(String leafletId, String passphrase) {
  return Uri(
    scheme: _linkScheme,
    host: _linkHost,
    queryParameters: {'id': leafletId, 'p': passphrase},
  ).toString();
}

/// 参加に必要な、しおり ID とあいことば。
class JoinCredentials {
  /// [leafletId] は正規化済みの ID。
  const JoinCredentials(this.leafletId, this.passphrase);

  /// 公開用しおり ID。
  final String leafletId;

  /// あいことば。
  final String passphrase;
}

/// [buildJoinLink] で作った URL を読み取る。形式が違えば null。
JoinCredentials? parseJoinLink(String text) {
  final uri = Uri.tryParse(text.trim());
  if (uri == null || uri.scheme != _linkScheme || uri.host != _linkHost) {
    return null;
  }
  final id = normalizeLeafletId(uri.queryParameters['id'] ?? '');
  final passphrase = uri.queryParameters['p'] ?? '';
  if (id == null || !isValidPassphrase(passphrase)) return null;
  return JoinCredentials(id, passphrase);
}
