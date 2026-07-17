import { useState, useRef, useEffect } from 'react';
import { X, Upload, FileText, AlertCircle, CheckCircle2 } from 'lucide-react';
import { getAccounts, importCSV } from '../api/client';

interface Account {
  id: number;
  name: string;
  broker: { code: string; name: string };
  currency: string;
}

interface Props {
  onClose: () => void;
  onImported: () => void;
}

interface ImportResult {
  imported: number;
  skipped: number;
  errors: string[];
  total_errors: number;
}

export default function ImportModal({ onClose, onImported }: Props) {
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [selectedAccountId, setSelectedAccountId] = useState<number | null>(null);
  const [csvContent, setCsvContent] = useState('');
  const [fileName, setFileName] = useState('');
  const [skipDuplicates, setSkipDuplicates] = useState(true);
  const [loading, setLoading] = useState(true);
  const [importing, setImporting] = useState(false);
  const [error, setError] = useState('');
  const [result, setResult] = useState<ImportResult | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Load accounts on mount
  useEffect(() => {
    getAccounts()
      .then((data) => {
        const list = data.results ?? data;
        setAccounts(list);
      })
      .catch(() => setError('Failed to load accounts'))
      .finally(() => setLoading(false));
  }, []);

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setFileName(file.name);
    setError('');
    setResult(null);

    const reader = new FileReader();
    reader.onload = (event) => {
      const content = event.target?.result as string;
      setCsvContent(content);
    };
    reader.onerror = () => {
      setError('Failed to read file');
    };
    reader.readAsText(file);
  };

  const handleImport = async () => {
    if (!selectedAccountId || !csvContent) return;

    setImporting(true);
    setError('');
    setResult(null);

    try {
      const importResult = await importCSV(selectedAccountId, csvContent, skipDuplicates);
      setResult(importResult);

      if (importResult.imported > 0) {
        onImported();
      }
    } catch (err) {
      setError(err instanceof Error && err.message ? err.message : 'Import failed');
    } finally {
      setImporting(false);
    }
  };

  const previewLines = csvContent
    ? csvContent.split('\n').slice(0, 6).join('\n')
    : '';

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal modal-lg" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h3>
            <Upload size={18} style={{ marginRight: 8 }} />
            Import CSV Data
          </h3>
          <button className="btn btn-ghost" onClick={onClose}>
            <X size={18} />
          </button>
        </div>

        {error && <div className="form-error">{error}</div>}

        {result && (
          <div className={`import-result ${result.imported > 0 ? 'success' : 'warning'}`}>
            <div className="import-result-icon">
              {result.imported > 0 ? (
                <CheckCircle2 size={24} />
              ) : (
                <AlertCircle size={24} />
              )}
            </div>
            <div className="import-result-text">
              <p>
                <strong>{result.imported}</strong> snapshots imported
                {result.skipped > 0 && `, ${result.skipped} skipped (duplicates)`}
              </p>
              {result.total_errors > 0 && (
                <details className="import-errors">
                  <summary>{result.total_errors} errors</summary>
                  <ul>
                    {result.errors.map((err, i) => (
                      <li key={i}>{err}</li>
                    ))}
                    {result.total_errors > result.errors.length && (
                      <li>...and {result.total_errors - result.errors.length} more</li>
                    )}
                  </ul>
                </details>
              )}
            </div>
          </div>
        )}

        <div className="form-group">
          <label htmlFor="import-account">Select Account</label>
          {loading ? (
            <p className="form-hint">Loading accounts...</p>
          ) : (
            <select
              id="import-account"
              value={selectedAccountId ?? ''}
              onChange={(e) => setSelectedAccountId(Number(e.target.value) || null)}
            >
              <option value="">Select an account...</option>
              {accounts.map((acc) => (
                <option key={acc.id} value={acc.id}>
                  {acc.name} ({acc.broker.name}) - {acc.currency}
                </option>
              ))}
            </select>
          )}
        </div>

        <div className="form-group">
          <label>CSV File</label>
          <input
            type="file"
            accept=".csv,text/csv"
            ref={fileInputRef}
            onChange={handleFileSelect}
            style={{ display: 'none' }}
          />
          <div className="file-upload-area" onClick={() => fileInputRef.current?.click()}>
            {fileName ? (
              <div className="file-selected">
                <FileText size={24} />
                <span>{fileName}</span>
              </div>
            ) : (
              <div className="file-placeholder">
                <Upload size={24} />
                <span>Click to select a CSV file</span>
              </div>
            )}
          </div>
          <p className="form-hint">
            Expected format: date, balance, currency (e.g., 2025-01-26,77047,CHF)
          </p>
        </div>

        {previewLines && (
          <div className="form-group">
            <label>Preview</label>
            <pre className="csv-preview">{previewLines}</pre>
          </div>
        )}

        <div className="form-group">
          <label className="checkbox-label">
            <input
              type="checkbox"
              checked={skipDuplicates}
              onChange={(e) => setSkipDuplicates(e.target.checked)}
            />
            Skip duplicate dates (don't overwrite existing snapshots)
          </label>
        </div>

        <div className="form-actions">
          <button type="button" className="btn btn-ghost" onClick={onClose}>
            Close
          </button>
          <button
            className="btn btn-primary"
            onClick={handleImport}
            disabled={!selectedAccountId || !csvContent || importing}
          >
            {importing ? 'Importing...' : 'Import Data'}
          </button>
        </div>
      </div>
    </div>
  );
}
