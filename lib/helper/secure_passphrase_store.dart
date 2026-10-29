import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../logger.dart';

/// オーナーが設定したあいことばを、Android Keystore / iOS Keychain で暗号化して
/// この端末にだけ保存する。
///
/// サーバーにはハッシュしか置かないため、後から QR コードを再表示するには
/// 端末側に平文を残す必要がある。端末を替えると失われる。
class SecurePassphraseStore {
  /// 既定の [FlutterSecureStorage] を使う。
  const SecurePassphraseStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  static const _prefix = 'passphrase_';

  String _key(String leafletId) => '$_prefix$leafletId';

  /// [leafletId] のあいことば。保存していなければ null。
  Future<String?> read(String leafletId) async {
    try {
      return await _storage.read(key: _key(leafletId));
    } on Exception catch (e, s) {
      // バックアップの復元などで鍵が変わると復号できない。未保存として扱う。
      logger.w('PassphraseStore.read failed', e, s);
      return null;
    }
  }

  /// あいことばを保存する。
  Future<void> write(String leafletId, String passphrase) async {
    try {
      await _storage.write(key: _key(leafletId), value: passphrase);
    } on Exception catch (e, s) {
      logger.w('PassphraseStore.write failed', e, s);
    }
  }

  /// あいことばを消す。
  Future<void> delete(String leafletId) async {
    try {
      await _storage.delete(key: _key(leafletId));
    } on Exception catch (e, s) {
      logger.w('PassphraseStore.delete failed', e, s);
    }
  }

  /// 保存しているあいことばを、しおりに依らず、すべて消す。
  ///
  /// アカウントが使えなくなったときに使う。一覧が先に空になっていても、残さないため。
  Future<void> deleteAll() async {
    try {
      final all = await _storage.readAll();
      for (final key in all.keys) {
        if (key.startsWith(_prefix)) await _storage.delete(key: key);
      }
    } on Exception catch (e, s) {
      logger.w('PassphraseStore.deleteAll failed', e, s);
    }
  }
}
