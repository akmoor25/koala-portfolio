import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/helper/secure_passphrase_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('reads back what was written, per leaflet', () async {
    const store = SecurePassphraseStore();
    await store.write('LEAFLET-A', 'passphrase-a');
    await store.write('LEAFLET-B', 'passphrase-b');

    expect(await store.read('LEAFLET-A'), 'passphrase-a');
    expect(await store.read('LEAFLET-B'), 'passphrase-b');
  });

  test('returns null for a leaflet that was never saved', () async {
    expect(await const SecurePassphraseStore().read('NONE'), isNull);
  });

  test('overwrites and deletes', () async {
    const store = SecurePassphraseStore();
    await store.write('K', 'one-one-one');
    await store.write('K', 'two-two-two');
    expect(await store.read('K'), 'two-two-two');

    await store.delete('K');
    expect(await store.read('K'), isNull);
  });

  test('the key does not collide with another leaflet', () async {
    const store = SecurePassphraseStore();
    await store.write('A', 'only-for-a');
    await store.delete('B');

    expect(await store.read('A'), 'only-for-a');
  });
}
