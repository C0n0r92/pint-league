import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeagueDetailScreen extends StatefulWidget {
  final String leagueId;

  const LeagueDetailScreen({super.key, required this.leagueId});

  @override
  State<LeagueDetailScreen> createState() => _LeagueDetailScreenState();
}

class _LeagueDetailScreenState extends State<LeagueDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _league;
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLeague();
    _subscribeToUpdates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLeague() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      final league = await supabase
          .from('leagues')
          .select()
          .eq('id', widget.leagueId)
          .single();

      final members = await supabase
          .from('league_members')
          .select('*, profiles(*)')
          .eq('league_id', widget.leagueId)
          .order('rank', ascending: true);

      if (mounted) {
        setState(() {
          _league = league;
          _members = List<Map<String, dynamic>>.from(members);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _subscribeToUpdates() {
    // Subscribe to real-time updates
    Supabase.instance.client
        .from('league_members')
        .stream(primaryKey: ['id'])
        .eq('league_id', widget.leagueId)
        .listen((data) {
          _loadLeague();
        });
  }

  void _shareLeagueCode() {
    final code = _league?['code'] ?? '';
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('League code copied: $code'),
        action: SnackBarAction(
          label: 'Share',
          onPressed: () {
            // TODO: Implement share functionality
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_league == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('League not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_league!['name'] ?? 'League'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareLeagueCode,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Leaderboard'),
            Tab(text: 'This Week'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _LeaderboardTab(members: _members),
          _WeeklyTab(members: _members),
        ],
      ),
    );
  }
}

class _LeaderboardTab extends StatelessWidget {
  final List<Map<String, dynamic>> members;

  const _LeaderboardTab({required this.members});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const Center(child: Text('No members yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        final profile = member['profiles'] as Map<String, dynamic>?;
        final rank = member['rank'] ?? index + 1;
        final totalPoints = member['total_points'] ?? 0;

        return _MemberCard(
          rank: rank,
          username: profile?['username'] ?? 'Unknown',
          displayName: profile?['display_name'],
          avatarUrl: profile?['avatar_url'],
          points: totalPoints,
          isTopThree: rank <= 3,
        );
      },
    );
  }
}

class _WeeklyTab extends StatelessWidget {
  final List<Map<String, dynamic>> members;

  const _WeeklyTab({required this.members});

  @override
  Widget build(BuildContext context) {
    // Sort by weekly points
    final sorted = List<Map<String, dynamic>>.from(members)
      ..sort((a, b) => ((b['weekly_points'] ?? 0) as int)
          .compareTo((a['weekly_points'] ?? 0) as int));

    if (sorted.isEmpty) {
      return const Center(child: Text('No activity this week'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final member = sorted[index];
        final profile = member['profiles'] as Map<String, dynamic>?;
        final weeklyPoints = member['weekly_points'] ?? 0;

        return _MemberCard(
          rank: index + 1,
          username: profile?['username'] ?? 'Unknown',
          displayName: profile?['display_name'],
          avatarUrl: profile?['avatar_url'],
          points: weeklyPoints,
          isTopThree: index < 3,
          label: 'this week',
        );
      },
    );
  }
}

class _MemberCard extends StatelessWidget {
  final int rank;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final int points;
  final bool isTopThree;
  final String? label;

  const _MemberCard({
    required this.rank,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.points,
    this.isTopThree = false,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isTopThree
          ? _getRankColor(rank).withOpacity(0.1)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Center(
                child: rank <= 3
                    ? Text(
                        _getRankEmoji(rank),
                        style: const TextStyle(fontSize: 24),
                      )
                    : Text(
                        '$rank',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl!) : null,
              child: avatarUrl == null
                  ? Text(username[0].toUpperCase())
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName ?? username,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '@$username',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$points',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                Text(
                  label ?? 'pts',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return Colors.grey;
    }
  }

  String _getRankEmoji(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '$rank';
    }
  }
}

