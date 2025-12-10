import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

class LeaguesScreen extends StatefulWidget {
  const LeaguesScreen({super.key});

  @override
  State<LeaguesScreen> createState() => _LeaguesScreenState();
}

class _LeaguesScreenState extends State<LeaguesScreen> {
  List<Map<String, dynamic>> _leagues = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeagues();
  }

  Future<void> _loadLeagues() async {
    setState(() => _isLoading = true);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final leagues = await SupabaseService.getUserLeagues(userId);

      if (mounted) {
        setState(() {
          _leagues = leagues;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leagues'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateOrJoinDialog(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _leagues.isEmpty
              ? _EmptyLeagues(
                  onCreateTap: () => context.push('/leagues/create'),
                  onJoinTap: () => context.push('/leagues/join'),
                )
              : RefreshIndicator(
                  onRefresh: _loadLeagues,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _leagues.length,
                    itemBuilder: (context, index) {
                      final membership = _leagues[index];
                      final league =
                          membership['leagues'] as Map<String, dynamic>?;

                      if (league == null) return const SizedBox();

                      return _LeagueCard(
                        league: league,
                        rank: membership['rank'] ?? 0,
                        onTap: () => context.push('/leagues/${league['id']}'),
                      );
                    },
                  ),
                ),
    );
  }

  void _showCreateOrJoinDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Join or Create a League',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.add),
                ),
                title: const Text('Create New League'),
                subtitle: const Text('Start your own league and invite friends'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/leagues/create');
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.group_add),
                ),
                title: const Text('Join with Code'),
                subtitle: const Text('Enter a league code to join'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/leagues/join');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLeagues extends StatelessWidget {
  final VoidCallback onCreateTap;
  final VoidCallback onJoinTap;

  const _EmptyLeagues({
    required this.onCreateTap,
    required this.onJoinTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'No Leagues Yet',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a league and invite friends to compete, or join an existing league with a code.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onCreateTap,
                icon: const Icon(Icons.add),
                label: const Text('Create League'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onJoinTap,
                icon: const Icon(Icons.group_add),
                label: const Text('Join with Code'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeagueCard extends StatelessWidget {
  final Map<String, dynamic> league;
  final int rank;
  final VoidCallback onTap;

  const _LeagueCard({
    required this.league,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = league['name'] ?? 'Unknown League';
    final memberCount = league['member_count'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _getRankColor(rank).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: rank > 0 && rank <= 3
                      ? Text(
                          _getRankEmoji(rank),
                          style: const TextStyle(fontSize: 28),
                        )
                      : Text(
                          '#$rank',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _getRankColor(rank),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$memberCount members',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
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
        return '';
    }
  }
}

