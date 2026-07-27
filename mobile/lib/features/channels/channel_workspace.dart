import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../shared/shell/shell_state.dart';
import '../../shared/shell/shell_state_provider.dart';
import '../../shared/theme/theme.dart';
import '../forum/forum_thread_page.dart';
import '../profile/profile_provider.dart';
import 'channel.dart';
import 'channel_detail_page.dart';
import 'channel_messages_provider.dart';
import 'channels_provider.dart';
import 'thread_detail_page.dart';
import 'timeline_message.dart';

/// Width of the desktop shell's right-edge overlay side panel.
///
/// Phase 1 presents every side panel as an overlay at every expanded width;
/// this constant is the single retuning point for Phase 0 visual QA.
const double kSidePanelWidth = 360;

/// Elevation of the overlay side-panel surface.
const double kSidePanelElevation = 8;

/// Message pane of the desktop shell.
///
/// Renders the [ChannelDetailView] for the shell's selected channel, or an
/// empty state when nothing is selected (or the selection matches no loaded
/// channel). The view is keyed by a record of the selection and its pending
/// deep-link IDs plus the selection nonce, so every new selection — even a
/// repeated identical deep link — remounts the view. Remounting re-runs the
/// view's keyed hooks, reproducing the fresh-route-per-navigation read-state
/// semantics of the mobile push flow.
///
/// The thread and forum-thread side panels render as a right-edge overlay
/// above the message pane; the activity panel is shell-level and lives in
/// the desktop shell's `SidePanelHost`.
class ChannelWorkspace extends HookConsumerWidget {
  const ChannelWorkspace({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shellState = ref.watch(shellStateProvider);
    final channelsAsync = ref.watch(channelsProvider);

    final selectedChannelId = shellState.selectedChannelId;
    Channel? channel;
    if (selectedChannelId != null) {
      for (final candidate in channelsAsync.value ?? const <Channel>[]) {
        if (candidate.id == selectedChannelId) {
          channel = candidate;
          break;
        }
      }
    }

    if (channel == null) {
      return const _WorkspaceEmptyState();
    }

    return Stack(
      children: [
        Positioned.fill(
          child: ChannelDetailView(
            key: ValueKey((
              channel.id,
              shellState.pendingInitialMessageId,
              shellState.pendingInitialThreadRootId,
              shellState.pendingSelectionNonce,
            )),
            channel: channel,
            initialMessageId: shellState.pendingInitialMessageId,
            initialThreadRootId: shellState.pendingInitialThreadRootId,
          ),
        ),
        // Right-edge side-panel slot: the thread and forum-thread overlays
        // render here. Keep the Stack structure.
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          child: _SidePanelSlot(
            channel: channel,
            sidePanel: shellState.sidePanel,
          ),
        ),
      ],
    );
  }
}

/// Right-edge overlay surface shared by every desktop-shell side panel.
///
/// Renders a fixed-width elevated column with a titled header and a close
/// button wired to `closeSidePanel()`; the message pane stays visible
/// beneath it. Also used by the shell-level activity panel host.
class SidePanelSurface extends ConsumerWidget {
  /// Header title of the panel.
  final String title;

  /// Panel body rendered below the header.
  final Widget child;

