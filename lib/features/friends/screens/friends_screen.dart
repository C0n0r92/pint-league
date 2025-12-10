import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/services/contacts_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _suggestedFriends = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final friends = await SupabaseService.getFriends(userId);

      // Load pending requests
      final pending = await Supabase.instance.client
          .from('friendships')
          .select('*, profiles!friendships_user_id_fkey(*)')
          .eq('friend_id', userId)
          .eq('status', 'pending');

      if (mounted) {
        setState(() {
          _friends = friends;
          _pendingRequests = List<Map<String, dynamic>>.from(pending);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _findContactFriends() async {
    final contactsService = ContactsService(Supabase.instance.client);
    
    try {
      final suggested = await contactsService.findFriendsFromContacts();
      if (mounted) {
        setState(() => _suggestedFriends = suggested);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to search contacts: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showAddFriendDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Friends',
              icon: Badge(
                label: Text('${_friends.length}'),
                isLabelVisible: _friends.isNotEmpty,
                child: const Icon(Icons.people),
              ),
            ),
            Tab(
              text: 'Requests',
              icon: Badge(
                label: Text('${_pendingRequests.length}'),
                isLabelVisible: _pendingRequests.isNotEmpty,
                child: const Icon(Icons.person_add),
              ),
            ),
            const Tab(text: 'Find', icon: Icon(Icons.search)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _FriendsTab(friends: _friends, onRefresh: _loadData),
                _RequestsTab(
                  requests: _pendingRequests,
                  onAccept: _acceptRequest,
                  onDecline: _declineRequest,
                ),
                _FindFriendsTab(
                  suggestedFriends: _suggestedFriends,
                  onFindContacts: _findContactFriends,
                  onSendRequest: _sendFriendRequest,
                ),
              ],
            ),
    );
  }

  void _showAddFriendDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Friend'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Username',
            hintText: 'Enter their username',
            prefixIcon: Icon(Icons.alternate_email),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final username = controller.text.trim();
              if (username.isEmpty) return;

              Navigator.pop(context);
              await _sendFriendRequestByUsername(username);
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendFriendRequestByUsername(String username) async {
    try {
      final user = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('username', username)
          .maybeSingle();

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not found')),
          );
        }
        return;
      }

      await _sendFriendRequest(user['id']);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _sendFriendRequest(String toUserId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await SupabaseService.sendFriendRequest(
        fromUserId: userId,
        toUserId: toUserId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
    }
  }

  Future<void> _acceptRequest(String friendshipId) async {
    try {
      await SupabaseService.acceptFriendRequest(friendshipId);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request accepted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _declineRequest(String friendshipId) async {
    try {
      await Supabase.instance.client
          .from('friendships')
          .delete()
          .eq('id', friendshipId);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _FriendsTab extends StatelessWidget {
  final List<Map<String, dynamic>> friends;
  final VoidCallback onRefresh;

  const _FriendsTab({required this.friends, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No friends yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Add friends to see their activity and compete together!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: friends.length,
        itemBuilder: (context, index) {
          final friendship = friends[index];
          final friend = friendship['friend'] as Map<String, dynamic>?;

          if (friend == null) return const SizedBox();

          return _FriendCard(friend: friend);
        },
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  final Map<String, dynamic> friend;

  const _FriendCard({required this.friend});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: friend['avatar_url'] != null
              ? NetworkImage(friend['avatar_url'])
              : null,
          child: friend['avatar_url'] == null
              ? Text((friend['username'] as String? ?? 'U')[0].toUpperCase())
              : null,
        ),
        title: Text(friend['display_name'] ?? friend['username'] ?? 'Unknown'),
        subtitle: Text('@${friend['username'] ?? 'unknown'}'),
        trailing: Text(
          '${friend['total_pints'] ?? 0} 🍺',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _RequestsTab extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final Function(String) onAccept;
  final Function(String) onDecline;

  const _RequestsTab({
    required this.requests,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No pending requests',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        final profile = request['profiles'] as Map<String, dynamic>?;

        if (profile == null) return const SizedBox();

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage: profile['avatar_url'] != null
                      ? NetworkImage(profile['avatar_url'])
                      : null,
                  child: profile['avatar_url'] == null
                      ? Text((profile['username'] as String? ?? 'U')[0]
                          .toUpperCase())
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile['display_name'] ?? profile['username'],
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '@${profile['username']}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => onDecline(request['id']),
                ),
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () => onAccept(request['id']),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FindFriendsTab extends StatelessWidget {
  final List<Map<String, dynamic>> suggestedFriends;
  final VoidCallback onFindContacts;
  final Function(String) onSendRequest;

  const _FindFriendsTab({
    required this.suggestedFriends,
    required this.onFindContacts,
    required this.onSendRequest,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.contacts)),
            title: const Text('Find friends from contacts'),
            subtitle: const Text('See who from your contacts is on Pints League'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onFindContacts,
          ),
        ),
        if (suggestedFriends.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Suggested Friends',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...suggestedFriends.map((friend) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: friend['avatar_url'] != null
                        ? NetworkImage(friend['avatar_url'])
                        : null,
                    child: friend['avatar_url'] == null
                        ? Text((friend['username'] as String? ?? 'U')[0]
                            .toUpperCase())
                        : null,
                  ),
                  title: Text(
                      friend['display_name'] ?? friend['username'] ?? 'Unknown'),
                  subtitle: Text('@${friend['username'] ?? 'unknown'}'),
                  trailing: ElevatedButton(
                    onPressed: () => onSendRequest(friend['user_id']),
                    child: const Text('Add'),
                  ),
                ),
              )),
        ],
      ],
    );
  }
}
