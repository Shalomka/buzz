import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../community/community_provider.dart';
import 'shell_state.dart';

/// Owns the desktop shell's navigation state.
///
/// Lives in the root [ProviderScope], so widget-subtree remounts (e.g. the
/// auth remount triggered by a community switch) do NOT reset it. The
/// [build] watch on the active community identity is the only reset path.
class ShellStateNotifier extends Notifier<ShellState> {
  @override
  ShellState build() {
    // Reset to the initial state whenever the active community changes.
    // Deliberately no unwrapPrevious(): while a reload is in flight the
    // AsyncLoading state keeps reporting the previous community's id, so
    // unrelated reloads (rename, add/remove) never spuriously reset the
    // shell — only a genuine id change does.
    ref.watch(activeCommunityProvider.select((value) => value.value?.id));
    return const ShellState();
  }

  /// Selects the channel [id] for the message pane.
  ///
  /// Closes any thread/forum side panel (they reference the previous
  /// selection), forces [ShellMainContent.channels], and stores the pending
  /// deep-link IDs. When initial IDs are provided the selection nonce is
  /// bumped so a repeated identical deep link still remounts the workspace.
  void selectChannel(
    String id, {
    String? initialMessageId,
    String? initialThreadRootId,
  }) {
    final hasPendingIds =
        initialMessageId != null || initialThreadRootId != null;
    state = state.copyWith(
      selectedChannelId: id,
      pendingInitialMessageId: initialMessageId,
      pendingInitialThreadRootId: initialThreadRootId,
      pendingSelectionNonce: hasPendingIds
          ? state.pendingSelectionNonce + 1
          : state.pendingSelectionNonce,
      sidePanel: _withoutSelectionScopedPanel(state.sidePanel),
      mainContent: ShellMainContent.channels,
    );
  }

  /// Clears the channel selection and any pending deep-link IDs, closing a
  /// thread/forum panel that referenced the cleared selection.
  void clearSelection() {
    state = state.copyWith(
      selectedChannelId: null,
      pendingInitialMessageId: null,
      pendingInitialThreadRootId: null,
      sidePanel: _withoutSelectionScopedPanel(state.sidePanel),
    );
  }

  /// Opens the thread side panel rooted at [rootId], replacing any other
  /// open panel.
  void openThreadPanel(String rootId, {String? initialMessageId}) {
    state = state.copyWith(
      sidePanel: ShellSidePanelThread(
        rootId,
        initialMessageId: initialMessageId,
      ),
    );
  }

  /// Opens the forum thread side panel for [postEventId], replacing any
  /// other open panel.
  void openForumThreadPanel(String postEventId) {
    state = state.copyWith(sidePanel: ShellSidePanelForumThread(postEventId));
  }

  /// Toggles the activity side panel, replacing any other open panel.
  void toggleActivityPanel() {
    state = state.copyWith(
      sidePanel: state.sidePanel is ShellSidePanelActivity
          ? const ShellSidePanelNone()
          : const ShellSidePanelActivity(),
    );
  }

  /// Closes whichever side panel is open.
  void closeSidePanel() {
    state = state.copyWith(sidePanel: const ShellSidePanelNone());
  }

  /// Shows the Pulse feed in the main pane.
  void showPulse() {
    state = state.copyWith(mainContent: ShellMainContent.pulse);
  }

  /// Shows the channels content in the main pane.
  void showChannels() {
    state = state.copyWith(mainContent: ShellMainContent.channels);
  }

  ShellSidePanel _withoutSelectionScopedPanel(ShellSidePanel panel) {
    return panel is ShellSidePanelThread || panel is ShellSidePanelForumThread
        ? const ShellSidePanelNone()
        : panel;
  }
}

/// The desktop shell's navigation state. Ignored at narrow widths, where
/// push navigation remains authoritative.
final shellStateProvider = NotifierProvider<ShellStateNotifier, ShellState>(
  ShellStateNotifier.new,
);
