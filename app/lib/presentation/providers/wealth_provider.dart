import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return profile.whenOrNull(data: (p) => p?.defaultChartRange) ?? 365;
  }

  void set(int value) => state = value;
}

/// Provider for chart granularity setting.
final chartGranularityProvider = NotifierProvider<ChartGranularityNotifier, String>(ChartGranularityNotifier.new);

class ChartGranularityNotifier extends Notifier<String> {
  @override
  String build() {
    final profile = ref.watch(profileProvider);
    return profile.whenOrNull(data: (p) => p?.defaultChartGranularity) ?? 'daily';
  }

  void set(String value) => state = value;
}

/// Provider for wealth history based on current chart settings.
final wealthHistoryProvider =
    FutureProvider<List<WealthHistoryPoint>>((ref) async {
  final repository = ref.watch(wealthRepositoryProvider);
  final days = ref.watch(chartRangeProvider);
  final granularity = ref.watch(chartGranularityProvider);

  return repository.getHistory(days: days, granularity: granularity);
});
