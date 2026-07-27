import 'channel.dart';
import 'channel_sections/channel_sections_storage.dart';
import 'dm_channel_labels.dart';

/// One user-defined section together with the channels rendered under it.
class ChannelSectionGroup {
  /// The section itself, carrying its name and sort order.
  final ChannelSection section;

  /// Channels assigned to [section], in list order.
  final List<Channel> channels;

  const ChannelSectionGroup({required this.section, required this.channels});
}

/// The channel list exactly as the sidebar renders it.
///
/// Mutes deliberately play no part: muting changes a row's styling, never its
/// position.
class ChannelListOrder {
  /// Channels the list can show at all — joined and not archived — in the
  /// order they arrived from the channels provider.
  final List<Channel> visible;

  /// Starred stream channels, pinned above every section.
  final List<Channel> starred;

  /// User-defined sections in their configured order.
  final List<ChannelSectionGroup> sections;

  /// Stream channels in no user-defined section (the built-in "Channels").
  final List<Channel> ungrouped;

  /// Direct-message channels, sorted by display label.
  final List<Channel> dms;

  const ChannelListOrder({
    required this.visible,
    required this.starred,
    required this.sections,
    required this.ungrouped,
    required this.dms,
  });

  /// Every rendered channel, flattened top to bottom — the order keyboard
  /// navigation steps through.
  List<Channel> get ordered => [
    ...starred,
    for (final group in sections) ...group.channels,
    ...ungrouped,
    ...dms,
  ];
}

/// Computes the visible channel list and its rendered order.
///
/// Starring is exclusive: a starred stream channel appears only under
/// "Starred", never in its custom section or the built-in list.
ChannelListOrder computeChannelListOrder({
  required List<Channel> channels,
  required List<ChannelSection> sections,
  required Map<String, String> sectionAssignments,
  required Set<String> starredChannelIds,
  required String? currentPubkey,
}) {
  final visible = channels
      .where((channel) => channel.isMember && !channel.isArchived)
      .toList();
  final streamChannels = visible.where((channel) => channel.isStream).toList();

  final orderedSections = sections.toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  final validSectionIds = {for (final section in orderedSections) section.id};
  final assignedChannelIds = {
    for (final entry in sectionAssignments.entries)
      if (validSectionIds.contains(entry.value)) entry.key,
  };

  return ChannelListOrder(
    visible: visible,
    starred: streamChannels
        .where((c) => starredChannelIds.contains(c.id))
        .toList(),
    sections: [
      for (final section in orderedSections)
        ChannelSectionGroup(
          section: section,
          channels: streamChannels
              .where(
                (c) =>
                    sectionAssignments[c.id] == section.id &&
                    !starredChannelIds.contains(c.id),
              )
              .toList(),
        ),
    ],
    ungrouped: streamChannels
        .where(
          (c) =>
              !assignedChannelIds.contains(c.id) &&
              !starredChannelIds.contains(c.id),
        )
        .toList(),
    dms: sortDmChannelsByDisplayLabel(
      visible.where((channel) => channel.isDm),
      currentPubkey: currentPubkey,
    ),
  );
}
