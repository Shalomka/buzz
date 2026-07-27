import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../shared/theme/theme.dart';
import '../../shared/widgets/avatar_image.dart';
import '../../shared/widgets/frosted_app_bar.dart';
import '../../shared/widgets/frosted_scaffold.dart';
import '../channels/compose_bar.dart';
import '../channels/message_content.dart';
import '../profile/user_cache_provider.dart';
import '../profile/user_profile.dart';
import '../profile/user_profile_sheet.dart';
import 'forum_models.dart';
import 'forum_provider.dart';

part 'forum_thread_page/forum_thread_view.dart';

/// Full-window route wrapper around [ForumThreadView].
///
/// Keeps the push-navigation contract used at narrow widths; the desktop
/// shell embeds [ForumThreadView] in its side panel instead of pushing this
/// page.
class ForumThreadPage extends ConsumerWidget {
  final String channelId;
  final String postEventId;
  final String? currentPubkey;
  final bool isMember;
  final bool isArchived;

  const ForumThreadPage({
    super.key,
    required this.channelId,
    required this.postEventId,
    required this.currentPubkey,
    required this.isMember,
    required this.isArchived,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadAsync = ref.watch(
      forumThreadProvider((channelId: channelId, eventId: postEventId)),
    );

    final isOwnPost =
        threadAsync
            .whenData(
              (t) =>
                  currentPubkey != null &&
                  t.post.pubkey.toLowerCase() == currentPubkey!.toLowerCase(),
            )
            .value ??
        false;

    return FrostedScaffold(
      appBar: FrostedAppBar(
        title: const Text('Thread'),
        actions: [
          if (isOwnPost)
            IconButton(
              onPressed: () =>
                  _showPostActions(context, ref, threadAsync.value!),
              tooltip: 'Post actions',
              icon: const Icon(LucideIcons.ellipsis),
            ),
        ],
      ),
      body: ForumThreadView(
        channelId: channelId,
        postEventId: postEventId,
        currentPubkey: currentPubkey,
        isMember: isMember,
        isArchived: isArchived,
      ),
    );
  }

  void _showPostActions(
    BuildContext context,
    WidgetRef ref,
    ForumThreadResponse thread,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Grid.gutter,
            0,
            Grid.gutter,
            Grid.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(LucideIcons.copy),
                title: const Text('Copy text'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Clipboard.setData(ClipboardData(text: thread.post.content));
                },
              ),
              ListTile(
                leading: Icon(
                  LucideIcons.trash2,
                  color: sheetContext.colors.error,
                ),
                title: Text(
                  'Delete post',
                  style: TextStyle(color: sheetContext.colors.error),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmDeletePost(context, ref, thread.post.eventId);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeletePost(BuildContext context, WidgetRef ref, String eventId) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete post'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await deleteForumEvent(
                ref,
                channelId: channelId,
                eventId: eventId,
              );
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: dialogContext.colors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
