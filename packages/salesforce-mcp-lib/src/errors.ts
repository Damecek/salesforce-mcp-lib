/**
 * Custom error types for the salesforce-mcp-lib stdio proxy.
 * T034 — authentication and remote-endpoint error classes.
 */

/** Thrown when Salesforce OAuth 2.0 authentication fails. */
export class SalesforceAuthError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'SalesforceAuthError';
    // Restore prototype chain (required when extending built-ins in TS).
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

/** User's Salesforce credentials were rejected (wrong password, locked account, bad client_id). */
export class InvalidCredentialsError extends SalesforceAuthError {
  readonly oauthError?: string;

  constructor(message: string, oauthError?: string) {
    super(message);
    this.name = 'InvalidCredentialsError';
    this.oauthError = oauthError;
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

/** User doesn't have access to the Connected App or required permissions. */
export class InsufficientAccessError extends SalesforceAuthError {
  readonly oauthError?: string;

  constructor(message: string, oauthError?: string) {
    super(message);
    this.name = 'InsufficientAccessError';
    this.oauthError = oauthError;
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

/** User denied consent during OAuth authorization. */
export class ConsentDeniedError extends SalesforceAuthError {
  constructor(message: string) {
    super(message);
    this.name = 'ConsentDeniedError';
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

/** Per-user auth is configured but the user must complete the login command first. */
export class LoginRequiredError extends SalesforceAuthError {
  constructor(message: string) {
    super(message);
    this.name = 'LoginRequiredError';
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

/** Access token expired or was revoked. Refresh may resolve. */
export class SessionExpiredError extends SalesforceAuthError {
  constructor(message: string) {
    super(message);
    this.name = 'SessionExpiredError';
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

/** Cannot reach Salesforce (network, DNS, timeout). */
export class ConnectivityError extends SalesforceAuthError {
  readonly cause?: Error;

  constructor(message: string, cause?: Error) {
    super(message);
    this.name = 'ConnectivityError';
    this.cause = cause;
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

/**
 * Thrown when the remote Salesforce endpoint returns a non-JSON or
 * unexpected HTTP error response.
 */
export class RemoteMcpError extends Error {
  /** HTTP status code returned by Salesforce. */
  readonly statusCode: number;
  /** Raw response body. */
  readonly responseBody: string;

  constructor(message: string, statusCode: number, responseBody: string) {
    super(message);
    this.name = 'RemoteMcpError';
    this.statusCode = statusCode;
    this.responseBody = responseBody;
    Object.setPrototypeOf(this, new.target.prototype);
  }
}
