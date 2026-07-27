part of '../thread_detail_page.dart';

/// The thread conversation view: thread head, replies, typing indicators
/// scoped to the thread, and a compose bar for replying.
///
/// Extracted move-only from [ThreadDetailPage] so the desktop shell can embed
/// the same view in its side panel without a route push.
class ThreadView extends HookConsumerWidget {
  final TimelineMessage threadHead;
  final List<TimelineMessage> allMessages;
  final String channelId;
  final String? currentPubkey;
  final bool isMember;
  final bool isArchived;
  final String? initialMessageId;

  /// Top inset of the reply list.
  ///
  /// Defaults to [frostedAppBarHeight] so the full-window page clears its
  /// floating [FrostedAppBar]. Embedders without that chrome — the desktop
  /// shell's side panel — pass their own inset instead of inheriting dead
  /// space under the panel header.
  final double? topPadding;

  const ThreadView({
    super.key,
    required this.threadHead,
    required this.allMessages,
    required this.channelId,
    required this.currentPubkey,
    required this.isMember,
    required this.isArchived,
    this.initialMessageId,
    this.topPadding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repliesState = ref.watch(
      threadRepliesProvider(
        ThreadRepliesArgs(channelId: channelId, rootId: threadHead.id),
      ),
    );
    final replyMessages = repliesState.whenData((events) {
      return formatTimeline(events, currentPubkey: currentPubkey);
    });

    final fetchedReplies = replyMessages.value;
    final allMsgs = fetchedReplies == null
        ? allMessages
        : [threadHead, ...fetchedReplies];

    // Index all messages by parentId so we can find direct children of any
    // message and compute thread summaries for nested threads.
    final childrenByParent = <String, List<TimelineMessage>>{};
    for (final msg in allMsgs) {
      final pid = msg.parentId;
      if (pid == null) continue;
      childrenByParent.putIfAbsent(pid, () => []).add(msg);
    }

    final replies = childrenByParent[threadHead.id] ?? const [];
    final itemScrollController = useMemoized(ItemScrollController.new);
    final didJumpToInitialMessage = useRef(false);
    useEffect(() {
      final messageId = initialMessageId;
      // Wait for the authoritative thread query before consuming the one-shot
      // jump; the fallback main-timeline list can contain only the linked reply.
      if (messageId == null || fetchedReplies == null) return null;
      final chronologicalIndex = replies.indexWhere(
        (reply) => reply.id == messageId,
      );
      final targetIndex = messageId == threadHead.id
          ? replies.length
          : chronologicalIndex < 0
          ? null
          : replies.length - 1 - chronologicalIndex;
      if (targetIndex == null || didJumpToInitialMessage.value) return null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || !itemScrollController.isAttached) return;
        itemScrollController.jumpTo(index: targetIndex, alignment: 0.35);
        didJumpToInitialMessage.value = true;
      });
      return null;
    }, [initialMessageId, fetchedReplies, replies.length]);
    final readState = ref.watch(readStateProvider);
    final visibleReplyReadKey = replies
        .map((reply) => '${reply.id}:${reply.createdAt}')
        .join(',');

    useEffect(() {
      if (!readState.isReady || replies.isEmpty) return null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final reply in replies) {
          ref
              .read(readStateProvider.notifier)
              .markContextRead(msgContextKey(reply.id), reply.createdAt);
        }
      });
      return null;
    }, [threadHead.id, readState.isReady, visibleReplyReadKey]);

    // Thread-scoped typing indicators (exclude self).
    final allTyping = ref.watch(channelTypingProvider(channelId));
    final threadTyping = allTyping
        .where((e) => e.threadHeadId == threadHead.id)
        .where(
          (e) =>
              currentPubkey == null ||
              e.pubkey.toLowerCase() != currentPubkey?.toLowerCase(),
        )
        .toList();

    // Resolve thread head from live data (reactions/edits may have changed).
    final liveHead =
        allMsgs.where((m) => m.id == threadHead.id).firstOrNull ?? threadHead;

    // The root of the entire thread chain. If the current thread head is
    // itself a root message its rootId is null, so fall back to its own id.
    final effectiveRootId = threadHead.rootId ?? threadHead.id;

    // Channel names for message content rendering.
    final channelsAsync = ref.watch(channelsProvider);
    final channelNamesMap = <String, String>{};
    channelsAsync.whenData((channels) {
      for (final ch in channels) {
        channelNamesMap[ch.name.toLowerCase()] = ch.id;
      }
    });

    return Column(
      children: [
        Expanded(
          child: ScrollablePositionedList.builder(
            itemScrollController: itemScrollController,
            // Reversed so the list opens pinned to the newest reply,
            // matching the channel message list.
            reverse: true,
            padding: EdgeInsets.only(
              left: Grid.gutter,
              right: Grid.gutter,
              top: topPadding ?? frostedAppBarHeight(context),
              bottom: Grid.xxs,
            ),
            itemCount: replies.length + 1, // +1 for thread head
            itemBuilder: (context, index) {
              if (index == replies.length) {
                // Thread head.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ThreadMessage(
                      message: liveHead,
                      channelNames: channelNamesMap,
                      channelId: channelId,
                      currentPubkey: currentPubkey,
                      showAuthor: true,
                      allMessages: allMsgs,
                      isMember: isMember,
                      isArchived: isArchived,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: Grid.xxs),
                      child: Row(
                        children: [
                          Text(
                            '${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}',
                            style: context.textTheme.labelMedium?.copyWith(
                              color: context.colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: Grid.xxs),
                          Expanded(
                            child: Divider(
                              color: context.colors.outlineVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              // Reversed list: index 0 = newest reply.
              final chronIdx = replies.length - 1 - index;
              final reply = replies[chronIdx];
              final prevReply = chronIdx > 0 ? replies[chronIdx - 1] : null;
              final showAuthor =
                  prevReply == null ||
                  prevReply.pubkey.toLowerCase() !=
                      reply.pubkey.toLowerCase() ||
                  (reply.createdAt - prevReply.createdAt) > 300;

              // Check if this reply itself has children (nested thread).
              final nestedChildren = childrenByParent[reply.id];
              final nestedSummary =
                  nestedChildren != null && nestedChildren.isNotEmpty
                  ? _buildNestedSummary(reply.id, nestedChildren)
                  : null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ThreadMessage(
                    message: reply,
                    channelNames: channelNamesMap,
                    channelId: channelId,
                    currentPubkey: currentPubkey,
                    showAuthor: showAuthor,
                    allMessages: allMsgs,
                    isMember: isMember,
                    isArchived: isArchived,
                  ),
                  if (nestedSummary != null)
                    _NestedThreadSummaryRow(
                      summary: nestedSummary,
                      replyMessage: reply,
                      allMessages: allMsgs,
                      channelId: channelId,
                      currentPubkey: currentPubkey,
                      isMember: isMember,
                      isArchived: isArchived,
                    ),
                ],
              );
            },
          ),
        ),
        if (threadTyping.isNotEmpty)
          _ThreadTypingIndicator(entries: threadTyping),
        if (isMember && !isArchived)
          ComposeBar(
            channelId: channelId,
            hintText: 'Reply in thread…',
            threadHeadId: threadHead.id,
            rootId: effectiveRootId,
            onSend:
                (
                  content,
                  mentionPubkeys, {
                  mediaTags = const <List<String>>[],
                }) => ref
                    .read(sendMessageProvider)
                    .call(
                      channelId: channelId,
                      content: content,
                      mentionPubkeys: mentionPubkeys,
                      parentEventId: threadHead.id,
                      rootEventId: effectiveRootId,
                      mediaTags: mediaTags,
                    ),
          ),
      ],
    );
  }
}

/// Build a lightweight summary for a nested thread (reply that has its own
/// replies). Same logic as the top-level [ThreadSummary] but kept local to
/// avoid coupling.
ThreadSummary _buildNestedSummary(
  String messageId,
  List<TimelineMessage> children,
) {
  final seen = <String>{};
  final participants = <String>[];
  for (var i = children.length - 1; i >= 0 && participants.length < 3; i--) {
    final pk = children[i].pubkey.toLowerCase();
    if (seen.add(pk)) participants.add(pk);
  }
  return ThreadSummary(
    threadHeadId: messageId,
    replyCount: children.length,
    participantPubkeys: participants.reversed.toList(),
  );
}

/// Tappable summary row shown below a reply that itself has replies.
///
/// At narrow widths it pushes a nested [ThreadDetailPage]; at expanded widths
/// it replaces the shell's thread panel content with the nested thread.
class _NestedThreadSummaryRow extends ConsumerWidget {
  final ThreadSummary summary;
  final TimelineMessage replyMessage;
  final List<TimelineMessage> allMessages;
  final String channelId;
  final String? currentPubkey;
  final bool isMember;
  final bool isArchived;

  const _NestedThreadSummaryRow({
    required this.summary,
    required this.replyMessage,
    required this.allMessages,
    required this.channelId,
    required this.currentPubkey,
    required this.isMember,
    required this.isArchived,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userCache = ref.watch(userCacheProvider);

    return GestureDetector(
      onTap: () {
        if (isExpandedLayout(context)) {
          ref
              .read(shellStateProvider.notifier)
              .openThreadPanel(replyMessage.id);
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ThreadDetailPage(
              threadHead: replyMessage,
              allMessages: allMessages,
              channelId: channelId,
              currentPubkey: currentPubkey,
              isMember: isMember,
              isArchived: isArchived,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(
          left: 36,
          top: Grid.half,
          bottom: Grid.half,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stacked participant avatars.
            SizedBox(
              width:
                  20.0 +
                  (summary.participantPubkeys.length - 1).clamp(0, 2) * 12.0,
              height: 20,
              child: Stack(
                children: [
                  for (var i = 0; i < summary.participantPubkeys.length; i++)
                    Positioned(
                      left: i * 12.0,
                      child: SmallAvatar(
                        pubkey: summary.participantPubkeys[i],
                        userCache: userCache,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: Grid.xxs),
            Text(
              '${summary.replyCount} ${summary.replyCount == 1 ? 'reply' : 'replies'}',
              style: context.textTheme.labelMedium?.copyWith(
                color: context.colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: Grid.half),
            Icon(
              LucideIcons.chevronRight,
              size: 14,
              color: context.colors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadMessage extends ConsumerWidget {
  final TimelineMessage message;
  final Map<String, String> channelNames;
  final String channelId;
  final String? currentPubkey;
  final bool showAuthor;
  final List<TimelineMessage>? allMessages;
  final bool isMember;
  final bool isArchived;

  const _ThreadMessage({
    required this.message,
    required this.channelNames,
    required this.channelId,
    required this.currentPubkey,
    required this.showAuthor,
    this.allMessages,
    this.isMember = false,
    this.isArchived = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pk = message.pubkey.toLowerCase();
    final profile =
        ref.watch(userCacheProvider.select((cache) => cache[pk])) ??
        ref.read(userCacheProvider.notifier).get(pk);
    final displayName = profile?.label ?? shortPubkey(message.pubkey);

    final userCache = ref.watch(userCacheProvider);
    final mentionNames = <String, String>{};
    for (final mpk in message.mentionPubkeys) {
      final p = userCache[mpk.toLowerCase()];
      if (p?.displayName != null) {
        mentionNames[mpk.toLowerCase()] = p!.displayName!;
      }
    }

    void openActions() => showMessageActions(
      context: context,
      ref: ref,
      message: message,
      channelId: channelId,
      canManageMessage:
          currentPubkey?.toLowerCase() == pk ||
          (profile?.ownerPubkey != null &&
              profile?.ownerPubkey == currentPubkey?.toLowerCase()),
      allMessages: allMessages,
      currentPubkey: currentPubkey,
      isMember: isMember,
      isArchived: isArchived,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: openActions,
      // Right-click opens the same actions surface as long-press (desktop).
      onSecondaryTapUp: (_) => openActions(),
      child: Padding(
        padding: EdgeInsets.only(top: showAuthor ? Grid.xs : Grid.quarter),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showAuthor)
              GestureDetector(
                onTap: () => showUserProfileSheet(context, message.pubkey),
                child: _Avatar(profile: profile, pubkey: message.pubkey),
              )
            else
              const SizedBox(width: 28),
            const SizedBox(width: Grid.xxs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showAuthor)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Grid.quarter),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () =>
                                showUserProfileSheet(context, message.pubkey),
                            child: Text(
                              displayName,
                              style: context.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: context.colors.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: Grid.xxs),
                          Text(
                            formatMessageTime(message.createdAt),
                            style: context.textTheme.labelSmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                          if (message.edited) ...[
                            const SizedBox(width: Grid.half),
                            Text(
                              '(edited)',
                              style: context.textTheme.labelSmall?.copyWith(
                                color: context.colors.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  MessageContent(
                    content: message.content,
                    mentionNames: mentionNames,
                    channelNames: channelNames,
                    tags: message.tags,
                    onChannelTap: (targetChannelId) {
                      openChannelLink(
                        context: context,
                        ref: ref,
                        channelId: targetChannelId,
                        currentChannelId: channelId,
                      );
                    },
                    onMentionTap: (pubkey) =>
                        showUserProfileSheet(context, pubkey),
                  ),
                  if (message.reactions.isNotEmpty)
                    ReactionRow(
                      reactions: message.reactions,
                      onToggle: (emoji) => toggleReaction(ref, message, emoji),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadTypingIndicator extends ConsumerWidget {
  final List<TypingEntry> entries;

  const _ThreadTypingIndicator({required this.entries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userCache = ref.watch(userCacheProvider);
    final names = entries.map((e) {
      final profile =
          userCache[e.pubkey.toLowerCase()] ??
          ref.read(userCacheProvider.notifier).get(e.pubkey.toLowerCase());
      return profile?.label ?? shortPubkey(e.pubkey);
    }).toList();
    final text = switch (names.length) {
      1 => '${names[0]} is typing...',
      2 => '${names[0]} and ${names[1]} are typing...',
      _ => '${names[0]} and ${names.length - 1} others are typing...',
    };

    final visibleEntries = entries.take(3).toList();
    final avatarCount = visibleEntries.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Grid.gutter,
        vertical: Grid.quarter + 2,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20.0 + (avatarCount - 1) * 12.0,
            height: 20,
            child: Stack(
              children: [
                for (var i = 0; i < avatarCount; i++)
                  Positioned(
                    left: i * 12.0,
                    child: SmallAvatar(
                      pubkey: visibleEntries[i].pubkey,
                      userCache: userCache,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Grid.xxs),
          Flexible(
            child: Text(
              text,
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colors.outline,
                fontStyle: FontStyle.italic,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final UserProfile? profile;
  final String pubkey;

  const _Avatar({required this.profile, required this.pubkey});

  @override
  Widget build(BuildContext context) {
    final initial =
        profile?.initial ?? (pubkey.isNotEmpty ? pubkey[0].toUpperCase() : '?');
    final avatarUrl = profile?.avatarUrl;

    return AvatarImage(
      imageUrl: avatarUrl,
      radius: 14,
      backgroundColor: context.colors.primaryContainer,
      fallback: Text(
        initial,
        style: context.textTheme.labelSmall?.copyWith(
          color: context.colors.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
