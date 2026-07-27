import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal key-value contract behind anything that persists sign-in material.
///
/// Deliberately exactly three methods. A wider surface (`readAll`,
/// `deleteAll`, `containsKey`, `registerListener`) is what this seam exists to
/// keep out: every extra capability is one more path that could reach durable
/// browser storage on web without a compile error or a failing test.
///
/// All methods take named parameters so a transposed
/// `write(value, key)` cannot compile silently.
abstract class KeyValueStore {
  /// Returns the value stored under [key], or `null` when absent.
  Future<String?> read({required String key});

  /// Stores [value] under [key].
  Future<void> write({required String key, required String value});

  /// Removes any value stored under [key].
  Future<void> delete({required String key});
}

/// Platform-keychain backed store (iOS Keychain / Android Keystore).
///
/// Wraps `const FlutterSecureStorage()` with default options, so keys and
/// payloads on device are byte-identical to the pre-seam behaviour.
class SecureKeyValueStore implements KeyValueStore {
  /// Creates a store backed by the platform keychain.
  const SecureKeyValueStore();

  static const _secure = FlutterSecureStorage();

  @override
  Future<String?> read({required String key}) => _secure.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _secure.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _secure.delete(key: key);
}

/// Process-lifetime store used on web.
///
/// The only durable browser storage available to `flutter_secure_storage_web`
/// is `localStorage` — and it persists its own extractable AES key next to the
/// ciphertext, so any XSS on the origin recovers the Nostr nsec. Web therefore
/// keeps sign-in material in memory only; a reload requires re-pairing. This
/// matches the posture of the shipped browser client
/// (`web/src/shared/lib/nostr-signer.ts`).
class InMemoryKeyValueStore implements KeyValueStore {
  /// Creates an empty store. Each instance owns its own values.
  InMemoryKeyValueStore();

  final Map<String, String> _values = {};

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }
}
