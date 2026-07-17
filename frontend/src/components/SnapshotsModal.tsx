import { useState, useEffect, useCallback } from 'react';
import { X, Pencil, Trash2, Check, XCircle } from 'lucide-react';
import { getSnapshots, updateSnapshot, deleteSnapshot, addSnapshot } from '../api/client';

interface Snapshot {
  id: number;
  balance: string;
  currency: string;
  balance_base_currency: string | null;
  base_currency: string | null;
  snapshot_date: string;
  snapshot_source: string;
  created_at: string;
}

interface Props {
  accountId: number;
  accountName: string;
  defaultCurrency: string;
  baseCurrency: string;
  onClose: () => void;
  onChanged: () => void;
}

function formatCurrency(value: number, currency: string): string {
  return new Intl.NumberFormat('de-CH', {
    style: 'currency',
    currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(value);
}

export default function SnapshotsModal({
  accountId,
  accountName,
  defaultCurrency,
  baseCurrency,
  onClose,
  onChanged,
}: Props) {
  const [snapshots, setSnapshots] = useState<Snapshot[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState('');
  const [nextPage, setNextPage] = useState<number | null>(null);
  const [totalCount, setTotalCount] = useState(0);

  // Edit state
  const [editingId, setEditingId] = useState<number | null>(null);
  const [editBalance, setEditBalance] = useState('');
  const [editCurrency, setEditCurrency] = useState('');
  const [editDate, setEditDate] = useState('');
  const [saving, setSaving] = useState(false);

  // Delete confirmation
  const [deleteId, setDeleteId] = useState<number | null>(null);
  const [deleting, setDeleting] = useState(false);

  // Add new snapshot
  const [addBalance, setAddBalance] = useState('');
  const [addCurrency, setAddCurrency] = useState(defaultCurrency);
  const [addDate, setAddDate] = useState(new Date().toISOString().slice(0, 10));
  const [adding, setAdding] = useState(false);

  const fetchSnapshots = useCallback(async (page = 1, append = false) => {
    try {
      const data = await getSnapshots(accountId, page);
      // Handle paginated response (results array) or plain array
      if (Array.isArray(data)) {
        setSnapshots(data);
        setNextPage(null);
        setTotalCount(data.length);
      } else {
        const results = data.results || [];
        if (append) {
          setSnapshots(prev => [...prev, ...results]);
        } else {
          setSnapshots(results);
        }
        setNextPage(data.next ? page + 1 : null);
        setTotalCount(data.count || results.length);
      }
    } catch (err) {
      setError(err instanceof Error && err.message ? err.message : 'Failed to load snapshots');
    } finally {
      setLoading(false);
      setLoadingMore(false);
    }
  }, [accountId]);

  const loadMore = async () => {
    if (!nextPage || loadingMore) return;
    setLoadingMore(true);
    await fetchSnapshots(nextPage, true);
  };

  useEffect(() => {
    // Wrapped in an async IIFE so the fetch (and its setState calls) runs
    // after the effect returns rather than synchronously in the effect body.
    (async () => { await fetchSnapshots(); })();
  }, [fetchSnapshots]);

  // Close on Escape key
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [onClose]);

  const startEdit = (snap: Snapshot) => {
    setEditingId(snap.id);
    setEditBalance(snap.balance);
    setEditCurrency(snap.currency);
    setEditDate(snap.snapshot_date);
    setError('');
  };

  const cancelEdit = () => {
    setEditingId(null);
    setEditBalance('');
    setEditCurrency('');
    setEditDate('');
  };

  const handleUpdate = async () => {
    if (!editingId) return;
    setSaving(true);
    setError('');
    try {
      await updateSnapshot(editingId, parseFloat(editBalance), editCurrency, editDate);
      cancelEdit();
      await fetchSnapshots();
      onChanged();
    } catch (err) {
      setError(err instanceof Error && err.message ? err.message : 'Failed to update snapshot');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    if (!deleteId) return;
    setDeleting(true);
    setError('');
    try {
      await deleteSnapshot(deleteId);
      setDeleteId(null);
      await fetchSnapshots();
      onChanged();
    } catch (err) {
      setError(err instanceof Error && err.message ? err.message : 'Failed to delete snapshot');
    } finally {
      setDeleting(false);
    }
  };

  const handleAdd = async (e: React.FormEvent) => {
    e.preventDefault();
    setAdding(true);
    setError('');
    try {
      await addSnapshot(accountId, parseFloat(addBalance), addCurrency, addDate);
      setAddBalance('');
      setAddDate(new Date().toISOString().slice(0, 10));
      await fetchSnapshots();
      onChanged();
    } catch (err) {
      setError(err instanceof Error && err.message ? err.message : 'Failed to add snapshot');
    } finally {
      setAdding(false);
    }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal modal-lg" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h3>Snapshots - {accountName}</h3>
          <button className="btn btn-ghost" onClick={onClose}>
            <X size={18} />
          </button>
        </div>

        {error && <div className="form-error">{error}</div>}

        {loading ? (
          <p style={{ padding: '20px', textAlign: 'center', color: 'var(--color-text-muted)' }}>
            Loading...
          </p>
        ) : (
          <>
            <form onSubmit={handleAdd} className="snapshot-add-form">
              <div className="snapshot-add-row">
                <input
                  type="number"
                  step="0.01"
                  required
                  autoFocus
                  value={addBalance}
                  onChange={(e) => setAddBalance(e.target.value)}
                  placeholder="Balance"
                  className="snapshot-input"
                />
                <select
                  value={addCurrency}
                  onChange={(e) => setAddCurrency(e.target.value)}
                  className="snapshot-select"
                >
                  <option value="EUR">EUR</option>
                  <option value="USD">USD</option>
                  <option value="CHF">CHF</option>
                  <option value="GBP">GBP</option>
                </select>
                <input
                  type="date"
                  required
                  value={addDate}
                  onChange={(e) => setAddDate(e.target.value)}
                  className="snapshot-input"
                />
                <button type="submit" className="btn btn-sm btn-primary" disabled={adding}>
                  {adding ? 'Adding...' : 'Add'}
                </button>
              </div>
            </form>

            {snapshots.length === 0 ? (
              <p style={{ padding: '20px', textAlign: 'center', color: 'var(--color-text-muted)' }}>
                No snapshots yet.
              </p>
            ) : (
              <>
                <div className="table-wrapper">
                  <table className="data-table">
                    <thead>
                      <tr>
                        <th>Date</th>
                        <th className="text-right">Balance</th>
                        <th className="text-right">{baseCurrency}</th>
                        <th>Source</th>
                        <th>Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      {snapshots.map((snap) => (
                        <tr key={snap.id}>
                          {editingId === snap.id ? (
                            <>
                              <td>
                                <input
                                  type="date"
                                  value={editDate}
                                  onChange={(e) => setEditDate(e.target.value)}
                                  className="snapshot-input-sm"
                                />
                              </td>
                              <td>
                                <div className="snapshot-edit-balance">
                                  <input
                                    type="number"
                                    step="0.01"
                                    value={editBalance}
                                    onChange={(e) => setEditBalance(e.target.value)}
                                    className="snapshot-input-sm"
                                  />
                                  <select
                                    value={editCurrency}
                                    onChange={(e) => setEditCurrency(e.target.value)}
                                    className="snapshot-select-sm"
                                  >
                                    <option value="EUR">EUR</option>
                                    <option value="USD">USD</option>
                                    <option value="CHF">CHF</option>
                                    <option value="GBP">GBP</option>
                                  </select>
                                </div>
                              </td>
                              <td className="text-right mono">—</td>
                              <td>{snap.snapshot_source}</td>
                              <td>
                                <div className="action-buttons">
                                  <button
                                    className="btn btn-sm btn-ghost"
                                    onClick={handleUpdate}
                                    disabled={saving}
                                    title="Save"
                                  >
                                    <Check size={14} />
                                  </button>
                                  <button
                                    className="btn btn-sm btn-ghost"
                                    onClick={cancelEdit}
                                    title="Cancel"
                                  >
                                    <XCircle size={14} />
                                  </button>
                                </div>
                              </td>
                            </>
                          ) : (
                            <>
                              <td>{snap.snapshot_date}</td>
                              <td className="text-right mono">
                                {formatCurrency(parseFloat(snap.balance), snap.currency)}
                              </td>
                              <td className="text-right mono">
                                {snap.balance_base_currency
                                  ? formatCurrency(parseFloat(snap.balance_base_currency), baseCurrency)
                                  : '—'}
                              </td>
                              <td>
                                <span className={`source-badge source-${snap.snapshot_source}`}>
                                  {snap.snapshot_source}
                                </span>
                              </td>
                              <td>
                                {deleteId === snap.id ? (
                                  <div className="action-buttons">
                                    <button
                                      className="btn btn-sm btn-danger"
                                      onClick={handleDelete}
                                      disabled={deleting}
                                    >
                                      {deleting ? '...' : 'Confirm'}
                                    </button>
                                    <button
                                      className="btn btn-sm btn-ghost"
                                      onClick={() => setDeleteId(null)}
                                    >
                                      Cancel
                                    </button>
                                  </div>
                                ) : (
                                  <div className="action-buttons">
                                    <button
                                      className="btn btn-sm btn-ghost"
                                      onClick={() => startEdit(snap)}
                                      title="Edit"
                                    >
                                      <Pencil size={14} />
                                    </button>
                                    <button
                                      className="btn btn-sm btn-ghost btn-danger"
                                      onClick={() => setDeleteId(snap.id)}
                                      title="Delete"
                                    >
                                      <Trash2 size={14} />
                                    </button>
                                  </div>
                                )}
                              </td>
                            </>
                          )}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                {nextPage && (
                  <div style={{ padding: '12px 16px', textAlign: 'center', borderTop: '1px solid var(--color-border)' }}>
                    <button
                      className="btn btn-ghost"
                      onClick={loadMore}
                      disabled={loadingMore}
                    >
                      {loadingMore ? 'Loading...' : `Load More (${snapshots.length} of ${totalCount})`}
                    </button>
                  </div>
                )}
              </>
            )}
          </>
        )}
      </div>
    </div>
  );
}
