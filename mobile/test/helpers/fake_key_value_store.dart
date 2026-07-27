import 'package:buzz/shared/storage/key_value_store.dart';

/// In-memory [KeyValueStore] for tests.
///
/// Mirrors the seeding affordances the previous `FakeSecureStorage` offered so
/// tests can plant legacy keys and assert post-migration cleanup synchronously.
/// These operators are deliberately test-only — the production
/// [InMemoryKeyValueStore] stays free of them.
class FakeKeyValueStore implements KeyValueStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({required String key}) async => _data[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _data[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _data.remove(key);
  }

  // Convenience for setting up test data.
  String? operator [](String key) => _data[key];
  void operator []=(String key, String value) => _data[key] = value;
}
