import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/chat/chat_screen.dart';
import '../../presentation/history/history_screen.dart';
import '../../presentation/models/model_library_screen.dart';
import '../../presentation/settings/settings_screen.dart';
import '../adaptive/adaptive_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/chat',
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AdaptiveShell(location: state.uri.toString(), child: child),
        routes: [
          GoRoute(
            path: '/chat',
            builder: (context, state) => const ChatScreen(conversationId: null),
          ),
          GoRoute(
            path: '/chat/:id',
            builder: (context, state) => ChatScreen(conversationId: state.pathParameters['id']),
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: '/models',
            builder: (context, state) => const ModelLibraryScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
