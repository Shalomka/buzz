import 'package:flutter/foundation.dart';

/// Which primary content the desktop shell's main pane shows.
enum ShellMainContent {
  /// The channel list and selected-channel workspace.
  channels,

  /// The Pulse feed.
  pulse,
}

/// The side panel currently open in the desktop shell, if any.
///
/// The shell shows at most one side panel at a time; modelling the open
/// panel as a single sealed value makes that exclusion structural.
@immutable
sealed class ShellSidePanel {
  const ShellSidePanel();
}

/// No side panel is open.
class ShellSidePanelNone extends ShellSidePanel {
  const ShellSidePanelNone();

  @override
  bool operator ==(Object other) => other is ShellSidePanelNone;

  @override
  int get hashCode => (ShellSidePanelNone).hashCode;
}

/// A message thread panel, rooted at [rootId].
class ShellSidePanelThread extends ShellSidePanel {
  /// Event ID of the thread root message.
  final String rootId;

  /// Optional message within the thread to scroll to on open.
  final String? initialMessageId;

  const ShellSidePanelThread(this.rootId, {this.initialMessageId});

  @override
  bool operator ==(Object other) =>
      other is ShellSidePanelThread &&
      other.rootId == rootId &&
      other.initialMessageId == initialMessageId;

  @override
  int get hashCode =>
      Object.hash(ShellSidePanelThread, rootId, initialMessageId);
}

/// A forum thread panel for the post with event ID [postEventId].
class ShellSidePanelForumThread extends ShellSidePanel {
  /// Event ID of the forum post whose thread is shown.
  final String postEventId;

  const ShellSidePanelForumThread(this.postEventId);

  @override
  bool operator ==(Object other) =>
      other is ShellSidePanelForumThread && other.postEventId == postEventId;

  @override
  int get hashCode => Object.hash(ShellSidePanelForumThread, postEventId);
}

/// The activity feed panel.
class ShellSidePanelActivity extends ShellSidePanel {
  const ShellSidePanelActivity();

  @override
  bool operator ==(Object other) => other is ShellSidePanelActivity;

  @override
  int get hashCode => (ShellSidePanelActivity).hashCode;
}

const _sentinel = Object();

/// Immutable navigation state for the desktop shell.
///
/// Holds IDs only — never feature types — so `shared/` stays free of
/// feature imports. Ignored entirely at narrow widths, where push
/// navigation remains authoritative.
@immutable
class ShellState {
  /// ID of the channel shown in the message pane, or null for none.
  final String? selectedChannelId;

  /// Message to scroll to when the selected channel mounts (deep links).
  final String? pendingInitialMessageId;

  /// Thread root to open when the selected channel mounts (deep links).
  final String? pendingInitialThreadRootId;

  /// Monotonic counter bumped whenever a selection carries pending IDs, so
  /// a repeated identical deep link still remounts the workspace.
  final int pendingSelectionNonce;

  /// The side panel currently open, if any.
  final ShellSidePanel sidePanel;

  /// Which primary content the main pane shows.
  final ShellMainContent mainContent;

  const ShellState({
    this.selectedChannelId,
    this.pendingInitialMessageId,
    this.pendingInitialThreadRootId,
    this.pendingSelectionNonce = 0,
    this.sidePanel = const ShellSidePanelNone(),
    this.mainContent = ShellMainContent.channels,
  });

  /// Copy with the given fields replaced. Nullable fields use a sentinel so
  /// they can be explicitly set to null.
  ShellState copyWith({
    Object? selectedChannelId = _sentinel,
    Object? pendingInitialMessageId = _sentinel,
    Object? pendingInitialThreadRootId = _sentinel,
    int? pendingSelectionNonce,
    ShellSidePanel? sidePanel,
    ShellMainContent? mainContent,
  }) {
    return ShellState(
      selectedChannelId: selectedChannelId == _sentinel
          ? this.selectedChannelId
          : selectedChannelId as String?,
      pendingInitialMessageId: pendingInitialMessageId == _sentinel
          ? this.pendingInitialMessageId
          : pendingInitialMessageId as String?,
      pendingInitialThreadRootId: pendingInitialThreadRootId == _sentinel
          ? this.pendingInitialThreadRootId
          : pendingInitialThreadRootId as String?,
      pendingSelectionNonce:
          pendingSelectionNonce ?? this.pendingSelectionNonce,
      sidePanel: sidePanel ?? this.sidePanel,
      mainContent: mainContent ?? this.mainContent,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ShellState &&
      other.selectedChannelId == selectedChannelId &&
      other.pendingInitialMessageId == pendingInitialMessageId &&
      other.pendingInitialThreadRootId == pendingInitialThreadRootId &&
      other.pendingSelectionNonce == pendingSelectionNonce &&
      other.sidePanel == sidePanel &&
      other.mainContent == mainContent;

  @override
  int get hashCode => Object.hash(
    selectedChannelId,
    pendingInitialMessageId,
    pendingInitialThreadRootId,
    pendingSelectionNonce,
    sidePanel,
    mainContent,
  );
}
