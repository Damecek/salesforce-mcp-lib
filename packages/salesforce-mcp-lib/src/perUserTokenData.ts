import { SalesforceAuthError } from "./errors.js";
import type { OAuthTokenResponse, PerUserTokenData } from "./types.js";

/**
 * Build persisted per-user token data from an OAuth response.
 * Refresh flows may omit refresh_token, in which case the cached one is reused.
 */
export function buildPerUserTokenData(
  response: OAuthTokenResponse,
  existingRefreshToken?: string,
): PerUserTokenData {
  const refreshToken = response.refresh_token ?? existingRefreshToken;
  if (!refreshToken) {
    throw new SalesforceAuthError(
      "Salesforce did not return a refresh token. Ensure the External Client App grants the refresh_token scope and that offline access is allowed.",
    );
  }

  return {
    accessToken: response.access_token,
    refreshToken,
    instanceUrl: response.instance_url,
    tokenType: response.token_type,
    issuedAt: parseInt(response.issued_at, 10) || Date.now(),
    identityUrl: response.id,
  };
}
