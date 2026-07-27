import 'package:flutter/widgets.dart';

/// Minimum logical window width at which the app switches from the mobile
/// shell to the expanded multi-pane desktop shell.
///
/// Matches the Material 3 "expanded" window-size-class boundary.
const double kExpandedLayoutMinWidth = 840;

/// Whether the current window is wide enough for the expanded multi-pane
/// desktop layout.
///
/// Reads [MediaQuery.sizeOf], so callers rebuild when the window size
/// changes. Returns true when the window width is at least
/// [kExpandedLayoutMinWidth].
bool isExpandedLayout(BuildContext context) {
  return MediaQuery.sizeOf(context).width >= kExpandedLayoutMinWidth;
}
