part of '../desktop_shell.dart';

/// Vertical community rail on the left edge of the desktop shell.
///
/// Lists community avatar buttons (tap an inactive community to switch to
/// it; tap the active one to show the channels content), an add-community
/// button, and the profile avatar (opens Settings). Part 3 adds the
/// activity-bell button and Part 4 the Pulse destination.
class CommunityRail extends ConsumerWidget {
  const CommunityRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communities =
        ref.watch(communityListProvider).value ?? const <Community>[];
    final activeCommunityId = ref.watch(
      activeCommunityProvider.select((value) => value.value?.id),
    );

    return SizedBox(
      width: Grid.xxl,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: Grid.xxs),
            Expanded(
              child: ListView(
                children: [
                  for (final community in communities)
                    _CommunityRailButton(
                      community: community,
                      isActive: community.id == activeCommunityId,
                    ),
                  _AddCommunityButton(
                    onPressed: () {
                      ref.read(pairingProvider.notifier).reset();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const PairingPage(addingCommunity: true),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            ProfileAvatar(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
              ),
            ),
            const SizedBox(height: Grid.xs),
          ],
        ),
      ),
    );
  }
}

class _CommunityRailButton extends ConsumerWidget {
  final Community community;
  final bool isActive;

  const _CommunityRailButton({required this.community, required this.isActive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trimmedName = community.name.trim();
    final initial = trimmedName.isNotEmpty
        ? trimmedName.substring(0, 1).toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: Grid.xxs),
      child: Center(
        child: Tooltip(
          message: community.name,
          child: InkWell(
            key: ValueKey('community-rail-item-${community.id}'),
            customBorder: const CircleBorder(),
            onTap: () async {
              if (isActive) {
                ref.read(shellStateProvider.notifier).showChannels();
                return;
              }
              await ref
                  .read(communityListProvider.notifier)
                  .switchCommunity(community.id);
            },
            child: Container(
              key: ValueKey(
                isActive
                    ? 'community-rail-active-${community.id}'
                    : 'community-rail-inactive-${community.id}',
              ),
              padding: const EdgeInsets.all(Grid.quarter),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? context.colors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: isActive
                    ? context.colors.primaryContainer
                    : context.colors.surfaceContainerHighest,
                child: Text(
                  initial,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: isActive
                        ? context.colors.onPrimaryContainer
                        : context.colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddCommunityButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _AddCommunityButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IconButton(
        tooltip: 'Add community',
        onPressed: onPressed,
        icon: Icon(LucideIcons.plus, color: context.colors.onSurfaceVariant),
      ),
    );
  }
}
