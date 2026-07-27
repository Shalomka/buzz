import 'package:buzz/features/channels/channel.dart';
import 'package:buzz/features/channels/channel_detail_page.dart';
import 'package:buzz/features/channels/channel_management_provider.dart';
import 'package:buzz/features/channels/channel_messages_provider.dart';
import 'package:buzz/features/channels/channel_typing_provider.dart';
import 'package:buzz/features/channels/channel_workspace.dart';
import 'package:buzz/features/channels/channels_provider.dart';
import 'package:buzz/features/channels/read_state/read_state_provider.dart';
import 'package:buzz/features/channels/thread_detail_page.dart';
import 'package:buzz/features/channels/thread_replies_provider.dart';
import 'package:buzz/features/forum/forum_models.dart';
import 'package:buzz/features/forum/forum_post_card.dart';
import 'package:buzz/features/forum/forum_provider.dart';
import 'package:buzz/features/forum/forum_thread_page.dart';
import 'package:buzz/features/profile/profile_provider.dart';
import 'package:buzz/features/profile/user_cache_provider.dart';
import 'package:buzz/features/profile/user_profile.dart';
import 'package:buzz/shared/relay/relay.dart';
import 'package:buzz/shared/shell/shell_state.dart';
import 'package:buzz/shared/shell/shell_state_provider.dart';
import 'package:buzz/shared/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

final _channelA = Channel(
  id: 'channel-a',
  name: 'alpha',
  channelType: 'stream',
  visibility: 'open',
  description: 'Alpha discussion',
  createdBy: 'creator',
  createdAt: DateTime(2026),
  memberCount: 3,
  isMember: true,
  lastMessageAt: DateTime.fromMillisecondsSinceEpoch(1000 * 1000, isUtc: true),
);

final _channelB = Channel(
  id: 'channel-b',
  name: 'beta',
  channelType: 'stream',
  visibility: 'open',
  description: 'Beta discussion',
  createdBy: 'creator',
  createdAt: DateTime(2026),
  memberCount: 3,
  isMember: true,
  lastMessageAt: DateTime.fromMillisecondsSinceEpoch(2000 * 1000, isUtc: true),
);

final _forumChannel = Channel(
  id: 'channel-forum',
  name: 'gamma',
  channelType: 'forum',
  visibility: 'open',
  description: 'Gamma forum',
  createdBy: 'creator',
  createdAt: DateTime(2026),
  memberCount: 3,
  isMember: true,
  lastMessageAt: DateTime.fromMillisecondsSinceEpoch(3000 * 1000, isUtc: true),
);

/// Build a kind:9 channel message event. Passing [parentId] marks it as a
/// (non-broadcast) reply, so it stays out of the main timeline.
NostrEvent _messageEvent({
  required String id,
  required String content,
  String pubkey = 'author',
  int createdAt = 100,
  String? parentId,
  String? rootId,
}) {
  return NostrEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    kind: 9,
    tags: [
      ['h', 'channel-a'],
      if (parentId != null) ...[
        ['e', rootId ?? parentId, '', 'root'],
        ['e', parentId, '', 'reply'],
      ],
    ],
    content: content,
    sig: '',
  );
}

final _forumPost = ForumPost(
  eventId: 'post-1',
  pubkey: 'author',
  content: 'Forum post body',
  kind: 45001,
  createdAt: 500,
  channelId: 'channel-forum',
  tags: const [
    ['h', 'channel-forum'],
  ],
);

