/**
 * File-based token persistence with encryption-at-rest.
 * T013 — store/load/delete tokens in ~/.salesforce-mcp-lib/tokens/.
 *
 * SECURITY: Tokens are encrypted with AES-256-GCM using a random 256-bit key
 * stored in ~/.salesforce-mcp-lib/.key (mode 0o400, owner read-only). This
 * protects against backup/disk-image leakage of the tokens directory when the
 * key file is not included in the backup.
 *
 * NOTE: Does NOT protect against an attacker with full read access to the home
 * directory (both the key file and token files are accessible). For stronger
 * guarantees, run on a system with full-disk encryption or integrate an OS
 * keychain / external secrets manager.
 */

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import { URL } from 'node:url';
import type { PerUserTokenData } from './types.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/**
 * Discriminated-union result of a loadTokens() call.
 * Replaces the previous PerUserTokenData | null return type and the
 * type-unsafe { corrupt: true } sentinel value.
 */
export type LoadTokensResult =
  | { status: 'loaded'; data: PerUserTokenData }
  | { status: 'missing' }
  | { status: 'corrupt'; reason: string }
  | { status: 'error'; error: Error };

/** On-disk format for encrypted token files (version 1). */
interface EncryptedTokenFile {
  v: 1;
  /** 12 random bytes, hex-encoded. */
  iv: string;
  /** 16-byte GCM authentication tag, hex-encoded. */
  tag: string;
  /** AES-256-GCM ciphertext, hex-encoded. */
  ct: string;
}

// ---------------------------------------------------------------------------
// Directory / path helpers
// ---------------------------------------------------------------------------

/**
 * Return the base configuration directory.
 * SALESFORCE_MCP_LIB_STORAGE_DIR overrides the default for test isolation.
 * Never set this env var in production.
 */
function getBaseDir(): string {
  return (
    process.env['SALESFORCE_MCP_LIB_STORAGE_DIR'] ??
    path.join(os.homedir(), '.salesforce-mcp-lib')
  );
}

/** Return the token storage directory path (~/.salesforce-mcp-lib/tokens/). */
export function getStorageDir(): string {
  return path.join(getBaseDir(), 'tokens');
}

/** Return the path to the encryption key file (~/.salesforce-mcp-lib/.key). */
export function getKeyFilePath(): string {
  return path.join(getBaseDir(), '.key');
}

/**
 * Derive a storage key (filename) from instance URL and client ID.
 * Uses SHA-256 hex digest of (canonicalInstanceUrl + '|' + clientId) to support
 * multiple orgs without exposing org details in filenames.
 */
function canonicalizeInstanceUrl(instanceUrl: string): string {
  return new URL(instanceUrl).origin;
}

export function deriveStorageKey(
  instanceUrl: string,
  clientId: string
): string {
  const canonicalInstanceUrl = canonicalizeInstanceUrl(instanceUrl);
  return crypto
    .createHash('sha256')
    .update(`${canonicalInstanceUrl}|${clientId}`)
    .digest('hex');
}

// ---------------------------------------------------------------------------
// Key management
// ---------------------------------------------------------------------------

/**
 * Load the encryption key, creating a new random key if none exists.
 * The key file is created with mode 0o400 (owner read-only).
 * Throws if the existing key file has an unexpected size (corrupt).
 */
function loadOrCreateKey(): Buffer {
  const keyPath = getKeyFilePath();
  fs.mkdirSync(getBaseDir(), { recursive: true, mode: 0o700 });

  try {
    const data = fs.readFileSync(keyPath);
    if (data.length !== 32) {
      throw new Error(
        `Encryption key file at ${keyPath} is corrupt ` +
          `(expected 32 bytes, got ${data.length}). ` +
          `Delete it and run "salesforce-mcp-lib login" to re-authenticate.`
      );
    }
    return data;
  } catch (err: unknown) {
    if (
      err instanceof Error &&
      (err as NodeJS.ErrnoException).code === 'ENOENT'
    ) {
      const key = crypto.randomBytes(32);
      fs.writeFileSync(keyPath, key, { mode: 0o400 });
      return key;
    }
    throw err;
  }
}

/**
 * Load the encryption key without creating it.
 * Returns null if the key file is absent. Throws on unexpected I/O errors.
 */
