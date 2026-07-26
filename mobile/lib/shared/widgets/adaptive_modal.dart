import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';
import '../theme/theme.dart';

/// Shows [builder]'s content as a modal bottom sheet at narrow widths and as
/// a centered [Dialog] at expanded widths (see [isExpandedLayout]).
///
/// Narrow mode delegates to [showModalBottomSheet], passing
/// [isScrollControlled] and [showDragHandle] through unchanged so converted
/// call sites keep today's exact look. Wide mode uses [showDialog] with a
/// [Radii.dialog]-rounded [Dialog] constrained to [maxWidth]; Flutter's
/// default [DismissIntent] handling closes it on Esc.
///
/// The width is snapshotted at open time: resizing across the breakpoint
/// while the modal is open keeps the original presentation until dismissed.
Future<T?> showAdaptiveModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool showDragHandle = true,
  double maxWidth = 480,
}) {
  if (!isExpandedLayout(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      showDragHandle: showDragHandle,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.dialog),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: builder(dialogContext),
      ),
    ),
  );
}
