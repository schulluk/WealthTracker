import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type FormEvent,
  type ReactNode,
} from 'react';
import { Lock, X, Loader } from 'lucide-react';
import { setKekRecoveryHandler, getCurrentUser } from '../api/client';
import { useAuth } from './AuthContext';

/**
 * Bridges the imperative KEK-recovery handler (called from fetchWithAuth when an
 * encrypted request 403s with "KEK required") to a password modal. On submit it
 * reuses the validated login() to re-derive and store the KEK; the original
 * request is then retried automatically. Resolving false (cancel) lets the
 * caller surface the original 403.
 */
export function UnlockProvider({ children }: { children: ReactNode }) {
  const { user, login } = useAuth();
  const [open, setOpen] = useState(false);
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const resolverRef = useRef<((ok: boolean) => void) | null>(null);

  useEffect(() => {
    setKekRecoveryHandler(
      () =>
        new Promise<boolean>((resolve) => {
          resolverRef.current = resolve;
          setPassword('');
          setError('');
          setBusy(false);
          setOpen(true);
        }),
    );
    return () => setKekRecoveryHandler(null);
  }, []);

  const finish = useCallback((ok: boolean) => {
    setOpen(false);
    setBusy(false);
    setPassword('');
    setError('');
    const resolve = resolverRef.current;
    resolverRef.current = null;
    resolve?.(ok);
  }, []);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError('');
    try {
      const username = user?.username ?? (await getCurrentUser()).username;
      // Re-derives and stores the KEK in sessionStorage, validating the password.
      await login(username, password);
      finish(true);
    } catch {
      setBusy(false);
      setError('Incorrect password. Please try again.');
    }
  };

  return (
    <>
      {children}
      {open && (
        <div className="modal-overlay" onClick={() => finish(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 420 }}>
            <div className="modal-header">
              <h3>
                <Lock size={18} style={{ marginRight: 8 }} />
                Unlock encrypted data
              </h3>
              <button className="btn btn-ghost" onClick={() => finish(false)}>
                <X size={18} />
              </button>
            </div>

            <p className="form-hint" style={{ marginBottom: 16 }}>
              This tab’s session key has expired. Enter your password to unlock your
              stored credentials — it’s used locally to re-derive your encryption key.
            </p>

            {error && <div className="form-error" style={{ marginBottom: 16 }}>{error}</div>}

            <form onSubmit={submit}>
              <div className="form-group">
                <label htmlFor="unlock-password">Password</label>
                <input
                  id="unlock-password"
                  type="password"
                  autoFocus
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  disabled={busy}
                />
              </div>
              <div className="form-actions">
                <button type="button" className="btn btn-ghost" onClick={() => finish(false)} disabled={busy}>
                  Cancel
                </button>
                <button type="submit" className="btn btn-primary" disabled={busy || !password}>
                  {busy ? (
                    <><Loader size={14} className="spin" style={{ marginRight: 6 }} />Unlocking...</>
                  ) : (
                    'Unlock'
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  );
}
