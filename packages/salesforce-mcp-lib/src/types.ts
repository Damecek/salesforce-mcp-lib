export interface CliArgs {
  url?: string;
  clientId?: string;
  clientSecret?: string;
  scope?: string;
}

export interface AppConfig {
  serverUrl: URL;
  tokenUrl: URL;
  clientId: string;
  clientSecret: string;
  scope?: string;
}

export interface TokenResponse {
  access_token: string;
  token_type?: string;
  expires_in?: number;
  scope?: string;
  [key: string]: unknown;
}

export interface CachedToken {
  accessToken: string;
  expiresAt: number;
}

export interface TokenProvider {
  getAccessToken(): Promise<string>;
}

export type FetchLike = typeof fetch;
