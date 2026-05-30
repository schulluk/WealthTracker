import { useEffect, useState } from 'react';
import { X, Search, Loader, Check, Shield } from 'lucide-react';
import {
  getBrokers,
  createAccount,
  discoverAccounts,
  createAccountsBulk,
  completeDiscoveryAuth,
} from '../api/client';

interface Broker {
  id: number;
  code: string;
  name: string;
  supports_2fa: boolean;
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

interface DiscoveredAccount {
  identifier: string;
  name: string;
  account_type: string;
  currency: string;
  balance: number | null;
}

interface Props {
  onClose: () => void;
  onCreated: () => void;
}

type Step = 'credentials' | 'discovering' | 'select' | 'manual' | 'confirm-skip' | '2fa';

interface ChallengeData {
  challenge?: string;
  challenge_html?: string;
}

export default function AddAccountModal({ onClose, onCreated }: Props) {
  const [brokers, setBrokers] = useState<Broker[]>([]);
  const [selectedBroker, setSelectedBroker] = useState<Broker | null>(null);
  const [credentials, setCredentials] = useState<Record<string, string>>({});
  const [error, setError] = useState('');
  const [loadingBrokers, setLoadingBrokers] = useState(true);

  // Discovery state
  const [step, setStep] = useState<Step>('credentials');
  const [discovered, setDiscovered] = useState<DiscoveredAccount[]>([]);
  const [selected, setSelected] = useState<Set<string>>(new Set());

  // Manual account state
  const [manualName, setManualName] = useState('');
  const [manualCurrency, setManualCurrency] = useState('CHF');
  const [manualType, setManualType] = useState('checking');
  const [saving, setSaving] = useState(false);

  // Skip credentials state
  const [skipName, setSkipName] = useState('');
  const [skipCurrency, setSkipCurrency] = useState('CHF');
  const [skipType, setSkipType] = useState('brokerage');

  // 2FA state
  const [sessionToken, setSessionToken] = useState('');
  const [twoFaType, setTwoFaType] = useState('');
  const [challengeData, setChallengeData] = useState<ChallengeData | null>(null);
  const [tanCode, setTanCode] = useState('');
  const [submitting2fa, setSubmitting2fa] = useState(false);

  useEffect(() => {
    getBrokers()
      .then((data) => {
        const list = data.results ?? data;
        // Sort brokers: Manual Entry always last
        list.sort((a: Broker, b: Broker) => {
          if (a.code === 'manual') return 1;
          if (b.code === 'manual') return -1;
          return a.name.localeCompare(b.name);
        });
        setBrokers(list);
      })
      .catch(() => setError('Failed to load brokers'))
      .finally(() => setLoadingBrokers(false));
  }, []);

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

  const handleBrokerChange = (code: string) => {
    const broker = brokers.find((b) => b.code === code) ?? null;
    setSelectedBroker(broker);
    setCredentials({});
    setError('');
    setStep(broker?.code === 'manual' ? 'manual' : 'credentials');
    if (broker) {
      setManualName(broker.name);
      setSkipName(broker.name);
    }
  };

  const handleSkipCredentials = () => {
    if (!selectedBroker) return;
    setSkipName(selectedBroker.name);
    setStep('confirm-skip');
  };

  const handleSkipSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedBroker) return;
    setError('');
    setSaving(true);
    try {
      await createAccount({
        name: skipName,
        broker_code: selectedBroker.code,
        account_type: skipType,
        currency: skipCurrency,
        is_manual: true,
      });
      onCreated();
    } catch (err: any) {
      setError(err.message || 'Failed to create account');
    } finally {
      setSaving(false);
    }
  };

  const requiredCreds = selectedBroker?.credential_schema?.required ?? [];
  // Sort credential fields: required fields first (in order), then optional fields
  const credentialFields = selectedBroker?.credential_schema?.properties
    ? Object.entries(selectedBroker.credential_schema.properties).sort(([keyA], [keyB]) => {
        const indexA = requiredCreds.indexOf(keyA);
        const indexB = requiredCreds.indexOf(keyB);
        // Required fields come first, in the order they appear in required array
        if (indexA !== -1 && indexB !== -1) return indexA - indexB;
        if (indexA !== -1) return -1;
        if (indexB !== -1) return 1;
        // Optional fields maintain their original order
        return 0;
      })
    : [];

  const handleDiscover = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedBroker) return;
    setError('');
    setStep('discovering');
    try {
      const result = await discoverAccounts(selectedBroker.code, credentials);
      if (result.status === 'pending_auth') {
        // 2FA required - show TAN entry
        setSessionToken(result.session_token || '');
        setTwoFaType(result.two_fa_type || 'tan');
        setChallengeData(result.challenge || null);
        setTanCode('');
        setStep('2fa');
        return;
      }
      setDiscovered(result.accounts);
      setSelected(new Set(result.accounts.map((a: DiscoveredAccount) => a.identifier)));
      setStep('select');
    } catch (err: any) {
      setError(err.message || 'Discovery failed');
      setStep('credentials');
    }
  };

  const handleSubmit2fa = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!sessionToken) {
      setError('Session expired. Please restart discovery.');
      setStep('credentials');
      return;
    }
    setError('');
    setSubmitting2fa(true);
    try {
      const result = await completeDiscoveryAuth(sessionToken, tanCode);
      if (result.status === 'pending_auth') {
        // Still pending (e.g., decoupled TAN waiting)
        setChallengeData(result.challenge || null);
        setError(result.message || 'Still waiting for authentication...');
        return;
      }
      setDiscovered(result.accounts);
      setSelected(new Set(result.accounts.map((a: DiscoveredAccount) => a.identifier)));
      setStep('select');
    } catch (err: any) {
      setError(err.message || 'Authentication failed');
    } finally {
      setSubmitting2fa(false);
    }
  };

  const toggleAccount = (identifier: string) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(identifier)) next.delete(identifier);
      else next.add(identifier);
      return next;
    });
  };

  const handleImport = async () => {
    if (!selectedBroker || selected.size === 0) return;
    setError('');
    setSaving(true);
    try {
      const accountsToCreate = discovered.filter((a) => selected.has(a.identifier));
      await createAccountsBulk(selectedBroker.code, credentials, accountsToCreate);
      onCreated();
    } catch (err: any) {
      setError(err.message || 'Failed to create accounts');
    } finally {
      setSaving(false);
    }
  };

  const handleManualSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedBroker) return;
    setError('');
    setSaving(true);
    try {
      await createAccount({
        name: manualName,
        broker_code: selectedBroker.code,
        account_type: manualType,
        currency: manualCurrency,
        is_manual: true,
      });
      onCreated();
    } catch (err: any) {
      setError(err.message || 'Failed to create account');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal modal-wide" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h3>
            {step === 'select' ? 'Select Accounts' :
             step === 'discovering' ? 'Discovering Accounts' :
             step === '2fa' ? 'Authentication Required' :
             step === 'confirm-skip' ? 'Add Manual Account' :
             'Add Account'}
          </h3>
          <button className="btn btn-ghost" onClick={onClose}>
            <X size={18} />
          </button>
        </div>

        {error && <div className="form-error">{error}</div>}

        {/* Step: Discovering (loading) */}
        {step === 'discovering' && (
          <div className="discover-loading">
            <Loader size={32} className="spin" />
            <p>Authenticating with {selectedBroker?.name}...</p>
            {selectedBroker?.supports_2fa && (
              <p className="form-hint">
                Check your phone for a push notification to approve the login.
              </p>
            )}
          </div>
        )}

        {/* Step: 2FA / TAN entry */}
        {step === '2fa' && (
          <form onSubmit={handleSubmit2fa}>
            <div className="twofa-header">
              <Shield size={32} />
              <h4>Two-Factor Authentication</h4>
            </div>

            {challengeData?.challenge_html ? (
              <div
                className="twofa-challenge"
                dangerouslySetInnerHTML={{ __html: challengeData.challenge_html }}
              />
            ) : challengeData?.challenge ? (
              <div className="twofa-challenge">
                <p className="form-hint">{challengeData.challenge}</p>
              </div>
            ) : (
              <p className="form-hint">
                {twoFaType === 'tan'
                  ? 'Please enter the TAN code from your banking app or TAN generator.'
                  : 'Please enter the authentication code.'}
              </p>
            )}

            <div className="form-group">
              <label htmlFor="tanCode">
                {twoFaType === 'tan' ? 'TAN Code' : 'Authentication Code'}
              </label>
              <input
                id="tanCode"
                type="text"
                inputMode="numeric"
                pattern="[0-9]*"
                autoComplete="one-time-code"
                autoFocus
                required
                value={tanCode}
                onChange={(e) => setTanCode(e.target.value)}
                placeholder="Enter code..."
                disabled={submitting2fa}
              />
            </div>

            <div className="form-actions">
              <button
                type="button"
                className="btn btn-ghost"
                onClick={() => {
                  setSessionToken('');
                  setChallengeData(null);
                  setTanCode('');
                  setStep('credentials');
                }}
                disabled={submitting2fa}
              >
                Cancel
              </button>
              <button
                type="submit"
                className="btn btn-primary"
                disabled={submitting2fa || !tanCode.trim()}
              >
                {submitting2fa ? (
                  <>
                    <Loader size={14} className="spin" />
                    Verifying...
                  </>
                ) : (
                  'Verify'
                )}
              </button>
            </div>
          </form>
        )}

        {/* Step: Credentials */}
        {step === 'credentials' && (
          <form onSubmit={handleDiscover}>
            <div className="form-group">
              <label htmlFor="broker">Broker</label>
              {loadingBrokers ? (
                <p className="form-hint">Loading brokers...</p>
              ) : (
                <select
                  id="broker"
                  required
                  value={selectedBroker?.code ?? ''}
                  onChange={(e) => handleBrokerChange(e.target.value)}
                >
                  <option value="">Select a broker...</option>
                  {brokers.map((b) => (
                    <option key={b.code} value={b.code}>{b.name}</option>
                  ))}
                </select>
              )}
            </div>

            {selectedBroker && credentialFields.length > 0 && (
              <fieldset className="form-fieldset">
                <legend>Credentials</legend>
                {credentialFields.map(([key, field]) => (
                  field.type === 'boolean' ? (
                    <div className="form-group" key={key}>
                      <label className="toggle-label">
                        <input
                          type="checkbox"
                          checked={String(credentials[key] ?? field.default ?? false).toLowerCase() === 'true'}
                          onChange={(e) =>
                            setCredentials((prev) => ({ ...prev, [key]: e.target.checked ? 'true' : 'false' }))
                          }
                        />
                        <span>{field.title}</span>
                      </label>
                      {field.description && <small className="form-hint">{field.description}</small>}
                    </div>
                  ) : (
                    <div className="form-group" key={key}>
                      <label htmlFor={`cred-${key}`}>
                        {field.title}
                        {requiredCreds.includes(key) ? '' : ' (optional)'}
                      </label>
                      <input
                        id={`cred-${key}`}
                        type={field.format === 'password' ? 'password' : 'text'}
                        required={requiredCreds.includes(key)}
                        value={credentials[key] ?? ''}
                        onChange={(e) =>
                          setCredentials((prev) => ({ ...prev, [key]: e.target.value }))
                        }
                        placeholder={field.description}
                      />
                    </div>
                  )
                ))}
                <p className="form-hint" style={{ marginTop: 8 }}>
                  Don't have credentials?{' '}
                  <button
                    type="button"
                    className="btn-link"
                    onClick={handleSkipCredentials}
                  >
                    Add without auto-sync
                  </button>
                </p>
              </fieldset>
            )}

            <div className="form-actions">
              <button type="button" className="btn btn-ghost" onClick={onClose}>
                Cancel
              </button>
              <button
                type="submit"
                className="btn btn-primary"
                disabled={!selectedBroker}
              >
                <Search size={14} />
                Discover Accounts
              </button>
            </div>
          </form>
        )}

        {/* Step: Select discovered accounts */}
        {step === 'select' && (
          <div>
            <p className="form-hint" style={{ marginBottom: 12 }}>
              Found {discovered.length} account{discovered.length !== 1 ? 's' : ''}.
              Select which to import:
            </p>
            <div className="discover-list">
              {discovered.map((a) => (
                <label key={a.identifier} className="discover-item">
                  <input
                    type="checkbox"
                    checked={selected.has(a.identifier)}
                    onChange={() => toggleAccount(a.identifier)}
                  />
                  <div className="discover-item-info">
                    <span className="discover-item-name">
                      {a.name}
                      {a.balance != null && (
                        <span style={{ fontWeight: 400, marginLeft: 8, color: 'var(--color-text-muted)' }}>
                          {new Intl.NumberFormat('de-CH', { style: 'currency', currency: a.currency }).format(a.balance)}
                        </span>
                      )}
                    </span>
                    <span className="discover-item-meta">
                      {a.identifier} &middot; {a.currency} &middot; {a.account_type}
                    </span>
                  </div>
                </label>
              ))}
            </div>
            <div className="form-actions">
              <button
                type="button"
                className="btn btn-ghost"
                onClick={() => setStep('credentials')}
              >
                Back
              </button>
              <button
                className="btn btn-primary"
                disabled={selected.size === 0 || saving}
                onClick={handleImport}
              >
                <Check size={14} />
                {saving
                  ? 'Importing...'
                  : `Import ${selected.size} Account${selected.size !== 1 ? 's' : ''}`}
              </button>
            </div>
          </div>
        )}

        {/* Step: Manual account */}
        {step === 'manual' && (
          <form onSubmit={handleManualSubmit}>
            <div className="form-group">
              <label htmlFor="broker">Broker</label>
              <select
                id="broker"
                required
                value={selectedBroker?.code ?? ''}
                onChange={(e) => handleBrokerChange(e.target.value)}
              >
                <option value="">Select a broker...</option>
                {brokers.map((b) => (
                  <option key={b.code} value={b.code}>{b.name}</option>
                ))}
              </select>
            </div>

            <div className="form-group">
              <label htmlFor="manualName">Account Name</label>
              <input
                id="manualName"
                type="text"
                required
                value={manualName}
                onChange={(e) => setManualName(e.target.value)}
                placeholder="e.g. My Savings Account"
              />
            </div>
            <div className="form-row">
              <div className="form-group">
                <label htmlFor="manualType">Account Type</label>
                <select
                  id="manualType"
                  value={manualType}
                  onChange={(e) => setManualType(e.target.value)}
                >
                  <option value="checking">Checking</option>
                  <option value="savings">Savings</option>
                  <option value="brokerage">Brokerage</option>
                  <option value="retirement">Retirement</option>
                  <option value="crypto">Crypto</option>
                  <option value="other">Other</option>
                </select>
              </div>
              <div className="form-group">
                <label htmlFor="manualCurrency">Currency</label>
                <select
                  id="manualCurrency"
                  value={manualCurrency}
                  onChange={(e) => setManualCurrency(e.target.value)}
                >
                  <option value="CHF">CHF</option>
                  <option value="EUR">EUR</option>
                  <option value="USD">USD</option>
                  <option value="GBP">GBP</option>
                </select>
              </div>
            </div>
            <div className="form-actions">
              <button type="button" className="btn btn-ghost" onClick={onClose}>
                Cancel
              </button>
              <button type="submit" className="btn btn-primary" disabled={saving}>
                {saving ? 'Creating...' : 'Create Account'}
              </button>
            </div>
          </form>
        )}

        {/* Step: Confirm skip credentials */}
        {step === 'confirm-skip' && (
          <form onSubmit={handleSkipSubmit}>
            <div className="form-notice">
              <p>
                This account will be created under <strong>{selectedBroker?.name}</strong> but
                without credentials. You'll need to add balances manually.
              </p>
            </div>

            <div className="form-group">
              <label htmlFor="skipName">Account Name</label>
              <input
                id="skipName"
                type="text"
                required
                value={skipName}
                onChange={(e) => setSkipName(e.target.value)}
                placeholder="e.g. My Brokerage Account"
              />
            </div>
            <div className="form-row">
              <div className="form-group">
                <label htmlFor="skipType">Account Type</label>
                <select
                  id="skipType"
                  value={skipType}
                  onChange={(e) => setSkipType(e.target.value)}
                >
                  <option value="checking">Checking</option>
                  <option value="savings">Savings</option>
                  <option value="brokerage">Brokerage</option>
                  <option value="retirement">Retirement</option>
                  <option value="crypto">Crypto</option>
                  <option value="other">Other</option>
                </select>
              </div>
              <div className="form-group">
                <label htmlFor="skipCurrency">Currency</label>
                <select
                  id="skipCurrency"
                  value={skipCurrency}
                  onChange={(e) => setSkipCurrency(e.target.value)}
                >
                  <option value="CHF">CHF</option>
                  <option value="EUR">EUR</option>
                  <option value="USD">USD</option>
                  <option value="GBP">GBP</option>
                </select>
              </div>
            </div>
            <div className="form-actions">
              <button
                type="button"
                className="btn btn-ghost"
                onClick={() => setStep('credentials')}
              >
                Back
              </button>
              <button type="submit" className="btn btn-primary" disabled={saving}>
                {saving ? 'Creating...' : 'Create Manual Account'}
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}
