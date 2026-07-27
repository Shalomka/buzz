import 'package:buzz/features/channels/channel.dart';
import 'package:buzz/features/channels/channels_provider.dart';
import 'package:buzz/features/custom_emoji/custom_emoji.dart';
import 'package:buzz/features/custom_emoji/custom_emoji_provider.dart';
import 'package:buzz/features/home/desktop_shell.dart';
import 'package:buzz/features/profile/profile_provider.dart';
import 'package:buzz/features/profile/user_cache_provider.dart';
import 'package:buzz/features/profile/user_profile.dart';
import 'package:buzz/features/profile/user_status.dart';
import 'package:buzz/features/profile/user_status_provider.dart';
import 'package:buzz/features/search/search_page.dart';
import 'package:buzz/features/search/search_provider.dart';
import 'package:buzz/features/settings/settings_page.dart';
import 'package:buzz/shared/shell/shell_state.dart';
import 'package:buzz/shared/shell/shell_state_provider.dart';
import 'package:buzz/shared/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

Channel _channel(String id) => Channel(
  id: id,
  name: id,
  channelType: 'stream',
  visibility: 'open',
  description: '',
  createdBy: 'creator',
  createdAt: DateTime(2026),
  memberCount: 2,
  isMember: true,
);

final _channels = [_channel('alpha'), _channel('beta'), _channel('gamma')];

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    // The Cmd/Ctrl+, route builds the real settings page, which reads stored
    // theme prefs and the package version off the platform.
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    PackageInfo.setMockInitialValues(
      appName: 'buzz',
      packageName: 'com.example.buzz',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  void useWideSurface(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
  }

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        channelsProvider.overrideWith(() => _FakeChannelsNotifier()),
        profileProvider.overrideWith(() => _FakeProfileNotifier()),
        searchProvider.overrideWith(() => _FakeSearchNotifier()),
        userCacheProvider.overrideWith(() => _NoopUserCacheNotifier()),
        // The Cmd/Ctrl+, route builds the real settings page, whose status
        // and emoji lookups would otherwise reach for the relay.
        userStatusProvider.overrideWith(() => _FakeUserStatusNotifier()),
        customEmojiPaletteProvider.overrideWith(
          () => _FakeCustomEmojiPaletteNotifier(),
        ),
        savedPrefsProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Hosts the shortcut layer over a text field standing in for the composer,
  /// so the chords can be asserted with a field holding focus — the state
  /// where `DefaultTextEditingShortcuts` competes for arrow keys.
  Future<void> pumpShortcuts(
    WidgetTester tester,
    ProviderContainer container, {
    bool focusField = false,
  }) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    // The shortcut layer reads these lazily; in the real shell the panes keep
    // them alive, so warm them here rather than reading an unmounted provider.
    await container.read(channelsProvider.future);
    await container.read(profileProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ShellShortcuts(
              child: TextField(focusNode: focusNode, maxLines: 5),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    if (focusField) {
      focusNode.requestFocus();
      await tester.pumpAndSettle();
      expect(focusNode.hasPrimaryFocus, isTrue);
    }
  }

  Future<void> pressChord(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    LogicalKeyboardKey modifier = LogicalKeyboardKey.meta,
    bool alt = false,
  }) async {
    await tester.sendKeyDownEvent(modifier);
    if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
    await tester.sendKeyEvent(key);
    if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
  }

  /// Fires [key] twice under a held modifier **without pumping in between**.
  ///
  /// Both events are therefore delivered while primary focus is still on the
  /// shell. Pumping first would install the pushed route and move focus into
  /// its scope, where the second chord could never reach [ShellShortcuts] at
  /// all — so the no-stack guard would appear to work even if deleted.
  Future<void> pressChordTwiceInOneFrame(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    LogicalKeyboardKey modifier = LogicalKeyboardKey.meta,
  }) async {
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(key);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
  }

  testWidgets('Cmd+K opens the search overlay', (tester) async {
    useWideSurface(tester);
    final container = createContainer();
    await pumpShortcuts(tester, container);

    await pressChord(tester, LogicalKeyboardKey.keyK);

    expect(find.byType(SearchView), findsOneWidget);
  });

  testWidgets('a repeated Cmd+K does not stack a second search overlay', (
    tester,
  ) async {
    useWideSurface(tester);
    final container = createContainer();
    await pumpShortcuts(tester, container);

    await pressChordTwiceInOneFrame(tester, LogicalKeyboardKey.keyK);

    expect(find.byType(SearchView), findsOneWidget);
  });

  testWidgets('Cmd+, pushes settings exactly once across repeated presses', (
    tester,
  ) async {
    useWideSurface(tester);
    final container = createContainer();
    await pumpShortcuts(tester, container);

    await pressChordTwiceInOneFrame(tester, LogicalKeyboardKey.comma);

    // skipOffstage: false is load-bearing — a second settings route would
    // push the first one offstage, so the default finder would report one
    // match either way and the guard would go untested.
    expect(find.byType(SettingsPage, skipOffstage: false), findsOneWidget);
  });

  testWidgets('Esc closes an open side panel', (tester) async {
    useWideSurface(tester);
    final container = createContainer();
    await pumpShortcuts(tester, container);

    container.read(shellStateProvider.notifier).toggleActivityPanel();
    await tester.pump();
    expect(
      container.read(shellStateProvider).sidePanel,
      isA<ShellSidePanelActivity>(),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(
      container.read(shellStateProvider).sidePanel,
      isA<ShellSidePanelNone>(),
    );
  });

  group('channel navigation with the composer focused', () {
    testWidgets('Cmd+Alt+ArrowDown selects the first channel when idle', (
      tester,
    ) async {
      useWideSurface(tester);
      final container = createContainer();
      await pumpShortcuts(tester, container, focusField: true);

      await pressChord(tester, LogicalKeyboardKey.arrowDown, alt: true);

      expect(container.read(shellStateProvider).selectedChannelId, 'alpha');
    });

    testWidgets('Ctrl+Alt+Arrows step through the rendered order', (
      tester,
    ) async {
      useWideSurface(tester);
      final container = createContainer();
      await pumpShortcuts(tester, container, focusField: true);
      container.read(shellStateProvider.notifier).selectChannel('beta');

      await pressChord(
        tester,
        LogicalKeyboardKey.arrowDown,
        modifier: LogicalKeyboardKey.control,
        alt: true,
      );
      expect(container.read(shellStateProvider).selectedChannelId, 'gamma');

      await pressChord(
        tester,
        LogicalKeyboardKey.arrowUp,
        modifier: LogicalKeyboardKey.control,
        alt: true,
      );
      expect(container.read(shellStateProvider).selectedChannelId, 'beta');
    });

    testWidgets('the chord no-ops at the list edges', (tester) async {
      useWideSurface(tester);
      final container = createContainer();
      await pumpShortcuts(tester, container, focusField: true);
      container.read(shellStateProvider.notifier).selectChannel('alpha');

      await pressChord(tester, LogicalKeyboardKey.arrowUp, alt: true);
      expect(container.read(shellStateProvider).selectedChannelId, 'alpha');

      container.read(shellStateProvider.notifier).selectChannel('gamma');
      await pressChord(tester, LogicalKeyboardKey.arrowDown, alt: true);
      expect(container.read(shellStateProvider).selectedChannelId, 'gamma');
    });
  });
}

class _FakeChannelsNotifier extends ChannelsNotifier {
  @override
  Future<List<Channel>> build() async => _channels;
}

class _FakeProfileNotifier extends ProfileNotifier {
  @override
  Future<UserProfile?> build() async =>
      const UserProfile(pubkey: 'self', displayName: 'Self');
}

class _FakeSearchNotifier extends SearchNotifier {
  @override
  SearchState build() => const SearchState.initial();

  @override
  Future<void> search(String query) async {}

  @override
  void clear() {}
}

class _FakeUserStatusNotifier extends UserStatusNotifier {
  @override
  Future<UserStatus?> build() async => null;
}

class _FakeCustomEmojiPaletteNotifier extends CustomEmojiPaletteNotifier {
  @override
  Future<List<CustomEmoji>> build() async => const [];
}

class _NoopUserCacheNotifier extends UserCacheNotifier {
  @override
  Map<String, UserProfile> build() => const {};

  @override
  UserProfile? get(String pubkey) => null;

  @override
  void preload(List<String> pubkeys) {}
}
