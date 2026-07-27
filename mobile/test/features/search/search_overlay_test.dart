import 'package:buzz/features/channels/channel.dart';
import 'package:buzz/features/channels/channels_provider.dart';
import 'package:buzz/features/profile/profile_provider.dart';
import 'package:buzz/features/profile/user_cache_provider.dart';
import 'package:buzz/features/profile/user_profile.dart';
import 'package:buzz/features/search/search_overlay.dart';
import 'package:buzz/features/search/search_page.dart';
import 'package:buzz/features/search/search_provider.dart';
import 'package:buzz/shared/shell/shell_state_provider.dart';
import 'package:buzz/shared/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final _channel = Channel(
  id: 'channel-1',
  name: 'general',
  channelType: 'stream',
  visibility: 'open',
  description: 'General discussion',
  createdBy: 'creator',
  createdAt: DateTime(2026),
  memberCount: 4,
  isMember: true,
);

void main() {
  void useWideSurface(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
  }

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        searchProvider.overrideWith(() => _FakeSearchNotifier()),
        channelsProvider.overrideWith(() => _FakeChannelsNotifier()),
        profileProvider.overrideWith(() => _FakeProfileNotifier()),
        userCacheProvider.overrideWith(() => _NoopUserCacheNotifier()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpOverlay(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showSearchOverlay(context),
                child: const Text('open search'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open search'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens as a dialog hosting the search view at wide widths', (
    tester,
  ) async {
    useWideSurface(tester);
    final container = createContainer();

    await pumpOverlay(tester, container);

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(SearchView), findsOneWidget);
    expect(find.byType(SearchInputField), findsOneWidget);
  });

  testWidgets('choosing a channel hit closes the overlay and selects it', (
    tester,
  ) async {
    useWideSurface(tester);
    final container = createContainer();

    await pumpOverlay(tester, container);
    expect(find.text('general'), findsOneWidget);

    await tester.tap(find.text('general'));
    await tester.pumpAndSettle();

    expect(container.read(shellStateProvider).selectedChannelId, 'channel-1');
    expect(find.byType(Dialog), findsNothing);
  });
}

class _FakeSearchNotifier extends SearchNotifier {
  @override
  SearchState build() => SearchState(query: 'gen', channelResults: [_channel]);

  @override
  Future<void> search(String query) async {}

  @override
  void clear() {}
}

class _FakeChannelsNotifier extends ChannelsNotifier {
  @override
  Future<List<Channel>> build() async => [_channel];
}

class _FakeProfileNotifier extends ProfileNotifier {
  @override
  Future<UserProfile?> build() async =>
      const UserProfile(pubkey: 'self', displayName: 'Self');
}

class _NoopUserCacheNotifier extends UserCacheNotifier {
  @override
  Map<String, UserProfile> build() => const {};

  @override
  UserProfile? get(String pubkey) => null;

  @override
  void preload(List<String> pubkeys) {}
}