function loadKey(): Buffer | null {
  const keyPath = getKeyFilePath();
  try {
    const data = fs.readFileSync(keyPath);
    if (data.length !== 32) {
      // Corrupt key file — cannot decrypt. Caller will return corrupt status.
      return null;
    }
    return data;
  } catch (err: unknown) {
    if (
      err instanceof Error &&
      (err as NodeJS.ErrnoException).code === 'ENOENT'
    ) {
      return null;
    }
    throw err;
  }
}

// ---------------------------------------------------------------------------
// Encryption helpers
// ---------------------------------------------------------------------------

/** Encrypt a plaintext string with AES-256-GCM using a fresh random IV. */
function encryptData(plaintext: string, key: Buffer): EncryptedTokenFile {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const ct = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return {
    v: 1,
    iv: iv.toString('hex'),
    tag: tag.toString('hex'),
    ct: ct.toString('hex'),
  };
}

/**
 * Decrypt an EncryptedTokenFile back to a plaintext string.
 * Throws if the GCM authentication tag does not match (tampered or wrong key).
 */
function decryptData(encrypted: EncryptedTokenFile, key: Buffer): string {
  const iv = Buffer.from(encrypted.iv, 'hex');
  const tag = Buffer.from(encrypted.tag, 'hex');
  const ct = Buffer.from(encrypted.ct, 'hex');
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tag);
  return (
    decipher.update(ct).toString('utf8') + decipher.final().toString('utf8')
  );
}

/** Type guard: does this value match the EncryptedTokenFile v1 shape? */
function isEncryptedFormat(data: unknown): data is EncryptedTokenFile {
  if (typeof data !== 'object' || data === null) return false;
  const d = data as Record<string, unknown>;
  return (
    d['v'] === 1 &&
    typeof d['iv'] === 'string' &&
    typeof d['tag'] === 'string' &&
    typeof d['ct'] === 'string'
  );
}

/** Heuristic: does this look like a legacy plaintext PerUserTokenData object? */
function isLegacyPlaintext(data: unknown): boolean {
  if (typeof data !== 'object' || data === null) return false;
  const d = data as Record<string, unknown>;
  return (
    typeof d['accessToken'] === 'string' && typeof d['refreshToken'] === 'string'
  );
}

// ---------------------------------------------------------------------------
// Atomic write helper
// ---------------------------------------------------------------------------

/**
 * Write content to filePath atomically via a .tmp intermediate file.
 * On POSIX, rename(2) is atomic when src and dst are on the same filesystem,
 * so readers never see a partially-written file.
 */
function atomicWriteFileSync(
  filePath: string,
  content: string,
  mode: number
): void {
  const tmpPath = `${filePath}.tmp`;
  try {
    fs.writeFileSync(tmpPath, content, { mode });
    fs.renameSync(tmpPath, filePath);
  } catch (err) {
    try {
      fs.unlinkSync(tmpPath);
    } catch {
      // Best-effort cleanup; ignore secondary errors.
    }
    throw err;
  }
}

// ---------------------------------------------------------------------------
// Field validation
// ---------------------------------------------------------------------------

