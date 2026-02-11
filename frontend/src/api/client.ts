import { argon2id } from 'hash-wasm';

const TOKEN_KEY = 'wealth_access_token';
const REFRESH_KEY = 'wealth_refresh_token';
const KEK_KEY = 'wealth_kek';
const AUTH_SALT_KEY = 'wealth_auth_salt';
const KEK_SALT_KEY = 'wealth_kek_salt';

// Argon2 parameters (must match server expectations)
const ARGON2_TIME_COST = 3;
const ARGON2_MEMORY_COST = 65536; // 64 MB
const ARGON2_PARALLELISM = 4;
const ARGON2_HASH_LEN = 32;

export function getAccessToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setTokens(access: string, refresh: string) {
  localStorage.setItem(TOKEN_KEY, access);
  localStorage.setItem(REFRESH_KEY, refresh);
}

export function clearTokens() {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(REFRESH_KEY);
  // Also clear KEK and salts on logout
  sessionStorage.removeItem(KEK_KEY);
  sessionStorage.removeItem(AUTH_SALT_KEY);
  sessionStorage.removeItem(KEK_SALT_KEY);
}

// KEK Management
export function getKEK(): string | null {
  return sessionStorage.getItem(KEK_KEY);
}

export function setKEK(kek: string) {
  sessionStorage.setItem(KEK_KEY, kek);
}

export function setSalts(authSalt: string, kekSalt: string) {
  sessionStorage.setItem(AUTH_SALT_KEY, authSalt);
  sessionStorage.setItem(KEK_SALT_KEY, kekSalt);
}

export function getSalts(): { authSalt: string | null; kekSalt: string | null } {
  return {
    authSalt: sessionStorage.getItem(AUTH_SALT_KEY),
    kekSalt: sessionStorage.getItem(KEK_SALT_KEY),
  };
}

// Crypto utilities
function base64ToBytes(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

async function deriveKey(password: string, salt: string): Promise<Uint8Array> {
  const saltBytes = base64ToBytes(salt);
  const hash = await argon2id({
    password,
    salt: saltBytes,
    iterations: ARGON2_TIME_COST,
    memorySize: ARGON2_MEMORY_COST,
    parallelism: ARGON2_PARALLELISM,
    hashLength: ARGON2_HASH_LEN,
    outputType: 'binary',
  });
  return hash;
}

async function refreshAccessToken(): Promise<string | null> {
  const refresh = localStorage.getItem(REFRESH_KEY);
  if (!refresh) return null;

  const res = await fetch('/api/auth/refresh/', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refresh }),
    credentials: 'include',
  });

  if (!res.ok) {
    clearTokens();
    return null;
  }

  const data = await res.json();
  setTokens(data.access, data.refresh ?? refresh);
  return data.access;
}

export async function fetchWithAuth(
  url: string,
  options: RequestInit = {},
): Promise<Response> {
  let token = getAccessToken();
  const kek = getKEK();

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(options.headers as Record<string, string> ?? {}),
  };

  if (token) {
    // Use X-Auth-Token to avoid conflict with HTTP Basic Auth's Authorization header
    headers['X-Auth-Token'] = `Bearer ${token}`;
  }

  // Add KEK header for encrypted operations (migrated users)
  if (kek) {
    headers['X-KEK'] = kek;
  }

  let res = await fetch(url, { ...options, headers, credentials: 'include' });

  if (res.status === 401 && token) {
    const newToken = await refreshAccessToken();
    if (newToken) {
      headers['X-Auth-Token'] = `Bearer ${newToken}`;
      res = await fetch(url, { ...options, headers, credentials: 'include' });
    }
  }

  return res;
}

// Auth API

// Get salts for a user (for key derivation)
async function getSaltsFromServer(username: string): Promise<{
  auth_salt: string;
  kek_salt: string;
  migrated: boolean;
}> {
  const res = await fetch(`/api/auth/salt/?username=${encodeURIComponent(username)}`, {
    credentials: 'include',
  });
  if (!res.ok) {
    throw new Error('Failed to get salts');
  }
  return res.json();
}

