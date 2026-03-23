import test from "node:test";
import assert from "node:assert/strict";
import { decorateInitializeMessage, RemoteMcpProxy } from "../src/mcpBridge.js";

test("decorateInitializeMessage adds the OAuth client credentials extension", () => {
  const message = decorateInitializeMessage({
    jsonrpc: "2.0",
    id: 1,
    method: "initialize",
    params: {
      protocolVersion: "2025-06-18",
      capabilities: {},
      clientInfo: {
        name: "test-client",
        version: "1.0.0"
      }
    }
  }) as Record<string, any>;

  assert.deepEqual(message.params.capabilities.extensions["io.modelcontextprotocol/oauth-client-credentials"], {});
});

test("RemoteMcpProxy sends bearer auth headers and forwards the response", async () => {
  const requests: Array<{ headers: Headers; body: string | null }> = [];
  const proxy = new RemoteMcpProxy({
    serverUrl: new URL("https://example.my.salesforce.com/services/apexrest/mcp"),
    tokenProvider: {
      getAccessToken: async () => "token-123"
    },
    fetchImpl: async (_input, init) => {
      requests.push({
        headers: new Headers(init?.headers),
        body: typeof init?.body === "string" ? init.body : null
      });
      return new Response(JSON.stringify({ jsonrpc: "2.0", id: 2, result: { tools: [] } }), {
        status: 200,
        headers: {
          "content-type": "application/json",
          "mcp-session-id": "session-1"
        }
      });
    }
  });

  const payload = await proxy.forwardMessage({
    jsonrpc: "2.0",
    id: 2,
    method: "tools/list",
    params: {}
  });

  assert.deepEqual(payload, { jsonrpc: "2.0", id: 2, result: { tools: [] } });
  assert.equal(requests[0]?.headers.get("authorization"), "Bearer token-123");
  assert.equal(requests[0]?.headers.get("mcp-session-id"), null);

  await proxy.forwardMessage({
    jsonrpc: "2.0",
    id: 3,
    method: "resources/list",
    params: {}
  });

  assert.equal(requests[1]?.headers.get("mcp-session-id"), "session-1");
});

test("RemoteMcpProxy rejects invalid JSON from the remote server", async () => {
  const proxy = new RemoteMcpProxy({
    serverUrl: new URL("https://example.my.salesforce.com/services/apexrest/mcp"),
    tokenProvider: {
      getAccessToken: async () => "token-123"
    },
    fetchImpl: async () => new Response("not-json", { status: 200 })
  });

  await assert.rejects(() =>
    proxy.forwardMessage({
      jsonrpc: "2.0",
      id: 1,
      method: "tools/list",
      params: {}
    })
  );
});

test("RemoteMcpProxy normalizes initialize protocolVersion to the client-requested version", async () => {
  const proxy = new RemoteMcpProxy({
    serverUrl: new URL("https://example.my.salesforce.com/services/apexrest/mcp"),
    tokenProvider: { getAccessToken: async () => "token-123" },
    fetchImpl: async () =>
      new Response(
        JSON.stringify({
          jsonrpc: "2.0",
          id: 1,
          result: {
            protocolVersion: "2025-11-25",
            capabilities: {},
            serverInfo: {
              name: "Remote Server",
              version: "1.0.0"
            }
          }
        }),
        { status: 200, headers: { "content-type": "application/json" } }
      )
  });

  const response = (await proxy.forwardMessage({
    jsonrpc: "2.0",
    id: 1,
    method: "initialize",
    params: {
      protocolVersion: "2025-06-18",
      capabilities: {},
      clientInfo: {
        name: "test-client",
        version: "1.0.0"
      }
    }
  })) as Record<string, any>;

  assert.equal(response.result.protocolVersion, "2025-06-18");
});
