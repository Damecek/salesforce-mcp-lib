import test from "node:test";
import assert from "node:assert/strict";
import { SalesforceAuthError } from "../src/errors.js";
import { SalesforceTokenClient } from "../src/oauth.js";

test("SalesforceTokenClient sends a client_credentials token request", async () => {
  let called = 0;
  let body = "";
  const client = new SalesforceTokenClient({
    tokenUrl: new URL("https://example.my.salesforce.com/services/oauth2/token"),
    clientId: "client-id",
    clientSecret: "client-secret",
    scope: "api",
    resource: "https://example.my.salesforce.com/services/apexrest/mcp",
    fetchImpl: async (_input, init) => {
      called += 1;
      body = String(init?.body);
      return new Response(JSON.stringify({ access_token: "token-123", expires_in: 300 }), {
        status: 200,
        headers: {
          "content-type": "application/json"
        }
      });
    }
  });

  const first = await client.getAccessToken();
  const second = await client.getAccessToken();

  assert.equal(first, "token-123");
  assert.equal(second, "token-123");
  assert.equal(called, 1);
  assert.match(body, /grant_type=client_credentials/);
  assert.match(body, /client_id=client-id/);
  assert.match(body, /client_secret=client-secret/);
  assert.match(body, /scope=api/);
  assert.match(body, /resource=https%3A%2F%2Fexample\.my\.salesforce\.com%2Fservices%2Fapexrest%2Fmcp/);
});

test("SalesforceTokenClient refreshes after expiry", async () => {
  let now = 0;
  let called = 0;
  const client = new SalesforceTokenClient({
    tokenUrl: new URL("https://example.my.salesforce.com/services/oauth2/token"),
    clientId: "client-id",
    clientSecret: "client-secret",
    now: () => now,
    fetchImpl: async () => {
      called += 1;
      return new Response(JSON.stringify({ access_token: `token-${called}`, expires_in: 60 }), {
        status: 200,
        headers: { "content-type": "application/json" }
      });
    }
  });

  assert.equal(await client.getAccessToken(), "token-1");
  now = 31_000;
  assert.equal(await client.getAccessToken(), "token-2");
});

test("SalesforceTokenClient maps auth failures to actionable errors", async () => {
  const client = new SalesforceTokenClient({
    tokenUrl: new URL("https://example.my.salesforce.com/services/oauth2/token"),
    clientId: "client-id",
    clientSecret: "client-secret",
    fetchImpl: async () =>
      new Response(JSON.stringify({ error: "invalid_client", error_description: "bad secret" }), {
        status: 401,
        headers: { "content-type": "application/json" }
      })
  });

  await assert.rejects(() => client.getAccessToken(), SalesforceAuthError);
});