/** Validate required token fields and build a typed PerUserTokenData object. */
function validateAndBuildTokenData(
  data: Record<string, unknown>
): PerUserTokenData | null {
  if (
    typeof data['accessToken'] !== 'string' ||
    typeof data['refreshToken'] !== 'string' ||
    typeof data['instanceUrl'] !== 'string' ||
    !data['accessToken'] ||
    !data['refreshToken']
  ) {
    return null;
  }
  return {
    accessToken: data['accessToken'] as string,
    refreshToken: data['refreshToken'] as string,
    instanceUrl: data['instanceUrl'] as string,
    tokenType: (data['tokenType'] as string | undefined) ?? 'Bearer',
    issuedAt:
      typeof data['issuedAt'] === 'number'
        ? (data['issuedAt'] as number)
        : Date.now(),
    identityUrl: (data['identityUrl'] as string | undefined) ?? '',
  };
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Save tokens for the given instance+client combination.
 * Creates the storage directory and encryption key file if they don't exist.
 * The token file is encrypted with AES-256-GCM and written atomically.
 * File permissions: 0600 (owner-only read/write).
 */
export function saveTokens(
  instanceUrl: string,
  clientId: string,
  data: PerUserTokenData
): void {
  const storageDir = getStorageDir();
  fs.mkdirSync(storageDir, { recursive: true, mode: 0o700 });

  const key = loadOrCreateKey();
  const encrypted = encryptData(JSON.stringify(data), key);

  const storageKey = deriveStorageKey(instanceUrl, clientId);
  const filePath = path.join(storageDir, `${storageKey}.json`);
  atomicWriteFileSync(filePath, JSON.stringify(encrypted), 0o600);
}

/**
 * Load stored tokens for the given instance+client combination.
 *
 * Returns a discriminated union:
 *   { status: 'loaded',  data }     — valid tokens found and decrypted
 *   { status: 'missing' }           — no token file (user has not logged in)
 *   { status: 'corrupt', reason }   — file exists but cannot be read/decrypted
 *   { status: 'error',   error }    — unexpected I/O or encryption key error
 *
 * Legacy plaintext token files (pre-encryption) are automatically migrated to
 * the encrypted format on first load.
 */
export function loadTokens(
  instanceUrl: string,
  clientId: string
): LoadTokensResult {
  const storageKey = deriveStorageKey(instanceUrl, clientId);
  const filePath = path.join(getStorageDir(), `${storageKey}.json`);

  // Step 1: Read the raw file.
  let content: string;
  try {
    content = fs.readFileSync(filePath, 'utf-8');
  } catch (err: unknown) {
    if (
      err instanceof Error &&
      (err as NodeJS.ErrnoException).code === 'ENOENT'
    ) {
      return { status: 'missing' };
    }
    return {
      status: 'error',
      error: err instanceof Error ? err : new Error(String(err)),
    };
  }

  // Step 2: Parse outer JSON.
  let parsed: unknown;
  try {
    parsed = JSON.parse(content);
  } catch {
    return { status: 'corrupt', reason: 'JSON parse failed' };
  }

  // Step 3a: Encrypted format v1.
  if (isEncryptedFormat(parsed)) {
    const encKey = loadKey();
    if (encKey === null) {
      return {
        status: 'error',
        error: new Error(
          `Encryption key file missing at ${getKeyFilePath()}. ` +
            `Run "salesforce-mcp-lib login" to re-authenticate.`
        ),
      };
    }

    let plaintext: string;
    try {
      plaintext = decryptData(parsed, encKey);
    } catch {
      return {
        status: 'corrupt',
        reason: 'Decryption failed (file tampered or wrong key)',
      };
    }

    let inner: unknown;
    try {
      inner = JSON.parse(plaintext);
    } catch {
      return { status: 'corrupt', reason: 'Decrypted content is not valid JSON' };
    }

    const tokenData = validateAndBuildTokenData(
      inner as Record<string, unknown>
    );
    if (!tokenData) {
      return { status: 'corrupt', reason: 'Missing required token fields' };
    }
    return { status: 'loaded', data: tokenData };
  }

  // Step 3b: Legacy plaintext format — validate, then auto-upgrade to encrypted.
  if (isLegacyPlaintext(parsed)) {
    const tokenData = validateAndBuildTokenData(
      parsed as Record<string, unknown>
    );
    if (!tokenData) {
      return {
        status: 'corrupt',
        reason: 'Missing required fields in legacy token file',
      };
    }
    // Best-effort upgrade: re-save as encrypted. If this fails, the plaintext
    // file remains and the next load will try again. Never block on upgrade failure.
    try {
      saveTokens(instanceUrl, clientId, tokenData);
    } catch {
      // Silently ignore — returning valid data is more important than encryption.
    }
    return { status: 'loaded', data: tokenData };
  }

  return { status: 'corrupt', reason: 'Unrecognized token file format' };
}

/**
 * Delete stored tokens for the given instance+client combination.
 * No-op if the token file doesn't exist.
 * NOTE: Does NOT delete the encryption key file.
 */
export function deleteTokens(instanceUrl: string, clientId: string): void {
  const storageKey = deriveStorageKey(instanceUrl, clientId);
  const filePath = path.join(getStorageDir(), `${storageKey}.json`);

  try {
    fs.unlinkSync(filePath);
  } catch (err: unknown) {
    if (
      err instanceof Error &&
      (err as NodeJS.ErrnoException).code !== 'ENOENT'
    ) {
      throw err;
    }
  }
}
