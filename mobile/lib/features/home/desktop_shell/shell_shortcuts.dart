part of '../desktop_shell.dart';

/// The desktop shell's keyboard layer.
///
/// [Focus] with `autofocus` keeps the bindings live when no text field holds
/// focus. Channel navigation uses Cmd/Ctrl+Alt+Arrows rather than plain
/// Alt+Arrow, which `DefaultTextEditingShortcuts` claims whenever the
/// composer is focused — the shell's most common state.
class ShellShortcuts extends HookConsumerWidget {
  /// The shell subtree the shortcuts apply to.
  final Widget child;

  const ShellShortcuts({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Guards against a held or repeated chord stacking a second overlay or
    // settings route on top of the one already open.
    final searchOpen = useRef(false);
    final settingsOpen = useRef(false);

    Future<void> openSearch() async {
      if (searchOpen.value) return;
      searchOpen.value = true;
      try {
        await showSearchOverlay(context);
      } finally {
        searchOpen.value = false;
      }
    }

    Future<void> openSettings() async {
      if (settingsOpen.value) return;
      settingsOpen.value = true;
      try {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
      } finally {
        settingsOpen.value = false;
      }
    }

    /// Moves the selection [delta] steps through the rendered channel list.
    ///
    /// No-ops at the list edges; with nothing selected it selects the first
    /// channel regardless of direction.
    void moveSelection(int delta) {
      final channels = ref.read(channelsProvider).value;
      if (channels == null || channels.isEmpty) return;

      final sections = ref.read(channelSectionsProvider).store;
      final stars = ref.read(channelStarsProvider).store;
      final ordered = computeChannelListOrder(
        channels: channels,
        sections: sections.sections,
        sectionAssignments: sections.assignments,
        starredChannelIds: {
          for (final entry in stars.channels.entries)
            if (entry.value.starred) entry.key,
        },
        currentPubkey: ref
            .read(profileProvider)
            .whenData((value) => value?.pubkey)
            .value,
      ).ordered;
      if (ordered.isEmpty) return;

      final notifier = ref.read(shellStateProvider.notifier);
      final selectedId = ref.read(shellStateProvider).selectedChannelId;
      final index = ordered.indexWhere((channel) => channel.id == selectedId);
      if (index < 0) {
        notifier.selectChannel(ordered.first.id);
        return;
      }
      final target = index + delta;
      if (target < 0 || target >= ordered.length) return;
      notifier.selectChannel(ordered[target].id);
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            ref.read(shellStateProvider.notifier).closeSidePanel(),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): openSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            openSearch,
        const SingleActivator(LogicalKeyboardKey.comma, meta: true):
            openSettings,
        const SingleActivator(LogicalKeyboardKey.comma, control: true):
            openSettings,
        const SingleActivator(
          LogicalKeyboardKey.arrowDown,
          meta: true,
          alt: true,
        ): () =>
            moveSelection(1),
        const SingleActivator(
          LogicalKeyboardKey.arrowDown,
          control: true,
          alt: true,
        ): () =>
            moveSelection(1),
        const SingleActivator(
          LogicalKeyboardKey.arrowUp,
          meta: true,
          alt: true,
        ): () =>
            moveSelection(-1),
        const SingleActivator(
          LogicalKeyboardKey.arrowUp,
          control: true,
          alt: true,
        ): () =>
            moveSelection(-1),
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}
