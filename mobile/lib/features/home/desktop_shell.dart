import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../shared/community/community.dart';
import '../../shared/community/community_provider.dart';
import '../../shared/shell/shell_state.dart';
import '../../shared/shell/shell_state_provider.dart';
import '../../shared/theme/theme.dart';
import '../activity/activity_page.dart';
import '../channels/channel_workspace.dart';
import '../channels/channels_page.dart';
import '../channels/unread_badge/unread_badge_provider.dart';
import '../pairing/pairing_page.dart';
import '../pairing/pairing_provider.dart';
import '../profile/profile_avatar.dart';
import '../settings/settings_page.dart';

part 'desktop_shell/community_rail.dart';
part 'desktop_shell/side_panel_host.dart';

/// Expanded-width desktop shell:
/// `community rail | channel list | message pane`.
///
/// The rail switches communities ([CommunityRail]), the list pane embeds
/// [ChannelsPage] (channel selection writes shell state at wide widths), and
/// the message pane renders the selected channel via [ChannelWorkspace].
/// [SidePanelHost] overlays the shell-level activity panel on the right edge.
///
/// The root [CallbackShortcuts] carries the shell's keyboard layer; Part 4
/// extends the binding map beyond the single Esc entry. [Focus] with
/// `autofocus` keeps the bindings live even when no field holds focus.
class DesktopShell extends HookConsumerWidget {
  const DesktopShell({super.key});

  static const double _channelListWidth = 280;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            ref.read(shellStateProvider.notifier).closeSidePanel(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    CommunityRail(),
                    SizedBox(width: _channelListWidth, child: ChannelsPage()),
                    Expanded(child: ChannelWorkspace()),
                  ],
                ),
              ),
              const Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                child: SidePanelHost(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
