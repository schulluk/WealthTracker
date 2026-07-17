import {
  createContext,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from 'react';
import {
  login as apiLogin,
  register as apiRegister,
  getCurrentUser,
  clearTokens,
  getAccessToken,
} from '../api/client';

interface User {
  id: number;
  username: string;
  email: string;
  first_name?: string;
  last_name?: string;
}

interface AuthContextType {
  user: User | null;
  isAuthenticated: boolean;
  loading: boolean;
  login: (username: string, password: string) => Promise<void>;
  register: (fields: {
    username: string;
    email: string;
    password: string;
    password_confirm: string;
    base_currency: string;
  }) => Promise<void>;
  logout: () => void;
  refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  // Start in the loading state only when a token exists and we still need to
  // fetch the user. With no token there is nothing to load, so loading starts
  // false — this also avoids a synchronous setState inside the effect below.
  const [loading, setLoading] = useState(() => getAccessToken() !== null);

  useEffect(() => {
    const token = getAccessToken();
    if (!token) {
      return;
    }
    getCurrentUser()
      .then(setUser)
      .catch(() => clearTokens())
      .finally(() => setLoading(false));
  }, []);

  const login = async (username: string, password: string) => {
    await apiLogin(username, password);
    const u = await getCurrentUser();
    setUser(u);
  };

  const register = async (fields: {
    username: string;
    email: string;
    password: string;
    password_confirm: string;
    base_currency: string;
  }) => {
    await apiRegister(fields);
    const u = await getCurrentUser();
    setUser(u);
  };

  const logout = () => {
    clearTokens();
    setUser(null);
  };

  const refreshUser = async () => {
    const u = await getCurrentUser();
    setUser(u);
  };

  return (
    <AuthContext.Provider
      value={{ user, isAuthenticated: !!user, loading, login, register, logout, refreshUser }}
    >
      {children}
    </AuthContext.Provider>
  );
}

// This module intentionally exports both the AuthProvider component and the
// useAuth hook (the standard React context pattern). Fast Refresh's
// "only-export-components" rule flags the hook; splitting it into its own
// module would fragment the context with no runtime benefit, so we opt out
// for this one export.
// eslint-disable-next-line react-refresh/only-export-components
export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
