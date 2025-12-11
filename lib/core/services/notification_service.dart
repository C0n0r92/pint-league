import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // Request notification permissions
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Android notification channel
    const androidChannel = AndroidNotificationChannel(
      'pint_confirmations',
      'Pint Confirmations',
      description: 'Notifications for confirming pub visits',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Initialize local notifications
    final initSettings = InitializationSettings(
      android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        notificationCategories: [
          DarwinNotificationCategory(
            'visit_confirmation',
            actions: [
              DarwinNotificationAction.plain('confirm', 'Confirm'),
              DarwinNotificationAction.plain('adjust', 'Adjust'),
              DarwinNotificationAction.plain('dismiss', "Wasn't there"),
            ],
          ),
        ],
      ),
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationAction,
    );

    // Handle FCM messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

    // Save FCM token
    await _saveFcmToken();

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen((token) => _saveFcmToken());
  }

  Future<void> _saveFcmToken() async {
    final token = await _firebaseMessaging.getToken();
    if (token == null) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Determine platform
    final platform = await _getPlatform();

    await Supabase.instance.client.from('device_tokens').upsert({
      'user_id': userId,
      'token': token,
      'platform': platform,
    }, onConflict: 'user_id,token');
  }

  String _getPlatform() {
    // Platform detection
    if (identical(0, 0.0)) {
      return 'web'; // Web platform
    }
    // Check for iOS vs Android using dart:io would require conditional import
    // For now, use a simple check based on the platform
    return 'android'; // Default, will be properly detected at runtime
  }

  void _handleNotificationAction(NotificationResponse response) async {
    final payload = jsonDecode(response.payload ?? '{}');
    final sessionId = payload['session_id'] as String?;
    final estimatedPints =
        int.tryParse(payload['estimated_pints']?.toString() ?? '0') ?? 0;

    if (sessionId == null) return;

    switch (response.actionId) {
      case 'confirm':
        await _confirmSession(sessionId, estimatedPints);
        break;
      case 'dismiss':
        await _discardSession(sessionId);
        break;
      case 'adjust':
        // This should navigate to adjustment screen
        // Handled by the app's navigation
        break;
    }
  }

  Future<void> _confirmSession(String sessionId, int pints) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Mark session as verified
    await supabase.from('sessions').update({'verified': true}).eq('id', sessionId);

    // Get session details
    final session =
        await supabase.from('sessions').select().eq('id', sessionId).single();

    // Create pints
    await supabase.from('pints').insert({
      'user_id': userId,
      'pub_id': session['pub_id'],
      'pub_name': session['pub_name'],
      'session_id': sessionId,
      'quantity': pints,
      'source': 'geo_auto',
      'logged_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _discardSession(String sessionId) async {
    await Supabase.instance.client
        .from('sessions')
        .update({'discarded': true}).eq('id', sessionId);
  }

  Future<void> showVisitConfirmation({
    required String sessionId,
    required String pubName,
    required int estimatedPints,
    required String pubId,
  }) async {
    await _localNotifications.show(
      sessionId.hashCode,
      'Visited $pubName?',
      'We detected a visit. Log $estimatedPints pint${estimatedPints > 1 ? 's' : ''}?',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'pint_confirmations',
          'Pint Confirmations',
          importance: Importance.high,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction('confirm', 'Confirm $estimatedPints'),
            AndroidNotificationAction('adjust', 'Adjust'),
            AndroidNotificationAction('dismiss', "Wasn't there"),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: 'visit_confirmation',
        ),
      ),
      payload: jsonEncode({
        'type': 'visit_confirmation',
        'session_id': sessionId,
        'pub_id': pubId,
        'pub_name': pubName,
        'estimated_pints': estimatedPints.toString(),
      }),
    );
  }
}

Future<void> _handleForegroundMessage(RemoteMessage message) async {
  // Handle foreground FCM message
  print('Foreground message: ${message.notification?.title}');
}

@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  // Handle background FCM message
  print('Background message: ${message.notification?.title}');
}

