import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../shared/layout/breakpoints.dart';
import '../../../shared/theme/theme.dart';
import '../../profile/user_cache_provider.dart';
import '../date_formatters.dart';
import 'observer_models.dart';
import 'observer_subscription.dart';
import 'transcript_item_widget.dart';

/// Live agent activity transcript, shown inside an adaptive modal.
///
/// At narrow widths this is a drag-resizable near-full-height bottom sheet.
/// At expanded widths the host is a centered dialog, where a
/// [DraggableScrollableSheet] would bottom-align its content and expose a
/// drag gesture with no sheet to drag, so the transcript is rendered directly
/// and the dialog's own constraints size it.
class AgentActivitySheet extends HookConsumerWidget {
  final String channelId;
  final String agentPubkey;

  const AgentActivitySheet({
    super.key,
    required this.channelId,
    required this.agentPubkey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final observerState = ref.watch(
      observerSubscriptionProvider((
        channelId: channelId,
        agentPubkey: agentPubkey,
      )),
    );
    final transcript = observerState.transcript;
    final connection = observerState.connection;

    // Resolve bot name.
    final profile = ref.watch(
      userCacheProvider.select((cache) => cache[agentPubkey.toLowerCase()]),
    );
    final botName = profile?.label ?? shortPubkey(agentPubkey);

    // Auto-scroll to bottom on new items.
    final sheetControllerRef = useRef<ScrollController?>(null);
    final previousLength = useRef(0);

    useEffect(() {
      final sc = sheetControllerRef.value;
      if (transcript.length > previousLength.value &&
          sc != null &&
          sc.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (sc.hasClients) {
            sc.animateTo(
              sc.position.maxScrollExtent,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
            );
          }
        });
      }
      previousLength.value = transcript.length;
      return null;
    }, [transcript.length]);

    // Preload the bot profile.
    useEffect(() {
      ref.read(userCacheProvider.notifier).preload([agentPubkey]);
      return null;
    }, [agentPubkey]);

    // Owns the transcript scroll position on the dialog path, where no
    // DraggableScrollableSheet is there to supply one.
    final dialogScrollController = useScrollController();
    final isDialog = isExpandedLayout(context);
    // The screen-edge inset only applies to a sheet sitting on that edge; a
    // centered dialog would render it as dead space.
    final bottomPadding = isDialog
        ? Grid.sm
        : MediaQuery.viewPaddingOf(context).bottom + Grid.sm;

    Widget buildTranscript(
      BuildContext context,
      ScrollController sheetScrollController,
    ) {
      sheetControllerRef.value = sheetScrollController;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Grid.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.bot,
                      size: 18,
                      color: context.colors.onSurface,
                    ),
                    const SizedBox(width: Grid.xxs),
                    Expanded(
                      child: Text(
                        botName,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _ConnectionBadge(connection: connection),
                  ],
                ),
                const SizedBox(height: Grid.half),
                Text(
                  'Showing live activity from this point.',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Grid.xxs),
                Divider(color: context.colors.outlineVariant),
              ],
            ),
          ),
          // Transcript list
          Expanded(
            child: transcript.isEmpty
                ? Padding(
                    padding: EdgeInsets.only(bottom: bottomPadding),
                    child: _EmptyState(
                      connection: connection,
                      errorMessage: observerState.errorMessage,
                    ),
                  )
                : ListView.builder(
                    controller: sheetScrollController,
                    padding: EdgeInsets.fromLTRB(
                      Grid.gutter,
                      Grid.xxs,
                      Grid.gutter,
                      bottomPadding,
                    ),
                    itemCount: transcript.length,
                    itemBuilder: (context, index) {
                      return TranscriptItemWidget(item: transcript[index]);
                    },
                  ),
          ),
        ],
      );
    }

    if (isDialog) {
      // The dialog gives the content unbounded-enough height; cap it so the
      // Column's Expanded transcript has a bound to lay out against and the
      // dialog does not stretch to the full window.
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: buildTranscript(context, dialogScrollController),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: buildTranscript,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ObserverConnectionState connection;
  final String? errorMessage;

  const _EmptyState({required this.connection, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    if (connection == ObserverConnectionState.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.circleX, size: 24, color: context.colors.error),
            const SizedBox(height: Grid.xxs),
            Text(
              'Error: ${errorMessage ?? 'Unknown error'}',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.error,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (connection == ObserverConnectionState.idle) {
      return Center(
        child: Text(
          'Not connected',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }

    // connecting or open — show spinner
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Grid.xxs),
          Text(
            'Waiting for activity\u2026',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  final ObserverConnectionState connection;

  const _ConnectionBadge({required this.connection});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (connection) {
      ObserverConnectionState.idle => (context.colors.onSurfaceVariant, 'Idle'),
      ObserverConnectionState.connecting => (
        context.appColors.warning,
        'Connecting',
      ),
      ObserverConnectionState.open => (context.appColors.success, 'Live'),
      ObserverConnectionState.error => (context.colors.error, 'Error'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Grid.xxs,
        vertical: Grid.quarter,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: Grid.half),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
