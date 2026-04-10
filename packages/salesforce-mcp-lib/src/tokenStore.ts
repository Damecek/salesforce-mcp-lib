/**
 * File-based token persistence.
 * T013 — store/load/delete tokens in ~/.salesforce-mcp-lib/tokens/.
 *
 * SECURITY NOTE: Tokens (including refresh tokens) are stored as plaintext
 * JSON with file permissions 0600 (owner-only read/write). This protects
 * against other local users but does NOT protect against root, malware, or
 * backup/disk-image leakage. For production deployments, consider running on
 * a system with full-disk encryption or using an external secrets manager.
 * A future version may add encryption-at-rest via node:crypto (aes-256-gcm).
 */

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import type { PerUserTokenData } from './types.js';

/**
 * Derive a storage key (filename) from instance URL and client ID.
 * Uses SHA-256 hex digest of (instanceUrl + '|' + clientId) to support
 * multiple orgs without exposing org details in filenames.
 */
export function deriveStorageKey(
  instanceUrl: string,
  clientId: string
): string {
  return crypto
    .createHash('sha256')
    .update(`${instanceUrl}|${clientId}`)
    .digest('hex');
}

/** Return the storage directory path (~/.salesforce-mcp-lib/tokens/). */
export function getStorageDir(): string {
  return path.join(os.homedir(), '.salesforce-mcp-lib', 'tokens');
}

/**
 * Save tokens for the given instance+client combination.
 * Creates the storage directory if it doesn't exist.
 * File permissions: 0600 (owner-only).
 */
export function saveTokens(
  instanceUrl: string,
  clientId: string,
  data: PerUserTokenData
): void {
  const storageDir = getStorageDir();
  fs.mkdirSync(storageDir, { recursive: true, mode: 0o700 });

  const key = deriveStorageKey(instanceUrl, clientId);
  const filePath = path.join(storageDir, `${key}.json`);
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2), {
    mode: 0o600,
  });
}

/**
 * Load stored tokens for the given instance+client combination.
 * Returns null if no tokens are stored or if the file is corrupt/unreadable.
 */
export function loadTokens(
  instanceUrl: string,
  clientId: string
): PerUserTokenData | null {
  const key = deriveStorageKey(instanceUrl, clientId);
  const filePath = path.join(getStorageDir(), `${key}.json`);

  let content: string;
  try {
    content = fs.readFileSync(filePath, 'utf-8');
  } catch (err: unknown) {
    // File doesn't exist — expected when user has not logged in yet.
    if (
      err instanceof Error &&
      (err as NodeJS.ErrnoException).code === 'ENOENT'
    ) {
      return null;
    }
    // Unexpected I/O error — treat as missing but warn via return value.
    return null;
  }

  try {
    const data = JSON.parse(content) as Record<string, unknown>;

    // Validate required fields.
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
      tokenType: (data['tokenType'] as string) ?? 'Bearer',
      issuedAt:
        typeof data['issuedAt'] === 'number'
          ? (data['issuedAt'] as number)
          : Date.now(),
      identityUrl: (data['identityUrl'] as string) ?? '',
    };
  } catch {
    // JSON parse failed — token file is corrupt. Return a sentinel so the
    // caller can distinguish this from "file not found".
    return { corrupt: true } as unknown as PerUserTokenData;
  }
}

/**
 * Delete stored tokens for the given instance+client combination.
 * No-op if the file doesn't exist.
 */
export function deleteTokens(
  instanceUrl: string,
  clientId: string
): void {
  const key = deriveStorageKey(instanceUrl, clientId);
  const filePath = path.join(getStorageDir(), `${key}.json`);

  try {
    fs.unlinkSync(filePath);
  } catch (err: unknown) {
    // No-op on ENOENT (file doesn't exist).
    if (
      err instanceof Error &&
      (err as NodeJS.ErrnoException).code !== 'ENOENT'
    ) {
      throw err;
    }
  }
}
