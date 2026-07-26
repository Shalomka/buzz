import 'package:buzz/features/channels/channel.dart';
import 'package:buzz/features/channels/channel_detail_page.dart';
import 'package:buzz/features/channels/channel_link_navigation.dart';
import 'package:buzz/features/channels/channel_management_provider.dart';
import 'package:buzz/features/channels/channel_messages_provider.dart';
import 'package:buzz/features/channels/channel_typing_provider.dart';
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

final _currentChannel = Channel(
  id: 'channel-current',
  name: 'current',
  channelType: 'stream',
  visibility: 'open',
  description: 'Current channel',
  createdBy: 'creator',
  createdAt: DateTime(2026),
  memberCount: 3,
  isMember: true,
  lastMessageAt: DateTime.fromMillisecondsSinceEpoch(1000 * 1000, isUtc: true),
);

final _targetChannel = Channel(
  id: 'channel-target',
  name: 'target',
  channelType: 'stream',
  visibility: 'open',
  description: 'Target channel',
  createdBy: 'creator',
  createdAt: DateTime(2026),
  memberCount: 3,
  isMember: true,
  lastMessageAt: DateTime.fromMillisecondsSinceEpoch(2000 * 1000, isUtc: true),
);

void main() {
  void useNarrowSurface(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
  }

  void useWideSurface(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
  }

  ProviderContainer createContainer() {
    final loaded = [_currentChannel, _targetChannel];
    final container = ProviderContainer(
      overrides: [
        channelsProvider.overrideWith(() => _FakeChannelsNotifier(loaded)),
        profileProvider.overrideWith(() => _FakeProfileNotifier()),
        userCacheProvider.overrideWith(() => _FakeUserCacheNotifier()),
        readStateProvider.overrideWith(() => _FakeReadStateNotifier()),
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
    required String channelId,
    NavigatorObserver? observer,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        navigatorObservers: [?observer],
        home: _LinkTapHost(
          channelId: channelId,
          currentChannelId: _currentChannel.id,
        ),
      ),
    );
  }

  testWidgets('tapping a link to the current channel is a no-op', (
    tester,
  ) async {
    useNarrowSurface(tester);
    final container = createContainer();
    final observer = _CountingNavigatorObserver();

    await tester.pumpWidget(
      buildTestable(
        container,
        channelId: _currentChannel.id,
        observer: observer,
      ),
    );
    // Resolve the channels list before tapping — openChannelLink reads it
    // synchronously, matching real usage where channels load before any
    // link can be rendered.
    await container.read(channelsProvider.future);
    await tester.pump();
    final pushesAfterMount = observer.pushCount;

    await tester.tap(find.text('open link'));
    await tester.pump();
    await tester.pump();

    expect(observer.pushCount, pushesAfterMount);
    expect(find.byType(ChannelDetailPage), findsNothing);
    expect(container.read(shellStateProvider).selectedChannelId, isNull);
  });

  testWidgets('at narrow widths a channel link pushes the detail page', (
    tester,
  ) async {
    useNarrowSurface(tester);
    final container = createContainer();
    final observer = _CountingNavigatorObserver();

    await tester.pumpWidget(
      buildTestable(
        container,
        channelId: _targetChannel.id,
        observer: observer,
      ),
    );
    // Resolve the channels list before tapping — openChannelLink reads it
    // synchronously, matching real usage where channels load before any
    // link can be rendered.
    await container.read(channelsProvider.future);
    await tester.pump();
    final pushesAfterMount = observer.pushCount;

    await tester.tap(find.text('open link'));
    await tester.pump();
    await tester.pump();

    expect(observer.pushCount, pushesAfterMount + 1);
    expect(find.byType(ChannelDetailPage), findsOneWidget);
    expect(find.text('target'), findsOneWidget);
    // Push navigation stays authoritative at narrow: no shell state write.
    expect(container.read(shellStateProvider).selectedChannelId, isNull);
  });

  testWidgets('at expanded widths a channel link selects the channel in the '
      'shell without a push', (tester) async {
    useWideSurface(tester);
    final container = createContainer();
    final observer = _CountingNavigatorObserver();

    await tester.pumpWidget(
      buildTestable(
        container,
        channelId: _targetChannel.id,
        observer: observer,
      ),
    );
    // Resolve the channels list before tapping — openChannelLink reads it
    // synchronously, matching real usage where channels load before any
    // link can be rendered.
    await container.read(channelsProvider.future);
    await tester.pump();
    final pushesAfterMount = observer.pushCount;

    await tester.tap(find.text('open link'));
    await tester.pump();
    await tester.pump();

    expect(observer.pushCount, pushesAfterMount);
    expect(find.byType(ChannelDetailPage), findsNothing);
    expect(
      container.read(shellStateProvider).selectedChannelId,
      _targetChannel.id,
    );
  });
}

class _LinkTapHost extends ConsumerWidget {
  final String channelId;
  final String currentChannelId;

  const _LinkTapHost({required this.channelId, required this.currentChannelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => openChannelLink(
            context: context,
            ref: ref,
            channelId: channelId,
            currentChannelId: currentChannelId,
          ),
          child: const Text('open link'),
        ),
      ),
    );
  }
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

class _FakeReadStateNotifier extends ReadStateNotifier {
  @override
  ReadStateState build() => const ReadStateState(
    isReady: true,
    pubkey: 'self',
    contexts: {},
    version: 0,
  );

  @override
  void markContextRead(String contextId, int unixTimestamp) {
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
