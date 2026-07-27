import 'package:buzz/shared/storage/key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryKeyValueStore', () {
    test('write then read round-trips', () async {
      final store = InMemoryKeyValueStore();

      await store.write(key: 'buzz_communities', value: 'payload');

      expect(await store.read(key: 'buzz_communities'), 'payload');
    });

    test('read returns null for an absent key', () async {
      final store = InMemoryKeyValueStore();

      expect(await store.read(key: 'missing'), isNull);
    });

    test('write overwrites an existing value', () async {
      final store = InMemoryKeyValueStore();

      await store.write(key: 'k', value: 'first');
      await store.write(key: 'k', value: 'second');

      expect(await store.read(key: 'k'), 'second');
    });

    test('delete removes the value', () async {
      final store = InMemoryKeyValueStore();
      await store.write(key: 'k', value: 'v');

      await store.delete(key: 'k');

      expect(await store.read(key: 'k'), isNull);
    });

    test('delete of an absent key is a no-op', () async {
      final store = InMemoryKeyValueStore();

      await expectLater(store.delete(key: 'missing'), completes);
    });

    test('two instances do not share state', () async {
      final first = InMemoryKeyValueStore();
      final second = InMemoryKeyValueStore();

      await first.write(key: 'k', value: 'v');

      // Guards against a static or module-level map, which would leak one
      // browser session's sign-in material into the next.
      expect(await second.read(key: 'k'), isNull);
    });
  });
}
