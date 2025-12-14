import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ConnectBankScreen extends StatefulWidget {
  const ConnectBankScreen({super.key});

  @override
  State<ConnectBankScreen> createState() => _ConnectBankScreenState();
}

class _ConnectBankScreenState extends State<ConnectBankScreen> {
  bool _isLoading = false;
  String? _error;

  final List<_BankInfo> _supportedBanks = [
    _BankInfo('Revolut', 'assets/images/banks/revolut.png', true),
    _BankInfo('AIB', 'assets/images/banks/aib.png', true),
    _BankInfo('Bank of Ireland', 'assets/images/banks/boi.png', true),
    _BankInfo('Ulster Bank', 'assets/images/banks/ulster.png', true),
    _BankInfo('Permanent TSB', 'assets/images/banks/ptsb.png', true),
    _BankInfo('N26', 'assets/images/banks/n26.png', true),
    _BankInfo('Monzo', 'assets/images/banks/monzo.png', true),
    _BankInfo('Starling', 'assets/images/banks/starling.png', true),
  ];

  Future<void> _connectBank() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Call Edge Function to get TrueLayer auth URL (GET request)
      final response = await Supabase.instance.client.functions.invoke(
        'truelayer-auth',
        method: HttpMethod.get,
      );

      if (response.status != 200) {
        throw Exception('Failed to get authorization URL: ${response.data}');
      }

      final authUrl = response.data['auth_url'] as String?;
      
      if (authUrl == null || authUrl.isEmpty) {
        throw Exception('TrueLayer is not configured yet.');
      }

      // Open bank auth in browser
      final uri = Uri.parse(authUrl);
      final launched = await launchUrl(
        uri, 
        mode: LaunchMode.externalApplication,
      );
      
      if (launched && mounted) {
        _showWaitingDialog();
      } else {
        throw Exception('Could not open browser.');
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _showWaitingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.open_in_browser),
            SizedBox(width: 12),
            Text('Complete in Browser'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A browser window has opened for you to securely connect your bank.'),
            SizedBox(height: 16),
            Text('After connecting, you\'ll be redirected back to the app.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isLoading = false);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/');
            },
            child: const Text('I\'ve Connected'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Bank'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero section
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance,
                    size: 50,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              Center(
                child: Text(
                  'Auto-Track Your Pints',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              
              Center(
                child: Text(
                  'Connect your bank to automatically log pints when you pay at pubs.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              // Benefits
              _BenefitItem(
                icon: Icons.auto_awesome,
                title: 'Automatic Tracking',
                description: 'No need to manually log - we detect pub purchases automatically',
              ),
              const SizedBox(height: 16),
              _BenefitItem(
                icon: Icons.verified,
                title: 'Bonus Points',
                description: 'Earn +5 bonus points for verified transactions',
              ),
              const SizedBox(height: 16),
              _BenefitItem(
                icon: Icons.history,
                title: 'Never Miss a Pint',
                description: 'Forgot to log? No worries, we\'ll catch it',
              ),
              const SizedBox(height: 32),

              // Supported banks
              Text(
                'Supported Banks',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: _supportedBanks.map((bank) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      bank.name,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                '+ 50 more Irish & UK banks',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 32),

              // Error message
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Connect button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _connectBank,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.link),
                            SizedBox(width: 12),
                            Text(
                              'Connect Your Bank',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Security info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock_outline, color: Colors.grey.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Bank-Grade Security',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SecurityPoint(text: 'Read-only access - we can never move money'),
                    const SizedBox(height: 8),
                    _SecurityPoint(text: 'Powered by TrueLayer (FCA regulated)'),
                    const SizedBox(height: 8),
                    _SecurityPoint(text: 'Only pub transactions are analyzed'),
                    const SizedBox(height: 8),
                    _SecurityPoint(text: 'Disconnect anytime in Settings'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Skip button
              Center(
                child: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Maybe Later'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BankInfo {
  final String name;
  final String logo;
  final bool isPopular;

  _BankInfo(this.name, this.logo, this.isPopular);
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SecurityPoint extends StatelessWidget {
  final String text;

  const _SecurityPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

