import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'notification_service.dart';

/// GeofenceService handles automatic pub visit detection using GPS.
/// 
/// Architecture notes:
/// - Foreground: Uses location stream for real-time detection
/// - Background: Uses Workmanager for periodic checks (15 min on Android)
/// - State persisted to SharedPreferences to survive app restarts
/// - Uses mutex-style locking to prevent race conditions
class GeofenceService {
  static final GeofenceService instance = GeofenceService._internal();
  GeofenceService._internal();

  static const double _pubRadius = 50.0; // meters
  static const Duration _minVisitDuration = Duration(minutes: 10);
  static const Duration _sessionResumeWindow = Duration(minutes: 30); // Resume recent sessions
  static const String _activeVisitsKey = 'active_pub_visits';
  static const String _userIdKey = 'user_id';
  static const String _authTokenKey = 'auth_access_token';
  static const String _refreshTokenKey = 'auth_refresh_token';
  static const String _lockKey = 'geofence_lock';

  StreamSubscription<Position>? _locationSubscription;
  bool _isProcessing = false; // Prevent concurrent processing

  Future<void> initialize() async {
    // Check and request permissions
    final permission = await _checkPermissions();
    if (!permission) return;

    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    final session = supabase.auth.currentSession;
    
    if (userId == null || session == null) return;

    // Save credentials for background tasks
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_authTokenKey, session.accessToken);
    await prefs.setString(_refreshTokenKey, session.refreshToken ?? '');

