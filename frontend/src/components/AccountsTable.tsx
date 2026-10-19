import { useState, useCallback, useImperativeHandle, type Ref } from 'react';
import { RefreshCw, Plus, PlusCircle, AlertCircle, CheckCircle2, Clock, X, Trash2, History, MinusCircle, Settings, Upload, Download, Repeat, FileUp } from 'lucide-react';
import { syncAccount, completeAccountAuth, deleteAccount, updateAccount, updateAccountCredentials, getAccountCredentials, getBroker, brokerCanSync } from '../api/client';
import { needsAttendedSync } from '../utils/staleSync';
import AddSnapshotModal from './AddSnapshotModal';
import AddAccountModal from './AddAccountModal';
import MigrateAccountModal from './MigrateAccountModal';
import SnapshotsModal from './SnapshotsModal';
import ImportModal from './ImportModal';
import TransactionCsvImportModal from './TransactionCsvImportModal';
import Tooltip from './Tooltip';
import ExportModal from './ExportModal';
import Toast from './Toast';
import TwoFactorModal, { type AuthPrompt } from './TwoFactorModal';
import ModalOverlay from './ModalOverlay';

interface ToastData {
  id: string;
  type: 'success' | 'error';
  message: string;
}

export interface Account {
  id: number;
  name: string;
  broker: {
    code: string;
    name: string;
    supports_auto_sync?: boolean;
    requires_interactive_sync?: boolean;
    supports_sync?: boolean;
  };
  account_type: string;
  currency: string;
  is_manual: boolean;
  sync_enabled: boolean;
  status: string;
  last_sync_at: string | null;
  last_sync_error: string;
  notes?: string;
  created_at?: string;
  latest_snapshot: {
    balance: string;
    currency: string;
    balance_base_currency: string | null;
    snapshot_date: string;
  } | null;
}

/** What the dashboard can ask the table to do from outside its rows. */
export interface AccountsTableHandle {
  /**
   * Start one account's sync exactly as its row's sync button does: the code
   * prompt, the credentials dialog on an auth error and the toasts all come
   * from the table. Resolves once the request is answered; a code prompt
   * then stays open on its own.
   */
  sync: (accountId: number) => Promise<void>;
}

interface Props {
  accounts: Account[];
  baseCurrency: string;
  onRefresh: () => void;
  ref?: Ref<AccountsTableHandle>;
}

interface CredentialField {
  type: string;
  title?: string;
  format?: string;
  description?: string;
  default?: boolean;
}

interface CredentialSchema {
  properties?: Record<string, CredentialField>;
  required?: string[];
}

