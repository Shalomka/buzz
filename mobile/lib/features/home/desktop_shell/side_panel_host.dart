part of '../desktop_shell.dart';

/// Shell-level host for the right-edge overlay side panel.
///
/// Renders the activity panel; the thread and forum-thread panels are scoped
/// to the selected channel and render inside [ChannelWorkspace] instead.
class SidePanelHost extends ConsumerWidget {
  const SidePanelHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sidePanel = ref.watch(
      shellStateProvider.select((state) => state.sidePanel),
    );

    if (sidePanel is! ShellSidePanelActivity) {
      return const SizedBox.shrink();
    }

    return const SidePanelSurface(title: 'Activity', child: ActivityView());
  }
}
