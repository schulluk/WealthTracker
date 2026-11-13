import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ImprintScreen extends StatelessWidget {
  const ImprintScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Imprint'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Developer Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Developer',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lukas Schulze',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Source Code
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Open Source',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This project is open source and licensed under the MIT License.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.code),
                    title: const Text('Source Code'),
                    subtitle: const Text('github.com/schulluk/WealthTracker'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () =>
                        _launchUrl('https://github.com/schulluk/WealthTracker'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.bug_report),
                    title: const Text('Report Issues'),
                    subtitle: const Text('Found a bug? Let us know!'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => _launchUrl(
                        'https://github.com/schulluk/WealthTracker/issues'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Support
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Support the Project',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'If you find this app useful, consider supporting its development.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () =>
                          _launchUrl('https://paypal.me/lukasschulze'),
                      icon: const Icon(Icons.favorite),
                      label: const Text('Donate via PayPal'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Footer
          Center(
            child: Text(
              'Made with love for personal finance tracking',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