export async function login(username: string, password: string) {
  // 1. Get salts from server
  const { auth_salt, kek_salt, migrated } = await getSaltsFromServer(username);

  let loginPayload: { username: string; password?: string; auth_hash?: string };

  if (migrated) {
    // 2a. User is migrated - derive auth_hash and KEK client-side
    const authHashBytes = await deriveKey(password, auth_salt);
    const kekBytes = await deriveKey(password, kek_salt);

    const authHash = bytesToBase64(authHashBytes);
    const kek = bytesToBase64(kekBytes);

    loginPayload = { username, auth_hash: authHash };

    // 3. Login with auth_hash
    const res = await fetch('/api/auth/login/', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(loginPayload),
      credentials: 'include',
    });

    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      throw new Error(data.error || data.detail || 'Login failed');
    }

    const data = await res.json();
    setTokens(data.access, data.refresh);

    // Store KEK and salts for encrypted operations
    setKEK(kek);
    setSalts(auth_salt, kek_salt);

    return data;
  } else {
    // 2b. User not migrated - use legacy password auth
    const res = await fetch('/api/auth/login/', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password }),
      credentials: 'include',
    });

    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      throw new Error(data.error || data.detail || 'Login failed');
    }

    const data = await res.json();
    setTokens(data.access, data.refresh);

    // Store salts for potential migration
    setSalts(auth_salt, kek_salt);

    // If user needs to set up encryption, derive and store KEK
    if (!data.encryption_migrated) {
      const kekBytes = await deriveKey(password, kek_salt);
      const kek = bytesToBase64(kekBytes);
      setKEK(kek);

      // Derive auth_hash for setup
      const authHashBytes = await deriveKey(password, auth_salt);
      const authHash = bytesToBase64(authHashBytes);

      // Auto-setup encryption for the user
      await setupEncryption(kek, authHash, auth_salt, kek_salt);
    }

    return data;
  }
}

// Set up per-user encryption (for migration)
export async function setupEncryption(
  kek: string,
  authHash: string,
  authSalt: string,
  kekSalt: string,
) {
  const res = await fetchWithAuth('/api/auth/setup-encryption/', {
    method: 'POST',
    body: JSON.stringify({
      kek,
      auth_hash: authHash,
      auth_salt: authSalt,
      kek_salt: kekSalt,
    }),
  });

  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(data.error || 'Failed to setup encryption');
  }

  return res.json();
}

export async function register(fields: {
  username: string;
  email: string;
  password: string;
  password_confirm: string;
  base_currency: string;
}) {
  const res = await fetch('/api/auth/register/', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(fields),
    credentials: 'include',
  });
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    const msg = Object.values(data).flat().join(' ') || 'Registration failed';
    throw new Error(msg);
  }
  const data = await res.json();
  if (data.tokens) {
    setTokens(data.tokens.access, data.tokens.refresh);
  }
  return data;
}

export async function getCurrentUser() {
  const res = await fetchWithAuth('/api/auth/me/');
  if (!res.ok) throw new Error('Not authenticated');
  return res.json();
}

// Wealth API
export async function getWealthSummary() {
  const res = await fetchWithAuth('/api/wealth/summary/');
  if (!res.ok) throw new Error('Failed to fetch summary');
  return res.json();
}

export async function getWealthHistory(days: number, granularity: 'daily' | 'monthly' = 'daily') {
  const res = await fetchWithAuth(`/api/wealth/history/?days=${days}&granularity=${granularity}`);
  if (!res.ok) throw new Error('Failed to fetch history');
  return res.json();
}

export async function getWealthBreakdown(by: string) {
  const res = await fetchWithAuth(`/api/wealth/breakdown/?by=${by}`);
  if (!res.ok) throw new Error('Failed to fetch breakdown');
  return res.json();
}

// Broker API
export async function getBrokers() {
  const res = await fetchWithAuth('/api/brokers/');
  if (!res.ok) throw new Error('Failed to fetch brokers');
  return res.json();
}

export async function discoverAccounts(brokerCode: string, credentials: Record<string, string>) {
  const res = await fetchWithAuth('/api/brokers/discover/', {
    method: 'POST',
    body: JSON.stringify({ broker_code: brokerCode, credentials }),
  });
  const data = await res.json();
  if (!res.ok) {
    throw new Error(data.error || 'Discovery failed');
  }
  return data;
}

