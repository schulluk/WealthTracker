import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/wealth_summary.dart';
import '../providers/core_providers.dart';
import '../providers/wealth_provider.dart';

class WealthLineChart extends ConsumerStatefulWidget {
  final List<WealthHistoryPoint> history;
  final String currency;
  final bool showGranularitySelector;

  const WealthLineChart({
    super.key,
    required this.history,
    required this.currency,
    this.showGranularitySelector = true,
  });

  @override
  ConsumerState<WealthLineChart> createState() => _WealthLineChartState();
}

class _WealthLineChartState extends ConsumerState<WealthLineChart> {
  int? _markedIndex;
  int? _lastTouchedIndex;

  @override
  Widget build(BuildContext context) {
    final chartRange = ref.watch(chartRangeProvider);
    final chartGranularity = ref.watch(chartGranularityProvider);
    final dateFormat = ref.watch(dateFormatProvider);

    if (widget.history.isEmpty) {
      return Card(
        child: SizedBox(
          height: 250,
          child: Center(
            child: Text(
              'No data available',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    // Downsample to max 150 points for rendering performance
    final history = _downsample(widget.history, 150);

    final spots = history.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.totalWealth,
      );
    }).toList();

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    // Calculate step size for exactly 5 ticks (4 intervals).
    // Step is rounded to a "nice" value: 100, 250, 500, 1k, 2.5k, 5k, 10k, ...
    final range = maxY - minY;
    var stepSize = _niceStep(range / 4);

    var roundedMin = (minY / stepSize).floor() * stepSize;
    var roundedMax = (maxY / stepSize).ceil() * stepSize;
    var intervals = ((roundedMax - roundedMin) / stepSize).round();

    // Bump to next nice step if floor/ceil pushed us over 4 intervals
    while (intervals > 4) {
      stepSize = _nextNiceStep(stepSize);
      roundedMin = (minY / stepSize).floor() * stepSize;
      roundedMax = (maxY / stepSize).ceil() * stepSize;
      intervals = ((roundedMax - roundedMin) / stepSize).round();
    }

    // Extend max to fill exactly 4 intervals
    while (intervals < 4) {
      roundedMax += stepSize;
      intervals++;
    }

    final gridInterval = stepSize;

    // Get the point to display (current touch or marked)
    final displayIndex = _lastTouchedIndex ?? _markedIndex;
    final displayPoint =
        displayIndex != null ? history[displayIndex] : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period selector
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _RangeChip(
                  label: '30d',
                  selected: chartRange == 30,
                  onTap: () =>
                      ref.read(chartRangeProvider.notifier).set(30),
                ),
                _RangeChip(
                  label: '90d',
                  selected: chartRange == 90,
                  onTap: () =>
                      ref.read(chartRangeProvider.notifier).set(90),
                ),
                _RangeChip(
                  label: '6m',
                  selected: chartRange == 180,
                  onTap: () =>
                      ref.read(chartRangeProvider.notifier).set(180),
                ),
                _RangeChip(
                  label: '1y',
                  selected: chartRange == 365,
                  onTap: () =>
                      ref.read(chartRangeProvider.notifier).set(365),
                ),
                _RangeChip(
                  label: '2y',
                  selected: chartRange == 730,
                  onTap: () =>
                      ref.read(chartRangeProvider.notifier).set(730),
                ),
                _RangeChip(
                  label: 'All',
                  selected: chartRange == 3650,
                  onTap: () =>
                      ref.read(chartRangeProvider.notifier).set(3650),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Granularity selector (hidden when forced to daily for short ranges)
            if (widget.showGranularitySelector &&
                !ref.watch(chartGranularityProvider.notifier).isForced)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'daily', label: Text('Daily')),
                  ButtonSegment(value: 'monthly', label: Text('Monthly')),
                ],
                selected: {chartGranularity},
                onSelectionChanged: (selected) {
                  ref.read(chartGranularityProvider.notifier).set(selected.first);
                },
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            const SizedBox(height: 12),
            // Selected point display (fixed position above chart)
            Container(
              height: 40,
              alignment: Alignment.center,
              child: displayPoint != null
                  ? Text(
                      '${formatDate(displayPoint.dateTime, dateFormat)}  •  ${formatCurrency(displayPoint.totalWealth, widget.currency)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    )
                  : Text(
                      'Slide on chart to see values',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
            ),
            const SizedBox(height: 8),
            // Chart
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: gridInterval,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: (spots.length / 4).ceilToDouble(),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= history.length) {
                            return const SizedBox.shrink();
                          }
                          // Skip first and last to avoid edge cutoff
                          if (index == 0 || index == history.length - 1) {
                            return const SizedBox.shrink();
                          }
                          final date = history[index].dateTime;
                          // Use day.month.year format for daily, month+year for monthly
                          final dateFmt = chartGranularity == 'daily'
                              ? DateFormat('d.M.yy')
                              : DateFormat('MMM yy');
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              dateFmt.format(date),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 55,
                        interval: gridInterval,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            formatChartAxisValue(value),
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: roundedMin,
                  maxY: roundedMax,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.2,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        checkToShowDot: (spot, barData) {
                          // Show dot for current touch or marked point
                          return spot.x.toInt() == displayIndex;
                        },
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 6,
                            color: Theme.of(context).colorScheme.primary,
                            strokeWidth: 2,
                            strokeColor: Theme.of(context).colorScheme.surface,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchCallback: (event, response) {
                      final touchedIndex =
                          response?.lineBarSpots?.firstOrNull?.x.toInt();

                      // Tap always selects the tapped point
                      if (event is FlTapUpEvent) {
                        if (touchedIndex != null) {
                          setState(() {
                            _markedIndex = touchedIndex;
                            _lastTouchedIndex = null;
                          });
                        }
                        return;
                      }

                      // Finger lifted - mark the last touched position
                      if (event is FlPointerExitEvent ||
                          event is FlPanEndEvent ||
                          event is FlLongPressEnd) {
                        if (_lastTouchedIndex != null) {
                          setState(() {
                            _markedIndex = _lastTouchedIndex;
                            _lastTouchedIndex = null;
                          });
                        }
                        return;
                      }

                      // Update display in real-time while sliding
                      if (touchedIndex != null &&
                          touchedIndex != _lastTouchedIndex) {
                        setState(() {
                          _lastTouchedIndex = touchedIndex;
                        });
                      }
                    },
                    // Disable tooltip overlay - info shown above chart
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((_) => null).toList(),
                    ),
                    getTouchedSpotIndicator: (barData, spotIndexes) {
                      return spotIndexes.map((index) {
                        return TouchedSpotIndicatorData(
                          FlLine(
                            color: Theme.of(context).colorScheme.primary,
                            strokeWidth: 1,
                            dashArray: [4, 4],
                          ),
                          FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, idx) {
                              return FlDotCirclePainter(
                                radius: 6,
                                color: Theme.of(context).colorScheme.primary,
                                strokeWidth: 2,
                                strokeColor: Theme.of(context).colorScheme.surface,
                              );
                            },
                          ),
                        );
                      }).toList();
                    },
                  ),
                  // No tooltip indicators - info shown above chart
                  showingTooltipIndicators: [],
                  // Vertical line for marked point (when not actively touching)
                  extraLinesData: _markedIndex != null && _lastTouchedIndex == null
                      ? ExtraLinesData(
                          verticalLines: [
                            VerticalLine(
                              x: _markedIndex!.toDouble(),
                              color: Theme.of(context).colorScheme.primary,
                              strokeWidth: 1,
                              dashArray: [4, 4],
                            ),
                          ],
                        )
                      : ExtraLinesData(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round up to a "nice" step in the 1-2.5-5 sequence at each decade,
/// floored at 100. Produces clean axis labels: 100, 250, 500, 1k, 2.5k, 5k, 10k, ...
double _niceStep(double rawStep) {
  if (rawStep <= 100) return 100;
  final magnitude =
      math.pow(10, (math.log(rawStep) / math.ln10).floor()).toDouble();
  final normalized = rawStep / magnitude;
  final double mantissa;
  if (normalized <= 1) {
    mantissa = 1;
  } else if (normalized <= 2.5) {
    mantissa = 2.5;
  } else if (normalized <= 5) {
    mantissa = 5;
  } else {
    mantissa = 10;
  }
  return mantissa * magnitude;
}

/// Next nice step after the given one (e.g. 250 -> 500, 500 -> 1000).
double _nextNiceStep(double step) {
  final magnitude =
      math.pow(10, (math.log(step) / math.ln10).floor()).toDouble();
  final normalized = step / magnitude;
  if (normalized < 2.5) return 2.5 * magnitude;
  if (normalized < 5) return 5 * magnitude;
  return 10 * magnitude;
}

/// Largest-Triangle-Three-Buckets downsampling.
/// Preserves visual shape while reducing point count.
List<WealthHistoryPoint> _downsample(List<WealthHistoryPoint> data, int threshold) {
  if (data.length <= threshold) return data;

  final result = <WealthHistoryPoint>[data.first];
  final bucketSize = (data.length - 2) / (threshold - 2);

  var lastSelected = 0;

  for (var i = 0; i < threshold - 2; i++) {
    final bucketStart = ((i + 1) * bucketSize + 1).floor();
    final bucketEnd = ((i + 2) * bucketSize + 1).floor().clamp(0, data.length);
    final nextStart = bucketEnd;
    final nextEnd = ((i + 3) * bucketSize + 1).floor().clamp(0, data.length);

    // Average of next bucket
    var avgX = 0.0;
    var avgY = 0.0;
    final nextCount = nextEnd - nextStart;
    if (nextCount > 0) {
      for (var j = nextStart; j < nextEnd; j++) {
        avgX += j;
        avgY += data[j].totalWealth;
      }
      avgX /= nextCount;
      avgY /= nextCount;
    }

    // Find point in current bucket with largest triangle area
    var maxArea = -1.0;
    var maxIndex = bucketStart;
    final pointAX = lastSelected.toDouble();
    final pointAY = data[lastSelected].totalWealth;

    for (var j = bucketStart; j < bucketEnd; j++) {
      final area = ((pointAX - avgX) * (data[j].totalWealth - pointAY) -
                  (pointAX - j.toDouble()) * (avgY - pointAY))
              .abs() *
          0.5;
      if (area > maxArea) {
        maxArea = area;
        maxIndex = j;
      }
    }

    result.add(data[maxIndex]);
    lastSelected = maxIndex;
  }

  result.add(data.last);
  return result;
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
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
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
