import 'package:buzz/shared/storage/key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_secure_storage_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSecureStorageChannel channel;

  setUp(() {
    channel = MockSecureStorageChannel()..install();
  });

  group('SecureKeyValueStore', () {
    // After the KeyValueStore refactor this wrapper is the only untested link
    // between the app and the platform Keychain/Keystore. These cases catch a
    // dropped or transposed named argument that the type system cannot.
    test('write then read round-trips through the platform channel', () async {
      const store = SecureKeyValueStore();

      await store.write(key: 'buzz_active_community_id', value: 'community-1');

      expect(await store.read(key: 'buzz_active_community_id'), 'community-1');
      expect(channel.values['buzz_active_community_id'], 'community-1');
    });

    test('read returns null for an absent key', () async {
      const store = SecureKeyValueStore();

      expect(await store.read(key: 'missing'), isNull);
    });

    test('delete removes the value', () async {
      const store = SecureKeyValueStore();
      await store.write(key: 'k', value: 'v');

      await store.delete(key: 'k');

      expect(await store.read(key: 'k'), isNull);
      expect(channel.values.containsKey('k'), isFalse);
    });

    test('forwards each call to the platform channel', () async {
      const store = SecureKeyValueStore();

      await store.write(key: 'k', value: 'v');
      await store.read(key: 'k');
      await store.delete(key: 'k');

      expect(channel.calls, containsAll(<String>['write', 'read', 'delete']));
    });
  });
}
