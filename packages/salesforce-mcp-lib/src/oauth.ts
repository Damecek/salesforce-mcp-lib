import { SalesforceAuthError } from "./errors.js";
import type { CachedToken, FetchLike, TokenProvider, TokenResponse } from "./types.js";

const DEFAULT_TOKEN_TTL_MS = 10 * 60 * 1000;
const REFRESH_BUFFER_MS = 30 * 1000;

export interface SalesforceTokenClientOptions {
  tokenUrl: URL;
  clientId: string;
  clientSecret: string;
  scope?: string;
  resource?: string;
  fetchImpl?: FetchLike;
  now?: () => number;
}

export class SalesforceTokenClient implements TokenProvider {
  private readonly tokenUrl: URL;
  private readonly clientId: string;
  private readonly clientSecret: string;
  private readonly scope?: string;
  private readonly resource?: string;
  private readonly fetchImpl: FetchLike;
  private readonly now: () => number;
  private cachedToken?: CachedToken;

  constructor(options: SalesforceTokenClientOptions) {
    this.tokenUrl = options.tokenUrl;
    this.clientId = options.clientId;
    this.clientSecret = options.clientSecret;
    this.scope = options.scope;
    this.resource = options.resource;
    this.fetchImpl = options.fetchImpl ?? fetch;
    this.now = options.now ?? Date.now;
  }

  async getAccessToken(): Promise<string> {
    if (this.cachedToken && this.cachedToken.expiresAt - REFRESH_BUFFER_MS > this.now()) {
      return this.cachedToken.accessToken;
    }

    const token = await this.fetchToken();
    this.cachedToken = token;
    return token.accessToken;
  }

  private async fetchToken(): Promise<CachedToken> {
    const body = new URLSearchParams({
      grant_type: "client_credentials",
      client_id: this.clientId,
      client_secret: this.clientSecret
    });

    if (this.scope) {
      body.set("scope", this.scope);
    }

    if (this.resource) {
      body.set("resource", this.resource);
    }

    const response = await this.fetchImpl(this.tokenUrl, {
      method: "POST",
      headers: {
        "content-type": "application/x-www-form-urlencoded",
        "accept": "application/json"
      },
      body: body.toString()
    });

    const payloadText = await response.text();
    const payload = tryParseJson(payloadText);

    if (!response.ok) {
      throw mapAuthError(response.status, payload, payloadText);
    }

    const tokenPayload = payload as TokenResponse | undefined;
    const accessToken = typeof tokenPayload?.access_token === "string" ? tokenPayload.access_token : undefined;
    if (!accessToken) {
      throw new SalesforceAuthError("Salesforce token response did not include access_token.");
    }

    const expiresInSeconds =
      typeof tokenPayload?.expires_in === "number" && Number.isFinite(tokenPayload.expires_in)
        ? tokenPayload.expires_in
        : DEFAULT_TOKEN_TTL_MS / 1000;

    return {
      accessToken,
      expiresAt: this.now() + expiresInSeconds * 1000
    };
  }
}

function tryParseJson(value: string): Record<string, unknown> | undefined {
  if (!value) {
    return undefined;
  }

  try {
    return JSON.parse(value) as Record<string, unknown>;
  } catch {
    return undefined;
  }
}

function mapAuthError(status: number, payload: Record<string, unknown> | undefined, fallbackText: string): SalesforceAuthError {
  const error = typeof payload?.error === "string" ? payload.error : undefined;
  const description = typeof payload?.error_description === "string" ? payload.error_description : undefined;
  const detail = description ?? error ?? fallbackText ?? `HTTP ${status}`;

  if (status === 400) {
    return new SalesforceAuthError(`Salesforce rejected the client credentials request: ${detail}`, status);
  }

  if (status === 401) {
    return new SalesforceAuthError(`Salesforce authorization failed. Check the connected app secret, policy, and run-as user: ${detail}`, status);
  }

  return new SalesforceAuthError(`Salesforce token request failed with HTTP ${status}: ${detail}`, status);
}
