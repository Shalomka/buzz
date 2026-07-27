import 'package:buzz/shared/platform/is_web.dart';
import 'package:buzz/shared/relay/relay.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nostr/nostr.dart' as nostr;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Matcher throwsWebUnsupported() => throwsA(
    isA<Exception>().having(
      (e) => e.toString(),
      'message',
      contains('not supported in the browser'),
    ),
  );

  MediaUploadService readService({required bool isWeb}) {
    final container = ProviderContainer(
      overrides: [
        relayConfigProvider.overrideWith(() => _FakeRelayConfigNotifier()),
        isWebProvider.overrideWithValue(isWeb),
      ],
    );
    addTearDown(container.dispose);
    return container.read(mediaUploadServiceProvider);
  }

  group('mediaUploadServiceProvider', () {
    test('threads the web capability into the service', () async {
      final service = readService(isWeb: true);

      await expectLater(service.pickAndUploadImage, throwsWebUnsupported());
      await expectLater(service.pickAndUploadVideo, throwsWebUnsupported());
    });

    test('leaves media upload enabled off web', () async {
      final service = readService(isWeb: false);

      // Control: off web the guard is a no-op, so the call reaches the real
      // image_picker, which has no mock handler in a VM test and fails with a
      // platform error instead of the web message.
      await expectLater(
        service.pickAndUploadImage(),
        throwsA(
          isA<Object>().having(
            (e) => e.toString(),
            'message',
            isNot(contains('not supported in the browser')),
          ),
        ),
      );
    });
  });
}

class _FakeRelayConfigNotifier extends RelayConfigNotifier {
  @override
  RelayConfig build() => RelayConfig(
    baseUrl: 'http://localhost:3000',
    nsec: nostr.Keys.generate().nsec,
  );
}
