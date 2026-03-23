import { RemoteMcpError } from "./errors.js";
import type { FetchLike, TokenProvider } from "./types.js";

const OAUTH_CLIENT_CREDENTIALS_EXTENSION = "io.modelcontextprotocol/oauth-client-credentials";

export interface RemoteMcpProxyOptions {
  serverUrl: URL;
  tokenProvider: TokenProvider;
  fetchImpl?: FetchLike;
}

export class RemoteMcpProxy {
  private readonly serverUrl: URL;
  private readonly tokenProvider: TokenProvider;
  private readonly fetchImpl: FetchLike;
  private sessionId?: string;

  constructor(options: RemoteMcpProxyOptions) {
    this.serverUrl = options.serverUrl;
    this.tokenProvider = options.tokenProvider;
    this.fetchImpl = options.fetchImpl ?? fetch;
  }

  async forwardMessage(message: unknown): Promise<unknown | undefined> {
    if (Array.isArray(message)) {
      throw new RemoteMcpError("Batch JSON-RPC requests are not supported.");
    }

    const payload = decorateInitializeMessage(message);
    const requestedProtocolVersion = getInitializeProtocolVersion(payload);
    const accessToken = await this.tokenProvider.getAccessToken();
    const headers = new Headers({
      "authorization": `Bearer ${accessToken}`,
      "accept": "application/json, text/event-stream",
      "content-type": "application/json"
    });

    if (this.sessionId) {
      headers.set("mcp-session-id", this.sessionId);
    }

    const response = await this.fetchImpl(this.serverUrl, {
      method: "POST",
      headers,
      body: JSON.stringify(payload)
    });

    const nextSessionId = response.headers.get("mcp-session-id");
    if (nextSessionId) {
      this.sessionId = nextSessionId;
    }

    const bodyText = await response.text();
    if (response.status === 204 || bodyText.length === 0) {
      return undefined;
    }

    if (!response.ok) {
      throw new RemoteMcpError(`Remote MCP request failed with HTTP ${response.status}: ${bodyText}`, response.status);
    }

    try {
      const parsedBody = JSON.parse(bodyText) as unknown;
      return normalizeInitializeResponse(parsedBody, requestedProtocolVersion);
    } catch {
      throw new RemoteMcpError("Remote MCP server returned invalid JSON.", response.status);
    }
  }
}

export function decorateInitializeMessage(message: unknown): unknown {
  if (!isObject(message) || message.method !== "initialize") {
    return message;
  }

  const params = isObject(message.params) ? { ...message.params } : {};
  const capabilities = isObject(params.capabilities) ? { ...params.capabilities } : {};
  const extensions = isObject(capabilities.extensions) ? { ...capabilities.extensions } : {};

  extensions[OAUTH_CLIENT_CREDENTIALS_EXTENSION] = isObject(extensions[OAUTH_CLIENT_CREDENTIALS_EXTENSION])
    ? extensions[OAUTH_CLIENT_CREDENTIALS_EXTENSION]
    : {};

  capabilities.extensions = extensions;
  params.capabilities = capabilities;

  return {
    ...message,
    params
  };
}

function isObject(value: unknown): value is Record<string, any> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function getInitializeProtocolVersion(message: unknown): string | undefined {
  if (!isObject(message) || message.method !== "initialize" || !isObject(message.params)) {
    return undefined;
  }

  const { protocolVersion } = message.params;
  return typeof protocolVersion === "string" && protocolVersion.length > 0 ? protocolVersion : undefined;
}

function normalizeInitializeResponse(message: unknown, requestedProtocolVersion?: string): unknown {
  if (!requestedProtocolVersion || !isObject(message) || !isObject(message.result)) {
    return message;
  }

  if (typeof message.result.protocolVersion !== "string") {
    return message;
  }

  return {
    ...message,
    result: {
      ...message.result,
      protocolVersion: requestedProtocolVersion
    }
  };
}
