import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';
import '../theme/theme.dart';

/// Shows [builder]'s content as a modal bottom sheet at narrow widths and as
/// a centered [Dialog] at expanded widths (see [isExpandedLayout]).
///
/// Narrow mode delegates to [showModalBottomSheet], passing
/// [isScrollControlled], [showDragHandle], [backgroundColor] and
/// [constraints] through unchanged so converted call sites keep today's exact
/// look. Wide mode uses [showDialog] with a [Radii.dialog]-rounded [Dialog]
/// constrained to [constraints] (or [maxWidth] when none are given);
/// Flutter's default [DismissIntent] handling closes it on Esc.
///
/// The width is snapshotted at open time: resizing across the breakpoint
/// while the modal is open keeps the original presentation until dismissed.
Future<T?> showAdaptiveModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool showDragHandle = true,
  double maxWidth = 480,
  Color? backgroundColor,
  BoxConstraints? constraints,
}) {
  if (!isExpandedLayout(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      showDragHandle: showDragHandle,
      backgroundColor: backgroundColor,
      constraints: constraints,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.dialog),
      ),
      child: ConstrainedBox(
        constraints: constraints ?? BoxConstraints(maxWidth: maxWidth),
        child: builder(dialogContext),
      ),
    ),
  );
}
