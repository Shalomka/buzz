part of '../desktop_shell.dart';

/// Vertical community rail on the left edge of the desktop shell.
///
/// Lists community avatar buttons (tap an inactive community to switch to
/// it; tap the active one to show the channels content), an add-community
/// button, the Pulse destination (swaps the main pane to the Pulse feed),
/// the activity bell (toggles the shell's activity side panel), and the
/// profile avatar (opens Settings).
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
            const _PulseButton(),
            const _ActivityBellButton(),
            const SizedBox(height: Grid.xxs),
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

/// Rail button showing the Pulse feed in the shell's main pane.
///
/// Selecting a channel switches the pane back to channels, so this reads as a
/// destination rather than a toggle.
class _PulseButton extends ConsumerWidget {
  const _PulseButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = ref.watch(
      shellStateProvider.select(
        (state) => state.mainContent == ShellMainContent.pulse,
      ),
    );

    return Center(
      child: IconButton(
        key: const ValueKey('community-rail-pulse'),
        tooltip: 'Pulse',
        onPressed: () => ref.read(shellStateProvider.notifier).showPulse(),
        icon: Icon(
          LucideIcons.activity,
          color: isActive
              ? context.colors.primary
              : context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Rail button toggling the activity side panel, badged with the unread
/// counts from [unreadBadgeProvider].
class _ActivityBellButton extends ConsumerWidget {
  const _ActivityBellButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badge = ref.watch(unreadBadgeProvider);
    final isOpen = ref.watch(
      shellStateProvider.select(
        (state) => state.sidePanel is ShellSidePanelActivity,
      ),
    );
    final count = badge.highPriorityCount + badge.generalUnreadCount;

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            key: const ValueKey('community-rail-activity'),
            tooltip: 'Activity',
            onPressed: () =>
                ref.read(shellStateProvider.notifier).toggleActivityPanel(),
            icon: Icon(
              LucideIcons.bell,
              color: isOpen
                  ? context.colors.primary
                  : context.colors.onSurfaceVariant,
            ),
          ),
          if (count > 0)
            Positioned(
              top: Grid.quarter,
              right: Grid.quarter,
              child: Container(
                key: const ValueKey('community-rail-activity-badge'),
                padding: const EdgeInsets.symmetric(horizontal: Grid.quarter),
                constraints: const BoxConstraints(minWidth: 16),
                decoration: BoxDecoration(
                  color: badge.highPriorityCount > 0
                      ? context.colors.error
                      : context.colors.primary,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: badge.highPriorityCount > 0
                        ? context.colors.onError
                        : context.colors.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
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
