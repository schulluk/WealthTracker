import { brokerCanSync } from '../api/client';
import type { Account } from '../components/AccountsTable';

/**
 * Brokers that stop for a one-time code (an SMS, a TAN) are left out of Sync
 * all and of the daily sync: a bulk run would only trigger codes nobody is
 * waiting for. Nothing else reminds the user to sync them by hand, so once
 * such an account has gone three weeks without a sync the dashboard says so,
 * in three steps of growing urgency.
 *
 * Mirrors the app's stale_sync_provider.dart (thresholds in app_config.dart);
 * keep the days and the wording in step.
 */

export type StaleSyncLevel = 'notice' | 'warning' | 'urgent';

/** Days since the last sync at which each level starts. */
export const STALE_SYNC_LEVEL_DAYS: Record<StaleSyncLevel, number> = {
  notice: 21,
  warning: 25,
  urgent: 28,
};

const LEVELS: StaleSyncLevel[] = ['notice', 'warning', 'urgent'];

/** The level reached after `days` without a sync, or null while fine. */
export function staleSyncLevelForDays(days: number): StaleSyncLevel | null {
  let reached: StaleSyncLevel | null = null;
  for (const level of LEVELS) {
    if (days >= STALE_SYNC_LEVEL_DAYS[level]) reached = level;
  }
  return reached;
}

/** One overdue account and how overdue it is. */
export interface StaleSyncStatus {
  account: Account;
  days: number;
  level: StaleSyncLevel;
}

/** Headline of the notice. */
export function staleSyncTitle(status: StaleSyncStatus): string {
  return `${status.account.name} not synced for ${status.days} days`;
}

/** What to do about it, sharper with every level. */
export function staleSyncAdvice(level: StaleSyncLevel): string {
  switch (level) {
    case 'notice':
      return 'It needs a code, so Sync all and the daily sync skip it.';
    case 'warning':
      return 'Sync it in the next few days to keep its history complete.';
    case 'urgent':
      return 'Sync it now, or its history will have a gap.';
  }
}

/**
 * Whether this account is left out of unattended runs, and so can go stale
 * without anyone noticing: it can sync, but only with a code typed in.
 */
export function needsAttendedSync(account: Account): boolean {
  return (
    !account.is_manual
    && account.sync_enabled
    && brokerCanSync(account.broker)
    && Boolean(account.broker.requires_interactive_sync)
  );
}

// A bare date ("2026-10-19") is read as a local day; `new Date()` would take
// it as UTC midnight and shift it a day west of Greenwich.
function parseDate(value: string | null | undefined): Date | null {
  if (!value) return null;
  const dateOnly = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (dateOnly) {
    return new Date(Number(dateOnly[1]), Number(dateOnly[2]) - 1, Number(dateOnly[3]));
  }
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

/**
 * When the account was last brought up to date: the last sync, else the
 * newest snapshot, else the day it was added (an account never synced counts
 * from then). Null when none of these is known.
 */
export function lastUpdateOf(account: Account): Date | null {
  return (
    parseDate(account.last_sync_at)
    ?? parseDate(account.latest_snapshot?.snapshot_date)
    ?? parseDate(account.created_at)
  );
}

/**
 * Whole calendar days from `from` to `now`, so a sync late in the evening and
 * a check early next morning count as one day, not zero.
 */
export function calendarDaysBetween(from: Date, now: Date): number {
  const start = new Date(from.getFullYear(), from.getMonth(), from.getDate());
  const end = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  // Rounded, so a daylight-saving switch in between does not shave an hour off.
  return Math.round((end.getTime() - start.getTime()) / 86_400_000);
}

/**
 * How overdue `account` is, or null when it syncs unattended, is fine, or its
 * last update is unknown.
 */
export function staleSyncStatusOf(account: Account, now: Date): StaleSyncStatus | null {
  if (!needsAttendedSync(account)) return null;
  const last = lastUpdateOf(account);
  if (!last) return null;
  const days = calendarDaysBetween(last, now);
  const level = staleSyncLevelForDays(days);
  if (!level) return null;
  return { account, days, level };
}

/** The overdue accounts among `accounts`, most overdue first. */
export function staleSyncStatuses(accounts: Account[], now: Date): StaleSyncStatus[] {
  const statuses: StaleSyncStatus[] = [];
  for (const account of accounts) {
    const status = staleSyncStatusOf(account, now);
    if (status) statuses.push(status);
  }
  statuses.sort((a, b) => b.days - a.days);
  return statuses;
}
