import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _bankConnection;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      final bankConnection = await Supabase.instance.client
          .from('bank_connections')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _profile = profile;
          _bankConnection = bankConnection;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _connectBank() async {
    try {
      // Get auth URL from Edge Function
      final response = await Supabase.instance.client.functions.invoke(
        'truelayer-auth',
        method: HttpMethod.get,
      );

      final authUrl = response.data['auth_url'] as String?;
      if (authUrl != null) {
        // Open the auth URL in browser
        // The callback will be handled by the app's deep link handler
        // For now, show the URL (in production, use url_launcher)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening bank connection...'),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () {
                  // TODO: Use url_launcher to open authUrl
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect bank: $e')),
        );
      }
    }
  }

  Future<void> _disconnectBank() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Bank?'),
        content: const Text(
          'This will remove your bank connection. You can reconnect at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client
          .from('bank_connections')
          .delete()
          .eq('user_id', userId);

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank disconnected')),
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

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await Supabase.instance.client.auth.signOut();

    if (mounted) {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final username = _profile?['username'] ?? 'User';
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final avatarUrl = _profile?['avatar_url'];
    final hasBankConnection =
        _bankConnection != null && _bankConnection!['status'] == 'active';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Profile section
          Container(
            padding: const EdgeInsets.all(24),
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(
                          username[0].toUpperCase(),
                          style: const TextStyle(fontSize: 28),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profile?['display_name'] ?? username,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '@$username',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      Text(
                        email,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    // TODO: Navigate to edit profile
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _StatCard(
                  label: 'Total Pints',
                  value: '${_profile?['total_pints'] ?? 0}',
                  icon: Icons.sports_bar,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Unique Pubs',
                  value: '${_profile?['unique_pubs_count'] ?? 0}',
                  icon: Icons.location_on,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Points',
                  value: '${_profile?['total_points'] ?? 0}',
                  icon: Icons.star,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Bank connection
          _SettingsSection(
            title: 'Bank Connection',
            children: [
              ListTile(
                leading: Icon(
                  Icons.account_balance,
                  color: hasBankConnection ? Colors.green : Colors.grey,
                ),
                title: Text(
                  hasBankConnection ? 'Bank Connected' : 'Connect Bank',
                ),
                subtitle: Text(
                  hasBankConnection
                      ? 'Automatic pint verification enabled'
                      : 'Verify pub visits with payment data',
                ),
                trailing: hasBankConnection
                    ? TextButton(
                        onPressed: _disconnectBank,
                        child: const Text('Disconnect'),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: hasBankConnection ? null : _connectBank,
              ),
            ],
          ),

          // Preferences
          _SettingsSection(
            title: 'Preferences',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.auto_awesome),
                title: const Text('Auto-confirm high confidence visits'),
                subtitle: const Text(
                  'Automatically log pints for visits with GPS + bank verification',
                ),
                value: _profile?['auto_confirm_high_confidence'] ?? false,
                onChanged: (value) async {
                  final userId = Supabase.instance.client.auth.currentUser?.id;
                  if (userId == null) return;

                  await Supabase.instance.client.from('profiles').update({
                    'auto_confirm_high_confidence': value,
                  }).eq('id', userId);

                  await _loadData();
                },
              ),
            ],
          ),

          // Privacy & Data
          _SettingsSection(
            title: 'Privacy & Data',
            children: [
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Export My Data'),
                subtitle: const Text('Download all your data'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Implement GDPR data export
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon!')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Delete Account'),
                subtitle: const Text('Permanently delete your account and data'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Implement account deletion
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact support to delete account')),
                  );
                },
              ),
            ],
          ),

          // About
          _SettingsSection(
            title: 'About',
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Version'),
                trailing: const Text('1.0.0'),
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Terms of Service'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Sign out
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton(
              onPressed: _signOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              child: const Text('Sign Out'),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: children),
        ),
      ],
    );
  }
}

