import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/services/supabase_service.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final sessions = await SupabaseService.getSessions(userId: userId);

      if (mounted) {
        setState(() {
          _sessions = sessions;
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
        title: const Text('Visit History'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? _EmptyState()
              : RefreshIndicator(
                  onRefresh: _loadSessions,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      return _SessionCard(
                        session: session,
                        onConfirm: () => _confirmSession(session),
                        onDiscard: () => _discardSession(session),
                      );
                    },
                  ),
                ),
    );
  }

  Future<void> _confirmSession(Map<String, dynamic> session) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Mark session as verified
      await Supabase.instance.client
          .from('sessions')
          .update({'verified': true}).eq('id', session['id']);

      // Create pints
      await Supabase.instance.client.from('pints').insert({
        'user_id': userId,
        'pub_id': session['pub_id'],
        'pub_name': session['pub_name'],
        'session_id': session['id'],
        'quantity': session['estimated_pints'] ?? 1,
        'source': 'geo_auto',
        'logged_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visit confirmed!')),
        );
        _loadSessions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _discardSession(Map<String, dynamic> session) async {
    try {
      await Supabase.instance.client
          .from('sessions')
          .update({'discarded': true}).eq('id', session['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visit discarded')),
        );
        _loadSessions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No visits detected',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'When you visit a pub, we\'ll automatically detect it and show it here for confirmation.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final VoidCallback onConfirm;
  final VoidCallback onDiscard;

  const _SessionCard({
    required this.session,
    required this.onConfirm,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final pubName = session['pub_name'] ?? 'Unknown Pub';
    final startAt = DateTime.parse(session['start_at']);
    final endAt = session['end_at'] != null
        ? DateTime.parse(session['end_at'])
        : null;
    final durationMinutes = session['duration_minutes'] ?? 0;
    final estimatedPints = session['estimated_pints'] ?? 1;
    final source = session['source'] ?? 'geo';
    final confidence = session['confidence'] ?? 'medium';
    final verified = session['verified'] ?? false;
    final discarded = session['discarded'] ?? false;

    final isActive = endAt == null && !discarded;
    final isPending = endAt != null && !verified && !discarded;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isActive
          ? Colors.green.shade50
          : isPending
              ? Colors.orange.shade50
              : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getStatusColor(isActive, isPending, verified, discarded)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getStatusIcon(isActive, isPending, verified, discarded),
                    color: _getStatusColor(isActive, isPending, verified, discarded),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pubName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        DateFormat('EEE, MMM d · HH:mm').format(startAt),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(
                  isActive: isActive,
                  isPending: isPending,
                  verified: verified,
                  discarded: discarded,
                ),
              ],
            ),
            if (!isActive && !discarded) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.timer,
                    label: '$durationMinutes min',
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.sports_bar,
                    label: '$estimatedPints pint${estimatedPints > 1 ? 's' : ''}',
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: _getSourceIcon(source),
                    label: _getConfidenceLabel(confidence),
                  ),
                ],
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDiscard,
                      child: const Text("Wasn't there"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onConfirm,
                      child: Text('Confirm $estimatedPints 🍺'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(bool isActive, bool isPending, bool verified, bool discarded) {
    if (isActive) return Colors.green;
    if (isPending) return Colors.orange;
    if (verified) return Colors.blue;
    if (discarded) return Colors.grey;
    return Colors.grey;
  }

  IconData _getStatusIcon(bool isActive, bool isPending, bool verified, bool discarded) {
    if (isActive) return Icons.location_on;
    if (isPending) return Icons.help_outline;
    if (verified) return Icons.check_circle;
    if (discarded) return Icons.cancel;
    return Icons.location_off;
  }

  IconData _getSourceIcon(String source) {
    switch (source) {
      case 'geo':
        return Icons.gps_fixed;
      case 'bank':
        return Icons.account_balance;
      default:
        return Icons.edit;
    }
  }

  String _getConfidenceLabel(String confidence) {
    switch (confidence) {
      case 'high':
        return 'High confidence';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return confidence;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  final bool isPending;
  final bool verified;
  final bool discarded;

  const _StatusBadge({
    required this.isActive,
    required this.isPending,
    required this.verified,
    required this.discarded,
  });

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;

    if (isActive) {
      label = 'Active';
      color = Colors.green;
    } else if (isPending) {
      label = 'Confirm?';
      color = Colors.orange;
    } else if (verified) {
      label = 'Confirmed';
      color = Colors.blue;
    } else if (discarded) {
      label = 'Discarded';
      color = Colors.grey;
    } else {
      label = 'Unknown';
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
