import { useState, useEffect } from 'react';
import { Download, X } from 'lucide-react';
import { getAccounts, getSnapshots } from '../api/client';

interface Account {
  id: number;
  name: string;
  broker: { code: string; name: string };
  currency: string;
}

interface Snapshot {
  id: number;
  balance: string;
  currency: string;
  snapshot_date: string;
}

interface Props {
  onClose: () => void;
}

export default function ExportModal({ onClose }: Props) {
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [selectedAccountId, setSelectedAccountId] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [exporting, setExporting] = useState(false);

  useEffect(() => {
    async function loadAccounts() {
      try {
        const data = await getAccounts();
        // Handle both array and paginated { results: [...] } response
        const accountList = Array.isArray(data) ? data : data.results || [];
        setAccounts(accountList);
        if (accountList.length > 0) {
          setSelectedAccountId(accountList[0].id);
        }
      } catch (err) {
        console.error('Failed to load accounts:', err);
      } finally {
        setLoading(false);
      }
    }
    loadAccounts();
  }, []);

  async function handleExport() {
    if (!selectedAccountId) return;

    setExporting(true);
    try {
      const data = await getSnapshots(selectedAccountId);
      // Handle both array and paginated { results: [...] } response
      const snapshots: Snapshot[] = Array.isArray(data) ? data : data.results || [];
      const account = accounts.find(a => a.id === selectedAccountId);

      if (snapshots.length === 0) {
        alert('No snapshots to export for this account.');
        return;
      }

      // Generate CSV content
      const csvLines = ['date,balance,currency'];
      for (const snap of snapshots) {
        csvLines.push(`${snap.snapshot_date},${snap.balance},${snap.currency}`);
      }
      const csvContent = csvLines.join('\n');

      // Download file
      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `${account?.name.replace(/[^a-z0-9]/gi, '_') || 'account'}_snapshots.csv`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);

      onClose();
    } catch (err) {
      console.error('Export failed:', err);
      alert('Failed to export snapshots.');
    } finally {
      setExporting(false);
    }
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h3>
            <Download size={18} style={{ marginRight: 8 }} />
            Export Snapshots
          </h3>
          <button className="btn btn-ghost" onClick={onClose}>
            <X size={18} />
          </button>
        </div>

        {loading ? (
          <p className="text-muted">Loading accounts...</p>
        ) : accounts.length === 0 ? (
          <p className="text-muted">No accounts available to export.</p>
        ) : (
          <>
            <div className="form-group">
              <label htmlFor="export-account">Select Account</label>
              <select
                id="export-account"
                value={selectedAccountId || ''}
                onChange={(e) => setSelectedAccountId(Number(e.target.value))}
              >
                {accounts.map((account) => (
                  <option key={account.id} value={account.id}>
                    {account.name} ({account.broker.name})
                  </option>
                ))}
              </select>
            </div>

            <p className="form-hint" style={{ marginBottom: 16 }}>
              Export all snapshots for this account as a CSV file.
            </p>

            <div className="form-actions">
              <button type="button" className="btn btn-ghost" onClick={onClose}>
                Cancel
              </button>
              <button
                type="button"
                className="btn btn-primary"
                onClick={handleExport}
                disabled={exporting || !selectedAccountId}
              >
                <Download size={14} />
                {exporting ? 'Exporting...' : 'Export CSV'}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
