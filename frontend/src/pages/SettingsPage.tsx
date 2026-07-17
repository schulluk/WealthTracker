import { useState, useEffect } from 'react';
import { Save, Key, User, Bell } from 'lucide-react';
import {
  getProfile,
  updateProfile,
  updateUser,
  changePassword,
} from '../api/client';
import { useAuth } from '../contexts/AuthContext';

interface UserData {
  id: number;
  username: string;
  email: string;
  first_name: string;
  last_name: string;
}

interface Profile {
  user: UserData;
  base_currency: string;
  auto_sync_enabled: boolean;
  send_weekly_report: boolean;
  default_chart_range: number;
  default_chart_granularity: 'daily' | 'monthly';
}

const CURRENCIES = ['EUR', 'USD', 'CHF', 'GBP'];

const CHART_RANGES = [
  { value: 30, label: '30d' },
  { value: 90, label: '90d' },
  { value: 180, label: '6m' },
  { value: 365, label: '1y' },
  { value: 730, label: '2y' },
  { value: 3650, label: 'All' },
];

export default function SettingsPage() {
  const { refreshUser } = useAuth();
  const [, setProfile] = useState<Profile | null>(null);
  const [user, setUser] = useState<UserData | null>(null);
  const [loading, setLoading] = useState(true);

  // Profile form
  const [baseCurrency, setBaseCurrency] = useState('EUR');
  const [autoSyncEnabled, setAutoSyncEnabled] = useState(true);
  const [sendWeeklyReport, setSendWeeklyReport] = useState(false);
  const [defaultChartRange, setDefaultChartRange] = useState(365);
  const [defaultChartGranularity, setDefaultChartGranularity] = useState<'daily' | 'monthly'>('daily');
  const [profileSaving, setProfileSaving] = useState(false);
  const [profileMessage, setProfileMessage] = useState('');

  // User form
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [email, setEmail] = useState('');
  const [userSaving, setUserSaving] = useState(false);
  const [userMessage, setUserMessage] = useState('');

  // Password form
  const [oldPassword, setOldPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [passwordSaving, setPasswordSaving] = useState(false);
  const [passwordMessage, setPasswordMessage] = useState('');
  const [passwordError, setPasswordError] = useState('');

  useEffect(() => {
    async function loadData() {
      try {
        const profileData = await getProfile();
        setProfile(profileData);
        setUser(profileData.user);

        setBaseCurrency(profileData.base_currency);
        setAutoSyncEnabled(profileData.auto_sync_enabled);
        setSendWeeklyReport(profileData.send_weekly_report);
        setDefaultChartRange(profileData.default_chart_range);
        setDefaultChartGranularity(profileData.default_chart_granularity);

        setFirstName(profileData.user.first_name || '');
        setLastName(profileData.user.last_name || '');
        setEmail(profileData.user.email || '');
      } catch (err) {
        console.error('Failed to load settings:', err);
      } finally {
        setLoading(false);
      }
    }
    loadData();
  }, []);

  async function handleProfileSave(e: React.FormEvent) {
    e.preventDefault();
    setProfileSaving(true);
    setProfileMessage('');
    try {
      await updateProfile({
        base_currency: baseCurrency,
        auto_sync_enabled: autoSyncEnabled,
        send_weekly_report: sendWeeklyReport,
        default_chart_range: defaultChartRange,
        default_chart_granularity: defaultChartGranularity,
      });
      setProfileMessage('Preferences saved');
    } catch (err) {
      setProfileMessage(err instanceof Error && err.message ? err.message : 'Failed to save');
    } finally {
      setProfileSaving(false);
    }
  }

  async function handleUserSave(e: React.FormEvent) {
    e.preventDefault();
    setUserSaving(true);
    setUserMessage('');
    try {
      await updateUser({
        first_name: firstName,
        last_name: lastName,
        email,
      });
      await refreshUser();
      setUserMessage('User details saved successfully');
    } catch (err) {
      setUserMessage(err instanceof Error && err.message ? err.message : 'Failed to save');
    } finally {
      setUserSaving(false);
    }
  }

  async function handlePasswordChange(e: React.FormEvent) {
    e.preventDefault();
    setPasswordError('');
    setPasswordMessage('');

    if (newPassword !== confirmPassword) {
      setPasswordError('Passwords do not match');
      return;
    }

    if (newPassword.length < 8) {
      setPasswordError('Password must be at least 8 characters');
      return;
    }

    setPasswordSaving(true);
    try {
      await changePassword(oldPassword, newPassword, confirmPassword);
      setPasswordMessage('Password changed successfully');
      setOldPassword('');
      setNewPassword('');
      setConfirmPassword('');
    } catch (err) {
      setPasswordError(err instanceof Error && err.message ? err.message : 'Failed to change password');
    } finally {
      setPasswordSaving(false);
    }
  }

  if (loading) {
    return <div className="loading">Loading...</div>;
  }

  return (
    <div className="settings-page">
      <h1>Settings</h1>

      <div className="settings-grid">
        {/* User Details */}
        <section className="settings-section">
          <h2>
            <User size={20} />
            User Details
          </h2>
          <form onSubmit={handleUserSave}>
            <div className="form-group">
              <label>Username</label>
              <input type="text" value={user?.username || ''} disabled />
            </div>
            <div className="form-row">
              <div className="form-group">
                <label>First Name</label>
                <input
                  type="text"
                  value={firstName}
                  onChange={(e) => setFirstName(e.target.value)}
                />
              </div>
              <div className="form-group">
                <label>Last Name</label>
                <input
                  type="text"
                  value={lastName}
                  onChange={(e) => setLastName(e.target.value)}
                />
              </div>
            </div>
            <div className="form-group">
              <label>Email</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </div>
            <div className="form-actions">
              {userMessage && <span className="form-message success">{userMessage}</span>}
              <button type="submit" className="btn btn-primary" disabled={userSaving}>
                <Save size={16} />
                {userSaving ? 'Saving...' : 'Save Details'}
              </button>
            </div>
          </form>
        </section>

        {/* Profile Settings */}
        <section className="settings-section">
          <h2>
            <Bell size={20} />
            Preferences
          </h2>
          <form onSubmit={handleProfileSave}>
            <div className="form-group">
              <label>Base Currency</label>
              <select
                value={baseCurrency}
                onChange={(e) => setBaseCurrency(e.target.value)}
              >
                {CURRENCIES.map((c) => (
                  <option key={c} value={c}>
                    {c}
                  </option>
                ))}
              </select>
            </div>
            <div className="form-group checkbox-group">
              <label>
                <input
                  type="checkbox"
                  checked={autoSyncEnabled}
                  onChange={(e) => setAutoSyncEnabled(e.target.checked)}
                />
                Enable automatic account sync
              </label>
            </div>
            <div className="form-group checkbox-group">
              <label>
                <input
                  type="checkbox"
                  checked={sendWeeklyReport}
                  onChange={(e) => setSendWeeklyReport(e.target.checked)}
                />
                Send weekly wealth report (Mondays)
              </label>
            </div>
            <div className="form-group">
              <label>Default Chart View</label>
              <div className="button-group-row">
                <div className="button-group">
                  {CHART_RANGES.map((r) => (
                    <button
                      key={r.value}
                      type="button"
                      className={`btn btn-sm ${defaultChartRange === r.value ? 'btn-primary' : 'btn-ghost'}`}
                      onClick={() => setDefaultChartRange(r.value)}
                    >
                      {r.label}
                    </button>
                  ))}
                </div>
                <div className="button-group">
                  <button
                    type="button"
                    className={`btn btn-sm ${defaultChartGranularity === 'daily' ? 'btn-primary' : 'btn-ghost'}`}
                    onClick={() => setDefaultChartGranularity('daily')}
                  >
                    Daily
                  </button>
                  <button
                    type="button"
                    className={`btn btn-sm ${defaultChartGranularity === 'monthly' ? 'btn-primary' : 'btn-ghost'}`}
                    onClick={() => setDefaultChartGranularity('monthly')}
                  >
                    Monthly
                  </button>
                </div>
              </div>
            </div>
            <div className="form-actions">
              {profileMessage && <span className="form-message success">{profileMessage}</span>}
              <button type="submit" className="btn btn-primary" disabled={profileSaving}>
                <Save size={16} />
                {profileSaving ? 'Saving...' : 'Save Preferences'}
              </button>
            </div>
          </form>
        </section>

        {/* Password Change */}
        <section className="settings-section">
          <h2>
            <Key size={20} />
            Change Password
          </h2>
          <form onSubmit={handlePasswordChange}>
            <div className="form-group">
              <label>Current Password</label>
              <input
                type="password"
                value={oldPassword}
                onChange={(e) => setOldPassword(e.target.value)}
                required
              />
            </div>
            <div className="form-group">
              <label>New Password</label>
              <input
                type="password"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                required
                minLength={8}
              />
            </div>
            <div className="form-group">
              <label>Confirm New Password</label>
              <input
                type="password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                required
              />
            </div>
            {passwordError && <p className="form-error">{passwordError}</p>}
            <div className="form-actions">
              {passwordMessage && <span className="form-message success">{passwordMessage}</span>}
              <button type="submit" className="btn btn-primary" disabled={passwordSaving}>
                <Key size={16} />
                {passwordSaving ? 'Changing...' : 'Change Password'}
              </button>
            </div>
          </form>
        </section>
      </div>
    </div>
  );
}
