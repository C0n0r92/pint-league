import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/skeleton_loading.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _recentPints = [];
  Map<String, dynamic>? _weeklyPoints;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Profile might not exist for new users, handle gracefully
      Map<String, dynamic>? profile;
      try {
        profile = await SupabaseService.getProfile(userId);
      } catch (e) {
        // Profile doesn't exist yet, use defaults
        profile = {
          'username': 'User',
          'total_pints': 0,
          'total_points': 0,
        };
      }
      
      final pints = await SupabaseService.getPints(userId: userId, limit: 5);

      // Get current week start (Monday)
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      Map<String, dynamic>? weeklyPoints;
      try {
        weeklyPoints = await SupabaseService.getWeeklyPoints(
          userId: userId,
          weekStart: weekStart,
        );
      } catch (e) {
        weeklyPoints = null;
      }

      if (mounted) {
        setState(() {
          _profile = profile;
          _recentPints = pints;
          _weeklyPoints = weeklyPoints;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pints League'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/sessions'),
            tooltip: 'Visit History',
          ),
        ],
      ),
      body: _isLoading
          ? const SkeletonLoading(type: SkeletonType.homeScreen)
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Welcome card
                  _WelcomeCard(
                    username: _profile?['username'] ?? 'User',
                    avatarUrl: _profile?['avatar_url'],
                  ),
                  const SizedBox(height: 16),

                  // Weekly stats card
                  _WeeklyStatsCard(
                    weeklyPoints: _weeklyPoints,
                  ),
                  const SizedBox(height: 16),

                  // Quick actions
                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.sports_bar,
                          label: 'Log Pint',
                          onTap: () => context.push('/log-pint'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.history,
                          label: 'History',
                          onTap: () => context.push('/pint-history'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Recent pints
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Pints',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      TextButton(
                        onPressed: () => context.push('/pint-history'),
                        child: const Text('See all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_recentPints.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.sports_bar_outlined,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No pints logged yet',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the button below to log your first pint!',
                              style: TextStyle(color: Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...(_recentPints.map((pint) => _PintListItem(pint: pint))),
                ],
              ),
            ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final String username;
  final String? avatarUrl;

  const _WelcomeCard({
    required this.username,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final greeting = _getGreeting();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl!) : null,
              child: avatarUrl == null
                  ? Text(
                      username[0].toUpperCase(),
                      style: const TextStyle(fontSize: 24),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  Text(
                    username,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}

class _WeeklyStatsCard extends StatelessWidget {
  final Map<String, dynamic>? weeklyPoints;

  const _WeeklyStatsCard({this.weeklyPoints});

  @override
  Widget build(BuildContext context) {
    final total = weeklyPoints?['total_points'] ?? 0;
    final breakdown =
        weeklyPoints?['breakdown'] as Map<String, dynamic>? ?? {};

    // Calculate pints from base points (10 pts per pint)
    final basePoints = breakdown['base'] ?? 0;
    final pintsCount = basePoints ~/ 10;
    
    // Calculate unique pubs from bonus (5 pts per new pub)
    final uniquePubPoints = breakdown['unique_pubs'] ?? 0;
    final uniquePubsCount = uniquePubPoints ~/ 5;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'This Week',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '$total pts',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Pints',
                  value: '$pintsCount',
                  icon: Icons.sports_bar,
                ),
                _StatItem(
                  label: 'New Pubs',
                  value: '$uniquePubsCount',
                  icon: Icons.explore,
                ),
                _StatItem(
                  label: 'Streak',
                  value: _getStreakEmoji(breakdown['streak'] ?? 0),
                  icon: Icons.local_fire_department,
                ),
              ],
            ),
            
            // Show breakdown if user has points
            if (total > 0) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _BreakdownRow(
                items: [
                  if (basePoints > 0) ('Pints', basePoints as int),
                  if (uniquePubPoints > 0) ('New pubs', uniquePubPoints as int),
                  if ((breakdown['social'] ?? 0) > 0) ('Social', (breakdown['social'] as num).toInt()),
                  if ((breakdown['streak'] ?? 0) > 0) ('Streak', (breakdown['streak'] as num).toInt()),
                  if ((breakdown['verification'] ?? 0) > 0) ('Verified', (breakdown['verification'] as num).toInt()),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getStreakEmoji(int streakPoints) {
    if (streakPoints >= 25) return '🔥7+';
    if (streakPoints >= 10) return '🔥3+';
    return '—';
  }
}

class _BreakdownRow extends StatelessWidget {
  final List<(String, int)> items;

  const _BreakdownRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${item.$1}: +${item.$2}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PintListItem extends StatelessWidget {
  final Map<String, dynamic> pint;

  const _PintListItem({required this.pint});

  @override
  Widget build(BuildContext context) {
    final pubName = pint['pub_name'] ?? 'Unknown Pub';
    final quantity = pint['quantity'] ?? 1;
    final loggedAt = DateTime.parse(pint['logged_at']);
    final source = pint['source'] ?? 'manual';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: Icon(
            Icons.sports_bar,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(pubName),
        subtitle: Text(_formatDate(loggedAt)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (source != 'manual')
              Icon(
                source == 'geo_auto' ? Icons.gps_fixed : Icons.account_balance,
                size: 16,
                color: Colors.grey,
              ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$quantity 🍺',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

