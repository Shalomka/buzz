import 'package:buzz/features/channels/channel.dart';
import 'package:buzz/features/channels/channel_list_order.dart';
import 'package:buzz/features/channels/channel_sections/channel_sections_storage.dart';
import 'package:flutter_test/flutter_test.dart';

Channel _channel(
  String id, {
  String type = 'stream',
  bool isMember = true,
  bool isArchived = false,
  List<String> participants = const [],
}) {
  return Channel(
    id: id,
    name: id,
    channelType: type,
    visibility: 'open',
    description: '',
    createdBy: 'creator',
    createdAt: DateTime(2026),
    memberCount: 2,
    isMember: isMember,
    archivedAt: isArchived ? DateTime(2026, 2) : null,
    participants: participants,
  );
}

void main() {
  List<String> idsOf(List<Channel> channels) => [
    for (final channel in channels) channel.id,
  ];

  test('hides channels the user has not joined or has archived', () {
    final order = computeChannelListOrder(
      channels: [
        _channel('joined'),
        _channel('not-joined', isMember: false),
        _channel('archived', isArchived: true),
      ],
      sections: const [],
      sectionAssignments: const {},
      starredChannelIds: const {},
      currentPubkey: null,
    );

    expect(idsOf(order.visible), ['joined']);
    expect(idsOf(order.ordered), ['joined']);
  });

  test('pins starred channels above sections and the built-in list', () {
    final order = computeChannelListOrder(
      channels: [_channel('alpha'), _channel('beta'), _channel('gamma')],
      sections: const [],
      sectionAssignments: const {},
      starredChannelIds: const {'gamma'},
      currentPubkey: null,
    );

    expect(idsOf(order.starred), ['gamma']);
    expect(idsOf(order.ungrouped), ['alpha', 'beta']);
    expect(idsOf(order.ordered), ['gamma', 'alpha', 'beta']);
  });

  test('starring is exclusive — a starred channel leaves its section', () {
    final order = computeChannelListOrder(
      channels: [_channel('alpha'), _channel('beta')],
      sections: const [ChannelSection(id: 's1', name: 'Work', order: 0)],
      sectionAssignments: const {'alpha': 's1', 'beta': 's1'},
      starredChannelIds: const {'beta'},
      currentPubkey: null,
    );

    expect(idsOf(order.sections.single.channels), ['alpha']);
    expect(idsOf(order.starred), ['beta']);
    expect(idsOf(order.ungrouped), isEmpty);
    expect(idsOf(order.ordered), ['beta', 'alpha']);
  });

  test(
    'orders sections by their configured order, then ungrouped, then DMs',
    () {
      final order = computeChannelListOrder(
        channels: [
          _channel('loose'),
          _channel('second'),
          _channel('first'),
          _channel('dm', type: 'dm', participants: const ['Zoe']),
        ],
        sections: const [
          ChannelSection(id: 's2', name: 'Later', order: 5),
          ChannelSection(id: 's1', name: 'Earlier', order: 1),
        ],
        sectionAssignments: const {'first': 's1', 'second': 's2'},
        starredChannelIds: const {},
        currentPubkey: null,
      );

      expect(
        [for (final group in order.sections) group.section.id],
        ['s1', 's2'],
      );
      expect(idsOf(order.ordered), ['first', 'second', 'loose', 'dm']);
    },
  );

  test('drops assignments to sections that no longer exist', () {
    final order = computeChannelListOrder(
      channels: [_channel('orphan')],
      sections: const [],
      sectionAssignments: const {'orphan': 'deleted-section'},
      starredChannelIds: const {},
      currentPubkey: null,
    );

    expect(idsOf(order.ungrouped), ['orphan']);
  });

  test('sorts DMs by display label', () {
    final order = computeChannelListOrder(
      channels: [
        _channel('dm-z', type: 'dm', participants: const ['Zoe']),
        _channel('dm-a', type: 'dm', participants: const ['Ana']),
      ],
      sections: const [],
      sectionAssignments: const {},
      starredChannelIds: const {},
      currentPubkey: null,
    );

    expect(idsOf(order.dms), ['dm-a', 'dm-z']);
  });
}