export async function completeDiscoveryAuth(sessionToken: string, authCode: string) {
  const res = await fetchWithAuth('/api/brokers/discover/complete-auth/', {
    method: 'POST',
    body: JSON.stringify({ session_token: sessionToken, auth_code: authCode }),
  });
  const data = await res.json();
  if (!res.ok) {
    throw new Error(data.error || 'Authentication failed');
  }
  return data;
}

export async function createAccountsBulk(
  brokerCode: string,
  credentials: Record<string, string>,
  accounts: { identifier: string; name: string; account_type: string; currency: string; balance?: number | null; balance_date?: string }[],
) {
  const res = await fetchWithAuth('/api/accounts/bulk/', {
    method: 'POST',
    body: JSON.stringify({ broker_code: brokerCode, credentials, accounts }),
  });
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(data.error || 'Failed to create accounts');
  }
  return res.json();
}

// Account API
export async function getAccounts() {
  const res = await fetchWithAuth('/api/accounts/');
  if (!res.ok) throw new Error('Failed to fetch accounts');
  return res.json();
}

export async function createAccount(fields: {
  name: string;
  broker_code: string;
  account_identifier?: string;
  account_type: string;
  currency: string;
  is_manual: boolean;
  credentials?: Record<string, string>;
}) {
  const res = await fetchWithAuth('/api/accounts/', {
    method: 'POST',
    body: JSON.stringify(fields),
  });
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    const msg = Object.values(data).flat().join(' ') || 'Failed to create account';
    throw new Error(msg);
  }
  return res.json();
}

export async function syncAccount(accountId: number) {
  const res = await fetchWithAuth(`/api/accounts/${accountId}/sync/`, {
    method: 'POST',
  });
  const data = await res.json();
  if (!res.ok && !data.status) {
    throw new Error(data.error || 'Sync failed');
  }
  return data;
}

export async function completeAccountAuth(accountId: number, authCode: string) {
  const res = await fetchWithAuth(`/api/accounts/${accountId}/auth/`, {
    method: 'POST',
    body: JSON.stringify({ auth_code: authCode }),
  });
  const data = await res.json();
  if (!res.ok) {
    throw new Error(data.error || 'Authentication failed');
  }
  return data;
}

export async function addSnapshot(
  accountId: number,
  balance: number,
  currency: string,
  snapshotDate: string,
) {
  const res = await fetchWithAuth(`/api/accounts/${accountId}/snapshots/`, {
    method: 'POST',
    body: JSON.stringify({
      balance,
      currency,
      snapshot_date: snapshotDate,
    }),
  });
  if (!res.ok) throw new Error('Failed to add snapshot');
  return res.json();
}

export async function getSnapshots(accountId: number, page = 1) {
  const url = `/api/accounts/${accountId}/snapshots/${page > 1 ? `?page=${page}` : ''}`;
  const res = await fetchWithAuth(url);
  if (!res.ok) throw new Error('Failed to fetch snapshots');
  return res.json();
}

export async function updateSnapshot(
  snapshotId: number,
  balance: number,
  currency: string,
  snapshotDate: string,
) {
  const res = await fetchWithAuth(`/api/snapshots/${snapshotId}/`, {
    method: 'PUT',
    body: JSON.stringify({
      balance,
      currency,
      snapshot_date: snapshotDate,
    }),
  });
  if (!res.ok) throw new Error('Failed to update snapshot');
  return res.json();
}

export async function deleteSnapshot(snapshotId: number) {
  const res = await fetchWithAuth(`/api/snapshots/${snapshotId}/`, {
    method: 'DELETE',
  });
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(data.error || 'Failed to delete snapshot');
  }
}

export async function updateAccount(accountId: number, fields: { name?: string; sync_enabled?: boolean }) {
  const res = await fetchWithAuth(`/api/accounts/${accountId}/`, {
    method: 'PATCH',
    body: JSON.stringify(fields),
  });
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(data.error || 'Failed to update account');
  }
  return res.json();
}

export async function deleteAccount(accountId: number) {
  const res = await fetchWithAuth(`/api/accounts/${accountId}/`, {
    method: 'DELETE',
  });
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(data.error || 'Failed to delete account');
  }
}

