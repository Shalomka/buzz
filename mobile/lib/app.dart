import 'dart:async';

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'features/channels/unread_badge/unread_badge_provider.dart';
import 'features/home/home_page.dart';
import 'features/pairing/pairing_page.dart';
import 'features/channels/agent_activity/observer_subscription.dart';
import 'features/channels/deep_link_dispatcher.dart';
import 'features/profile/user_status_cache_provider.dart';
import 'shared/auth/auth.dart';
import 'shared/deeplink/pending_deep_link_provider.dart';
import 'shared/platform/is_web.dart';
import 'shared/relay/relay.dart';
import 'shared/theme/theme.dart';

class App extends HookConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final accentIndex = ref.watch(accentProvider);
    final schemeName = ref.watch(schemeProvider);
    final authState = ref.watch(authProvider);
    final isWeb = ref.watch(isWebProvider);

    final resolved = resolveSchemes(schemeName);
    final lightScheme = applyAccent(resolved.light, accentIndex);
    final darkScheme = applyAccent(resolved.dark, accentIndex);
    // Default and named schemes can force light or dark mode; otherwise
    // respect the user's ThemeMode preference.
    final effectiveMode = resolved.forcedMode ?? themeMode;

    // Eagerly initialize websocket session and lifecycle observer when
    // authenticated. These providers connect and manage the websocket.
    if (authState.value?.status == AuthStatus.authenticated) {
      ref.watch(relaySessionProvider);
      ref.watch(observerRelayProvider);
      ref.watch(appLifecycleProvider);
      ref.watch(userStatusCacheProvider);
    }

    // Start listening for buzz:// links immediately (even pre-auth) so a
    // cold-start link survives until the authenticated UI can dispatch it.
    ref.watch(pendingDeepLinkProvider);

    void applyBadge(UnreadBadgeState state) {
      // app_badge_plus has no web implementation; every call throws
      // MissingPluginException in a browser. isSupported() throws too, so it
      // cannot be used as a probe — gate at the call site.
      if (isWeb) return;
      final count = state.highPriorityCount > 0
          ? state.highPriorityCount
          : (state.generalUnreadCount > 0 ? 1 : 0);
      // Fire-and-forget: some Android launchers reject badge updates, and the
      // returned Future was previously discarded, so a rejection surfaced as
      // an unhandled async error.
      unawaited(
        AppBadgePlus.updateBadge(count).catchError((Object error) {
          debugPrint('Failed to update app badge: $error');
        }),
      );
    }

    useEffect(() {
      applyBadge(ref.read(unreadBadgeProvider));
      return null;
    }, const []);
    ref.listen<UnreadBadgeState>(unreadBadgeProvider, (_, next) {
      applyBadge(next);
    });

    return MaterialApp(
      title: 'Buzz',
      theme: AppTheme.light(colorScheme: lightScheme),
      darkTheme: AppTheme.dark(colorScheme: darkScheme),
      themeMode: effectiveMode,
      home: authState.when(
        loading: () => const _SplashScreen(),
        error: (_, _) => const PairingPage(),
        data: (state) => switch (state.status) {
          AuthStatus.authenticated => const DeepLinkDispatcher(
            child: HomePage(),
          ),
          _ => const DeepLinkDispatcher(
            dispatchMessageLinks: false,
            child: PairingPage(),
          ),
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