    // Listen for token refreshes and update stored tokens
    supabase.auth.onAuthStateChange.listen((data) async {
      if (data.session != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_authTokenKey, data.session!.accessToken);
        await prefs.setString(_refreshTokenKey, data.session!.refreshToken ?? '');
      }
    });

    // Start foreground tracking
    _startForegroundTracking();

    // Initialize background task manager
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

    // Register periodic background task (Android: minimum 15 min)
    await Workmanager().registerPeriodicTask(
      'geofence-check',
      'checkGeofences',
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  Future<bool> _checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  void _startForegroundTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 30, // meters - update every 30m moved
      ),
    ).listen(_handleLocationUpdate, onError: (e) {
      // Log error but don't crash
      print('Location stream error: $e');
    });
  }

  Future<void> _handleLocationUpdate(Position position) async {
    // Prevent concurrent processing
    if (_isProcessing) return;
    _isProcessing = true;
    
    try {
      await _checkLocation(position);
    } catch (e) {
      print('Error checking location: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _checkLocation(Position position) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();

    // Acquire lock to prevent race conditions with background task
    final lockTime = prefs.getInt(_lockKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lockTime < 5000) return; // Another process is running
    await prefs.setInt(_lockKey, now);

    try {
      // Load persisted active visits
      final activeVisitsJson = prefs.getString(_activeVisitsKey) ?? '{}';
      final activeVisits = Map<String, int>.from(jsonDecode(activeVisitsJson));

      // Fetch nearby pubs with error handling
      List<dynamic> pubs;
      try {
        pubs = await supabase.rpc('nearby_pubs', params: {
          'user_lat': position.latitude,
          'user_lng': position.longitude,
          'radius_m': 200,
        });
      } catch (e) {
        print('Failed to fetch nearby pubs: $e');
        return;
      }

      final nearbyPubIds = <String>{};
      for (final pub in pubs) {
        nearbyPubIds.add(pub['id'] as String);
      }

      // Check for new entries
      for (final pub in pubs) {
        final pubId = pub['id'] as String;
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          (pub['lat'] as num).toDouble(),
          (pub['lng'] as num).toDouble(),
        );

        if (distance <= _pubRadius && !activeVisits.containsKey(pubId)) {
          // Check for recent session to resume (user stepped out briefly)
          final recentSession = await _findRecentSession(supabase, userId, pubId);
          
          if (recentSession != null) {
            // Resume existing session - clear end_at
            await supabase.from('sessions').update({
              'end_at': null,
              'duration_minutes': null,
              'estimated_pints': null,
            }).eq('id', recentSession['id']);
            
            // Use original start time
            activeVisits[pubId] = DateTime.parse(recentSession['start_at']).millisecondsSinceEpoch;
          } else {
            // Check for existing open session at this pub (prevent duplicates)
            final existingOpen = await supabase
                .from('sessions')
                .select()
                .eq('pub_id', pubId)
                .eq('user_id', userId)
                .isFilter('end_at', null)
                .limit(1);
            
            if (existingOpen.isEmpty) {
              // ENTER: Start tracking new visit
              activeVisits[pubId] = DateTime.now().millisecondsSinceEpoch;

              await supabase.from('sessions').insert({
                'user_id': userId,
                'pub_id': pubId,
                'pub_name': pub['name'],
                'start_at': DateTime.now().toIso8601String(),
                'source': 'geo',
                'confidence': 'high',
              });
            }
          }
        }
      }

      // Check for exits (was tracking, now not nearby)
      final exitedPubs = <String>[];
      for (final pubId in activeVisits.keys) {
        if (!nearbyPubIds.contains(pubId)) {
          exitedPubs.add(pubId);
        }
      }

      for (final pubId in exitedPubs) {
        final enterTime = DateTime.fromMillisecondsSinceEpoch(activeVisits[pubId]!);
        final duration = DateTime.now().difference(enterTime);

        if (duration >= _minVisitDuration) {
          final estimatedPints = _estimatePintsFromDuration(duration);

          // Get session to update
          final sessions = await supabase
              .from('sessions')
              .select()
              .eq('pub_id', pubId)
              .eq('user_id', userId)
              .isFilter('end_at', null)
              .order('start_at', ascending: false)
              .limit(1);

          if (sessions.isNotEmpty) {
            final session = sessions.first;

            await supabase.from('sessions').update({
              'end_at': DateTime.now().toIso8601String(),
              'duration_minutes': duration.inMinutes,
              'estimated_pints': estimatedPints,
            }).eq('id', session['id']);

            // Check user preferences for auto-confirm
            try {
              final profile = await supabase
                  .from('profiles')
                  .select('auto_confirm_high_confidence')
                  .eq('id', userId)
                  .single();

              if (profile['auto_confirm_high_confidence'] == true) {
                // Auto-log pints
                await supabase.from('pints').insert({
                  'user_id': userId,
                  'pub_id': pubId,
                  'pub_name': session['pub_name'],
                  'session_id': session['id'],
                  'quantity': estimatedPints,
                  'source': 'geo_auto',
                  'logged_at': DateTime.now().toIso8601String(),
                });

                // Mark session as verified
                await supabase
                    .from('sessions')
                    .update({'verified': true}).eq('id', session['id']);
              } else {
                // Send notification for confirmation
                await NotificationService.instance.showVisitConfirmation(
                  sessionId: session['id'],
                  pubName: session['pub_name'] ?? 'Unknown Pub',
                  estimatedPints: estimatedPints,
                  pubId: pubId,
                );
              }
            } catch (e) {
              // Profile might not exist, send notification
              await NotificationService.instance.showVisitConfirmation(
                sessionId: session['id'],
                pubName: session['pub_name'] ?? 'Unknown Pub',
                estimatedPints: estimatedPints,
                pubId: pubId,
              );
            }
          }
        }

        activeVisits.remove(pubId);
      }

      // Persist updated active visits
      await prefs.setString(_activeVisitsKey, jsonEncode(activeVisits));
    } finally {
      // Release lock
      await prefs.remove(_lockKey);
    }
  }

  /// Find a recent session at this pub that ended within the resume window
  Future<Map<String, dynamic>?> _findRecentSession(
    SupabaseClient supabase,
    String userId,
    String pubId,
  ) async {
    final cutoff = DateTime.now().subtract(_sessionResumeWindow);
    
    final sessions = await supabase
        .from('sessions')
        .select()
        .eq('pub_id', pubId)
        .eq('user_id', userId)
        .not('end_at', 'is', null)
        .gte('end_at', cutoff.toIso8601String())
        .order('end_at', ascending: false)
        .limit(1);
    
    return sessions.isNotEmpty ? sessions.first : null;
  }

  static int _estimatePintsFromDuration(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes < 10) return 0;
    if (minutes < 30) return 1;
    if (minutes < 60) return 2;
    if (minutes < 90) return 3;
    if (minutes < 120) return 4;
    if (minutes < 180) return 5;
    if (minutes < 240) return 6;
    return (minutes / 40).floor().clamp(1, 12);
  }

  void dispose() {
    _locationSubscription?.cancel();
  }
}

