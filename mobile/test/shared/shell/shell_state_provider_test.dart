import 'package:buzz/shared/community/community.dart';
import 'package:buzz/shared/community/community_provider.dart';
import 'package:buzz/shared/shell/shell_state.dart';
import 'package:buzz/shared/shell/shell_state_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        activeCommunityProvider.overrideWith((ref) {
          final id = ref.watch(_activeCommunityIdProvider);
          return Community(
            id: id,
            name: 'Community $id',
            relayUrl: 'wss://relay.test',
            addedAt: DateTime(2026),
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    // Keep the shell provider active so community changes propagate to it.
    container.listen(shellStateProvider, (_, _) {});
    return container;
  }

  test('starts in the initial state', () async {
    final container = buildContainer();

    expect(container.read(shellStateProvider), const ShellState());
  });

  group('selectChannel', () {
    test('stores the id and forces channels content', () {
      final container = buildContainer();
      final notifier = container.read(shellStateProvider.notifier);

      notifier.showPulse();
      notifier.selectChannel('channel-1');

      final state = container.read(shellStateProvider);
      expect(state.selectedChannelId, 'channel-1');
      expect(state.mainContent, ShellMainContent.channels);
    });

    test('stores pending IDs and bumps the nonce', () {
      final container = buildContainer();
      final notifier = container.read(shellStateProvider.notifier);

      notifier.selectChannel(
        'channel-1',
        initialMessageId: 'msg-1',
        initialThreadRootId: 'root-1',
      );

      final state = container.read(shellStateProvider);
      expect(state.pendingInitialMessageId, 'msg-1');
      expect(state.pendingInitialThreadRootId, 'root-1');
      expect(state.pendingSelectionNonce, 1);
    });

    test('bumps the nonce again on a repeated identical deep link', () {
      final container = buildContainer();
      final notifier = container.read(shellStateProvider.notifier);

      notifier.selectChannel('channel-1', initialMessageId: 'msg-1');
      notifier.selectChannel('channel-1', initialMessageId: 'msg-1');

      expect(container.read(shellStateProvider).pendingSelectionNonce, 2);
    });

    test('without pending IDs clears stale ones and keeps the nonce', () {
      final container = buildContainer();
      final notifier = container.read(shellStateProvider.notifier);

      notifier.selectChannel(
        'channel-1',
        initialMessageId: 'msg-1',
        initialThreadRootId: 'root-1',
      );
      notifier.selectChannel('channel-2');

      final state = container.read(shellStateProvider);
      expect(state.selectedChannelId, 'channel-2');
      expect(state.pendingInitialMessageId, isNull);
      expect(state.pendingInitialThreadRootId, isNull);
      expect(state.pendingSelectionNonce, 1);
    });

    test('closes an open thread panel', () {
      final container = buildContainer();
      final notifier = container.read(shellStateProvider.notifier);

      notifier.openThreadPanel('root-1');
      notifier.selectChannel('channel-2');

      expect(
        container.read(shellStateProvider).sidePanel,
        const ShellSidePanelNone(),
      );
    });

    test('closes an open forum thread panel', () {
      final container = buildContainer();
      final notifier = container.read(shellStateProvider.notifier);

      notifier.openForumThreadPanel('post-1');
      notifier.selectChannel('channel-2');

      expect(
        container.read(shellStateProvider).sidePanel,
        const ShellSidePanelNone(),
      );
    });

    test('keeps the activity panel open', () {
      final container = buildContainer();
      final notifier = container.read(shellStateProvider.notifier);

      notifier.toggleActivityPanel();
      notifier.selectChannel('channel-1');

      expect(
        container.read(shellStateProvider).sidePanel,
        const ShellSidePanelActivity(),
      );
    });
  });

  group('side panels', () {
    test('are mutually exclusive', () {
      final container = buildContainer();
      final notifier = container.read(shellStateProvider.notifier);

      notifier.openThreadPanel('root-1', initialMessageId: 'msg-1');
      expect(
        container.read(shellStateProvider).sidePanel,
        const ShellSidePanelThread('root-1', initialMessageId: 'msg-1'),
      );

      notifier.openForumThreadPanel('post-1');
      expect(
        container.read(shellStateProvider).sidePanel,
        const ShellSidePanelForumThread('post-1'),
      );

      notifier.toggleActivityPanel();
      expect(
        container.read(shellStateProvider).sidePanel,
        const ShellSidePanelActivity(),
      );

      notifier.openThreadPanel('root-2');
      expect(
        container.read(shellStateProvider).sidePanel,
        const ShellSidePanelThread('root-2'),
      );
    });

    test('toggleActivityPanel toggles open and closed', () {
      final container = buildContainer();
      final notifier = container.read(shellStateProvider.notifier);

      notifier.toggleActivityPanel();
      expect(
        container.read(shellStateProvider).sidePanel,
        const ShellSidePanelActivity(),
      );

      notifier.toggleActivityPanel();
      expect(
        container.read(shellStateProvider).sidePanel,
        const ShellSidePanelNone(),
      );
    });

    test('closeSidePanel closes whichever panel is open', () {
      final container = buildContainer();
      final notifier = container.read(shellStateProvider.notifier);

      notifier.openThreadPanel('root-1');
      notifier.closeSidePanel();

      expect(
        container.read(shellStateProvider).sidePanel,
        const ShellSidePanelNone(),
      );
    });
  });

  test('clearSelection clears selection, pending IDs, and thread panel', () {
    final container = buildContainer();
    final notifier = container.read(shellStateProvider.notifier);

    notifier.selectChannel('channel-1', initialMessageId: 'msg-1');
    notifier.openThreadPanel('root-1');
    notifier.clearSelection();

    final state = container.read(shellStateProvider);
    expect(state.selectedChannelId, isNull);
    expect(state.pendingInitialMessageId, isNull);
    expect(state.pendingInitialThreadRootId, isNull);
    expect(state.sidePanel, const ShellSidePanelNone());
  });

  test('showPulse and showChannels switch the main content', () {
    final container = buildContainer();
    final notifier = container.read(shellStateProvider.notifier);

    notifier.showPulse();
    expect(
      container.read(shellStateProvider).mainContent,
      ShellMainContent.pulse,
    );

    notifier.showChannels();
    expect(
      container.read(shellStateProvider).mainContent,
      ShellMainContent.channels,
    );
  });

  test('community switch resets selection, pending IDs, and panel', () async {
    final container = buildContainer();
    final notifier = container.read(shellStateProvider.notifier);

    notifier.selectChannel(
      'channel-1',
      initialMessageId: 'msg-1',
      initialThreadRootId: 'root-1',
    );
    notifier.toggleActivityPanel();
    notifier.showPulse();
    expect(container.read(shellStateProvider), isNot(const ShellState()));

    container.read(_activeCommunityIdProvider.notifier).setId('community-b');
    await container.read(activeCommunityProvider.future);

    expect(container.read(shellStateProvider), const ShellState());
  });

  test('same community identity does not reset state', () async {
    final container = buildContainer();
    final notifier = container.read(shellStateProvider.notifier);

    notifier.selectChannel('channel-1');

    // Re-set the same id: activeCommunityProvider rebuilds, but the watched
    // identity is unchanged, so the shell state survives.
    container.read(_activeCommunityIdProvider.notifier).setId('community-a');
    await container.read(activeCommunityProvider.future);

    expect(container.read(shellStateProvider).selectedChannelId, 'channel-1');
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