export async function getAccountCredentials(accountId: number) {
  const res = await fetchWithAuth(`/api/accounts/${accountId}/credentials/`);
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(data.error || 'Failed to fetch credentials');
  }
  return res.json();
}

export async function updateAccountCredentials(
  accountId: number,
  credentials: Record<string, string>,
) {
  const res = await fetchWithAuth(`/api/accounts/${accountId}/credentials/`, {
    method: 'PUT',
    body: JSON.stringify({ credentials }),
  });
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(data.error || 'Failed to update credentials');
  }
  return res.json();
}

export async function getBroker(brokerCode: string) {
  const res = await fetchWithAuth(`/api/brokers/${brokerCode}/`);
  if (!res.ok) throw new Error('Failed to fetch broker');
  return res.json();
}

// CSV Import
export async function importCSV(
  accountId: number,
  csvData: string,
  skipDuplicates: boolean = true,
) {
  const res = await fetchWithAuth('/api/import/csv/', {
    method: 'POST',
    body: JSON.stringify({
      account_id: accountId,
      csv_data: csvData,
      skip_duplicates: skipDuplicates,
    }),
  });
  const data = await res.json();
  if (!res.ok) {
    throw new Error(data.error || 'Import failed');
  }
  return data;
}

// Profile API
export async function getProfile() {
  const res = await fetchWithAuth('/api/profile/');
  if (!res.ok) throw new Error('Failed to fetch profile');
  return res.json();
}

export async function updateProfile(fields: {
  base_currency?: string;
  auto_sync_enabled?: boolean;
  send_weekly_report?: boolean;
  default_chart_range?: number;
  default_chart_granularity?: 'daily' | 'monthly';
}) {
  const res = await fetchWithAuth('/api/profile/', {
    method: 'PATCH',
    body: JSON.stringify(fields),
  });
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(data.error || 'Failed to update profile');
  }
  return res.json();
}

export async function updateUser(fields: {
  first_name?: string;
  last_name?: string;
  email?: string;
}) {
  const res = await fetchWithAuth('/api/user/', {
    method: 'PATCH',
    body: JSON.stringify(fields),
  });
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(data.error || 'Failed to update user');
  }
  return res.json();
}

export async function changePassword(
  oldPassword: string,
  newPassword: string,
  newPasswordConfirm: string,
) {
  // Check if user has KEK (is migrated)
  const kek = getKEK();
  const { authSalt, kekSalt } = getSalts();

  if (kek && authSalt && kekSalt) {
    // KEK-based password change for migrated users
    // 1. Get new salts from server
    const newSaltsRes = await fetchWithAuth('/api/auth/salt/new/', {
      method: 'POST',
    });
    if (!newSaltsRes.ok) {
      throw new Error('Failed to get new salts');
    }
    const { new_auth_salt, new_kek_salt } = await newSaltsRes.json();

    // 2. Derive old and new keys
    const oldAuthHashBytes = await deriveKey(oldPassword, authSalt);
    const oldKekBytes = await deriveKey(oldPassword, kekSalt);
    const newAuthHashBytes = await deriveKey(newPassword, new_auth_salt);
    const newKekBytes = await deriveKey(newPassword, new_kek_salt);

    // 3. Call KEK password change endpoint
    const res = await fetchWithAuth('/api/auth/change-password/kek/', {
      method: 'POST',
      body: JSON.stringify({
        old_auth_hash: bytesToBase64(oldAuthHashBytes),
        new_auth_hash: bytesToBase64(newAuthHashBytes),
        old_kek: bytesToBase64(oldKekBytes),
        new_kek: bytesToBase64(newKekBytes),
        new_auth_salt: new_auth_salt,
        new_kek_salt: new_kek_salt,
      }),
    });

    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.error || 'Failed to change password');
    }

    // 4. Update local KEK and salts
    setKEK(bytesToBase64(newKekBytes));
    setSalts(new_auth_salt, new_kek_salt);

    return data;
  } else {
    // Legacy password change for non-migrated users
    const res = await fetchWithAuth('/api/auth/change-password/', {
      method: 'POST',
      body: JSON.stringify({
        old_password: oldPassword,
        new_password: newPassword,
        new_password_confirm: newPasswordConfirm,
      }),
    });
    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.old_password || data.new_password_confirm || data.error || 'Failed to change password');
    }
    return data;
  }
}
