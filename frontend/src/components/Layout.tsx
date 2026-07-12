import { Link } from 'react-router-dom';
import { LogOut, Settings, TrendingUp, Info, Landmark } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';

export default function Layout({ children }: { children: React.ReactNode }) {
  const { user, logout } = useAuth();

  const displayName = user
    ? [user.first_name, user.last_name].filter(Boolean).join(' ').trim() || user.username
    : '';

  return (
    <div className="app-layout">
      <header className="app-header">
        <Link to="/" className="app-logo">
          <TrendingUp size={24} />
          <span>Wealth Tracker</span>
        </Link>
        <div className="header-right">
          {user && (
            <>
              <span className="header-user">{displayName}</span>
              <Link to="/ebics" className="btn btn-ghost" title="EBICS bank connections">
                <Landmark size={18} />
              </Link>
              <Link to="/settings" className="btn btn-ghost" title="Settings">
                <Settings size={18} />
              </Link>
              <button onClick={logout} className="btn btn-ghost" title="Logout">
                <LogOut size={18} />
              </button>
            </>
          )}
          <Link to="/imprint" className="btn btn-ghost" title="Imprint">
            <Info size={18} />
          </Link>
        </div>
      </header>
      <main className="app-main">{children}</main>
    </div>
  );
}
