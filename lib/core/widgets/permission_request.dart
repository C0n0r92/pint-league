import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// A friendly permission request widget for location access
class LocationPermissionRequest extends StatelessWidget {
  final VoidCallback onGranted;
  final VoidCallback? onSkip;

  const LocationPermissionRequest({
    super.key,
    required this.onGranted,
    this.onSkip,
  });

  Future<void> _requestPermission(BuildContext context) async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enable location services in settings'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => Geolocator.openLocationSettings(),
            ),
          ),
        );
      }
      return;
    }

    // Request permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        _showSettingsDialog(context);
      }
      return;
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      onGranted();
    }
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Location access was permanently denied. Please enable it in your device settings to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.location_on,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sports_bar,
                      size: 24,
                      color: Color(0xFFD4A853),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          Text(
            'Find Nearby Pubs',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 12),
          
          Text(
            'Allow location access to discover pubs near you and automatically track your visits.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Benefits list
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Column(
              children: [
                _BenefitRow(
                  icon: Icons.explore,
                  text: 'Discover pubs within 500m',
                ),
                SizedBox(height: 12),
                _BenefitRow(
                  icon: Icons.auto_awesome,
                  text: 'Auto-detect when you visit a pub',
                ),
                SizedBox(height: 12),
                _BenefitRow(
                  icon: Icons.emoji_events,
                  text: 'Earn points automatically',
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _requestPermission(context),
              icon: const Icon(Icons.location_on),
              label: const Text('Enable Location'),
            ),
          ),
          
          if (onSkip != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onSkip,
              child: const Text('Skip for now'),
            ),
          ],
          
          const SizedBox(height: 16),
          
          Text(
            'Your location is only used to find nearby pubs and is never shared.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: Colors.green),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

/// A permission request for contacts access
class ContactsPermissionRequest extends StatelessWidget {
  final VoidCallback onGranted;
  final VoidCallback? onSkip;

  const ContactsPermissionRequest({
    super.key,
    required this.onGranted,
    this.onSkip,
  });

  Future<void> _requestPermission(BuildContext context) async {
    final status = await Permission.contacts.request();
    
    if (status.isGranted) {
      onGranted();
    } else if (status.isPermanentlyDenied) {
      if (context.mounted) {
        _showSettingsDialog(context);
      }
    }
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contacts Permission Required'),
        content: const Text(
          'Contacts access was denied. Enable it in settings to find friends.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.contacts,
              size: 48,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'Find Your Friends',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 12),
          
          Text(
            'We can check your contacts to find friends who are already on Pints League.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _requestPermission(context),
              icon: const Icon(Icons.people),
              label: const Text('Find Friends'),
            ),
          ),
          
          if (onSkip != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onSkip,
              child: const Text('Skip'),
            ),
          ],
          
          const SizedBox(height: 12),
          
          Text(
            'Phone numbers are hashed for privacy. We never store actual numbers.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

