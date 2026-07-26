import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../shared/community/community.dart';
import '../../shared/community/community_provider.dart';
import '../../shared/shell/shell_state_provider.dart';
import '../../shared/theme/theme.dart';
import '../channels/channel_workspace.dart';
import '../channels/channels_page.dart';
import '../pairing/pairing_page.dart';
import '../pairing/pairing_provider.dart';
import '../profile/profile_avatar.dart';
import '../settings/settings_page.dart';

part 'desktop_shell/community_rail.dart';

/// Expanded-width desktop shell:
/// `community rail | channel list | message pane`.
///
/// The rail switches communities ([CommunityRail]), the list pane embeds
/// [ChannelsPage] (channel selection writes shell state at wide widths), and
/// the message pane renders the selected channel via [ChannelWorkspace].
/// Later parts add the side-panel host and shortcuts.
class DesktopShell extends HookConsumerWidget {
  const DesktopShell({super.key});

  static const double _channelListWidth = 280;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          CommunityRail(),
          SizedBox(width: _channelListWidth, child: ChannelsPage()),
          Expanded(child: ChannelWorkspace()),
        ],
      ),
    );
  }
}
