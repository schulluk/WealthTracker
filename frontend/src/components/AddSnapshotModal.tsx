import { useState, useEffect } from 'react';
import { X } from 'lucide-react';
import { addSnapshot } from '../api/client';

interface Props {
  accountId: number;
  accountName: string;
  defaultCurrency: string;
  onClose: () => void;
  onSaved: () => void;
}

export default function AddSnapshotModal({
  accountId,
  accountName,
  defaultCurrency,
  onClose,
  onSaved,
}: Props) {
  const [balance, setBalance] = useState('');
  const [currency, setCurrency] = useState(defaultCurrency);
  const [date, setDate] = useState(new Date().toISOString().slice(0, 10));
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);

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

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setSaving(true);
    try {
      await addSnapshot(accountId, parseFloat(balance), currency, date);
      onSaved();
    } catch (err) {
      setError(err instanceof Error && err.message ? err.message : 'Failed to save');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h3>Add Snapshot - {accountName}</h3>
          <button className="btn btn-ghost" onClick={onClose}>
            <X size={18} />
          </button>
        </div>
        <form onSubmit={handleSubmit}>
          {error && <div className="form-error">{error}</div>}
          <div className="form-group">
            <label htmlFor="balance">Balance</label>
            <input
              id="balance"
              type="number"
              step="0.01"
              required
              autoFocus
              value={balance}
              onChange={(e) => setBalance(e.target.value)}
              placeholder="0.00"
            />
          </div>
          <div className="form-group">
            <label htmlFor="date">Date</label>
            <input
              id="date"
              type="date"
              required
              value={date}
              onChange={(e) => setDate(e.target.value)}
            />
          </div>
          <div className="form-group">
            <label>Currency</label>
            <div className="button-group">
              {['EUR', 'USD', 'CHF', 'GBP'].map((c) => (
                <button
                  key={c}
                  type="button"
                  className={`btn btn-sm ${currency === c ? 'btn-primary' : 'btn-ghost'}`}
                  onClick={() => setCurrency(c)}
                >
                  {c}
                </button>
              ))}
            </div>
          </div>
          <div className="form-actions">
            <button type="button" className="btn btn-ghost" onClick={onClose}>
              Cancel
            </button>
            <button type="submit" className="btn btn-primary" disabled={saving}>
              {saving ? 'Saving...' : 'Save'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
