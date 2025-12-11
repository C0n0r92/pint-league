import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'notification_service.dart';

class GeofenceService {
  static final GeofenceService instance = GeofenceService._internal();
  GeofenceService._internal();

  static const double _pubRadius = 50.0; // meters
  static const Duration _minVisitDuration = Duration(minutes: 10);
  static const String _activeVisitsKey = 'active_pub_visits';
  static const String _userIdKey = 'user_id';

  StreamSubscription<Position>? _locationSubscription;

  Future<void> initialize() async {
    // Check and request permissions
    final permission = await _checkPermissions();
    if (!permission) return;

    // Save user ID for background tasks
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, userId);
    }

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
    ).listen(_handleLocationUpdate);
  }

  Future<void> _handleLocationUpdate(Position position) async {
    await _checkLocation(position);
  }

  Future<void> _checkLocation(Position position) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();

    // Load persisted active visits
    final activeVisitsJson = prefs.getString(_activeVisitsKey) ?? '{}';
    final activeVisits = Map<String, int>.from(jsonDecode(activeVisitsJson));

    // Fetch nearby pubs
    final pubs = await supabase.rpc('nearby_pubs', params: {
      'user_lat': position.latitude,
      'user_lng': position.longitude,
      'radius_m': 200,
    });

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
        // ENTER: Start tracking visit
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

    // Check for exits (was tracking, now not nearby)
    final exitedPubs = <String>[];
    for (final pubId in activeVisits.keys) {
      if (!nearbyPubIds.contains(pubId)) {
        exitedPubs.add(pubId);
      }
    }

    for (final pubId in exitedPubs) {
      final enterTime =
          DateTime.fromMillisecondsSinceEpoch(activeVisits[pubId]!);
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
            .limit(1);

        if (sessions.isNotEmpty) {
          final session = sessions.first;

          await supabase.from('sessions').update({
            'end_at': DateTime.now().toIso8601String(),
            'duration_minutes': duration.inMinutes,
            'estimated_pints': estimatedPints,
          }).eq('id', session['id']);

          // Check user preferences for auto-confirm
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
              pubName: session['pub_name'],
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

        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id');
        if (userId == null) return true;

        // Get current position
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        // Check location in background
        await _checkLocationBackground(position, userId, prefs);
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
) async {
  final supabase = Supabase.instance.client;

  // Load persisted active visits
  final activeVisitsJson =
      prefs.getString(GeofenceService._activeVisitsKey) ?? '{}';
  final activeVisits = Map<String, int>.from(jsonDecode(activeVisitsJson));

  // Fetch nearby pubs
  final pubs = await supabase.rpc('nearby_pubs', params: {
    'user_lat': position.latitude,
    'user_lng': position.longitude,
    'radius_m': 200,
  });

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

  // Check for exits
  for (final pubId in activeVisits.keys.toList()) {
    if (!nearbyPubIds.contains(pubId)) {
      final enterTime =
          DateTime.fromMillisecondsSinceEpoch(activeVisits[pubId]!);
      final duration = DateTime.now().difference(enterTime);

      if (duration >= GeofenceService._minVisitDuration) {
        final estimatedPints =
            GeofenceService._estimatePintsFromDuration(duration);

        await supabase.from('sessions').update({
          'end_at': DateTime.now().toIso8601String(),
          'duration_minutes': duration.inMinutes,
          'estimated_pints': estimatedPints,
        }).eq('pub_id', pubId).eq('user_id', userId).isFilter('end_at', null);
      }

      activeVisits.remove(pubId);
    }
  }

  // Persist updated active visits
  await prefs.setString(GeofenceService._activeVisitsKey, jsonEncode(activeVisits));
}

