import test from "node:test";
import assert from "node:assert/strict";
import { deriveTokenUrl, parseServerUrl, resolveConfig } from "../src/config.js";
import { CliUsageError } from "../src/errors.js";

test("parseServerUrl accepts root, nested, and wildcard-style Salesforce MCP endpoints", () => {
  const root = parseServerUrl("https://example.my.salesforce.com/services/apexrest/mcp");
  const nested = parseServerUrl("https://example.my.salesforce.com/services/apexrest/opportunity/mcp");
  const wildcardStyle = parseServerUrl("https://example.my.salesforce.com/services/apexrest/mcp/opportunity/");

  assert.equal(root.pathname, "/services/apexrest/mcp");
  assert.equal(nested.pathname, "/services/apexrest/opportunity/mcp");
  assert.equal(wildcardStyle.pathname, "/services/apexrest/mcp/opportunity/");
});

test("parseServerUrl rejects malformed or non-https values", () => {
  assert.throws(() => parseServerUrl("http://example.my.salesforce.com/services/apexrest/mcp"), CliUsageError);
  assert.throws(() => parseServerUrl("https://example.my.salesforce.com/other"), CliUsageError);
  assert.throws(() => parseServerUrl("https://example.my.salesforce.com/services/apexrest"), CliUsageError);
  assert.throws(() => parseServerUrl("not-a-url"), CliUsageError);
});

test("deriveTokenUrl uses the Salesforce origin", () => {
  const tokenUrl = deriveTokenUrl(new URL("https://example.my.salesforce.com/services/apexrest/opportunity/mcp"));
  assert.equal(tokenUrl.href, "https://example.my.salesforce.com/services/oauth2/token");
});

test("resolveConfig uses cli flags before environment values", () => {
  const config = resolveConfig(
    [
      "--url",
      "https://example.my.salesforce.com/services/apexrest/mcp",
      "--client-id",
      "cli-id",
      "--client-secret",
      "cli-secret",
      "--scope",
      "api"
    ],
    {
      SF_CLIENT_ID: "env-id",
      SF_CLIENT_SECRET: "env-secret",
      SF_SCOPE: "refresh_token"
    }
  );

  assert.equal(config.clientId, "cli-id");
  assert.equal(config.clientSecret, "cli-secret");
  assert.equal(config.scope, "api");
});

test("resolveConfig fails fast when credentials are missing", () => {
  assert.throws(
    () => resolveConfig(["--url", "https://example.my.salesforce.com/services/apexrest/mcp"], {}),
    /Missing Salesforce client id/
  );
});
