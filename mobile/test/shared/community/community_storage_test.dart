import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:buzz/shared/community/community.dart';
import 'package:buzz/shared/community/community_storage.dart';

import '../../helpers/fake_key_value_store.dart';

void main() {
  late FakeKeyValueStore fakeStore;
  late CommunityStorage storage;

  setUp(() {
    fakeStore = FakeKeyValueStore();
    storage = CommunityStorage(store: fakeStore);
  });

  group('CommunityStorage', () {
    test('loadAll returns empty list when no data', () async {
      final result = await storage.loadAll();
      expect(result, isEmpty);
    });

    test('save and loadAll round-trips a community', () async {
      final ws = Community.create(
        name: 'Test',
        relayUrl: 'https://relay.example.com',
        pubkey: 'abc123',
      );

      await storage.save(ws);
      final loaded = await storage.loadAll();

      expect(loaded, hasLength(1));
      expect(loaded.first.id, ws.id);
      expect(loaded.first.name, 'Test');
      expect(loaded.first.relayUrl, 'https://relay.example.com');
      expect(loaded.first.pubkey, 'abc123');
    });

    test('save updates existing community with same id', () async {
      final ws = Community.create(
        name: 'Original',
        relayUrl: 'https://relay.example.com',
      );

      await storage.save(ws);
      await storage.save(ws.copyWith(name: 'Updated'));

      final loaded = await storage.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.first.name, 'Updated');
    });

    test('remove deletes a community', () async {
      final ws1 = Community.create(
        name: 'One',
        relayUrl: 'https://one.example.com',
      );
      final ws2 = Community.create(
        name: 'Two',
        relayUrl: 'https://two.example.com',
      );

      await storage.save(ws1);
      await storage.save(ws2);
      await storage.remove(ws1.id);

      final loaded = await storage.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.first.id, ws2.id);
    });

    test('active community ID persists', () async {
      await storage.saveActiveId('ws-123');
      final id = await storage.loadActiveId();
      expect(id, 'ws-123');
    });

    test('clearActiveId removes active ID', () async {
      await storage.saveActiveId('ws-123');
      await storage.clearActiveId();
      final id = await storage.loadActiveId();
      expect(id, isNull);
    });

    group('migration', () {
      test('migrates saved workspaces to communities', () async {
        final legacy = Community.create(
          name: 'Legacy',
          relayUrl: 'https://legacy.example.com',
        );
        fakeStore['buzz_workspaces'] = jsonEncode([legacy.toJson()]);
        fakeStore['buzz_active_workspace_id'] = legacy.id;

        final loaded = await storage.loadAll();

        expect(loaded.single.id, legacy.id);
        expect(await storage.loadActiveId(), legacy.id);
        expect(fakeStore['buzz_communities'], isNotNull);
        expect(fakeStore['buzz_workspaces'], isNull);
        expect(fakeStore['buzz_active_workspace_id'], isNull);
      });

      test('migrates legacy keys to community on first load', () async {
        fakeStore['buzz_relay_url'] = 'https://legacy.example.com';
        fakeStore['buzz_token'] = 'legacy_token';
        fakeStore['buzz_pubkey'] = 'legacy_pub';
        fakeStore['buzz_nsec'] = 'legacy_nsec';

        final loaded = await storage.loadAll();

        expect(loaded, hasLength(1));
        expect(loaded.first.relayUrl, 'https://legacy.example.com');
        expect(loaded.first.pubkey, 'legacy_pub');
        expect(loaded.first.nsec, 'legacy_nsec');
        expect(loaded.first.name, isNotEmpty);

        // Legacy keys should be deleted.
        expect(fakeStore['buzz_relay_url'], isNull);
        expect(fakeStore['buzz_token'], isNull);
        expect(fakeStore['buzz_pubkey'], isNull);
        expect(fakeStore['buzz_nsec'], isNull);

        // Active ID should be set.
        final activeId = await storage.loadActiveId();
        expect(activeId, loaded.first.id);
      });

      test('does not migrate when no legacy keys exist', () async {
        final loaded = await storage.loadAll();
        expect(loaded, isEmpty);
      });

      test('does not re-migrate after first load', () async {
        fakeStore['buzz_relay_url'] = 'https://legacy.example.com';
        fakeStore['buzz_token'] = 'legacy_token';

        final first = await storage.loadAll();
        expect(first, hasLength(1));

        final second = await storage.loadAll();
        expect(second, hasLength(1));
        expect(second.first.id, first.first.id);
      });

      test('migration generates name from localhost URL', () async {
        fakeStore['buzz_relay_url'] = 'http://localhost:3000';
        fakeStore['buzz_token'] = 'tok';

        final loaded = await storage.loadAll();
        expect(loaded.first.name, 'Local Dev');
      });
    });
  });
}
