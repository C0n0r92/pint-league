import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

class LogPintScreen extends StatefulWidget {
  const LogPintScreen({super.key});

  @override
  State<LogPintScreen> createState() => _LogPintScreenState();
}

class _LogPintScreenState extends State<LogPintScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _nearbyPubs = [];
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedPub;
  int _quantity = 1;
  String _drinkType = 'pint';
  bool _isLoadingNearby = false;
  bool _isSearching = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadNearbyPubs();
  }

  Future<void> _loadNearbyPubs() async {
    setState(() => _isLoadingNearby = true);

    try {
      final position = await Geolocator.getCurrentPosition();
      final pubs = await SupabaseService.getNearbyPubs(
        lat: position.latitude,
        lng: position.longitude,
        radiusM: 500,
      );

      if (mounted) {
        setState(() {
          _nearbyPubs = pubs;
          _isLoadingNearby = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingNearby = false);
      }
    }
  }

  Future<void> _searchPubs(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await SupabaseService.searchPubs(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _submitPint() async {
    if (_selectedPub == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pub')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await SupabaseService.logPint(
        userId: userId,
        pubId: _selectedPub!['id'],
        pubName: _selectedPub!['name'],
        drinkType: _drinkType,
        quantity: _quantity,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Logged $_quantity $_drinkType${_quantity > 1 ? 's' : ''} at ${_selectedPub!['name']}',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log pint: $e')),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Pint'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search for a pub...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            onChanged: _searchPubs,
          ),
          const SizedBox(height: 16),

          // Search results
          if (_searchResults.isNotEmpty) ...[
            Text(
              'Search Results',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._searchResults.map((pub) => _PubListItem(
                  pub: pub,
                  isSelected: _selectedPub?['id'] == pub['id'],
                  onTap: () => setState(() {
                    _selectedPub = pub;
                    _searchController.clear();
                    _searchResults = [];
                  }),
                )),
            const SizedBox(height: 16),
          ],

          // Nearby pubs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nearby Pubs',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadNearbyPubs,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoadingNearby)
            const Center(child: CircularProgressIndicator())
          else if (_nearbyPubs.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.location_off,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No pubs nearby',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try searching for a pub by name',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._nearbyPubs.take(5).map((pub) => _PubListItem(
                  pub: pub,
                  isSelected: _selectedPub?['id'] == pub['id'],
                  onTap: () => setState(() => _selectedPub = pub),
                )),

          const SizedBox(height: 24),

          // Selected pub
          if (_selectedPub != null) ...[
            Card(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedPub!['name'],
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _selectedPub = null),
                        ),
                      ],
                    ),
                    if (_selectedPub!['address'] != null)
                      Text(
                        _selectedPub!['address'],
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Drink type
            Text(
              'What are you having?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _DrinkTypeChip(
                  label: '🍺 Pint',
                  isSelected: _drinkType == 'pint',
                  onTap: () => setState(() => _drinkType = 'pint'),
                ),
                _DrinkTypeChip(
                  label: '🥃 Whiskey',
                  isSelected: _drinkType == 'whiskey',
                  onTap: () => setState(() => _drinkType = 'whiskey'),
                ),
                _DrinkTypeChip(
                  label: '🍷 Wine',
                  isSelected: _drinkType == 'wine',
                  onTap: () => setState(() => _drinkType = 'wine'),
                ),
                _DrinkTypeChip(
                  label: '🍹 Cocktail',
                  isSelected: _drinkType == 'cocktail',
                  onTap: () => setState(() => _drinkType = 'cocktail'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quantity
            Text(
              'How many?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filled(
                  onPressed: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    '$_quantity',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton.filled(
                  onPressed: _quantity < 12
                      ? () => setState(() => _quantity++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar: _selectedPub != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitPint,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Log $_quantity ${_drinkType}${_quantity > 1 ? 's' : ''}'),
                ),
              ),
            )
          : null,
    );
  }
}

class _PubListItem extends StatelessWidget {
  final Map<String, dynamic> pub;
  final bool isSelected;
  final VoidCallback onTap;

  const _PubListItem({
    required this.pub,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected
          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
          : null,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: Icon(
            Icons.local_bar,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(pub['name'] ?? 'Unknown Pub'),
        subtitle: Text(
          pub['address'] ?? pub['city'] ?? 'No address',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isSelected
            ? Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              )
            : null,
      ),
    );
  }
}

class _DrinkTypeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DrinkTypeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
    );
  }
}

