import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../shared/shell/shell_state_provider.dart';
import '../../shared/theme/theme.dart';
import 'channel.dart';
import 'channel_detail_page.dart';
import 'channels_provider.dart';

/// Message pane of the desktop shell.
///
/// Renders the [ChannelDetailView] for the shell's selected channel, or an
/// empty state when nothing is selected (or the selection matches no loaded
/// channel). The view is keyed by a record of the selection and its pending
/// deep-link IDs plus the selection nonce, so every new selection — even a
/// repeated identical deep link — remounts the view. Remounting re-runs the
/// view's keyed hooks, reproducing the fresh-route-per-navigation read-state
/// semantics of the mobile push flow.
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
        // Right-edge side-panel slot: Part 3 renders the thread/forum/
        // activity overlay panels here. Keep the Stack structure.
        const Positioned(top: 0, bottom: 0, right: 0, child: _SidePanelSlot()),
      ],
    );
  }
}

/// Placeholder host for the right-edge overlay side panel (thread, forum
/// thread, activity). Filled in Part 3 — do not remove.
class _SidePanelSlot extends StatelessWidget {
  const _SidePanelSlot();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
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
