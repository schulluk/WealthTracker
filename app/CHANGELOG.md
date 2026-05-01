# Changelog

## Next: 1.3.6

- Per-account chart y-axis now adapts to the visible value range with clean tick steps (100, 250, 500, 1k, 2.5k, 5k, 10k, ...)
- Per-account chart now loads the full snapshot history instead of just the most recent 100 entries

## 1.3.5

- Stability improvements
- Tap an account card to view its history, balance chart, and full snapshot list

## 1.3.4

- Upgrade dependencies to the latest versions
- Quick snapshot sheet auto-closes after the last account is submitted
- 30-day chart range now forces daily granularity; previous setting restored when switching back
- Chart performance improved with downsampling for large datasets
- Y-axis labels always show 2 decimal places for million values
- Monthly aggregation method (last/min/max/avg) is now a user setting
- Sync no longer blocks the UI — graphs and manual data work while syncing
