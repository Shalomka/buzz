import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Scans the real source set for [.dart] files whose content contains [needle].
List<String> _libFilesContaining(String needle) =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => file.readAsStringSync().contains(needle))
        .map((file) => file.path.replaceAll(r'\', '/'))
        .toList()
      ..sort();

void main() {
  test('flutter_secure_storage is imported from exactly one file in lib', () {
    // Standing invariant, not a point-in-time audit: reaching for
    // FlutterSecureStorage anywhere else re-opens the hole this seam closed —
    // on web the plugin persists to localStorage alongside its own extractable
    // AES key, so the Nostr nsec would be recoverable by any XSS on the origin.
    // Route new persistence through KeyValueStore instead.
    expect(_libFilesContaining('package:flutter_secure_storage'), [
      'lib/shared/storage/key_value_store.dart',
    ]);
  });

  test('SecureKeyValueStore is constructed in exactly one file in lib', () {
    // The import fence above guards the *package*; this one guards the *class*.
    // SecureKeyValueStore is exported from key_value_store.dart, which every
    // consumer already imports — so a new file doing
    // `const SecureKeyValueStore().write(key: 'k', value: nsec)` reaches the
    // identical localStorage path one abstraction layer up while the import
    // fence stays green. Construction belongs to the declaration itself and to
    // keyValueStoreProvider, which is the only place allowed to decide between
    // the secure and in-memory backends.
    expect(_libFilesContaining('SecureKeyValueStore('), [
      'lib/shared/storage/key_value_store.dart',
      'lib/shared/storage/key_value_store_provider.dart',
    ]);
  });
}
