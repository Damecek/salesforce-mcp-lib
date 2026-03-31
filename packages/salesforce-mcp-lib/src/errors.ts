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
