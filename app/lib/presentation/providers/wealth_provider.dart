import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../data/models/wealth_summary.dart';
import '../../data/repositories/wealth_repository.dart';
import 'core_providers.dart';
import 'profile_provider.dart';

/// Provider for the wealth repository.
final wealthRepositoryProvider = Provider<WealthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return WealthRepository(apiClient);
});

/// Provider for the current wealth summary.
final wealthSummaryProvider = FutureProvider<WealthSummary>((ref) async {
  final repository = ref.watch(wealthRepositoryProvider);
  return repository.getSummary();
});

/// Provider for chart range setting.
final chartRangeProvider = NotifierProvider<ChartRangeNotifier, int>(ChartRangeNotifier.new);

class ChartRangeNotifier extends Notifier<int> {
  @override
  int build() {
    final profile = ref.watch(profileProvider);
    return profile.whenOrNull(data: (p) => p?.defaultChartRange) ?? AppConfig.defaultChartRange;
  }

  void set(int value) {
    final granularity = ref.read(chartGranularityProvider.notifier);
    if (value <= 30) {
      // Force daily for short ranges; remember previous granularity
      granularity.forceDaily();
    } else {
      // Restore previous granularity when leaving short range
      granularity.restorePrevious();
    }
    state = value;
  }
}

/// Provider for chart granularity setting.
final chartGranularityProvider = NotifierProvider<ChartGranularityNotifier, String>(ChartGranularityNotifier.new);

class ChartGranularityNotifier extends Notifier<String> {
  String? _savedGranularity;
  bool _forced = false;

  @override
  String build() {
    final profile = ref.watch(profileProvider);
    return profile.whenOrNull(data: (p) => p?.defaultChartGranularity) ?? AppConfig.defaultChartGranularity;
  }

  void set(String value) {
    _forced = false;
    _savedGranularity = null;
    state = value;
  }

  /// Force daily granularity (e.g. for 30d range). Saves previous value.
  void forceDaily() {
    if (!_forced && state != 'daily') {
      _savedGranularity = state;
    }
    _forced = true;
    state = 'daily';
  }

  /// Restore the granularity saved before forceDaily was called.
  void restorePrevious() {
    if (_forced && _savedGranularity != null) {
      state = _savedGranularity!;
      _savedGranularity = null;
    }
    _forced = false;
  }

  bool get isForced => _forced;
}

/// Provider for wealth history based on current chart settings.
final wealthHistoryProvider =
    FutureProvider<List<WealthHistoryPoint>>((ref) async {
  final repository = ref.watch(wealthRepositoryProvider);
  final days = ref.watch(chartRangeProvider);
  final granularity = ref.watch(chartGranularityProvider);

  return repository.getHistory(days: days, granularity: granularity);
});
