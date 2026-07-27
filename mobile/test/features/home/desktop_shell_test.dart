import 'package:buzz/features/activity/activity_page.dart';
import 'package:buzz/features/activity/activity_provider.dart';
import 'package:buzz/features/activity/feed_item.dart';
import 'package:buzz/features/channels/channel.dart';
import 'package:buzz/features/channels/channel_workspace.dart';
import 'package:buzz/features/channels/channels_provider.dart';
import 'package:buzz/features/channels/unread_badge/observed_unread_event.dart';
import 'package:buzz/features/channels/unread_badge/unread_badge_provider.dart';
import 'package:buzz/features/home/desktop_shell.dart';
import 'package:buzz/features/profile/profile_provider.dart';
import 'package:buzz/features/profile/user_profile.dart';
import 'package:buzz/shared/community/community.dart';
import 'package:buzz/shared/community/community_provider.dart';
import 'package:buzz/shared/shell/shell_state.dart';
import 'package:buzz/shared/shell/shell_state_provider.dart';
import 'package:buzz/shared/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final _communityA = Community(
  id: 'community-a',
  name: 'Alpha',
  relayUrl: 'wss://alpha.test',
  addedAt: DateTime(2026),
);

final _communityB = Community(
  id: 'community-b',
  name: 'Beta',
  relayUrl: 'wss://beta.test',
  addedAt: DateTime(2026),
);

final _testChannels = [
  Channel(
    id: '1',
    name: 'general',
    channelType: 'stream',
    visibility: 'open',
    description: 'General discussion',
    createdBy: 'creator',
    createdAt: DateTime(2026),
    memberCount: 5,
    isMember: true,
  ),
];

void main() {
  void useWideSurface(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
  }

  (ProviderContainer, _FakeCommunityListNotifier) createContainer({
    UnreadBadgeState? unreadBadge,
  }) {
    final communities = [_communityA, _communityB];
    final communityList = _FakeCommunityListNotifier(communities);
    final container = ProviderContainer(
      overrides: [
        communityListProvider.overrideWith(() => communityList),
        activeCommunityProvider.overrideWith((ref) async {
          final id = ref.watch(_activeCommunityIdProvider);
          return communities.firstWhere((community) => community.id == id);
        }),
        channelsProvider.overrideWith(
          () => _FakeChannelsNotifier(_testChannels),
        ),
        profileProvider.overrideWith(() => _FakeProfileNotifier()),
        presenceProvider.overrideWith(() => _FakePresenceNotifier()),
        activityProvider.overrideWith(() => _FakeActivityNotifier()),
        if (unreadBadge != null)
          unreadBadgeProvider.overrideWithValue(unreadBadge),
      ],
    );
    addTearDown(container.dispose);
    return (container, communityList);
  }

  Widget buildTestable(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light(), home: const DesktopShell()),
    );
  }

  testWidgets('lists communities on the rail with the active one indicated', (
    tester,
  ) async {
    useWideSurface(tester);
    final (container, _) = createContainer();

    await tester.pumpWidget(buildTestable(container));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('community-rail-item-community-a')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('community-rail-item-community-b')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('community-rail-active-community-a')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('community-rail-inactive-community-b')),
      findsOneWidget,
    );
    expect(find.byTooltip('Add community'), findsOneWidget);
    // The three panes render: channel list content and empty message pane.
    expect(find.text('general'), findsOneWidget);
    expect(find.text('Select a channel'), findsOneWidget);
  });

  testWidgets('tapping another community switches and resets the shell state', (
    tester,
  ) async {
    useWideSurface(tester);
    final (container, communityList) = createContainer();

    await tester.pumpWidget(buildTestable(container));
    await tester.pumpAndSettle();

    // Dirty the shell state so the reset is observable. The id matches no
    // loaded channel, keeping the workspace on its light empty state.
    container.read(shellStateProvider.notifier)
      ..selectChannel('missing-channel')
      ..toggleActivityPanel();
    await tester.pump();
    expect(container.read(shellStateProvider), isNot(const ShellState()));

    await tester.tap(
      find.byKey(const ValueKey('community-rail-item-community-b')),
    );
    await tester.pumpAndSettle();

    expect(communityList.switchedTo, ['community-b']);
    expect(container.read(shellStateProvider), const ShellState());
    expect(
      find.byKey(const ValueKey('community-rail-active-community-b')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('community-rail-inactive-community-a')),
      findsOneWidget,
    );
  });

  testWidgets('tapping the active community shows channels without switching', (
    tester,
  ) async {
    useWideSurface(tester);
    final (container, communityList) = createContainer();

    await tester.pumpWidget(buildTestable(container));
    await tester.pumpAndSettle();

    container.read(shellStateProvider.notifier).showPulse();
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('community-rail-item-community-a')),
    );
    await tester.pumpAndSettle();

    expect(communityList.switchedTo, isEmpty);
    expect(
      container.read(shellStateProvider).mainContent,
      ShellMainContent.channels,
    );
  });

  group('activity side panel', () {
    testWidgets('the bell toggles the panel as a right-edge overlay', (
      tester,
    ) async {
      useWideSurface(tester);
      final (container, _) = createContainer();

      await tester.pumpWidget(buildTestable(container));
      await tester.pumpAndSettle();
      expect(find.byType(ActivityView), findsNothing);

      await tester.tap(find.byKey(const ValueKey('community-rail-activity')));
      await tester.pumpAndSettle();

      expect(
        container.read(shellStateProvider).sidePanel,
        isA<ShellSidePanelActivity>(),
      );
      expect(find.byType(ActivityView), findsOneWidget);
      final panel = find.byType(SidePanelSurface);
      expect(tester.getSize(panel).width, kSidePanelWidth);
      expect(tester.getTopRight(panel).dx, 1440);
      // Overlay: the three shell panes stay mounted beneath it.
      expect(find.text('general'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('community-rail-activity')));
      await tester.pumpAndSettle();

      expect(find.byType(ActivityView), findsNothing);
      expect(
        container.read(shellStateProvider).sidePanel,
        isA<ShellSidePanelNone>(),
      );
    });

    testWidgets('the embedded panel drops the floating app-bar top inset', (
      tester,
    ) async {
      useWideSurface(tester);
      final (container, _) = createContainer();

      await tester.pumpWidget(buildTestable(container));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('community-rail-activity')));
      await tester.pumpAndSettle();

      // The panel header replaces the page's floating FrostedAppBar, so the
      // page's clearance (frostedAppBarHeight, 48 with no status bar) would
      // sit between the header and the first feed row as dead space.
      expect(
        find.descendant(
          of: find.byType(ActivityView),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Padding &&
                widget.padding == const EdgeInsets.only(top: Grid.xxs),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ActivityView),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Padding &&
                widget.padding == const EdgeInsets.only(top: 48),
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('opening a thread panel closes the activity panel', (
      tester,
    ) async {
      useWideSurface(tester);
      final (container, _) = createContainer();

      await tester.pumpWidget(buildTestable(container));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('community-rail-activity')));
      await tester.pumpAndSettle();
      expect(find.byType(ActivityView), findsOneWidget);

      container.read(shellStateProvider.notifier).openThreadPanel('root-1');
      await tester.pumpAndSettle();

      expect(find.byType(ActivityView), findsNothing);
      expect(
        container.read(shellStateProvider).sidePanel,
        isA<ShellSidePanelThread>(),
      );
    });

    testWidgets('Esc closes the open side panel', (tester) async {
      useWideSurface(tester);
      final (container, _) = createContainer();

      await tester.pumpWidget(buildTestable(container));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('community-rail-activity')));
      await tester.pumpAndSettle();
      expect(find.byType(ActivityView), findsOneWidget);

      // No text field holds focus: the shell's autofocus node carries the
      // binding.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(ActivityView), findsNothing);
      expect(
        container.read(shellStateProvider).sidePanel,
        isA<ShellSidePanelNone>(),
      );
    });

    testWidgets('the bell renders the unread badge count', (tester) async {
      useWideSurface(tester);
      final (container, _) = createContainer(
        unreadBadge: const UnreadBadgeState(
          highPriorityCount: 2,
          generalUnreadCount: 1,
        ),
      );

      await tester.pumpWidget(buildTestable(container));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('community-rail-activity-badge')),
        findsOneWidget,
      );
      expect(find.text('3'), findsOneWidget);
    });
  });
}