void main() {
  void useWideSurface(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
  }

  ProviderContainer createContainer({
    List<Channel>? channels,
    _RecordingReadStateNotifier? readState,
    Map<String, _FakeMessagesNotifier>? messages,
  }) {
    final loaded = channels ?? [_channelA, _channelB];
    final container = ProviderContainer(
      overrides: [
        channelsProvider.overrideWith(() => _FakeChannelsNotifier(loaded)),
        profileProvider.overrideWith(() => _FakeProfileNotifier()),
        userCacheProvider.overrideWith(() => _FakeUserCacheNotifier()),
        readStateProvider.overrideWith(
          () => readState ?? _RecordingReadStateNotifier(),
        ),
        channelActionsProvider.overrideWith((ref) => _FakeChannelActions(ref)),
        relayClientProvider.overrideWithValue(
          RelayClient(baseUrl: 'http://localhost:3000'),
        ),
        threadRepliesProvider.overrideWith((ref, args) async => <NostrEvent>[]),
        forumPostsProvider.overrideWith(
          (ref, channelId) async => ForumPostsResponse(posts: [_forumPost]),
        ),
        forumThreadProvider.overrideWith(
          (ref, args) async => ForumThreadResponse(
            post: _forumPost,
            replies: const [],
            totalReplies: 0,
          ),
        ),
        for (final channel in loaded) ...[
          channelMessagesProvider(channel.id).overrideWith(
            () => messages?[channel.id] ?? _FakeMessagesNotifier(channel.id),
          ),
          channelTypingProvider(
            channel.id,
          ).overrideWith(() => _FakeTypingNotifier(channel.id)),
          channelDetailsProvider(
            channel.id,
          ).overrideWith((ref) async => ChannelDetails.fromChannel(channel)),
          channelCanvasProvider(channel.id).overrideWith(
            (ref) async => ChannelCanvas(
              content: null,
              updatedAt: null,
              authorPubkey: null,
            ),
          ),
          channelMembersProvider(
            channel.id,
          ).overrideWith((ref) async => <ChannelMember>[]),
        ],
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Widget buildTestable(
    ProviderContainer container, {
    NavigatorObserver? observer,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        navigatorObservers: [?observer],
        home: const Scaffold(body: ChannelWorkspace()),
      ),
    );
  }

  testWidgets('renders the empty state with no selection', (tester) async {
    useWideSurface(tester);
    final container = createContainer();

    await tester.pumpWidget(buildTestable(container));
    await tester.pump();

    expect(find.text('Select a channel'), findsOneWidget);
    expect(find.byType(ChannelDetailView), findsNothing);
  });

  testWidgets('renders the empty state when the selection matches no loaded '
      'channel', (tester) async {
    useWideSurface(tester);
    final container = createContainer();
    container.read(shellStateProvider.notifier).selectChannel('missing');

    await tester.pumpWidget(buildTestable(container));
    await tester.pump();

    expect(find.text('Select a channel'), findsOneWidget);
    expect(find.byType(ChannelDetailView), findsNothing);
  });

  testWidgets('selecting a channel swaps in the view without a route push', (
    tester,
  ) async {
    useWideSurface(tester);
    final container = createContainer();
    final observer = _CountingNavigatorObserver();

    await tester.pumpWidget(buildTestable(container, observer: observer));
    await tester.pump();
    final pushesAfterMount = observer.pushCount;

    container.read(shellStateProvider.notifier).selectChannel('channel-a');
    await tester.pump();
    await tester.pump();

    expect(find.byType(ChannelDetailView), findsOneWidget);
    expect(find.text('Select a channel'), findsNothing);
    expect(find.text('alpha'), findsOneWidget);
    expect(observer.pushCount, pushesAfterMount);
    // Embedded at the shell root: no route below, so no back button.
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('marks the channel read on selection and re-marks on switch', (
    tester,
  ) async {
    useWideSurface(tester);
    final readState = _RecordingReadStateNotifier();
    final container = createContainer(readState: readState);

    await tester.pumpWidget(buildTestable(container));
    await tester.pump();
    expect(readState.markCalls, isEmpty);

    container.read(shellStateProvider.notifier).selectChannel('channel-a');
    await tester.pump();
    await tester.pump();
    expect(readState.markCalls, [('channel-a', 1000)]);

    container.read(shellStateProvider.notifier).selectChannel('channel-b');
    await tester.pump();
    await tester.pump();
    expect(readState.markCalls, [('channel-a', 1000), ('channel-b', 2000)]);
    expect(find.text('beta'), findsOneWidget);
  });

  testWidgets('embedded manage-channel leave clears the selection instead of '
      'popping the root route', (tester) async {
    useWideSurface(tester);
    final container = createContainer();
    final observer = _CountingNavigatorObserver();

    await tester.pumpWidget(buildTestable(container, observer: observer));
    await tester.pump();

    container.read(shellStateProvider.notifier).selectChannel('channel-a');
    await tester.pump();
    await tester.pump();
    expect(find.byType(ChannelDetailView), findsOneWidget);
    final pushesBeforeSheet = observer.pushCount;
    final popsBeforeSheet = observer.popCount;

    await tester.tap(find.byTooltip('Manage channel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave channel'));
    await tester.pumpAndSettle();

    // The shell selection is cleared instead of popping the root route.
    expect(container.read(shellStateProvider).selectedChannelId, isNull);
    expect(find.byType(ChannelDetailView), findsNothing);
    expect(find.text('Select a channel'), findsOneWidget);
    // Only the sheet's own route was pushed and popped; the root route
    // hosting the workspace is still mounted.
    expect(observer.pushCount, pushesBeforeSheet + 1);
    expect(observer.popCount, popsBeforeSheet + 1);
    expect(find.byType(ChannelWorkspace), findsOneWidget);
  });

  testWidgets('a repeated identical deep-link selection remounts the view', (
    tester,
  ) async {
    useWideSurface(tester);
    final readState = _RecordingReadStateNotifier();
    final container = createContainer(readState: readState);
    final notifier = container.read(shellStateProvider.notifier);

    await tester.pumpWidget(buildTestable(container));
    await tester.pump();

    notifier.selectChannel('channel-a', initialMessageId: 'message-1');
    await tester.pump();
    await tester.pump();
    expect(readState.markCalls, [('channel-a', 1000)]);

    // Same channel, same pending ID: the nonce bump forces a remount, which
    // re-runs the keyed read-state effect — matching push-a-fresh-route
    // behavior.
    notifier.selectChannel('channel-a', initialMessageId: 'message-1');
    await tester.pump();
    await tester.pump();
    expect(readState.markCalls, [('channel-a', 1000), ('channel-a', 1000)]);
  });

  group('thread side panel', () {
    /// Container whose channel-a window holds [events] and can additionally
    /// fetch [loadable] through the deep-link loader.
    (ProviderContainer, _FakeMessagesNotifier) createThreadContainer({
      List<NostrEvent> events = const [],
      List<NostrEvent> loadable = const [],
    }) {
      final messages = _FakeMessagesNotifier(
        'channel-a',
        events: events,
        loadable: loadable,
      );
      final container = createContainer(messages: {'channel-a': messages});
      return (container, messages);
    }

    testWidgets('renders as a right-edge overlay above the message pane', (
      tester,
    ) async {
      useWideSurface(tester);
      final (container, _) = createThreadContainer(
        events: [_messageEvent(id: 'root-1', content: 'root message')],
      );

      await tester.pumpWidget(buildTestable(container));
      await tester.pump();
      container.read(shellStateProvider.notifier)
        ..selectChannel('channel-a')
        ..openThreadPanel('root-1');
      await tester.pump();
      await tester.pump();

      expect(find.byType(ThreadView), findsOneWidget);
      // Overlay, not a replacement: the message pane stays mounted beneath.
      expect(find.byType(ChannelDetailView), findsOneWidget);

      final panel = find.byType(SidePanelSurface);
      expect(tester.getSize(panel).width, kSidePanelWidth);
      expect(tester.getTopRight(panel).dx, 1440);
      expect(tester.getTopLeft(panel).dy, 0);
    });

    testWidgets('resolves a nested thread head that the main timeline omits', (
      tester,
    ) async {
      useWideSurface(tester);
      final (container, _) = createThreadContainer(
        events: [
          _messageEvent(id: 'root-1', content: 'root message'),
          _messageEvent(
            id: 'reply-1',
            content: 'nested reply',
            createdAt: 200,
            parentId: 'root-1',
          ),
        ],
      );

      await tester.pumpWidget(buildTestable(container));
      await tester.pump();
      container.read(shellStateProvider.notifier).selectChannel('channel-a');
      await tester.pump();
      await tester.pump();
      // The reply is not a main-timeline entry, so it renders nowhere yet.
      expect(find.text('nested reply'), findsNothing);

      container.read(shellStateProvider.notifier).openThreadPanel('reply-1');
      await tester.pump();
      await tester.pump();

      expect(find.byType(ThreadView), findsOneWidget);
      expect(find.text('nested reply'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('loads a thread root outside the window before rendering', (
      tester,
    ) async {
      useWideSurface(tester);
      final (container, messages) = createThreadContainer(
        events: [_messageEvent(id: 'root-1', content: 'root message')],
        loadable: [_messageEvent(id: 'far-root', content: 'far away root')],
      );

      await tester.pumpWidget(buildTestable(container));
      await tester.pump();
      container.read(shellStateProvider.notifier)
        ..selectChannel('channel-a')
        ..openThreadPanel('far-root');
      await tester.pump();

      // Loading state, not a permanent spinner: the loader was asked for the
      // missing root.
      expect(find.byType(ThreadView), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(messages.loadCalls, [
        {'far-root'},
      ]);

      await tester.pump();
      await tester.pump();

      expect(find.byType(ThreadView), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SidePanelSurface),
          matching: find.text('far away root'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('re-fetches a thread head that leaves the loaded window', (
      tester,
    ) async {
      useWideSurface(tester);
      final root = _messageEvent(id: 'root-1', content: 'root message');
      final (container, messages) = createThreadContainer(
        events: [root],
        loadable: [root],
      );

      await tester.pumpWidget(buildTestable(container));
      await tester.pump();
      container.read(shellStateProvider.notifier)
        ..selectChannel('channel-a')
        ..openThreadPanel('root-1');
      await tester.pump();
      await tester.pump();
      expect(find.byType(ThreadView), findsOneWidget);
      // The head was already loaded, so no fetch was needed.
      expect(messages.loadCalls, isEmpty);

      // The head drops out of the window (eviction, window rebuild, an
      // unpinned deep-link event). Resolution must be retried rather than
      // leaving the panel on a permanent spinner.
      messages.setEvents(const []);
      await tester.pump();
      await tester.pump();

      expect(messages.loadCalls, [
        {'root-1'},
      ]);
      await tester.pump();
      expect(find.byType(ThreadView), findsOneWidget);
    });

    testWidgets('an unresolvable thread root offers a retry, not a spinner', (
      tester,
    ) async {
      useWideSurface(tester);
      // 'ghost-root' is in neither the window nor the loader's reach.
      final (container, messages) = createThreadContainer(
        events: [_messageEvent(id: 'root-1', content: 'root message')],
      );

      await tester.pumpWidget(buildTestable(container));
      await tester.pump();
      container.read(shellStateProvider.notifier)
        ..selectChannel('channel-a')
        ..openThreadPanel('ghost-root');
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text("Couldn't load this thread"), findsOneWidget);
      expect(messages.loadCalls, [
        {'ghost-root'},
      ]);

      await tester.tap(find.byKey(const ValueKey('thread-panel-retry')));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Retry re-runs the fetch and lands back on the terminal state.
      expect(messages.loadCalls, [
        {'ghost-root'},
        {'ghost-root'},
      ]);
      expect(find.text("Couldn't load this thread"), findsOneWidget);
    });

    testWidgets('a failing deep-link fetch shows the retry state', (
      tester,
    ) async {
      useWideSurface(tester);
      final messages = _FakeMessagesNotifier(
        'channel-a',
        events: [_messageEvent(id: 'root-1', content: 'root message')],
        failLoad: true,
      );
      final container = createContainer(messages: {'channel-a': messages});

      await tester.pumpWidget(buildTestable(container));
      await tester.pump();
      container.read(shellStateProvider.notifier)
        ..selectChannel('channel-a')
        ..openThreadPanel('far-root');
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text("Couldn't load this thread"), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('releases exactly its own thread-root pin on close', (
      tester,
    ) async {
      useWideSurface(tester);
      final (container, messages) = createThreadContainer(
        events: [_messageEvent(id: 'root-1', content: 'root message')],
      );

      await tester.pumpWidget(buildTestable(container));
      await tester.pump();
      container.read(shellStateProvider.notifier)
        ..selectChannel('channel-a')
        ..openThreadPanel('root-1');
      await tester.pump();
      await tester.pump();
      expect(find.byType(ThreadView), findsOneWidget);
      // The panel holds its pin for as long as it is open.
      expect(messages.releaseCalls, isEmpty);

      await tester.tap(find.byKey(const ValueKey('side-panel-close')));
      await tester.pump();
      await tester.pump();

      // Exactly one release, scoped to the root the panel itself retained:
      // retention is refcounted, so this cannot unpin the message pane's own
      // deep-link events.
      expect(messages.releaseCalls, [
        {'root-1'},
      ]);
    });

    testWidgets('the embedded panel drops the floating app-bar top inset', (
      tester,
    ) async {
      useWideSurface(tester);
      final (container, _) = createThreadContainer(
        events: [_messageEvent(id: 'root-1', content: 'root message')],
      );

      await tester.pumpWidget(buildTestable(container));
      await tester.pump();
      container.read(shellStateProvider.notifier)
        ..selectChannel('channel-a')
        ..openThreadPanel('root-1');
      await tester.pump();
      await tester.pump();

      final list = tester.widget<ScrollablePositionedList>(
        find.descendant(
          of: find.byType(ThreadView),
          matching: find.byType(ScrollablePositionedList),
        ),
      );
      // The panel header replaces the page's floating FrostedAppBar, so the
      // page's clearance (frostedAppBarHeight, 48 with no status bar) would
      // be dead space here.
      expect(list.padding?.top, Grid.xxs);
    });

    testWidgets('the close button clears the panel', (tester) async {
      useWideSurface(tester);
      final (container, _) = createThreadContainer(
        events: [_messageEvent(id: 'root-1', content: 'root message')],
      );

      await tester.pumpWidget(buildTestable(container));
      await tester.pump();
      container.read(shellStateProvider.notifier)
        ..selectChannel('channel-a')
        ..openThreadPanel('root-1');
      await tester.pump();
      await tester.pump();
      expect(find.byType(ThreadView), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('side-panel-close')));
      await tester.pump();
      await tester.pump();

      expect(
        container.read(shellStateProvider).sidePanel,
        isA<ShellSidePanelNone>(),
      );
      expect(find.byType(ThreadView), findsNothing);
    });

    testWidgets('switching channels clears the panel', (tester) async {
      useWideSurface(tester);
      final (container, _) = createThreadContainer(
        events: [_messageEvent(id: 'root-1', content: 'root message')],
      );

      await tester.pumpWidget(buildTestable(container));
      await tester.pump();
      container.read(shellStateProvider.notifier)
        ..selectChannel('channel-a')
        ..openThreadPanel('root-1');
      await tester.pump();
      await tester.pump();
      expect(find.byType(ThreadView), findsOneWidget);

      container.read(shellStateProvider.notifier).selectChannel('channel-b');
      await tester.pump();
      await tester.pump();

      expect(find.byType(ThreadView), findsNothing);
      expect(
        container.read(shellStateProvider).sidePanel,
        isA<ShellSidePanelNone>(),
      );
    });

    testWidgets('opening the activity panel closes the thread panel', (
      tester,
    ) async {
      useWideSurface(tester);
      final (container, _) = createThreadContainer(
        events: [_messageEvent(id: 'root-1', content: 'root message')],
      );

      await tester.pumpWidget(buildTestable(container));
      await tester.pump();
      container.read(shellStateProvider.notifier)
        ..selectChannel('channel-a')
        ..openThreadPanel('root-1');
      await tester.pump();
      await tester.pump();
      expect(find.byType(ThreadView), findsOneWidget);

      container.read(shellStateProvider.notifier).toggleActivityPanel();
      await tester.pump();
      await tester.pump();

      expect(find.byType(ThreadView), findsNothing);
      expect(find.byType(SidePanelSurface), findsNothing);
    });

    testWidgets('a deep-link selection with a thread root opens the panel', (
      tester,
    ) async {
      useWideSurface(tester);
      final (container, _) = createThreadContainer(
        events: [_messageEvent(id: 'root-1', content: 'root message')],
      );
      final observer = _CountingNavigatorObserver();

      await tester.pumpWidget(buildTestable(container, observer: observer));
      await tester.pump();
      final pushesBefore = observer.pushCount;

      // Mirrors what the deep-link dispatcher writes at expanded widths.
      container
          .read(shellStateProvider.notifier)
          .selectChannel(
            'channel-a',
            initialMessageId: 'root-1',
            initialThreadRootId: 'root-1',
          );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final panel = container.read(shellStateProvider).sidePanel;
      expect(panel, isA<ShellSidePanelThread>());
      expect((panel as ShellSidePanelThread).rootId, 'root-1');
      expect(panel.initialMessageId, 'root-1');
      expect(find.byType(ThreadView), findsOneWidget);
      // No push: the thread opened in the panel.
      expect(observer.pushCount, pushesBefore);
    });
  });

  group('forum thread side panel', () {
    testWidgets('tapping a post opens the panel instead of pushing', (
      tester,
    ) async {
      useWideSurface(tester);
      final container = createContainer(channels: [_channelA, _forumChannel]);
      final observer = _CountingNavigatorObserver();

      await tester.pumpWidget(buildTestable(container, observer: observer));
      await tester.pump();
      container
          .read(shellStateProvider.notifier)
          .selectChannel('channel-forum');
      await tester.pumpAndSettle();
      final pushesBefore = observer.pushCount;

      await tester.tap(find.byType(ForumPostCard));
      await tester.pumpAndSettle();

      expect(
        container.read(shellStateProvider).sidePanel,
        isA<ShellSidePanelForumThread>(),
      );
      expect(find.byType(ForumThreadView), findsOneWidget);
      expect(observer.pushCount, pushesBefore);
    });

    testWidgets('the embedded panel drops the floating app-bar top inset', (
      tester,
    ) async {
      useWideSurface(tester);
      final container = createContainer(channels: [_channelA, _forumChannel]);

      await tester.pumpWidget(buildTestable(container));
      await tester.pump();
      container.read(shellStateProvider.notifier)
        ..selectChannel('channel-forum')
        ..openForumThreadPanel('post-1');
      await tester.pumpAndSettle();

      final list = tester.widget<ListView>(
        find.descendant(
          of: find.byType(ForumThreadView),
          matching: find.byType(ListView),
        ),
      );
      // Same reasoning as the thread panel: the page's frostedAppBarHeight
      // clearance (48 with no status bar) is dead space under the panel
      // header.
      expect(
        list.padding,
        const EdgeInsets.only(top: Grid.xxs, bottom: Grid.xs),
      );
    });
  });
}

class _FakeChannelsNotifier extends ChannelsNotifier {
  final List<Channel> _channels;

  _FakeChannelsNotifier(this._channels);

  @override
  Future<List<Channel>> build() async => _channels;

  @override
  void clearObservedUnreadCoveredByRead(String channelId, int readAt) {}
}

class _FakeMessagesNotifier extends ChannelMessagesNotifier {
  /// Events already inside the loaded channel window.
  final List<NostrEvent> events;

  /// Events the deep-link loader can fetch on demand, mirroring the real
  /// notifier's `loadEventsById` behavior of widening the window.
  final List<NostrEvent> loadable;

  /// Whether the deep-link loader should fail, mirroring an unreachable relay.
  final bool failLoad;

  final List<Set<String>> loadCalls = [];
  final List<Set<String>> releaseCalls = [];

  _FakeMessagesNotifier(
    super.channelId, {
    this.events = const [],
    this.loadable = const [],
    this.failLoad = false,
  });

  @override
  AsyncValue<List<NostrEvent>> build() => AsyncData(events);

  /// Replaces the loaded window, e.g. to drop an event out of it.
  void setEvents(List<NostrEvent> next) => state = AsyncData(next);

  @override
  bool get reachedOldest => true;

  @override
  Future<bool> fetchOlder() async => false;

  @override
  Future<void> loadEventsById(Iterable<String> eventIds) async {
    final ids = eventIds.toSet();
    loadCalls.add(ids);
    if (failLoad) throw Exception('deep-link fetch failed');
    final fetched = loadable.where((event) => ids.contains(event.id)).toList();
    if (fetched.isEmpty) return;
    state = AsyncData([...?state.value, ...fetched]);
  }

  @override
  void releaseDeepLinkEvents(Iterable<String> eventIds) {
    releaseCalls.add(eventIds.toSet());
  }
}

class _FakeTypingNotifier extends ChannelTypingNotifier {
  _FakeTypingNotifier(super.channelId);

  @override
  List<TypingEntry> build() => const [];
}

class _FakeProfileNotifier extends ProfileNotifier {
  @override
  Future<UserProfile?> build() async =>
      const UserProfile(pubkey: 'self', displayName: 'Self');
}

class _FakeUserCacheNotifier extends UserCacheNotifier {
  @override
  Map<String, UserProfile> build() => const {};

  @override
  UserProfile? get(String pubkey) => null;

  @override
  void preload(List<String> pubkeys) {}
}

class _RecordingReadStateNotifier extends ReadStateNotifier {
  final List<(String, int)> markCalls = [];

  @override
  ReadStateState build() => const ReadStateState(
    isReady: true,
    pubkey: 'self',
    contexts: {},
    version: 0,
  );

  @override
  void markContextRead(String contextId, int unixTimestamp) {
    markCalls.add((contextId, unixTimestamp));
    state = state.copyWithContext(contextId, unixTimestamp);
  }
}

class _CountingNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;
  int popCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount += 1;
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount += 1;
    super.didPop(route, previousRoute);
  }
}

class _FakeChannelActions extends ChannelActions {
  _FakeChannelActions(Ref ref)
    : super(
        ref: ref,
        session: ref.read(relaySessionProvider.notifier),
        signedEventRelay: SignedEventRelay(
          session: ref.read(relaySessionProvider.notifier),
          nsec: null,
        ),
        currentPubkey: 'self',
      );

  @override
  Future<void> leaveChannel(String channelId) async {}
}
