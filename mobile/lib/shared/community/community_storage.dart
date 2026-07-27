import 'dart:convert';

import '../storage/key_value_store.dart';
import 'community.dart';

class CommunityStorage {
  static const _keyCommunities = 'buzz_communities';
  static const _keyActiveId = 'buzz_active_community_id';

  // Legacy keys for migration.
  static const _legacyCommunities = 'buzz_workspaces';
  static const _legacyActiveId = 'buzz_active_workspace_id';
  static const _legacyRelayUrl = 'buzz_relay_url';
  static const _legacyToken = 'buzz_token';
  static const _legacyPubkey = 'buzz_pubkey';
  static const _legacyNsec = 'buzz_nsec';

  final KeyValueStore _store;

  /// Creates storage backed by [store].
  ///
  /// [store] is deliberately required and has no default. This parameter
  /// carries the whole security decision: a default of [SecureKeyValueStore]
  /// would route the Nostr nsec to `localStorage` on web for any caller that
  /// simply forgot to pass one — silently, with every test and lint still
  /// green. Requiring it turns that hazard into a compile error. Production
  /// callers should resolve it from `keyValueStoreProvider`.
  CommunityStorage({required KeyValueStore store}) : _store = store;

  /// Load all communities. On first call, migrates legacy single-community
  /// credentials if present.
  Future<List<Community>> loadAll() async {
    final raw = await _store.read(key: _keyCommunities);
    if (raw != null) return _decodeList(raw);

    final legacyCommunities = await _store.read(key: _legacyCommunities);
    if (legacyCommunities != null) {
      final communities = _decodeList(legacyCommunities);
      await _saveList(communities);
      final legacyActiveId = await _store.read(key: _legacyActiveId);
      if (legacyActiveId != null) await saveActiveId(legacyActiveId);
      await _store.delete(key: _legacyCommunities);
      await _store.delete(key: _legacyActiveId);
      return communities;
    }

    // Migration: check for legacy single-community keys.
    final legacyUrl = await _store.read(key: _legacyRelayUrl);
    final legacyToken = await _store.read(key: _legacyToken);
    if (legacyUrl != null && legacyToken != null) {
      final legacyPubkey = await _store.read(key: _legacyPubkey);
      final legacyNsec = await _store.read(key: _legacyNsec);

      final name = Community.nameFromUrl(legacyUrl);
      final community = Community.create(
        name: name,
        relayUrl: legacyUrl,
        pubkey: legacyPubkey,
        nsec: legacyNsec,
      );

      await _saveList([community]);
      await saveActiveId(community.id);

      // Delete legacy keys.
      await _store.delete(key: _legacyRelayUrl);
      await _store.delete(key: _legacyToken);
      await _store.delete(key: _legacyPubkey);
      await _store.delete(key: _legacyNsec);

      return [community];
    }

    return [];
  }

  Future<void> save(Community community) async {
    final all = await loadAll();
    final index = all.indexWhere((w) => w.id == community.id);
    if (index >= 0) {
      all[index] = community;
    } else {
      all.add(community);
    }
    await _saveList(all);
  }

  Future<void> remove(String id) async {
    final all = await loadAll();
    all.removeWhere((w) => w.id == id);
    await _saveList(all);
  }

  Future<String?> loadActiveId() async {
    return _store.read(key: _keyActiveId);
  }

  Future<void> saveActiveId(String id) async {
    await _store.write(key: _keyActiveId, value: id);
  }

  Future<void> clearActiveId() async {
    await _store.delete(key: _keyActiveId);
  }

  List<Community> _decodeList(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((entry) => Community.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveList(List<Community> communities) async {
    final json = jsonEncode(communities.map((item) => item.toJson()).toList());
    await _store.write(key: _keyCommunities, value: json);
  }
}
