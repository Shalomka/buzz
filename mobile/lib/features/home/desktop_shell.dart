import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../shared/community/community.dart';
import '../../shared/community/community_provider.dart';
import '../../shared/shell/shell_state.dart';
import '../../shared/shell/shell_state_provider.dart';
import '../../shared/theme/theme.dart';
import '../activity/activity_page.dart';
import '../channels/channel_list_order.dart';
import '../channels/channel_sections/channel_sections_provider.dart';
import '../channels/channel_stars/channel_stars_provider.dart';
import '../channels/channel_workspace.dart';
import '../channels/channels_page.dart';
import '../channels/channels_provider.dart';
import '../channels/unread_badge/unread_badge_provider.dart';
import '../pairing/pairing_page.dart';
import '../pairing/pairing_provider.dart';
import '../profile/profile_avatar.dart';
import '../profile/profile_provider.dart';
import '../pulse/pulse_page.dart';
import '../search/search_overlay.dart';
import '../settings/settings_page.dart';

part 'desktop_shell/community_rail.dart';
part 'desktop_shell/shell_shortcuts.dart';
part 'desktop_shell/side_panel_host.dart';

/// Expanded-width desktop shell:
/// `community rail | channel list | message pane`.
///
/// The rail switches communities ([CommunityRail]), the list pane embeds
/// [ChannelsPage] (channel selection writes shell state at wide widths), and
/// the message pane renders the selected channel via [ChannelWorkspace].
/// [SidePanelHost] overlays the shell-level activity panel on the right edge.
///
/// [ShellShortcuts] carries the shell's keyboard layer. The rail can swap the
/// content region to [PulsePage]; selecting a channel returns it to the
/// channels view.
class DesktopShell extends HookConsumerWidget {
  const DesktopShell({super.key});

  static const double _channelListWidth = 280;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mainContent = ref.watch(
      shellStateProvider.select((state) => state.mainContent),
    );

    return ShellShortcuts(
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CommunityRail(),
                  if (mainContent == ShellMainContent.pulse)
                    const Expanded(child: PulsePage())
                  else ...const [
                    SizedBox(width: _channelListWidth, child: ChannelsPage()),
                    Expanded(child: ChannelWorkspace()),
                  ],
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
    );
  }
}
