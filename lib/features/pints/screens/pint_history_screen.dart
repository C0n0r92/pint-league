import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/services/supabase_service.dart';

class PintHistoryScreen extends StatefulWidget {
  const PintHistoryScreen({super.key});

  @override
  State<PintHistoryScreen> createState() => _PintHistoryScreenState();
}

class _PintHistoryScreenState extends State<PintHistoryScreen> {
  List<Map<String, dynamic>> _pints = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _offset = 0;
  static const int _limit = 20;

  @override
  void initState() {
    super.initState();
    _loadPints();
  }

  Future<void> _loadPints({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _offset = 0;
        _isLoading = true;
      });
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final pints = await SupabaseService.getPints(
        userId: userId,
        limit: _limit,
        offset: refresh ? 0 : _offset,
      );

      if (mounted) {
        setState(() {
          if (refresh) {
            _pints = pints;
          } else {
            _pints.addAll(pints);
          }
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
      _offset += _limit;
    });

    await _loadPints();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pint History'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pints.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sports_bar_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No pints logged yet',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your pint history will appear here',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadPints(refresh: true),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pints.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _pints.length) {
                        return _isLoadingMore
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : TextButton(
                                onPressed: _loadMore,
                                child: const Text('Load more'),
                              );
                      }

                      final pint = _pints[index];
                      final showDateHeader = index == 0 ||
                          _getDateKey(_pints[index - 1]['logged_at']) !=
                              _getDateKey(pint['logged_at']);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showDateHeader) ...[
                            if (index > 0) const SizedBox(height: 16),
                            Text(
                              _formatDateHeader(pint['logged_at']),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 8),
                          ],
                          _PintCard(pint: pint),
                        ],
                      );
                    },
                  ),
                ),
    );
  }

  String _getDateKey(String dateStr) {
    final date = DateTime.parse(dateStr);
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatDateHeader(String dateStr) {
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }
}

class _PintCard extends StatelessWidget {
  final Map<String, dynamic> pint;

  const _PintCard({required this.pint});

  @override
  Widget build(BuildContext context) {
    final pubName = pint['pub_name'] ?? 'Unknown Pub';
    final quantity = pint['quantity'] ?? 1;
    final drinkType = pint['drink_type'] ?? 'pint';
    final source = pint['source'] ?? 'manual';
    final loggedAt = DateTime.parse(pint['logged_at']);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _getDrinkEmoji(drinkType),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pubName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        DateFormat('HH:mm').format(loggedAt),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 8),
                      _SourceBadge(source: source),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '$quantity × ${_getDrinkLabel(drinkType)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDrinkEmoji(String drinkType) {
    switch (drinkType) {
      case 'pint':
        return '🍺';
      case 'whiskey':
        return '🥃';
      case 'wine':
        return '🍷';
      case 'cocktail':
        return '🍹';
      default:
        return '🍺';
    }
  }

  String _getDrinkLabel(String drinkType) {
    switch (drinkType) {
      case 'pint':
        return 'Pint';
      case 'whiskey':
        return 'Whiskey';
      case 'wine':
        return 'Wine';
      case 'cocktail':
        return 'Cocktail';
      default:
        return drinkType;
    }
  }
}

class _SourceBadge extends StatelessWidget {
  final String source;

  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String label;
    Color color;

    switch (source) {
      case 'geo_auto':
        icon = Icons.gps_fixed;
        label = 'GPS';
        color = Colors.green;
        break;
      case 'bank':
        icon = Icons.account_balance;
        label = 'Bank';
        color = Colors.blue;
        break;
      default:
        icon = Icons.edit;
        label = 'Manual';
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}