class _ActiveCommunityIdNotifier extends Notifier<String> {
  @override
  String build() => 'community-a';

  void setId(String id) => state = id;
}

final _activeCommunityIdProvider =
    NotifierProvider<_ActiveCommunityIdNotifier, String>(
      _ActiveCommunityIdNotifier.new,
    );

class _FakeCommunityListNotifier extends CommunityListNotifier {
  final List<Community> _communities;
  final List<String> switchedTo = [];

  _FakeCommunityListNotifier(this._communities);

  @override
  Future<List<Community>> build() async => _communities;

  @override
  Future<void> switchCommunity(String id) async {
    switchedTo.add(id);
    ref.read(_activeCommunityIdProvider.notifier).setId(id);
  }
}

class _FakeChannelsNotifier extends ChannelsNotifier {
  final List<Channel> _channels;

  _FakeChannelsNotifier(this._channels);

  @override
  Future<List<Channel>> build() async => _channels;

  @override
  Map<String, int> get latestObservedByChannel => const {};

  @override
  Map<String, Map<String, ObservedUnreadEvent>>
  get observedUnreadEventsByChannel => const {};
}

class _FakeProfileNotifier extends ProfileNotifier {
  @override
  Future<UserProfile?> build() async =>
      const UserProfile(pubkey: 'self', displayName: 'Self');
}

class _FakePresenceNotifier extends PresenceNotifier {
  @override
  Future<String> build() async => 'online';
}

class _FakeActivityNotifier extends ActivityNotifier {
  @override
  Future<HomeFeedResponse> build() async => HomeFeedResponse(
    mentions: const [],
    needsAction: const [],
    activity: const [],
    agentActivity: const [],
  );
}