  const SidePanelSurface({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: kSidePanelWidth,
      child: Material(
        elevation: kSidePanelElevation,
        color: context.colors.surface,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(left: Grid.xs, right: Grid.half),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.colors.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: context.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('side-panel-close'),
                    tooltip: 'Close panel',
                    onPressed: () =>
                        ref.read(shellStateProvider.notifier).closeSidePanel(),
                    icon: const Icon(LucideIcons.x, size: 18),
                  ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Resolves the open side panel to its overlay content.
///
/// The activity panel is shell-level (see `SidePanelHost`), so it renders
/// nothing here.
class _SidePanelSlot extends StatelessWidget {
  final Channel channel;
  final ShellSidePanel sidePanel;

  const _SidePanelSlot({required this.channel, required this.sidePanel});

  @override
  Widget build(BuildContext context) {
    return switch (sidePanel) {
      ShellSidePanelThread(:final rootId, :final initialMessageId) =>
        SidePanelSurface(
          title: 'Thread',
          child: _ThreadPanelBody(
            // Keyed so replacing the panel content with a nested thread
            // remounts the body, resetting its retention and load state.
            key: ValueKey((channel.id, rootId)),
            channel: channel,
            rootId: rootId,
            initialMessageId: initialMessageId,
          ),
        ),
      ShellSidePanelForumThread(:final postEventId) => SidePanelSurface(
        title: 'Thread',
        child: _ForumThreadPanelBody(
          channel: channel,
          postEventId: postEventId,
        ),
      ),
      ShellSidePanelNone() ||
      ShellSidePanelActivity() => const SizedBox.shrink(),
    };
  }
}

/// Thread panel body: resolves the thread head and hosts a [ThreadView].
class _ThreadPanelBody extends HookConsumerWidget {
  final Channel channel;
  final String rootId;
  final String? initialMessageId;

  const _ThreadPanelBody({
    super.key,
    required this.channel,
    required this.rootId,
    required this.initialMessageId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPubkey = ref
        .watch(profileProvider)
        .whenData((value) => value?.pubkey)
        .value;
    final messagesState = ref.watch(channelMessagesProvider(channel.id));

    // Format every loaded event, not just the main timeline: the main
    // timeline holds roots and broadcast replies only, so a nested-thread
    // open (a reply ID as root) would never resolve against it.
    final messages = formatTimeline(
      messagesState.value ?? const [],
      currentPubkey: currentPubkey,
    );
    final threadHead = messages
        .where((message) => message.id == rootId)
        .firstOrNull;
    final hasThreadHead = threadHead != null;
    final loadFailed = useState(false);

    // Retention is scoped to the panel's lifetime, not to whether the head is
    // currently resolved: releasing on a `false -> true` transition would
    // unpin the very event the loader just fetched. Retention is refcounted,
    // so this pin never drops the message pane's own deep-link pin.
    useEffect(() {
      final notifier = ref.read(channelMessagesProvider(channel.id).notifier);
      notifier.retainDeepLinkEvents({rootId});
      return () => notifier.releaseDeepLinkEvents({rootId});
    }, [channel.id, rootId]);

    // Resolution is a separate effect keyed on the head's presence, so a head
    // that later leaves the loaded window is fetched again instead of
    // stranding the panel on a permanent spinner.
    useEffect(() {
      if (hasThreadHead || loadFailed.value) return null;
      final notifier = ref.read(channelMessagesProvider(channel.id).notifier);
      // Deferred: the effect runs inside the build phase, where widening the
      // message window would be a provider write during a build.
      unawaited(
        Future<void>.microtask(() async {
          final loaded = await _loadThreadRoot(notifier, rootId);
          if (!context.mounted) return;
          final resolved =
              loaded &&
              (ref.read(channelMessagesProvider(channel.id)).value ?? const [])
                  .any((event) => event.id == rootId);
          if (!resolved) loadFailed.value = true;
        }),
      );
      return null;
    }, [channel.id, rootId, hasThreadHead, loadFailed.value]);

    if (threadHead == null) {
      if (loadFailed.value) {
        return _ThreadPanelError(onRetry: () => loadFailed.value = false);
      }
      return const Center(child: CircularProgressIndicator());
    }

    return ThreadView(
      key: ValueKey(rootId),
      threadHead: threadHead,
      allMessages: messages,
      channelId: channel.id,
      currentPubkey: currentPubkey,
      isMember: channel.isMember,
      isArchived: channel.isArchived,
      initialMessageId: initialMessageId,
      topPadding: Grid.xxs,
    );
  }
}

/// Terminal state for a thread root that could not be resolved.
///
/// Without it an unreachable or deleted root would leave the panel on an
/// indefinite spinner with no way to try again.
class _ThreadPanelError extends StatelessWidget {
  final VoidCallback onRetry;

  const _ThreadPanelError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Grid.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Couldn't load this thread",
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Grid.xxs),
            TextButton(
              key: const ValueKey('thread-panel-retry'),
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Forum-thread panel body: hosts a [ForumThreadView] for the open post.
class _ForumThreadPanelBody extends ConsumerWidget {
  final Channel channel;
  final String postEventId;

  const _ForumThreadPanelBody({
    required this.channel,
    required this.postEventId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPubkey = ref
        .watch(profileProvider)
        .whenData((value) => value?.pubkey)
        .value;

    return ForumThreadView(
      key: ValueKey(postEventId),
      channelId: channel.id,
      postEventId: postEventId,
      currentPubkey: currentPubkey,
      isMember: channel.isMember,
      isArchived: channel.isArchived,
      topPadding: Grid.xxs,
    );
  }
}

/// Fetch a thread root that may be outside the loaded channel window.
///
/// Returns whether the fetch completed; the caller decides whether the root
/// actually landed. `loadEventsById` acquires its own retention pin, which is
/// released again here: the panel already holds a pin for its whole lifetime,
/// so a retried fetch must not stack refcounts that nothing will ever drop.
Future<bool> _loadThreadRoot(
  ChannelMessagesNotifier notifier,
  String rootId,
) async {
  if (rootId.isEmpty) return false;
  try {
    await notifier.loadEventsById({rootId});
    return true;
  } catch (error) {
    debugPrint('side panel: failed to load thread root: $error');
    return false;
  } finally {
    notifier.releaseDeepLinkEvents({rootId});
  }
}

class _WorkspaceEmptyState extends StatelessWidget {
  const _WorkspaceEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.messageSquare,
            size: Grid.lg,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(height: Grid.xs),
          Text(
            'Select a channel',
            style: context.textTheme.titleMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
