import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../shared/layout/breakpoints.dart';
import '../../shared/theme/theme.dart';
import '../activity/activity_page.dart';
import '../channels/channels_page.dart';
import '../search/search_page.dart';
import 'desktop_shell.dart';

part 'home_page/mobile_home_body.dart';

/// Adaptive root of the authenticated app.
///
/// Renders the unchanged mobile tab shell below the expanded breakpoint and
/// the multi-pane [DesktopShell] at expanded widths (see
/// [isExpandedLayout]).
class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return isExpandedLayout(context)
        ? const DesktopShell()
        : const _MobileHomeBody();
  }
}
