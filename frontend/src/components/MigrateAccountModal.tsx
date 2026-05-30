import { useEffect, useState } from 'react';
import { X, Repeat, AlertTriangle, Loader } from 'lucide-react';
import { getBrokers, updateAccount, updateAccountCredentials } from '../api/client';

interface Broker {
  id: number;
  code: string;
  name: string;
  credential_schema: {
    properties?: Record<string, {
      type: string;
      title: string;
      format?: string;
      description?: string;
      default?: boolean;
    }>;
    required?: string[];
  };
}

interface Props {
  account: {
    id: number;
    name: string;
    is_manual: boolean;
    broker: { code: string; name: string };
  };
  onClose: () => void;
  onMigrated: (message: string) => void;
}

type Step = 'select' | 'credentials';

export default function MigrateAccountModal({ account, onClose, onMigrated }: Props) {
  const [brokers, setBrokers] = useState<Broker[]>([]);
  const [loadingBrokers, setLoadingBrokers] = useState(true);
  const [step, setStep] = useState<Step>('select');
  const [targetCode, setTargetCode] = useState('');
  const [credentialValues, setCredentialValues] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    getBrokers()
      .then((data) => {
        const list: Broker[] = data.results ?? data;
        list.sort((a, b) => {
          if (a.code === 'manual') return 1;
          if (b.code === 'manual') return -1;
          return a.name.localeCompare(b.name);
        });
        setBrokers(list);
      })
      .catch(() => setError('Failed to load brokers'))
      .finally(() => setLoadingBrokers(false));
  }, []);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [onClose]);

  const target = brokers.find((b) => b.code === targetCode) ?? null;
  const targetIsManual = targetCode === 'manual';
  const credentialFields = Object.entries(target?.credential_schema?.properties ?? {});
  // Non-manual account currently has stored credentials that will be dropped.
  const willDropCredentials = !account.is_manual;

  const handleContinue = () => {
    if (!targetCode || targetCode === account.broker.code) return;
    setError('');
    if (targetIsManual || credentialFields.length === 0) {
      void doMigrate();
    } else {
      setStep('credentials');
    }
  };

  const doMigrate = async () => {
    setSaving(true);
    setError('');
    try {
      // Changing the broker drops stored credentials server-side (security).
      await updateAccount(account.id, {
        broker_code: targetCode,
        is_manual: targetIsManual,
      });
      // Optionally seed credentials for the new broker (account is now non-manual,
      // so the credentials endpoint will accept them).
      if (!targetIsManual) {
        const creds = Object.fromEntries(
          Object.entries(credentialValues).filter(([, v]) => v && v.trim()),
        );
        if (Object.keys(creds).length > 0) {
          await updateAccountCredentials(account.id, creds);
        }
      }
      onMigrated(`${account.name} changed to ${target?.name ?? targetCode}`);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to change account type');
      setSaving(false);
    }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h3>
            <Repeat size={18} style={{ marginRight: 8 }} />
            Change Account Type
          </h3>
          <button className="btn btn-ghost" onClick={onClose}>
            <X size={18} />
          </button>
        </div>

        {error && <div className="form-error" style={{ marginBottom: 16 }}>{error}</div>}

        {step === 'select' && (
          <form onSubmit={(e) => { e.preventDefault(); handleContinue(); }}>
            <p className="form-hint" style={{ marginBottom: 16 }}>
              Change <strong>{account.name}</strong> from{' '}
              <strong>{account.is_manual ? 'Manual' : account.broker.name}</strong> to another type.
              Balance history is preserved.
            </p>

            <div className="form-group">
              <label htmlFor="migrate-target">New account type</label>
              {loadingBrokers ? (
                <p className="form-hint">Loading brokers...</p>
              ) : (
                <select
                  id="migrate-target"
                  required
                  value={targetCode}
                  onChange={(e) => { setTargetCode(e.target.value); setCredentialValues({}); }}
                >
                  <option value="">Select a type...</option>
                  {brokers.map((b) => (
                    <option key={b.code} value={b.code} disabled={b.code === account.broker.code}>
                      {b.code === 'manual' ? 'Manual Entry' : b.name}
                      {b.code === account.broker.code ? ' (current)' : ''}
                    </option>
                  ))}
                </select>
              )}
            </div>

            {willDropCredentials && (
              <div className="form-warning" style={{ display: 'flex', gap: 8, alignItems: 'flex-start', marginBottom: 16 }}>
                <AlertTriangle size={16} style={{ flexShrink: 0, marginTop: 2 }} />
                <span>
                  The stored credentials for <strong>{account.broker.name}</strong> will be
                  permanently deleted. You'll need to re-enter them, even if you switch back.
                </span>
              </div>
            )}

            <div className="form-actions">
              <button type="button" className="btn btn-ghost" onClick={onClose}>Cancel</button>
              <button
                type="submit"
                className="btn btn-primary"
                disabled={!targetCode || targetCode === account.broker.code || saving}
              >
                {saving ? <><Loader size={14} className="spin" style={{ marginRight: 6 }} />Changing...</> : 'Continue'}
              </button>
            </div>
          </form>
        )}

        {step === 'credentials' && target && (
          <form onSubmit={(e) => { e.preventDefault(); void doMigrate(); }}>
            <p className="form-hint" style={{ marginBottom: 16 }}>
              Add credentials for <strong>{target.name}</strong> now, or skip and add them later.
            </p>
            <fieldset className="form-fieldset">
              <legend>Credentials</legend>
              {credentialFields.map(([key, field]) => (
                field.type === 'boolean' ? (
                  <div className="form-group" key={key}>
                    <label className="toggle-label">
                      <input
                        type="checkbox"
                        checked={String(credentialValues[key] ?? field.default ?? false).toLowerCase() === 'true'}
                        onChange={(e) => setCredentialValues((prev) => ({ ...prev, [key]: e.target.checked ? 'true' : 'false' }))}
                      />
                      <span>{field.title || key}</span>
                    </label>
                    {field.description && <small className="form-hint">{field.description}</small>}
                  </div>
                ) : (
                  <div className="form-group" key={key}>
                    <label htmlFor={`migrate-cred-${key}`}>{field.title || key}</label>
                    <input
                      id={`migrate-cred-${key}`}
                      type={field.format === 'password' ? 'password' : 'text'}
                      value={credentialValues[key] ?? ''}
                      onChange={(e) => setCredentialValues((prev) => ({ ...prev, [key]: e.target.value }))}
                      placeholder={field.description || ''}
                    />
                    {field.description && <small className="form-hint">{field.description}</small>}
                  </div>
                )
              ))}
            </fieldset>

            <div className="form-actions">
              <button type="button" className="btn btn-ghost" onClick={() => setStep('select')} disabled={saving}>
                Back
              </button>
              <button type="button" className="btn btn-ghost" onClick={() => void doMigrate()} disabled={saving}>
                Skip for now
              </button>
              <button type="submit" className="btn btn-primary" disabled={saving}>
                {saving ? <><Loader size={14} className="spin" style={{ marginRight: 6 }} />Changing...</> : 'Change & Save'}
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}
