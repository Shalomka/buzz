import 'package:buzz/features/activity/activity_provider.dart';
import 'package:buzz/features/activity/feed_item.dart';
import 'package:buzz/features/channels/channel.dart';
import 'package:buzz/features/channels/channels_provider.dart';
import 'package:buzz/features/channels/unread_badge/observed_unread_event.dart';
import 'package:buzz/features/home/desktop_shell.dart';
import 'package:buzz/features/home/home_page.dart';
import 'package:buzz/features/profile/profile_provider.dart';
import 'package:buzz/features/profile/user_profile.dart';
import 'package:buzz/shared/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  final testChannels = [
    Channel(
      id: '1',
      name: 'general',
      channelType: 'stream',
      visibility: 'open',
      description: 'General discussion',
      createdBy: 'abc',
      createdAt: DateTime(2025),
      memberCount: 10,
      isMember: true,
    ),
  ];

  Widget buildTestable() {
    return ProviderScope(
      overrides: [
        channelsProvider.overrideWith(
          () => _FakeChannelsNotifier(testChannels),
        ),
        profileProvider.overrideWith(() => _FakeProfileNotifier()),
        presenceProvider.overrideWith(() => _FakePresenceNotifier()),
        activityProvider.overrideWith(() => _FakeActivityNotifier()),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const HomePage()),
    );
  }

  testWidgets('renders the mobile tab shell at narrow widths', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.byType(DesktopShell), findsNothing);
    // The floating tab bar destinations.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
  });

  testWidgets('renders the desktop shell at expanded widths', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.byType(DesktopShell), findsOneWidget);
    // The embedded channel list pane and the empty message pane.
    expect(find.text('general'), findsOneWidget);
    expect(find.text('Select a channel'), findsOneWidget);
    // No floating tab bar.
    expect(find.text('Home'), findsNothing);
    expect(find.text('Search'), findsNothing);
  });
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
      const UserProfile(pubkey: 'aabb', displayName: 'Test');
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
