import { useCallback, useEffect, useState } from 'react';
import {
  getWealthSummary,
  getWealthHistory,
  getWealthBreakdown,
  getAccounts,
  getProfile,
} from '../api/client';
import WealthSummaryCard from '../components/WealthSummaryCard';
import WealthChart from '../components/WealthChart';
import BreakdownChart from '../components/BreakdownChart';
import RecentChanges from '../components/RecentChanges';
import AccountsTable, { type Account } from '../components/AccountsTable';

interface Summary {
  total_wealth: number;
  base_currency: string;
  accounts: Account[];
  account_count: number;
}

interface History {
  history: { date: string; total_wealth: number }[];
  base_currency: string;
}

interface Breakdown {
  breakdown: { category: string; amount: number; percentage: number }[];
  base_currency: string;
}

export default function DashboardPage() {
  const [summary, setSummary] = useState<Summary | null>(null);
  const [history, setHistory] = useState<History | null>(null);
  const [breakdown, setBreakdown] = useState<Breakdown | null>(null);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [loading, setLoading] = useState(true);
  const [defaultChartRange, setDefaultChartRange] = useState(365);
  const [defaultChartGranularity, setDefaultChartGranularity] = useState<'daily' | 'monthly'>('daily');

  const fetchAll = useCallback(async () => {
    // Try to fetch profile for chart preferences, but use defaults if it fails
    let chartRange = 365;
    let chartGranularity: 'daily' | 'monthly' = 'daily';
    try {
      const profile = await getProfile();
      chartRange = profile.default_chart_range ?? 365;
      chartGranularity = profile.default_chart_granularity ?? 'daily';
      setDefaultChartRange(chartRange);
      setDefaultChartGranularity(chartGranularity);
    } catch {
      // Use defaults if profile fetch fails
    }

    try {
      const [s, h, b, a] = await Promise.all([
        getWealthSummary(),
        getWealthHistory(chartRange, chartGranularity),
        getWealthBreakdown('broker'),
        getAccounts(),
      ]);
      setSummary(s);
      setHistory(h);
      setBreakdown(b);
      setAccounts(a.results ?? a);
    } catch {
      // Will show empty state
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    // Wrapped in an async IIFE so the fetch (and its setState calls) runs
    // after the effect returns rather than synchronously in the effect body.
    (async () => { await fetchAll(); })();
  }, [fetchAll]);

  const handleRangeChange = async (days: number, granularity: 'daily' | 'monthly') => {
    try {
      const h = await getWealthHistory(days, granularity);
      setHistory(h);
    } catch {
      // keep current state
    }
  };

  const handleGroupChange = async (by: string) => {
    try {
      const b = await getWealthBreakdown(by);
      setBreakdown(b);
    } catch {
      // keep current state
    }
  };

  if (loading) {
    return <div className="loading">Loading dashboard...</div>;
  }

  const baseCurrency = summary?.base_currency ?? 'CHF';

  return (
    <div className="dashboard">
      <WealthSummaryCard
        totalWealth={summary?.total_wealth ?? 0}
        baseCurrency={baseCurrency}
        accountCount={summary?.account_count ?? 0}
      />

      <WealthChart
        history={history?.history ?? []}
        baseCurrency={baseCurrency}
        onRangeChange={handleRangeChange}
        defaultRange={defaultChartRange}
        defaultGranularity={defaultChartGranularity}
      />

      <div className="dashboard-grid">
        <BreakdownChart
          breakdown={breakdown?.breakdown ?? []}
          baseCurrency={baseCurrency}
          onGroupChange={handleGroupChange}
        />
        <RecentChanges
          history={history?.history ?? []}
          baseCurrency={baseCurrency}
        />
      </div>

      <AccountsTable
        accounts={accounts}
        baseCurrency={baseCurrency}
        onRefresh={fetchAll}
      />
    </div>
  );
}
