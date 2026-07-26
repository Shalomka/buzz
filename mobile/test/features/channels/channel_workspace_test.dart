import 'package:buzz/features/channels/channel.dart';
import 'package:buzz/features/channels/channel_detail_page.dart';
import 'package:buzz/features/channels/channel_management_provider.dart';
import 'package:buzz/features/channels/channel_messages_provider.dart';
import 'package:buzz/features/channels/channel_typing_provider.dart';
import 'package:buzz/features/channels/channel_workspace.dart';
import 'package:buzz/features/channels/channels_provider.dart';
import 'package:buzz/features/channels/read_state/read_state_provider.dart';
import 'package:buzz/features/profile/profile_provider.dart';
import 'package:buzz/features/profile/user_cache_provider.dart';
import 'package:buzz/features/profile/user_profile.dart';
import 'package:buzz/shared/relay/relay.dart';
import 'package:buzz/shared/shell/shell_state_provider.dart';
import 'package:buzz/shared/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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

void main() {
  void useWideSurface(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
  }

  ProviderContainer createContainer({
    List<Channel>? channels,
    _RecordingReadStateNotifier? readState,
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
        relayClientProvider.overrideWithValue(
          RelayClient(baseUrl: 'http://localhost:3000'),
        ),
        for (final channel in loaded) ...[
          channelMessagesProvider(
            channel.id,
          ).overrideWith(() => _FakeMessagesNotifier(channel.id)),
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
  _FakeMessagesNotifier(super.channelId);

  @override
  AsyncValue<List<NostrEvent>> build() => const AsyncData([]);

  @override
  bool get reachedOldest => true;

  @override
  Future<bool> fetchOlder() async => false;

  @override
  Future<void> loadEventsById(Iterable<String> eventIds) async {}

  @override
  void releaseDeepLinkEvents(Iterable<String> eventIds) {}
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

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount += 1;
    super.didPush(route, previousRoute);
  }
}
