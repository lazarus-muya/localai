import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/chat/chat_screen.dart';
import '../../presentation/history/history_screen.dart';
import '../../presentation/models/model_library_screen.dart';
import '../../presentation/settings/settings_screen.dart';
import '../adaptive/adaptive_shell.dart';

/// Every route below renders as a [NoTransitionPage]. Top-level destinations
/// live in their own [StatefulShellBranch] and are swapped by an
/// [IndexedStack] inside [AdaptiveShell] — an instant, stateful tab switch
/// rather than a pushed route, which is what native bottom-nav/sidebar apps
/// do (and avoids the Material "zoom" page transition reading as an
/// unwanted scale effect). The chat branch's two routes (new vs. existing
/// conversation) are the same screen gaining an id in the URL, so they stay
/// transition-free too instead of animating as if navigating to a new page.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/chat',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdaptiveShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ChatScreen(conversationId: null)),
              ),
              GoRoute(
                path: '/chat/:id',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: ChatScreen(conversationId: state.pathParameters['id']),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                pageBuilder: (context, state) => const NoTransitionPage(child: HistoryScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/models',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ModelLibraryScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) => const NoTransitionPage(child: SettingsScreen()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
