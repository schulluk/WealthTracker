import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/profile.dart';
import '../../services/notification_service.dart';
import '../providers/auth_provider.dart';
import '../providers/core_providers.dart';
import '../providers/profile_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/wealth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String? _serverUrl;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final storage = ref.read(secureStorageProvider);
    final biometricService = ref.read(biometricServiceProvider);

    final available = await biometricService.isAvailable();
    final enabled = await storage.isBiometricEnabled();
    final serverUrl = await storage.getServerUrl();

    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = enabled;
      _serverUrl = serverUrl;
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authStateProvider.notifier).logout();
      if (mounted) context.go('/login');
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    final storage = ref.read(secureStorageProvider);

    if (value) {
      // Verify biometric works before enabling
      final biometricService = ref.read(biometricServiceProvider);
      final authenticated = await biometricService.authenticate(
        reason: 'Verify your identity to enable biometric login',
      );
      if (!authenticated) return;
    }

    await storage.setBiometricEnabled(value);
    setState(() {
      _biometricEnabled = value;
    });
  }

  Future<void> _openWebsite(String path) async {
    final storage = ref.read(secureStorageProvider);
    final serverUrl = await storage.getServerUrl();
    if (serverUrl == null) return;

    final url = Uri.parse('$serverUrl$path');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _updateChartSettings(int? range, String? granularity) async {
    try {
      final repository = ref.read(profileRepositoryProvider);
      await repository.updateProfile(
        defaultChartRange: range,
        defaultChartGranularity: granularity,
      );

      // Update local state
      if (range != null) {
        ref.read(chartRangeProvider.notifier).set(range);
      }
      if (granularity != null) {
        ref.read(chartGranularityProvider.notifier).set(granularity);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final chartRange = ref.watch(chartRangeProvider);
    final chartGranularity = ref.watch(chartGranularityProvider);
    final themeMode = ref.watch(themeModeProvider);
    final dateFormat = ref.watch(dateFormatProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Chart Settings Section
          _SectionHeader(title: 'Chart Settings'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Default Time Range',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _ChartRangeChip(
                      label: '30d',
                      value: 30,
                      selected: chartRange == 30,
                      onTap: () => _updateChartSettings(30, null),
                    ),
                    _ChartRangeChip(
                      label: '90d',
                      value: 90,
                      selected: chartRange == 90,
                      onTap: () => _updateChartSettings(90, null),
                    ),
                    _ChartRangeChip(
                      label: '6m',
                      value: 180,
                      selected: chartRange == 180,
                      onTap: () => _updateChartSettings(180, null),
                    ),
                    _ChartRangeChip(
                      label: '1y',
                      value: 365,
                      selected: chartRange == 365,
                      onTap: () => _updateChartSettings(365, null),
                    ),
                    _ChartRangeChip(
                      label: '2y',
                      value: 730,
                      selected: chartRange == 730,
                      onTap: () => _updateChartSettings(730, null),
                    ),
                    _ChartRangeChip(
                      label: 'All',
                      value: 3650,
                      selected: chartRange == 3650,
                      onTap: () => _updateChartSettings(3650, null),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Default Granularity',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Daily'),
                      selected: chartGranularity == 'daily',
                      onSelected: (_) => _updateChartSettings(null, 'daily'),
                      showCheckmark: false,
                    ),
                    FilterChip(
                      label: const Text('Monthly'),
                      selected: chartGranularity == 'monthly',
                      onSelected: (_) => _updateChartSettings(null, 'monthly'),
                      showCheckmark: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Appearance Section
          _SectionHeader(title: 'Appearance'),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Theme'),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('Auto'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (selected) {
                ref.read(themeModeProvider.notifier).setThemeMode(selected.first);
              },
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Date Format'),
            trailing: DropdownButton<String>(
              value: dateFormat,
              underline: const SizedBox.shrink(),
              onChanged: (value) {
                if (value != null) {
                  ref.read(dateFormatProvider.notifier).setDateFormat(value);
                }
              },
              items: const [
                DropdownMenuItem(
                  value: 'system',
                  child: Text('System'),
                ),
                DropdownMenuItem(
                  value: 'dmy',
                  child: Text('DD.MM.YYYY'),
                ),
                DropdownMenuItem(
                  value: 'mdy',
                  child: Text('MM/DD/YYYY'),
                ),
                DropdownMenuItem(
                  value: 'ymd',
                  child: Text('YYYY-MM-DD'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Security Section
          if (_biometricAvailable) ...[
            _SectionHeader(title: 'Security'),
            SwitchListTile(
              title: const Text('Biometric Login'),
              subtitle: const Text('Use Face ID or Touch ID to unlock'),
              value: _biometricEnabled,
              onChanged: _toggleBiometric,
            ),
            const SizedBox(height: 24),
          ],

          // Sync Settings Section
          _SectionHeader(title: 'Sync Settings'),
          profile.when(
            data: (p) {
              if (p == null) return const SizedBox.shrink();
              return _SyncSettingsSection(profile: p);
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),

          // Account Management Section
          _SectionHeader(title: 'Account Management'),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: const Text('Manage Accounts'),
            subtitle: const Text('Add, edit, or remove accounts'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _openWebsite('/'),
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Change Password'),
            subtitle: const Text('Update your password on the web'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _openWebsite('/settings'),
          ),
          const SizedBox(height: 24),

          // Profile Info
          profile.when(
            data: (p) {
              if (p == null) return const SizedBox.shrink();
              return Column(
                children: [
                  _SectionHeader(title: 'Profile'),
                  ListTile(
                    leading: const Icon(Icons.currency_exchange),
                    title: const Text('Base Currency'),
                    trailing: Text(
                      p.baseCurrency,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),

          // Connection Info
          _SectionHeader(title: 'Connection'),
          ListTile(
            leading: const Icon(Icons.dns),
            title: const Text('Server'),
            subtitle: Text(
              _serverUrl ?? 'Not connected',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 24),

          // About Section
          _SectionHeader(title: 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Imprint & Legal'),
            subtitle: const Text('Developer info, source code, donations'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/imprint'),
          ),
          const SizedBox(height: 24),

          // Logout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.tonal(
              onPressed: _logout,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout),
                  SizedBox(width: 8),
                  Text('Logout'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ChartRangeChip extends StatelessWidget {
  final String label;
  final int value;
  final bool selected;
  final VoidCallback onTap;

  const _ChartRangeChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
    );
  }
}

class _SyncSettingsSection extends ConsumerStatefulWidget {
  final Profile profile;

  const _SyncSettingsSection({required this.profile});

  @override
  ConsumerState<_SyncSettingsSection> createState() =>
      _SyncSettingsSectionState();
}

class _SyncSettingsSectionState extends ConsumerState<_SyncSettingsSection> {
  late bool _syncOnAppOpen;
  bool _syncReminderEnabled = false;
  int _syncReminderHour = 9;
  int _syncReminderMinute = 0;

  @override
  void initState() {
    super.initState();
    _syncOnAppOpen = widget.profile.syncOnAppOpen;
    _loadLocalReminderSettings();
  }

  Future<void> _loadLocalReminderSettings() async {
    final notificationService = ref.read(notificationServiceProvider);
    final enabled = await notificationService.isSyncReminderEnabled();
    final hour = await notificationService.getSyncReminderHour();
    final minute = await notificationService.getSyncReminderMinute();
    if (mounted) {
      setState(() {
        _syncReminderEnabled = enabled;
        _syncReminderHour = hour;
        _syncReminderMinute = minute;
      });
    }
  }

  @override
  void didUpdateWidget(covariant _SyncSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      setState(() {
        _syncOnAppOpen = widget.profile.syncOnAppOpen;
      });
    }
  }

  Future<void> _updateSyncOnAppOpen(bool value) async {
    setState(() => _syncOnAppOpen = value);
    try {
      await ref.read(syncSettingsProvider).updateSyncOnAppOpen(value);
    } catch (e) {
      setState(() => _syncOnAppOpen = !value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  Future<void> _updateSyncReminder(bool enabled) async {
    if (enabled) {
      // When enabling, request notification permissions first
      final notificationService = ref.read(notificationServiceProvider);
      final result = await notificationService.requestPermissions();

      switch (result) {
        case NotificationPermissionResult.granted:
          // Permission granted, proceed with enabling
          break;
        case NotificationPermissionResult.denied:
          // Permission denied, don't enable
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notification permission required for reminders'),
              ),
            );
          }
          return;
        case NotificationPermissionResult.permanentlyDenied:
          // Permission permanently denied, show dialog
          if (mounted) {
            await _showPermissionDeniedDialog();
          }
          return;
      }
    }

    setState(() => _syncReminderEnabled = enabled);
    try {
      await ref.read(syncSettingsProvider).updateSyncReminder(
            enabled: enabled,
          );
    } catch (e) {
      setState(() => _syncReminderEnabled = !enabled);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  Future<void> _showPermissionDeniedDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications Disabled'),
        content: const Text(
          'You have previously denied notification permissions. '
          'To enable sync reminders, please allow notifications for Wealth Tracker '
          'in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              AppSettings.openAppSettings(type: AppSettingsType.notification);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectReminderTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _syncReminderHour,
        minute: _syncReminderMinute,
      ),
    );

    if (time == null) return;

    setState(() {
      _syncReminderHour = time.hour;
      _syncReminderMinute = time.minute;
    });

    try {
      await ref.read(syncSettingsProvider).updateSyncReminder(
            hour: time.hour,
            minute: time.minute,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  String _formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncAllProvider);

    return Column(
      children: [
        SwitchListTile(
          title: const Text('Sync when opening app'),
          subtitle: const Text(
            'Automatically sync all accounts when you open the app (max once per 20h)',
          ),
          value: _syncOnAppOpen,
          onChanged: _updateSyncOnAppOpen,
        ),
        SwitchListTile(
          title: const Text('Daily sync reminder'),
          subtitle: Text(
            _syncReminderEnabled
                ? 'Remind me at ${_formatTime(_syncReminderHour, _syncReminderMinute)}'
                : 'Disabled',
          ),
          value: _syncReminderEnabled,
          onChanged: _updateSyncReminder,
        ),
        if (_syncReminderEnabled)
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Reminder time'),
            trailing: TextButton(
              onPressed: _selectReminderTime,
              child: Text(_formatTime(_syncReminderHour, _syncReminderMinute)),
            ),
          ),
        if (syncState.lastSyncTime != null)
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Last sync'),
            subtitle: Text(_formatLastSync(syncState.lastSyncTime!)),
          ),
      ],
    );
  }

  String _formatLastSync(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} minutes ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else {
      return '${diff.inDays} days ago';
    }
  }
}
