import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../shared/layout/breakpoints.dart';
import '../../shared/relay/relay.dart';
import '../../shared/shell/shell_state_provider.dart';
import '../../shared/theme/theme.dart';
import '../../shared/widgets/adaptive_modal.dart';
import '../../shared/widgets/avatar_image.dart';
import '../../shared/widgets/frosted_app_bar.dart';
import '../../shared/widgets/frosted_scaffold.dart';
import '../profile/presence_cache_provider.dart';
import '../profile/profile_provider.dart';
import '../profile/user_cache_provider.dart';
import '../profile/user_profile.dart';
import '../forum/forum_posts_view.dart';
import 'channel.dart';
import 'channel_link_navigation.dart';
import 'agent_activity/working_bots_provider.dart';
import 'channel_management_provider.dart';
import 'channel_messages_provider.dart';
import 'channel_typing_provider.dart';
import 'channels_provider.dart';
import 'compose_bar.dart';
import 'date_formatters.dart';
import 'day_divider.dart';
import 'dm_channel_labels.dart';
import 'ephemeral_channel_display.dart';
import 'manage_channel_sheet.dart';
import 'members_sheet.dart';
import 'message_actions.dart';
import 'message_content.dart';
import 'read_state/deferred_read_state_update.dart';
import 'read_state/read_state_provider.dart';
import 'read_state/read_state_time.dart';
import 'reaction_row.dart';
import 'send_message_provider.dart';
import '../profile/user_profile_sheet.dart';
import 'small_avatar.dart';
import 'thread_detail_page.dart';
import 'timeline_message.dart';

part 'channel_detail_page/detail_view.dart';
part 'channel_detail_page/message_list.dart';
part 'channel_detail_page/system_rows.dart';
part 'channel_detail_page/message_bubble.dart';
part 'channel_detail_page/banners.dart';
part 'channel_detail_page/app_bar.dart';

/// Fetch deep-link targets that may be outside the loaded channel window.
Future<void> _loadDeepLinkEvents(
  WidgetRef ref,
  String channelId,
  Set<String> eventIds,
) async {
  try {
    await ref
        .read(channelMessagesProvider(channelId).notifier)
        .loadEventsById(eventIds);
  } catch (error) {
    debugPrint('deep-link: failed to load target messages: $error');
  }
}

/// Fetch channel members and preload their profiles into the user cache.
Future<void> _preloadMembers(WidgetRef ref, String channelId) async {
  // Capture references before async gap to avoid using disposed ref.
  final notifier = ref.read(userCacheProvider.notifier);
  try {
    final members = await ref.read(channelMembersProvider(channelId).future);
    final pubkeys = members.map((m) => m.pubkey).toList();
    if (pubkeys.isNotEmpty) {
      notifier.preload(pubkeys);
    }
  } catch (_) {
    // Non-fatal — mentions will just fall back to cache from messages.
  }
}

int? _channelReadTimestamp({
  required Channel channel,
  required AsyncValue<List<NostrEvent>> messagesState,
}) {
  if (channel.isForum) {
    return dateTimeToUnixSeconds(channel.lastMessageAt);
  }

  final events = messagesState.value;
  if (events != null && events.isNotEmpty) {
    var latest = 0;
    for (final event in events) {
      if (event.threadReference.parentId != null) continue;
      if (event.createdAt > latest) {
        latest = event.createdAt;
      }
    }
    if (latest > 0) {
      return latest;
    }
  }

  return dateTimeToUnixSeconds(channel.lastMessageAt);
}

/// Full-window route wrapper around [ChannelDetailView].
///
/// Keeps the push-navigation contract used at narrow widths; the desktop
/// shell embeds [ChannelDetailView] directly instead of pushing this page.
class ChannelDetailPage extends StatelessWidget {
  final Channel channel;
  final String? initialMessageId;
  final String? initialThreadRootId;

  const ChannelDetailPage({
    super.key,
    required this.channel,
    this.initialMessageId,
    this.initialThreadRootId,
  });

  @override
  Widget build(BuildContext context) {
    return ChannelDetailView(
      channel: channel,
      initialMessageId: initialMessageId,
      initialThreadRootId: initialThreadRootId,
    );
  }
}
