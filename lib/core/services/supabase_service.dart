import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  return Supabase.instance.client.auth.currentUser;
});

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  // Auth methods
  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? username,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: username != null ? {'username': username} : null,
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static Future<bool> signInWithGoogle() async {
    return await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.conor.pintleague://login-callback',
    );
  }

  static Future<bool> signInWithApple() async {
    return await client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'com.conor.pintleague://login-callback',
    );
  }

  // Profile methods
  static Future<Map<String, dynamic>?> getProfile(String userId) async {
    final response = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response;
  }

  static Future<void> updateProfile({
    required String userId,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? homeCity,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (username != null) updates['username'] = username;
    if (displayName != null) updates['display_name'] = displayName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (homeCity != null) updates['home_city'] = homeCity;

    await client.from('profiles').update(updates).eq('id', userId);
  }

  // Pints methods
  static Future<List<Map<String, dynamic>>> getPints({
    required String userId,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await client
        .from('pints')
        .select('*, pubs(*)')
        .eq('user_id', userId)
        .order('logged_at', ascending: false)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> logPint({
    required String userId,
    String? pubId,
    String? pubName,
    String? drinkType,
    int quantity = 1,
    String? photoUrl,
    List<String>? friendsTagged,
  }) async {
    await client.from('pints').insert({
      'user_id': userId,
      'pub_id': pubId,
      'pub_name': pubName,
      'drink_type': drinkType ?? 'pint',
      'quantity': quantity,
      'photo_url': photoUrl,
      'friends_tagged': friendsTagged,
      'source': 'manual',
      'logged_at': DateTime.now().toIso8601String(),
    });

    // Update profile total_pints and total_points
    try {
      await client.rpc('increment_profile_stats', params: {
        'p_user_id': userId,
        'p_pints': quantity,
        'p_points': quantity * 10, // Base points per pint
      });
    } catch (e) {
      // If RPC doesn't exist, try direct update
      final profile = await client
          .from('profiles')
          .select('total_pints, total_points')
          .eq('id', userId)
          .maybeSingle();
      
      if (profile != null) {
        await client.from('profiles').update({
          'total_pints': (profile['total_pints'] ?? 0) + quantity,
          'total_points': (profile['total_points'] ?? 0) + (quantity * 10),
        }).eq('id', userId);
      }
    }
  }

  // Pubs methods
  static Future<List<Map<String, dynamic>>> searchPubs(String query) async {
    final response = await client.rpc('search_pubs', params: {
      'search_query': query,
      'limit_count': 20,
    });
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> getNearbyPubs({
    required double lat,
    required double lng,
    int radiusM = 500,
  }) async {
    final response = await client.rpc('nearby_pubs', params: {
      'user_lat': lat,
      'user_lng': lng,
      'radius_m': radiusM,
    });
    return List<Map<String, dynamic>>.from(response);
  }

  // Sessions methods
  static Future<List<Map<String, dynamic>>> getSessions({
    required String userId,
    int limit = 50,
  }) async {
    final response = await client
        .from('sessions')
        .select('*, pubs(*)')
        .eq('user_id', userId)
        .order('start_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }

  // Leagues methods
  static Future<List<Map<String, dynamic>>> getUserLeagues(String userId) async {
    final response = await client
        .from('league_members')
        .select('*, leagues(*)')
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<Map<String, dynamic>?> getLeagueByCode(String code) async {
    final response = await client
        .from('leagues')
        .select()
        .eq('code', code.toUpperCase())
        .maybeSingle();
    return response;
  }

  static Future<void> createLeague({
    required String name,
    required String creatorId,
    String? description,
    bool isPublic = false,
  }) async {
    final league = await client.from('leagues').insert({
      'name': name,
      'creator_id': creatorId,
      'description': description,
      'is_public': isPublic,
    }).select().single();

    // Creator automatically joins
    await client.from('league_members').insert({
      'league_id': league['id'],
      'user_id': creatorId,
    });
  }

  static Future<void> joinLeague({
    required String leagueId,
    required String userId,
  }) async {
    await client.from('league_members').insert({
      'league_id': leagueId,
      'user_id': userId,
    });
  }

  // Friends methods - uses bidirectional RPC function
  static Future<List<Map<String, dynamic>>> getFriends(String userId) async {
    // Use the bidirectional function that returns friends from both directions
    final response = await client.rpc('get_user_friends', params: {
      'target_user_id': userId,
    });
    return List<Map<String, dynamic>>.from(response);
  }
  
  // Get pending friend requests (where user is recipient)
  static Future<List<Map<String, dynamic>>> getPendingFriendRequests(String userId) async {
    final response = await client.rpc('get_pending_friend_requests', params: {
      'target_user_id': userId,
    });
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> sendFriendRequest({
    required String fromUserId,
    required String toUserId,
  }) async {
    await client.from('friendships').insert({
      'user_id': fromUserId,
      'friend_id': toUserId,
      'status': 'pending',
    });
  }

  static Future<void> acceptFriendRequest(String friendshipId) async {
    await client
        .from('friendships')
        .update({'status': 'accepted'}).eq('id', friendshipId);
  }

  // Weekly points
  static Future<Map<String, dynamic>?> getWeeklyPoints({
    required String userId,
    required DateTime weekStart,
  }) async {
    final response = await client
        .from('weekly_points')
        .select()
        .eq('user_id', userId)
        .eq('week_start', weekStart.toIso8601String().split('T')[0])
        .maybeSingle();
    return response;
  }

  /// Calculate real-time stats from pints table for the current week
  static Future<Map<String, dynamic>> getWeeklyStatsRealtime({
    required String userId,
    required DateTime weekStart,
  }) async {
    final weekEnd = weekStart.add(const Duration(days: 7));
    
    // Get all pints for this week
    final pints = await client
        .from('pints')
        .select('id, pub_id, quantity, logged_at')
        .eq('user_id', userId)
        .gte('logged_at', weekStart.toIso8601String())
        .lt('logged_at', weekEnd.toIso8601String());
    
    final pintsList = List<Map<String, dynamic>>.from(pints);
    
    // Calculate stats
    int totalPints = 0;
    final uniquePubs = <String>{};
    
    for (final pint in pintsList) {
      totalPints += (pint['quantity'] as int? ?? 1);
      if (pint['pub_id'] != null) {
        uniquePubs.add(pint['pub_id'] as String);
      }
    }
    
    // Calculate points (10 per pint + 5 per unique pub)
    final basePoints = totalPints * 10;
    final uniquePubPoints = uniquePubs.length * 5;
    final totalPoints = basePoints + uniquePubPoints;
    
    return {
      'total_points': totalPoints,
      'breakdown': {
        'base': basePoints,
        'unique_pubs': uniquePubPoints,
        'social': 0,
        'streak': 0,
        'verification': 0,
      },
      'pints_count': totalPints,
      'unique_pubs_count': uniquePubs.length,
    };
  }
}