// Background task callback
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'checkGeofences') {
      try {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id');
        final accessToken = prefs.getString('auth_access_token');
        final refreshToken = prefs.getString('auth_refresh_token');
        
        if (userId == null || accessToken == null) return true;

        // Initialize Supabase in background isolate
        await Supabase.initialize(
          url: const String.fromEnvironment(
            'SUPABASE_URL',
            defaultValue: 'https://hsdhlnjpwbendlwfoyqp.supabase.co',
          ),
          anonKey: const String.fromEnvironment(
            'SUPABASE_ANON_KEY',
            defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhzZGhsbmpwd2JlbmRsd2ZveXFwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUzODYwNjcsImV4cCI6MjA4MDk2MjA2N30.Qx0N2eN9yx_pGceAdiv4Jk2yfyOSIKqZAbqT0ZkM-C8',
          ),
        );

        // Restore the auth session
        final supabase = Supabase.instance.client;
        await supabase.auth.setSession(accessToken);

        // Verify we have a valid session
        if (supabase.auth.currentUser == null) {
          // Try to refresh the token
          if (refreshToken != null && refreshToken.isNotEmpty) {
            try {
              final response = await supabase.auth.refreshSession();
              if (response.session != null) {
                await prefs.setString('auth_access_token', response.session!.accessToken);
                await prefs.setString('auth_refresh_token', response.session!.refreshToken ?? '');
              }
            } catch (e) {
              print('Failed to refresh token in background: $e');
              return true;
            }
          } else {
            return true; // No valid auth
          }
        }

        // Acquire lock to prevent race conditions
        final lockTime = prefs.getInt(GeofenceService._lockKey) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lockTime < 5000) return true; // Foreground is processing
        await prefs.setInt(GeofenceService._lockKey, now);

        try {
          // Get current position
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );

          // Check location in background
          await _checkLocationBackground(position, userId, prefs, supabase);
        } finally {
          await prefs.remove(GeofenceService._lockKey);
        }
      } catch (e) {
        print('Background geofence check failed: $e');
      }
    }
    return true;
  });
}

Future<void> _checkLocationBackground(
  Position position,
  String userId,
  SharedPreferences prefs,
  SupabaseClient supabase,
) async {
  // Load persisted active visits
  final activeVisitsJson = prefs.getString(GeofenceService._activeVisitsKey) ?? '{}';
  final activeVisits = Map<String, int>.from(jsonDecode(activeVisitsJson));

  // Fetch nearby pubs
  List<dynamic> pubs;
  try {
    pubs = await supabase.rpc('nearby_pubs', params: {
      'user_lat': position.latitude,
      'user_lng': position.longitude,
      'radius_m': 200,
    });
  } catch (e) {
    print('Failed to fetch nearby pubs in background: $e');
    return;
  }

  final nearbyPubIds = pubs.map((p) => p['id'] as String).toSet();

  // Check for new entries
  for (final pub in pubs) {
    final pubId = pub['id'] as String;
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      (pub['lat'] as num).toDouble(),
      (pub['lng'] as num).toDouble(),
    );

    if (distance <= GeofenceService._pubRadius &&
        !activeVisits.containsKey(pubId)) {
      
      // Check for existing open session (prevent duplicates)
      final existingOpen = await supabase
          .from('sessions')
          .select()
          .eq('pub_id', pubId)
          .eq('user_id', userId)
          .isFilter('end_at', null)
          .limit(1);
      
      if (existingOpen.isEmpty) {
        activeVisits[pubId] = DateTime.now().millisecondsSinceEpoch;

        await supabase.from('sessions').insert({
          'user_id': userId,
          'pub_id': pubId,
          'pub_name': pub['name'],
          'start_at': DateTime.now().toIso8601String(),
          'source': 'geo',
          'confidence': 'high',
        });
      }
    }
  }

  // Check for exits
  for (final pubId in activeVisits.keys.toList()) {
    if (!nearbyPubIds.contains(pubId)) {
      final enterTime = DateTime.fromMillisecondsSinceEpoch(activeVisits[pubId]!);
      final duration = DateTime.now().difference(enterTime);

      if (duration >= GeofenceService._minVisitDuration) {
        final estimatedPints = GeofenceService._estimatePintsFromDuration(duration);

        await supabase.from('sessions').update({
          'end_at': DateTime.now().toIso8601String(),
          'duration_minutes': duration.inMinutes,
          'estimated_pints': estimatedPints,
        }).eq('pub_id', pubId).eq('user_id', userId).isFilter('end_at', null);
        
        // Note: In background, we can't show notifications directly
        // The user will see pending sessions when they open the app
      }

      activeVisits.remove(pubId);
    }
  }

  // Persist updated active visits
  await prefs.setString(GeofenceService._activeVisitsKey, jsonEncode(activeVisits));
}
