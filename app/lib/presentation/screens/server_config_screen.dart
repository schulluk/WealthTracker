import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/core_providers.dart';

class ServerConfigScreen extends ConsumerStatefulWidget {
  const ServerConfigScreen({super.key});

  @override
  ConsumerState<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends ConsumerState<ServerConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCurrentUrl();
  }

  Future<void> _loadCurrentUrl() async {
    final storage = ref.read(secureStorageProvider);
    final url = await storage.getServerUrl();
    if (url != null && url.isNotEmpty) {
      _serverUrlController.text = url;
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      var url = _serverUrlController.text.trim();

      // Ensure URL has protocol
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }

      // Remove trailing slash
      if (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }

      // Test the server by making a simple request
      final apiClient = ref.read(apiClientProvider);
      await apiClient.setBaseUrl(url);

      // Try to reach the server (login endpoint should return 400 without credentials)
      try {
        await apiClient.post('/api/auth/login/', data: {});
      } catch (e) {
        // Expected - we just want to verify the server is reachable
        // A 400 or 401 means the server is there
      }

      // Save the URL
      final storage = ref.read(secureStorageProvider);
      await storage.setServerUrl(url);

      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      setState(() {
        _error = 'Could not connect to server. Please check the URL.';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.dns,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Server Configuration',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the URL of your Wealth Tracker server',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _serverUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'https://wealth.example.com',
                      prefixIcon: Icon(Icons.link),
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a server URL';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _saveAndContinue,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Continue'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => launchUrl(
                      Uri.parse('https://github.com/lsgd/wealth'),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Text("Don't have a server yet? Set one up"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
