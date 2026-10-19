import { AlertCircle, AlertTriangle, Info, RefreshCw } from 'lucide-react';
import type { Account } from './AccountsTable';
import { type StaleSyncLevel, type StaleSyncStatus, staleSyncAdvice, staleSyncTitle } from '../utils/staleSync';

interface Props {
  statuses: StaleSyncStatus[];
  /** The account whose sync is running right now, if any. */
  syncingId: number | null;
  onSync: (account: Account) => void;
}

// Each level borrows the colour of the matching table status: stale amber,
// then the pending warning, then the error red.
const LEVEL_STYLE: Record<StaleSyncLevel, { className: string; Icon: typeof Info }> = {
  notice: { className: 'status-stale', Icon: Info },
  warning: { className: 'status-pending', Icon: AlertTriangle },
  urgent: { className: 'status-error', Icon: AlertCircle },
};

/**
 * One notice per account that needs a code and has gone unsynced, coloured by
 * how overdue it is. The button starts that account's sync, which ends in the
 * code prompt. Renders nothing while every such account is fine.
 */
export default function StaleSyncNotice({ statuses, syncingId, onSync }: Props) {
  if (statuses.length === 0) return null;

  return (
    <div className="stale-sync-notices">
      {statuses.map((status) => {
        const { className, Icon } = LEVEL_STYLE[status.level];
        const syncing = syncingId === status.account.id;
        return (
          <div key={status.account.id} className={`stale-sync-notice ${className}`} role="status">
            <Icon size={18} />
            <div className="stale-sync-notice-text">
              <div className="stale-sync-notice-title">{staleSyncTitle(status)}</div>
              <div className="stale-sync-notice-detail">{staleSyncAdvice(status.level)}</div>
            </div>
            <button
              type="button"
              className="btn btn-sm btn-ghost"
              onClick={() => onSync(status.account)}
              disabled={syncing}
              title={`Sync ${status.account.name}`}
            >
              <RefreshCw size={14} className={syncing ? 'spin' : ''} />
              {syncing ? 'Syncing...' : 'Sync'}
            </button>
          </div>
        );
      })}
    </div>
  );
}
