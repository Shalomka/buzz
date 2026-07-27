import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../platform/is_web.dart';
import 'key_value_store.dart';

/// The store backing anything that must persist sign-in material.
///
/// Web gets a process-lifetime store — see [InMemoryKeyValueStore] for why the
/// Nostr nsec must never reach browser storage. Every other platform gets the
/// platform keychain, exactly as before this seam existed.
final keyValueStoreProvider = Provider<KeyValueStore>((ref) {
  return ref.watch(isWebProvider)
      ? InMemoryKeyValueStore()
      : const SecureKeyValueStore();
});
