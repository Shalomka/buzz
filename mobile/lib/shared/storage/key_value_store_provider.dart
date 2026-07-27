import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../platform/is_web.dart';
import 'key_value_store.dart';

/// The store backing anything that must persist sign-in material.
///
/// Web gets a process-lifetime store — see [InMemoryKeyValueStore] for why the
/// Nostr nsec must never reach browser storage. Every other platform gets the
/// platform keychain, exactly as before this seam existed.
///
/// **This must stay a plain, keep-alive [Provider].** On web the provider's
/// [InMemoryKeyValueStore] instance holds the session's *only* copy of the
/// Nostr nsec — nothing durable backs it up. Anything that lets Riverpod
/// dispose or rebuild this provider therefore destroys the signed-in session
/// and forces every web user to re-pair. Specifically, do not add
/// `autoDispose`, do not convert it to a `.family`, and do not
/// `ref.invalidate` or override it per community switch — the desktop
/// `resetCommunityState()` pattern in `CLAUDE.md` must not be mirrored here.
/// Off web the store is stateless, so the constraint costs nothing there.
final keyValueStoreProvider = Provider<KeyValueStore>((ref) {
  return ref.watch(isWebProvider)
      ? InMemoryKeyValueStore()
      : const SecureKeyValueStore();
});
