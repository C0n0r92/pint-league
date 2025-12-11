import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/services/notification_service.dart';
import 'core/services/geofence_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Supabase
  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://hsdhlnjpwbendlwfoyqp.supabase.co',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      // Default key for development - replace in production
      defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhzZGhsbmpwd2JlbmRsd2ZveXFwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUzODYwNjcsImV4cCI6MjA4MDk2MjA2N30.Qx0N2eN9yx_pGceAdiv4Jk2yfyOSIKqZAbqT0ZkM-C8',
    ),
  );

  // Initialize services after auth state is ready
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedIn) {
      NotificationService.instance.initialize();
      GeofenceService.instance.initialize();
    }
  });
  
  // Initialize if already logged in
  if (Supabase.instance.client.auth.currentUser != null) {
    await NotificationService.instance.initialize();
    await GeofenceService.instance.initialize();
  }

  runApp(
    const ProviderScope(
      child: PintsLeagueApp(),
    ),
  );
}

class PintsLeagueApp extends ConsumerWidget {
  const PintsLeagueApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Pints League',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
