import 'package:buzz/shared/community/community.dart';
import 'package:buzz/shared/community/community_provider.dart';
import 'package:buzz/shared/platform/is_web.dart';
import 'package:buzz/shared/storage/key_value_store.dart';
import 'package:buzz/shared/storage/key_value_store_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../helpers/mock_secure_storage_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSecureStorageChannel channel;

  setUp(() {
    channel = MockSecureStorageChannel()..install();
  });

  ProviderContainer createContainer({required bool isWeb}) {
    final container = ProviderContainer(
      overrides: [isWebProvider.overrideWithValue(isWeb)],
    );
    addTearDown(container.dispose);
    return container;
  }

  Community communityWithKey() => Community.create(
    name: 'Test',
    relayUrl: 'https://relay.example.com',
    pubkey: 'abc123',
    nsec: 'nsec1examplekeymaterial',
  );

  group('keyValueStoreProvider', () {
    // Structural half: independent of any plugin's method-channel name, so it
    // survives a future Pigeon migration inside flutter_secure_storage.
    test('resolves to the in-memory store on web', () {
      final container = createContainer(isWeb: true);

      expect(
        container.read(keyValueStoreProvider),
        isA<InMemoryKeyValueStore>(),
      );
    });

    test('resolves to the secure store off web', () {
      final container = createContainer(isWeb: false);

      expect(container.read(keyValueStoreProvider), isA<SecureKeyValueStore>());
    });
  });

  group('CommunityStorage secure-storage traffic', () {
    // Behavioural half. The isWeb: false control must record traffic AND
    // round-trip, otherwise the web assertion below could pass vacuously.
    test('control: off web, saving a community reaches the platform '
        'channel and round-trips', () async {
      final container = createContainer(isWeb: false);
      final storage = container.read(communityStorageProvider);
      final community = communityWithKey();

      await storage.save(community);
      final loaded = await storage.loadAll();

      expect(channel.calls, isNotEmpty);
      expect(loaded.single.id, community.id);
      expect(loaded.single.nsec, 'nsec1examplekeymaterial');
    });

    test('on web, saving a community with an nsec produces zero '
        'secure-storage channel calls and still round-trips', () async {
      final container = createContainer(isWeb: true);
      final storage = container.read(communityStorageProvider);
      final community = communityWithKey();

      await storage.save(community);
      await storage.saveActiveId(community.id);
      final loaded = await storage.loadAll();

      // The nsec never reaches browser storage: on web the plugin would write
      // it to localStorage next to its own extractable AES key.
      expect(channel.calls, isEmpty);
      expect(channel.values, isEmpty);

      // ...but the session still works within the container's lifetime.
      expect(loaded.single.id, community.id);
      expect(loaded.single.nsec, 'nsec1examplekeymaterial');
      expect(await storage.loadActiveId(), community.id);
    });
  });
}
