part of '../channel_detail_page.dart';

/// The channel conversation view: frosted app bar, message timeline (or
/// forum posts), banners, typing indicator, and composer.
///
/// Extracted move-only from [ChannelDetailPage] so the desktop shell can
/// embed the same view without a route push. When embedded at the shell
/// root, [FrostedAppBar] shows no back button because `Navigator.canPop`
/// is false there.
class ChannelDetailView extends HookConsumerWidget {
  final Channel channel;
  final String? initialMessageId;
  final String? initialThreadRootId;

  const ChannelDetailView({
    super.key,
    required this.channel,
    this.initialMessageId,
    this.initialThreadRootId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(channelDetailsProvider(channel.id));
    final channelsAsync = ref.watch(channelsProvider);
    final messagesState = ref.watch(channelMessagesProvider(channel.id));
    final readState = ref.watch(readStateProvider);
    final currentPubkey = ref
        .watch(profileProvider)
        .whenData((value) => value?.pubkey)
        .value;
    // Only show channel-level typing (exclude thread-scoped entries and self).
    final typingEntries = ref
        .watch(channelTypingProvider(channel.id))
        .where((e) => e.threadHeadId == null)
        .where(
          (e) =>
              currentPubkey == null ||
              e.pubkey.toLowerCase() != currentPubkey.toLowerCase(),
        )
        .toList();
    final baseChannel =
        channelsAsync
            .whenData(
              (channels) => channels.firstWhere(
                (candidate) => candidate.id == channel.id,
                orElse: () => channel,
              ),
            )
            .value ??
        channel;
    final resolvedChannel =
        detailsAsync.whenData(baseChannel.mergeDetails).value ?? baseChannel;
    final readTimestamp = _channelReadTimestamp(
      channel: resolvedChannel,
      messagesState: messagesState,
    );

    // Preload channel member profiles so @mentions resolve correctly.
    useEffect(() {
      _preloadMembers(ref, channel.id);
      return null;
    }, [channel.id]);

    useEffect(() {
      final messageId = initialMessageId;
      if (messageId == null || channel.isForum) return null;
      final eventIds = {messageId, ?initialThreadRootId};
      final notifier = ref.read(channelMessagesProvider(channel.id).notifier);
      unawaited(_loadDeepLinkEvents(ref, channel.id, eventIds));
      return () => notifier.releaseDeepLinkEvents(eventIds);
    }, [channel.id, initialMessageId, initialThreadRootId]);

    useEffect(() {
      if (!readState.isReady || readTimestamp == null) {
        return null;
      }
      return deferReadStateUpdate(context, () {
        ref
            .read(readStateProvider.notifier)
            .markContextRead(channel.id, readTimestamp);
        ref
            .read(channelsProvider.notifier)
            .clearObservedUnreadCoveredByRead(channel.id, readTimestamp);
      });
    }, [channel.id, readState.isReady, readTimestamp]);

    return FrostedScaffold(
      appBar: FrostedAppBar(
        title: resolvedChannel.isDm
            ? _DmAppBarTitle(
                channel: resolvedChannel,
                currentPubkey: currentPubkey,
              )
            : Row(
                children: [
                  Icon(
                    channelIcon(resolvedChannel),
                    size: 18,
                    color: context.colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: Grid.half),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                resolveDmChannelDisplayLabel(
                                  resolvedChannel,
                                  currentPubkey: currentPubkey,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (resolvedChannel.isEphemeral) ...[
                              const SizedBox(width: Grid.quarter),
                              _HeaderEphemeralBadge(channel: resolvedChannel),
                            ],
                          ],
                        ),
                        if (resolvedChannel.isStream)
                          Text(
                            resolvedChannel.description.isNotEmpty
                                ? resolvedChannel.description
                                : '${resolvedChannel.memberCount} member${resolvedChannel.memberCount == 1 ? '' : 's'}',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: [
          _MembersButton(
            channelId: resolvedChannel.id,
            channel: resolvedChannel,
            currentPubkey: currentPubkey,
          ),
          if (!resolvedChannel.isDm)
            IconButton(
              onPressed: () async {
                final shouldClose = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  constraints: BoxConstraints(
                    maxWidth: 640,
                    maxHeight: MediaQuery.sizeOf(context).height * 0.9,
                  ),
                  builder: (_) => ManageChannelSheet(channel: resolvedChannel),
                );
                if (shouldClose == true && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              tooltip: 'Manage channel',
              icon: const Icon(LucideIcons.ellipsis),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: resolvedChannel.isForum
                ? ForumPostsView(
                    channel: resolvedChannel,
                    currentPubkey: currentPubkey,
                  )
                : messagesState.when(
                    loading: () => Padding(
                      padding: EdgeInsets.only(
                        top: frostedAppBarHeight(context),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Padding(
                      padding: EdgeInsets.only(
                        top: frostedAppBarHeight(context),
                      ),
                      child: Center(
                        child: Text(
                          'Failed to load messages',
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colors.error,
                          ),
                        ),
                      ),
                    ),
                    data: (events) {
                      final messages = formatTimeline(
                        events,
                        currentPubkey: currentPubkey,
                      );
                      final summaries = ref
                          .read(channelMessagesProvider(channel.id).notifier)
                          .threadSummaries;
                      final entries = buildMainTimelineEntries(
                        messages,
                        relaySummaries: summaries,
                      );
                      return _MessageList(
                        entries: entries,
                        allMessages: messages,
                        initialMessageId: initialMessageId,
                        initialThreadRootId: initialThreadRootId,
                        channelId: channel.id,
                        currentPubkey: currentPubkey,
                        isMember: resolvedChannel.isMember,
                        isArchived: resolvedChannel.isArchived,
                      );
                    },
                  ),
          ),
          _DetailConnectionBanner(
            status: ref.watch(relaySessionProvider).status,
          ),
          if (!resolvedChannel.isForum && typingEntries.isNotEmpty)
            _TypingIndicator(entries: typingEntries),
          if (!resolvedChannel.isForum &&
              resolvedChannel.isMember &&
              !resolvedChannel.isArchived)
            ComposeBar(
              channelId: channel.id,
              channelName: resolvedChannel.isDm ? '' : resolvedChannel.name,
              onSend:
                  (
                    content,
                    mentionPubkeys, {
                    mediaTags = const <List<String>>[],
                  }) => ref
                      .read(sendMessageProvider)
                      .call(
                        channelId: channel.id,
                        content: content,
                        mentionPubkeys: mentionPubkeys,
                        mediaTags: mediaTags,
                      ),
            )
          else if (!resolvedChannel.isDm &&
              (!resolvedChannel.isMember || resolvedChannel.isArchived))
            _ReadOnlyNotice(channel: resolvedChannel),
        ],
      ),
    );
  }
}
