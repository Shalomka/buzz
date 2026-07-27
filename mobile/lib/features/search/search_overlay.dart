import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../shared/theme/theme.dart';
import '../../shared/widgets/adaptive_modal.dart';
import 'search_page.dart';

/// Height of the overlay's result area — the results list needs a bounded
/// box, and a fixed one keeps the dialog from jumping as hits arrive.
const double _overlayHeight = 520;

/// Opens search as an overlay above the current surface.
///
/// Delegates to [showAdaptiveModal], so this is a centered dialog at expanded
/// widths (where the shell's Cmd/Ctrl+K shortcut triggers it) and the usual
/// bottom sheet at narrow widths.
Future<void> showSearchOverlay(BuildContext context) {
  return showAdaptiveModal<void>(
    context,
    isScrollControlled: true,
    maxWidth: 640,
    builder: (_) => const _SearchOverlay(),
  );
}

class _SearchOverlay extends HookConsumerWidget {
  const _SearchOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();

    return SizedBox(
      height: _overlayHeight,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Grid.xs,
              Grid.xs,
              Grid.xs,
              Grid.xxs,
            ),
            child: SearchInputField(controller: controller),
          ),
          const Expanded(child: SearchView()),
        ],
      ),
    );
  }
}
