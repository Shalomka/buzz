import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../shared/theme/theme.dart';
import '../channels/channels_page.dart';

/// Skeleton of the expanded-width desktop shell:
/// `community rail | channel list | message pane`.
///
/// Part 1 ships placeholders: the rail is an empty slot (Part 2 adds
/// `CommunityRail`), the list pane embeds [ChannelsPage] (channel selection
/// still pushes until Part 2), and the message pane shows an empty state
/// (Part 2 adds `ChannelWorkspace`). Later parts add `desktop_shell/` part
/// files for the rail, side-panel host, and shortcuts.
class DesktopShell extends HookConsumerWidget {
  const DesktopShell({super.key});

  static const double _railWidth = Grid.xxl;
  static const double _channelListWidth = 280;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Community rail placeholder (Part 2).
          const SizedBox(width: _railWidth),
          // Channel list pane.
          const SizedBox(width: _channelListWidth, child: ChannelsPage()),
          // Message pane placeholder (Part 2).
          Expanded(
            child: Center(
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
            ),
          ),
        ],
      ),
    );
  }
}
