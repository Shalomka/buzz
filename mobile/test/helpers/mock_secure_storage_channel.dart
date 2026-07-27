import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The platform-interface channel `flutter_secure_storage` talks over.
const secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

/// A *stateful* mock for [secureStorageChannel].
///
/// Deliberately backed by a real map rather than recording calls and returning
/// `null`: a recording-only handler makes `CommunityStorage.loadAll()` return
/// `[]`, so the round-trip half of the non-web control could never pass and the
/// zero-traffic assertion for web would pass vacuously.
class MockSecureStorageChannel {
  final Map<String, String> values = {};

  /// Every method name invoked on the channel, in order.
  final List<String> calls = [];

  /// Installs the handler and removes it again at the end of the test.
  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, _handle);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, null),
    );
  }

  Future<Object?> _handle(MethodCall call) async {
    calls.add(call.method);
    final args = (call.arguments as Map?)?.cast<String, Object?>() ?? {};
    final key = args['key'] as String?;

    switch (call.method) {
      case 'read':
        return values[key];
      case 'write':
        final value = args['value'] as String?;
        if (key != null && value != null) values[key] = value;
        return null;
      case 'delete':
        values.remove(key);
        return null;
      case 'containsKey':
        return values.containsKey(key);
      case 'readAll':
        return Map<String, String>.from(values);
      case 'deleteAll':
        values.clear();
        return null;
      default:
        return null;
    }
  }
}