function formatCurrency(value: number, currency: string): string {
  return new Intl.NumberFormat('de-CH', {
    style: 'currency',
    currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(value);
}

// An active account whose last successful sync is older than this is flagged
// amber ("stale") so a long gap is visible at a glance.
const STALE_SYNC_DAYS = 7;

function daysSince(dateStr: string | null | undefined): number | null {
  if (!dateStr) return null;
  const then = new Date(dateStr).getTime();
  if (Number.isNaN(then)) return null;
  return Math.floor((Date.now() - then) / 86_400_000);
}

// Accounts whose broker stops for a code are left out of every bulk run (the
// app's Sync all, the server's daily sync); the tooltip says so, since
// nothing else on the page does.
const ATTENDED_SYNC_NOTE = '. Needs a code, so Sync all and the daily sync leave it out — sync it from its row';

function StatusIcon({ status, isManual, attendedOnly, lastSyncAt, onClick }: {
  status: string;
  isManual?: boolean;
  attendedOnly?: boolean;
  lastSyncAt?: string | null;
  onClick?: () => void;
}) {
  if (isManual) {
    return (
      <Tooltip label="Manual account — values are entered by hand and not synced automatically">
        <MinusCircle size={14} className="status-na" />
      </Tooltip>
    );
  }
  switch (status) {
    case 'error':
      return (
        <Tooltip label="Sync failed — click to see the error details">
          <button className="btn-status-error" onClick={onClick}>
            <AlertCircle size={14} className="status-error" />
          </button>
        </Tooltip>
      );
    case 'pending_auth':
      return (
        <Tooltip label="Action needed — finish authentication (enter a 2FA code or re-add credentials) before this account can sync">
          <Clock size={14} className="status-pending" />
        </Tooltip>
      );
    default: {
      // Active — but flag amber if the last successful sync is getting old.
      const note = attendedOnly ? ATTENDED_SYNC_NOTE : '';
      const age = daysSince(lastSyncAt);
      if (age !== null && age >= STALE_SYNC_DAYS) {
        return (
          <Tooltip label={`Synced, but ${age} days ago — data may be out of date${note}`}>
            <CheckCircle2 size={14} className="status-stale" />
          </Tooltip>
        );
      }
      return (
        <Tooltip label={`Active — the last sync succeeded recently${note}`}>
          <CheckCircle2 size={14} className="status-active" />
        </Tooltip>
      );
    }
  }
}

function formatDate(dateStr: string): string {
  const date = new Date(dateStr);
  return date.toLocaleDateString('de-CH', { day: '2-digit', month: '2-digit', year: 'numeric' });
}

function isAuthenticationError(errorMessage: string | undefined | null): boolean {
  if (!errorMessage) return false;
  const authErrorPatterns = [
    /auth/i,
    /credential/i,
    /login/i,
    /password/i,
    /pin/i,
    /invalid.*user/i,
    /user.*invalid/i,
    /access.*denied/i,
    /unauthorized/i,
    /forbidden/i,
    /jwt/i,
    /token.*expired/i,
    /expired.*token/i,
    /session.*expired/i,
  ];
  return authErrorPatterns.some(pattern => pattern.test(errorMessage));
}

export default function AccountsTable({ accounts, baseCurrency, onRefresh, ref }: Props) {
  const [syncing, setSyncing] = useState<number | null>(null);
  const [deleting, setDeleting] = useState<number | null>(null);
  const [deleteConfirm, setDeleteConfirm] = useState<Account | null>(null);
  const [snapshotAccount, setSnapshotAccount] = useState<Account | null>(null);
  const [snapshotsAccount, setSnapshotsAccount] = useState<Account | null>(null);
  const [txImportAccount, setTxImportAccount] = useState<Account | null>(null);
  const [showAddAccount, setShowAddAccount] = useState(false);
  const [showImport, setShowImport] = useState(false);
  const [showExport, setShowExport] = useState(false);
  const [authPrompt, setAuthPrompt] = useState<AuthPrompt | null>(null);


  // Error details modal
  const [errorAccount, setErrorAccount] = useState<Account | null>(null);

  // Account settings modal
  const [credentialsAccount, setCredentialsAccount] = useState<Account | null>(null);
  const [credentialSchema, setCredentialSchema] = useState<CredentialSchema | null>(null);
  const [credentialValues, setCredentialValues] = useState<Record<string, string>>({});
  const [savingCredentials, setSavingCredentials] = useState(false);
  const [credentialsRetrySync, setCredentialsRetrySync] = useState(false);
  const [credentialsError, setCredentialsError] = useState('');
  const [settingsAccountName, setSettingsAccountName] = useState('');
  const [settingsSyncEnabled, setSettingsSyncEnabled] = useState(true);
  const [settingsNotes, setSettingsNotes] = useState('');

  // Change-account-type (migration) workflow
  const [migrateAccount, setMigrateAccount] = useState<Account | null>(null);

  const openMigrate = (account: Account) => {
    setCredentialsAccount(null);
    setCredentialsRetrySync(false);
    setCredentialsError('');
    setMigrateAccount(account);
  };

  // Toast notifications
  const [toasts, setToasts] = useState<ToastData[]>([]);

  const addToast = useCallback((type: 'success' | 'error', message: string) => {
    const id = Date.now().toString();
    setToasts(prev => [...prev, { id, type, message }]);
  }, []);

  const dismissToast = useCallback((id: string) => {
    setToasts(prev => prev.filter(t => t.id !== id));
  }, []);

  const openCredentialsModal = async (account: Account, forRetry = false, errorMsg = '') => {
    setCredentialsAccount(account);
    setCredentialValues({});
    setCredentialSchema(null);
    setCredentialsRetrySync(forRetry);
    setCredentialsError(errorMsg);
    setSettingsAccountName(account.name);
    setSettingsSyncEnabled(account.sync_enabled);
    setSettingsNotes(account.notes ?? '');

    if (account.is_manual || !brokerCanSync(account.broker)) {
      // Neither has credentials: one has no broker to log into, the other has a
      // broker it never logs into.
      return;
    }

    try {
      // Fetch broker schema and current credentials in parallel
      const [broker, credData] = await Promise.all([
        getBroker(account.broker.code),
        getAccountCredentials(account.id),
      ]);
      setCredentialSchema(broker.credential_schema);
      // Pre-fill with current credentials (sensitive fields will be masked)
      if (credData.credentials) {
        setCredentialValues(credData.credentials);
      }
    } catch {
      setCredentialSchema(null);
    }
  };

  const handleSaveCredentials = async (andRetrySync = false) => {
    if (!credentialsAccount) return;
    setSavingCredentials(true);
    setCredentialsError('');
    const accountId = credentialsAccount.id;
    const accountName = credentialsAccount.name;
    try {
      // Save name and sync_enabled if changed
      const updates: { name?: string; sync_enabled?: boolean; notes?: string } = {};
      if (settingsAccountName.trim() && settingsAccountName !== credentialsAccount.name) {
        updates.name = settingsAccountName.trim();
      }
      if (settingsSyncEnabled !== credentialsAccount.sync_enabled) {
        updates.sync_enabled = settingsSyncEnabled;
      }
      if (settingsNotes !== (credentialsAccount.notes ?? '')) {
        updates.notes = settingsNotes;
      }
      if (Object.keys(updates).length > 0) {
        await updateAccount(accountId, updates);
      }
      // Save credentials — only where there are any. A manual account has no
      // broker to log into; a non-syncing broker never logs in either, and its
      // settings form shows name and notes only.
      if (!credentialsAccount.is_manual && brokerCanSync(credentialsAccount.broker)) {
        await updateAccountCredentials(accountId, credentialValues);
      }

      if (andRetrySync) {
        // Close modal and retry sync
        setCredentialsAccount(null);
        setCredentialValues({});
        setCredentialsRetrySync(false);
        addToast('success', `Credentials updated. Syncing ${accountName}...`);

        // Trigger sync
        setSyncing(accountId);
        try {
          const result = await syncAccount(accountId);
          if (result.status === 'pending_auth') {
            setAuthPrompt({
              accountId,
              accountName,
              twoFaType: result.two_fa_type || 'totp',
              challenge: result.challenge?.message,
            });
          } else if (result.status === 'error') {
            // If it's still an auth error, open credentials modal again
            const isAuthError = isAuthenticationError(result.error);
            if (isAuthError) {
              const account = accounts.find(a => a.id === accountId);
              if (account) {
                openCredentialsModal(account, true, result.error);
              }
            } else {
              addToast('error', `Sync failed: ${result.error || 'Unknown error'}`);
            }
            onRefresh();
          } else {
            addToast('success', `${accountName} synced successfully`);
            onRefresh();
          }
        } catch (err) {
          const message = err instanceof Error ? err.message : '';
          const isAuthError = isAuthenticationError(message);
          if (isAuthError) {
            const account = accounts.find(a => a.id === accountId);
            if (account) {
              openCredentialsModal(account, true, message);
            }
          } else {
            addToast('error', `Sync failed: ${message || 'Unknown error'}`);
          }
          onRefresh();
        } finally {
          setSyncing(null);
        }
      } else {
        addToast('success', `Credentials updated for ${accountName}`);
        setCredentialsAccount(null);
        setCredentialValues({});
        setCredentialsRetrySync(false);
        onRefresh();
      }
    } catch (err) {
      setCredentialsError(err instanceof Error && err.message ? err.message : 'Failed to update credentials');
    } finally {
      setSavingCredentials(false);
    }
  };

  const handleSync = async (accountId: number) => {
    const account = accounts.find(a => a.id === accountId);
    const accountName = account?.name || 'Account';
    setSyncing(accountId);
    try {
      const result = await syncAccount(accountId);
      if (result.status === 'pending_auth') {
        // 2FA required - show modal
        setAuthPrompt({
          accountId,
          accountName,
          twoFaType: result.two_fa_type || 'totp',
          challenge: result.challenge?.message,
        });
      } else if (result.status === 'error') {
        // Check if it's an authentication error
        if (account && isAuthenticationError(result.error)) {
          openCredentialsModal(account, true, result.error);
        } else {
          addToast('error', `Failed to sync ${accountName}: ${result.error || 'Unknown error'}`);
        }
        onRefresh();
      } else {
        addToast('success', `${accountName} synced successfully`);
        onRefresh();
      }
    } catch (err) {
      // Check if it's an authentication error
      const message = err instanceof Error ? err.message : '';
      if (account && isAuthenticationError(message)) {
        openCredentialsModal(account, true, message);
      } else {
        addToast('error', `Failed to sync ${accountName}: ${message || 'Unknown error'}`);
      }
      onRefresh();
    } finally {
      setSyncing(null);
    }
  };

  // The dashboard's stale-sync notices start a sync through here, so they end
  // in the same code prompt as the row button. No dependency list: the handle
  // must always see the current accounts.
  useImperativeHandle(ref, () => ({ sync: handleSync }));

  const handleAuthSubmit = async (code: string) => {
    if (!authPrompt) return;
    // A rejection here is shown inside the modal, so the code can be retyped.
    await completeAccountAuth(authPrompt.accountId, code);
    addToast('success', `${authPrompt.accountName} synced successfully`);
    setAuthPrompt(null);
    onRefresh();
  };

  const handleDelete = async () => {
    if (!deleteConfirm) return;
    setDeleting(deleteConfirm.id);
    try {
      await deleteAccount(deleteConfirm.id);
      setDeleteConfirm(null);
      onRefresh();
    } catch {
      // Error handling could be added here
    } finally {
      setDeleting(null);
    }
  };

  return (
    <div className="card">
      <h2>Accounts</h2>

      {accounts.length === 0 ? (
        <p className="table-empty">No accounts yet. Click "Add Account" to get started.</p>
      ) : (
        <div className="table-wrapper">
          <table className="data-table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Broker</th>
                <th className="text-right">Balance</th>
                <th className="text-right">{baseCurrency}</th>
                <th>Last Snapshot</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {accounts.map((a) => {
                const snap = a.latest_snapshot;
                const balance = snap ? parseFloat(snap.balance) : null;
                const baseBal = snap?.balance_base_currency
                  ? parseFloat(snap.balance_base_currency)
                  : balance;
                return (
                  <tr key={a.id}>
                    <td>
                      <button
                        className="account-name-link"
                        onClick={() => setSnapshotsAccount(a)}
                        title="View snapshots"
                      >
                        {a.name}
                      </button>
                    </td>
                    <td>{a.broker.name}</td>
                    <td className="text-right mono">
                      {balance != null
                        ? formatCurrency(balance, snap!.currency)
                        : '—'}
                    </td>
                    <td className="text-right mono">
                      {baseBal != null
                        ? formatCurrency(baseBal, baseCurrency)
                        : '—'}
                    </td>
                    <td className="text-muted">
                      {snap ? formatDate(snap.snapshot_date) : '—'}
                    </td>
                    <td>
                      <StatusIcon
                        status={a.status}
                        isManual={a.is_manual}
                        attendedOnly={needsAttendedSync(a)}
                        lastSyncAt={a.last_sync_at}
                        onClick={a.status === 'error' ? () => setErrorAccount(a) : undefined}
                      />
                    </td>
                    <td>
                      <div className="action-buttons">
                        <button
                          className="btn btn-sm btn-ghost"
                          onClick={() => setSnapshotAccount(a)}
                          title="Add Snapshot"
                        >
                          <Plus size={14} />
                        </button>
                        {!a.is_manual && brokerCanSync(a.broker) && (
                          <button
                            className="btn btn-sm btn-ghost"
                            onClick={() => handleSync(a.id)}
                            disabled={syncing === a.id}
                            title="Sync"
                          >
                            <RefreshCw
                              size={14}
                              className={syncing === a.id ? 'spin' : ''}
                            />
                          </button>
                        )}
                        <button
                          className="btn btn-sm btn-ghost"
                          onClick={() => setSnapshotsAccount(a)}
                          title="View Snapshots"
                        >
                          <History size={14} />
                        </button>
                        <button
                          className="btn btn-sm btn-ghost"
                          onClick={() => setTxImportAccount(a)}
                          title="Import Transactions (CSV)"
                        >
                          <FileUp size={14} />
                        </button>
                        <button
                          className="btn btn-sm btn-ghost"
                          onClick={() => openCredentialsModal(a)}
                          title="Account Settings"
                        >
                          <Settings size={14} />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      <div className="table-actions">
        <button
          className="btn btn-sm btn-ghost"
          onClick={() => setShowImport(true)}
          title="Import CSV"
        >
          <Upload size={14} />
          Import
        </button>
        <button
          className="btn btn-sm btn-ghost"
          onClick={() => setShowExport(true)}
          title="Export CSV"
        >
          <Download size={14} />
          Export
        </button>
        <button
          className="btn btn-sm btn-primary"
          onClick={() => setShowAddAccount(true)}
        >
          <PlusCircle size={14} />
          Add Account
        </button>
      </div>

      {snapshotAccount && (
        <AddSnapshotModal
          accountId={snapshotAccount.id}
          accountName={snapshotAccount.name}
          defaultCurrency={snapshotAccount.currency}
          onClose={() => setSnapshotAccount(null)}
          onSaved={() => {
            setSnapshotAccount(null);
            onRefresh();
          }}
        />
      )}

      {showAddAccount && (
        <AddAccountModal
          onClose={() => setShowAddAccount(false)}
          onCreated={() => {
            setShowAddAccount(false);
            onRefresh();
          }}
        />
      )}

      {txImportAccount && (
        <TransactionCsvImportModal
          accountId={txImportAccount.id}
          accountName={txImportAccount.name}
          onClose={() => setTxImportAccount(null)}
          onImported={onRefresh}
        />
      )}

      {showImport && (
        <ImportModal
          onClose={() => setShowImport(false)}
          onImported={() => {
            onRefresh();
          }}
        />
      )}

      {showExport && (
        <ExportModal onClose={() => setShowExport(false)} />
      )}

      {/* 2FA Authentication Modal */}
      {authPrompt && (
        <TwoFactorModal
          prompt={authPrompt}
          onSubmit={handleAuthSubmit}
          onClose={() => setAuthPrompt(null)}
        />
      )}

      {/* Delete Confirmation Modal */}
      {deleteConfirm && (
        <ModalOverlay onClose={() => setDeleteConfirm(null)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>
                <Trash2 size={18} style={{ marginRight: 8 }} />
                Delete Account
              </h3>
              <button className="btn btn-ghost" onClick={() => setDeleteConfirm(null)}>
                <X size={18} />
              </button>
            </div>

            <p style={{ marginBottom: 16 }}>
              Are you sure you want to delete <strong>{deleteConfirm.name}</strong>?
              This will also delete all snapshots for this account.
            </p>

            <div className="form-actions">
              <button
                type="button"
                className="btn btn-ghost"
                onClick={() => setDeleteConfirm(null)}
              >
                Cancel
              </button>
              <button
                type="button"
                className="btn btn-danger"
                onClick={handleDelete}
                disabled={deleting === deleteConfirm.id}
              >
                {deleting === deleteConfirm.id ? 'Deleting...' : 'Delete'}
              </button>
            </div>
          </div>
        </ModalOverlay>
      )}

      {/* Snapshots Modal */}
      {snapshotsAccount && (
        <SnapshotsModal
          accountId={snapshotsAccount.id}
          accountName={snapshotsAccount.name}
          defaultCurrency={snapshotsAccount.currency}
          baseCurrency={baseCurrency}
          onClose={() => setSnapshotsAccount(null)}
          onChanged={() => {
            onRefresh();
          }}
        />
      )}

      {/* Error Details Modal */}
      {errorAccount && (
        <ModalOverlay onClose={() => setErrorAccount(null)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>
                <AlertCircle size={18} style={{ marginRight: 8 }} className="status-error" />
                Sync Error
              </h3>
              <button className="btn btn-ghost" onClick={() => setErrorAccount(null)}>
                <X size={18} />
              </button>
            </div>

            <div style={{ marginBottom: 16 }}>
              <p style={{ marginBottom: 8 }}>
                Failed to sync <strong>{errorAccount.name}</strong>:
              </p>
              <div className="error-details">
                {errorAccount.last_sync_error || 'Unknown error'}
              </div>
            </div>

            <div className="form-actions">
              <button
                type="button"
                className="btn btn-ghost"
                onClick={() => setErrorAccount(null)}
              >
                Close
              </button>
              {isAuthenticationError(errorAccount.last_sync_error) && (
                <button
                  type="button"
                  className="btn btn-ghost"
                  onClick={() => {
                    const account = errorAccount;
                    setErrorAccount(null);
                    openCredentialsModal(account, true, account.last_sync_error);
                  }}
                >
                  <Settings size={14} style={{ marginRight: 6 }} />
                  Update Credentials
                </button>
              )}
              <button
                type="button"
                className="btn btn-primary"
                onClick={() => {
                  setErrorAccount(null);
                  handleSync(errorAccount.id);
                }}
              >
                <RefreshCw size={14} style={{ marginRight: 6 }} />
                Retry Sync
              </button>
            </div>
          </div>
        </ModalOverlay>
      )}

      {/* Account Settings Modal */}
      {credentialsAccount && (
        <ModalOverlay onClose={() => { setCredentialsAccount(null); setCredentialsRetrySync(false); setCredentialsError(''); }}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>
                {credentialsRetrySync ? (
                  <>
                    <AlertCircle size={18} style={{ marginRight: 8 }} className="status-error" />
                    Authentication Failed
                  </>
                ) : (
                  <>
                    <Settings size={18} style={{ marginRight: 8 }} />
                    Account Settings
                  </>
                )}
              </h3>
              <button className="btn btn-ghost" onClick={() => { setCredentialsAccount(null); setCredentialsRetrySync(false); setCredentialsError(''); }}>
                <X size={18} />
              </button>
            </div>

            {credentialsError && (
              <div className="form-error" style={{ marginBottom: 16 }}>
                {credentialsError}
              </div>
            )}

            {credentialsRetrySync && (
              <p className="form-hint" style={{ marginBottom: 16 }}>
                Update credentials for <strong>{credentialsAccount.name}</strong> and retry sync.
              </p>
            )}

            {!credentialsAccount.is_manual && brokerCanSync(credentialsAccount.broker)
              && credentialSchema?.properties ? (
              <form onSubmit={(e) => { e.preventDefault(); handleSaveCredentials(credentialsRetrySync); }}>
                <div className="form-group">
                  <label htmlFor="settings-name">Account Name</label>
                  <input
                    id="settings-name"
                    type="text"
                    value={settingsAccountName}
                    onChange={(e) => setSettingsAccountName(e.target.value)}
                  />
                </div>
                <div className="form-group">
                  <label htmlFor="settings-notes">Notes</label>
                  <textarea
                    id="settings-notes"
                    rows={3}
                    value={settingsNotes}
                    onChange={(e) => setSettingsNotes(e.target.value)}
                    placeholder="Optional — context, IBAN, etc."
                  />
                </div>
                {Object.entries(credentialSchema.properties).map(([key, field]) => (
                  field.type === 'boolean' ? (
                    <div className="form-group" key={key}>
                      <label className="toggle-label">
                        <input
                          type="checkbox"
                          checked={String(credentialValues[key] ?? field.default ?? false).toLowerCase() === 'true'}
                          onChange={(e) => setCredentialValues(prev => ({ ...prev, [key]: e.target.checked ? 'true' : 'false' }))}
                        />
                        <span>{field.title || key}</span>
                      </label>
                      {field.description && (
                        <small className="form-hint">{field.description}</small>
                      )}
                    </div>
                  ) : (
                    <div className="form-group" key={key}>
                      <label htmlFor={`cred-${key}`}>{field.title || key}</label>
                      <input
                        id={`cred-${key}`}
                        type={field.format === 'password' ? 'password' : 'text'}
                        value={credentialValues[key] || ''}
                        onChange={(e) => setCredentialValues(prev => ({ ...prev, [key]: e.target.value }))}
                        placeholder={field.description || ''}
                      />
                      {field.description && (
                        <small className="form-hint">{field.description}</small>
                      )}
                    </div>
                  )
                ))}

                {(credentialsAccount.broker.supports_auto_sync ||
                  credentialsAccount.broker.requires_interactive_sync) && (
                  <div className="form-group">
                    <label className="toggle-label">
                      <input
                        type="checkbox"
                        checked={settingsSyncEnabled}
                        onChange={(e) => setSettingsSyncEnabled(e.target.checked)}
                      />
                      <span>Sync enabled</span>
                    </label>
                    <small className="form-hint">
                      {credentialsAccount.broker.requires_interactive_sync
                        ? 'This bank texts a code, so it is left out of the daily sync — sync it from its row when you want it updated.'
                        : 'When enabled, this account will be synced automatically during daily sync.'}
                    </small>
                  </div>
                )}

                <div className="form-actions">
                  <button
                    type="button"
                    className="btn btn-ghost btn-danger btn-left"
                    onClick={() => {
                      setCredentialsAccount(null);
                      setCredentialsRetrySync(false);
                      setCredentialsError('');
                      setDeleteConfirm(credentialsAccount);
                    }}
                  >
                    <Trash2 size={14} style={{ marginRight: 6 }} />
                    Delete
                  </button>
                  <button
                    type="button"
                    className="btn btn-ghost"
                    onClick={() => openMigrate(credentialsAccount)}
                  >
                    <Repeat size={14} style={{ marginRight: 6 }} />
                    Change type
                  </button>
                  <button
                    type="button"
                    className="btn btn-ghost"
                    onClick={() => { setCredentialsAccount(null); setCredentialsRetrySync(false); setCredentialsError(''); }}
                  >
                    Cancel
                  </button>
                  {credentialsRetrySync ? (
                    <>
                      <button
                        type="button"
                        className="btn btn-ghost"
                        onClick={() => handleSaveCredentials(false)}
                        disabled={savingCredentials}
                      >
                        Save Only
                      </button>
                      <button
                        type="submit"
                        className="btn btn-primary"
                        disabled={savingCredentials}
                      >
                        {savingCredentials ? (
                          <>
                            <RefreshCw size={14} className="spin" style={{ marginRight: 6 }} />
                            Syncing...
                          </>
                        ) : (
                          <>
                            <RefreshCw size={14} style={{ marginRight: 6 }} />
                            Update & Retry Sync
                          </>
                        )}
                      </button>
                    </>
                  ) : (
                    <button
                      type="submit"
                      className="btn btn-primary"
                      disabled={savingCredentials}
                    >
                      {savingCredentials ? 'Saving...' : 'Save Credentials'}
                    </button>
                  )}
                </div>
              </form>
            ) : credentialsAccount.is_manual || !brokerCanSync(credentialsAccount.broker) ? (
              <form onSubmit={(e) => { e.preventDefault(); handleSaveCredentials(false); }}>
                <div className="form-group">
                  <label htmlFor="settings-name-manual">Account Name</label>
                  <input
                    id="settings-name-manual"
                    type="text"
                    value={settingsAccountName}
                    onChange={(e) => setSettingsAccountName(e.target.value)}
                  />
                </div>
                <div className="form-group">
                  <label htmlFor="settings-notes-manual">Notes</label>
                  <textarea
                    id="settings-notes-manual"
                    rows={3}
                    value={settingsNotes}
                    onChange={(e) => setSettingsNotes(e.target.value)}
                    placeholder="Optional — context, IBAN, etc."
                  />
                </div>
                <div className="form-actions">
                  <button
                    type="button"
                    className="btn btn-ghost btn-danger btn-left"
                    onClick={() => {
                      setCredentialsAccount(null);
                      setCredentialsRetrySync(false);
                      setCredentialsError('');
                      setDeleteConfirm(credentialsAccount);
                    }}
                  >
                    <Trash2 size={14} style={{ marginRight: 6 }} />
                    Delete Account
                  </button>
                  <button
                    type="button"
                    className="btn btn-ghost"
                    onClick={() => openMigrate(credentialsAccount)}
                  >
                    <Repeat size={14} style={{ marginRight: 6 }} />
                    Change type
                  </button>
                  <button
                    type="button"
                    className="btn btn-ghost"
                    onClick={() => { setCredentialsAccount(null); setCredentialsRetrySync(false); setCredentialsError(''); }}
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    className="btn btn-primary"
                    disabled={savingCredentials}
                  >
                    {savingCredentials ? 'Saving...' : 'Save'}
                  </button>
                </div>
              </form>
            ) : (
              <p className="text-muted">Loading credential fields...</p>
            )}
          </div>
        </ModalOverlay>
      )}

      {/* Change Account Type (migration) workflow */}
      {migrateAccount && (
        <MigrateAccountModal
          account={migrateAccount}
          onClose={() => setMigrateAccount(null)}
          onMigrated={(message) => {
            setMigrateAccount(null);
            addToast('success', message);
            onRefresh();
          }}
        />
      )}

      {/* Toast notifications */}
      <Toast toasts={toasts} onDismiss={dismissToast} />
    </div>
  );
}
