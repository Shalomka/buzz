import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../shared/layout/breakpoints.dart';
import '../../shared/shell/shell_state_provider.dart';
import '../../shared/theme/theme.dart';
import '../../shared/widgets/avatar_image.dart';
import '../../shared/widgets/frosted_app_bar.dart';
import '../../shared/widgets/frosted_scaffold.dart';
import '../profile/user_cache_provider.dart';
import '../profile/user_profile.dart';
import 'channel_link_navigation.dart';
import 'channel_typing_provider.dart';
import 'thread_replies_provider.dart';
import 'channels_provider.dart';
import 'compose_bar.dart';
import 'date_formatters.dart';
import '../profile/user_profile_sheet.dart';
import 'message_actions.dart';
import 'message_content.dart';
import 'reaction_row.dart';
import 'read_state/read_state_format.dart';
import 'read_state/read_state_provider.dart';
import 'send_message_provider.dart';
import 'small_avatar.dart';
import 'timeline_message.dart';

part 'thread_detail_page/thread_view.dart';

/// Full-window route wrapper around [ThreadView].
///
/// Keeps the push-navigation contract used at narrow widths; the desktop
/// shell embeds [ThreadView] in its side panel instead of pushing this page.
class ThreadDetailPage extends StatelessWidget {
  final TimelineMessage threadHead;
  final List<TimelineMessage> allMessages;
  final String channelId;
  final String? currentPubkey;
  final bool isMember;
  final bool isArchived;
  final String? initialMessageId;

  const ThreadDetailPage({
    super.key,
    required this.threadHead,
    required this.allMessages,
    required this.channelId,
    required this.currentPubkey,
    required this.isMember,
    required this.isArchived,
    this.initialMessageId,
  });

  @override
  Widget build(BuildContext context) {
    return FrostedScaffold(
      appBar: const FrostedAppBar(title: Text('Thread')),
      body: ThreadView(
        threadHead: threadHead,
        allMessages: allMessages,
        channelId: channelId,
        currentPubkey: currentPubkey,
        isMember: isMember,
        isArchived: isArchived,
        initialMessageId: initialMessageId,
      ),
    );
  }
}
