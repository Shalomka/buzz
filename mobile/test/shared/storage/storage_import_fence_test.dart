import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flutter_secure_storage is imported from exactly one file in lib', () {
    final importers =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .where(
              (file) => file.readAsStringSync().contains(
                'package:flutter_secure_storage',
              ),
            )
            .map((file) => file.path.replaceAll(r'\', '/'))
            .toList()
          ..sort();

    // Standing invariant, not a point-in-time audit: reaching for
    // FlutterSecureStorage anywhere else re-opens the hole this seam closed —
    // on web the plugin persists to localStorage alongside its own extractable
    // AES key, so the Nostr nsec would be recoverable by any XSS on the origin.
    // Route new persistence through KeyValueStore instead.
    expect(importers, ['lib/shared/storage/key_value_store.dart']);
  });
}
