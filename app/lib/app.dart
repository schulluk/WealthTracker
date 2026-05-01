import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/core_providers.dart';
import 'presentation/screens/account_detail_screen.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/imprint_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/server_config_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/theme/app_theme.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final location = state.matchedLocation;

      // Allow splash to handle its own routing
      if (location == '/splash') return null;

      // Allow server config without auth
      if (location == '/server-config') return null;

      // Read auth state without watching to avoid router rebuild loops
      final authState = ref.read(authStateProvider);

      return authState.when(
        data: (auth) {
          final isAuthenticated = auth != null;
          final isAuthRoute =
              location == '/login' || location == '/server-config';

          if (!isAuthenticated && !isAuthRoute) {
            return '/login';
          }
          if (isAuthenticated && isAuthRoute) {
            return '/dashboard';
          }
          return null;
        },
        loading: () => null,
        error: (_, _) => '/login',
      );
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/server-config',
        builder: (context, state) => const ServerConfigScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/accounts/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return AccountDetailScreen(accountId: id);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/imprint',
        builder: (context, state) => const ImprintScreen(),
      ),
    ],
  );
});

class WealthApp extends ConsumerWidget {
  const WealthApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Wealth Tracker',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
