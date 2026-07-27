import 'package:buzz/app.dart';
import 'package:buzz/shared/auth/auth.dart';
import 'package:buzz/shared/platform/is_web.dart';
import 'package:buzz/shared/theme/theme_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _appBadgeChannel = MethodChannel('app_badge_plus');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> badgeCalls;

  setUp(() {
    badgeCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_appBadgeChannel, (call) async {
          badgeCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_appBadgeChannel, null);
  });

  void failBadgeChannel() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_appBadgeChannel, (call) async {
          badgeCalls.add(call);
          throw PlatformException(
            code: 'unavailable',
            message: 'launcher rejected the badge update',
          );
        });
  }

  Future<void> pumpApp(WidgetTester tester, {required bool isWeb}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _FakeAuthNotifier()),
          savedPrefsProvider.overrideWithValue(prefs),
          isWebProvider.overrideWithValue(isWeb),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
  }

  group('app badge web gate', () {
    testWidgets('invokes the app_badge_plus channel off web', (tester) async {
      await pumpApp(tester, isWeb: false);

      // Control: proves this test actually observes the channel, so the web
      // assertion below cannot pass vacuously.
      expect(badgeCalls, isNotEmpty);
      expect(badgeCalls.first.method, 'updateBadge');
    });

    testWidgets('never touches the app_badge_plus channel on web', (
      tester,
    ) async {
      await pumpApp(tester, isWeb: true);

      expect(badgeCalls, isEmpty);
    });

    testWidgets('swallows a badge update rejected by the launcher', (
      tester,
    ) async {
      failBadgeChannel();

      await pumpApp(tester, isWeb: false);
      // Let the rejected updateBadge future settle; without the catchError the
      // rejection would surface here as an unhandled async error and fail the
      // test.
      await tester.pumpAndSettle();

      // The call was made and rejected, and nothing escaped to the framework.
      expect(badgeCalls, isNotEmpty);
      expect(badgeCalls.first.method, 'updateBadge');
      expect(tester.takeException(), isNull);
    });
  });
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async {
    return const AuthState(status: AuthStatus.unauthenticated);
  }
}
