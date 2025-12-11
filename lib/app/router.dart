import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/pints/screens/log_pint_screen.dart';
import '../features/pints/screens/pint_history_screen.dart';
import '../features/leagues/screens/leagues_screen.dart';
import '../features/leagues/screens/league_detail_screen.dart';
import '../features/leagues/screens/create_league_screen.dart';
import '../features/leagues/screens/join_league_screen.dart';
import '../features/friends/screens/friends_screen.dart';
import '../features/sessions/screens/sessions_screen.dart';
import '../features/settings/screens/settings_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

// Auth state notifier for router refresh - properly manages subscription
class AuthNotifier extends ChangeNotifier {
  StreamSubscription<AuthState>? _subscription;
  
  AuthNotifier() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      notifyListeners();
    });
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

// Use a provider so it can be properly disposed
final _authNotifierProvider = Provider<AuthNotifier>((ref) {
  final notifier = AuthNotifier();
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

// For non-riverpod contexts, keep a reference
late final AuthNotifier _authNotifier;

final routerProvider = Provider<GoRouter>((ref) {
  // Get auth notifier from provider (ensures proper disposal)
  _authNotifier = ref.watch(_authNotifierProvider);
  
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: _authNotifier,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/onboarding';

      if (!isLoggedIn && !isAuthRoute) {
        return '/onboarding';
      }
      if (isLoggedIn && isAuthRoute) {
        return '/';
      }
      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),

      // Main app with bottom navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/leagues',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LeaguesScreen(),
            ),
          ),
          GoRoute(
            path: '/friends',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: FriendsScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),

      // Full screen routes
      GoRoute(
        path: '/log-pint',
        builder: (context, state) => const LogPintScreen(),
      ),
      GoRoute(
        path: '/pint-history',
        builder: (context, state) => const PintHistoryScreen(),
      ),
      GoRoute(
        path: '/sessions',
        builder: (context, state) => const SessionsScreen(),
      ),
      GoRoute(
        path: '/leagues/create',
        builder: (context, state) => const CreateLeagueScreen(),
      ),
      GoRoute(
        path: '/leagues/join',
        builder: (context, state) => const JoinLeagueScreen(),
      ),
      GoRoute(
        path: '/leagues/:id',
        builder: (context, state) => LeagueDetailScreen(
          leagueId: state.pathParameters['id']!,
        ),
      ),

      // TrueLayer callback (deep link)
      GoRoute(
        path: '/truelayer/callback',
        builder: (context, state) {
          final code = state.uri.queryParameters['code'];
          // Handle TrueLayer OAuth callback
          return TrueLayerCallbackHandler(code: code);
        },
      ),
    ],
  );
});

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/log-pint'),
        icon: const Icon(Icons.sports_bar),
        label: const Text('Log Pint'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: 'Home',
              path: '/',
            ),
            _NavItem(
              icon: Icons.emoji_events_outlined,
              selectedIcon: Icons.emoji_events,
              label: 'Leagues',
              path: '/leagues',
            ),
            const SizedBox(width: 48), // Space for FAB
            _NavItem(
              icon: Icons.people_outline,
              selectedIcon: Icons.people,
              label: 'Friends',
              path: '/friends',
            ),
            _NavItem(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings,
              label: 'Settings',
              path: '/settings',
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String path;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).matchedLocation;
    final isSelected = currentPath == path;

    return InkWell(
      onTap: () => context.go(path),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder for TrueLayer callback handling
class TrueLayerCallbackHandler extends StatefulWidget {
  final String? code;

  const TrueLayerCallbackHandler({super.key, this.code});

  @override
  State<TrueLayerCallbackHandler> createState() => _TrueLayerCallbackHandlerState();
}

class _TrueLayerCallbackHandlerState extends State<TrueLayerCallbackHandler> {
  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    if (widget.code != null) {
      // Exchange code for tokens via Edge Function
      try {
        await Supabase.instance.client.functions.invoke(
          'truelayer-auth',
          body: {'code': widget.code},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bank connected successfully!')),
          );
          context.go('/settings');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to connect bank: $e')),
          );
          context.go('/settings');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Connecting your bank...'),
          ],
        ),
      ),
    );
  }
}

