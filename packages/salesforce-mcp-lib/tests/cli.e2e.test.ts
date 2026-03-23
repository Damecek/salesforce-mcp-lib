import test from "node:test";
import assert from "node:assert/strict";
import https from "node:https";
import { once } from "node:events";
import { spawn } from "node:child_process";
import path from "node:path";
import { encodeMessage } from "../src/stdio.js";

test("CLI proxies initialize and tools/list to a nested Salesforce MCP endpoint", async t => {
  const requests: Array<{ url: string; authorization: string | null; body: string }> = [];
  const server = https.createServer(
    {
      key: TEST_PRIVATE_KEY,
      cert: TEST_CERTIFICATE
    },
    async (req, res) => {
    const body = await readRequestBody(req);
    requests.push({
      url: req.url ?? "",
      authorization: req.headers.authorization ?? null,
      body
    });

    if (req.url === "/services/oauth2/token") {
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({ access_token: "token-123", expires_in: 300 }));
      return;
    }

    const payload = JSON.parse(body) as Record<string, any>;
    if (req.url === "/services/apexrest/opportunity/mcp" && payload.method === "initialize") {
      res.writeHead(200, {
        "content-type": "application/json",
        "mcp-session-id": "session-123"
      });
      res.end(
        JSON.stringify({
          jsonrpc: "2.0",
          id: payload.id,
          result: {
            protocolVersion: "2025-06-18",
            capabilities: {},
            serverInfo: {
              name: "Remote Harness",
              version: "1.0.0"
            }
          }
        })
      );
      return;
    }

    if (req.url === "/services/apexrest/opportunity/mcp" && payload.method === "tools/list") {
      res.writeHead(200, { "content-type": "application/json" });
      res.end(
        JSON.stringify({
          jsonrpc: "2.0",
          id: payload.id,
          result: {
            tools: [
              {
                name: "math.sum",
                description: "Adds two integers.",
                inputSchema: { type: "object" }
              }
            ]
          }
        })
      );
      return;
    }

    res.writeHead(404, { "content-type": "application/json" });
    res.end(JSON.stringify({ error: "unexpected request" }));
    }
  );

  await new Promise<void>(resolve => server.listen(0, "127.0.0.1", () => resolve()));
  t.after(async () => {
    server.close();
    await once(server, "close");
  });

  const address = server.address();
  if (!address || typeof address === "string") {
    throw new Error("Failed to start test server.");
  }

  const child = spawn(
    process.execPath,
    [
      "--import",
      "tsx",
      path.resolve(path.dirname(new URL(import.meta.url).pathname), "../src/index.ts"),
      "--url",
      `https://127.0.0.1:${address.port}/services/apexrest/opportunity/mcp`
    ],
    {
      cwd: path.resolve(path.dirname(new URL(import.meta.url).pathname), ".."),
      env: {
        ...process.env,
        NODE_TLS_REJECT_UNAUTHORIZED: "0",
        SF_CLIENT_ID: "env-client-id",
        SF_CLIENT_SECRET: "env-client-secret"
      },
      stdio: ["pipe", "pipe", "pipe"]
    }
  );

  const stdoutChunks: Buffer[] = [];
  const stderrChunks: Buffer[] = [];
  child.stdout.on("data", chunk => stdoutChunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)));
  child.stderr.on("data", chunk => stderrChunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)));

  child.stdin.write(
    Buffer.concat([
      encodeMessage({
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: {
          protocolVersion: "2025-06-18",
          capabilities: {},
          clientInfo: {
            name: "stdio-client",
            version: "1.0.0"
          }
        }
      }),
      encodeMessage({
        jsonrpc: "2.0",
        id: 2,
        method: "tools/list",
        params: {}
      })
    ])
  );
  child.stdin.end();

  const [exitCode] = (await once(child, "close")) as [number | null];
  assert.equal(exitCode, 0, Buffer.concat(stderrChunks).toString("utf8"));

  const outputText = Buffer.concat(stdoutChunks).toString("utf8");
  assert.match(outputText, /Remote Harness/);
  assert.match(outputText, /math\.sum/);
  assert.equal(requests[0]?.url, "/services/oauth2/token");
  assert.equal(requests[1]?.url, "/services/apexrest/opportunity/mcp");
  assert.equal(requests[1]?.authorization, "Bearer token-123");

  const initializeRequest = JSON.parse(requests[1]?.body ?? "{}") as Record<string, any>;
  assert.deepEqual(
    initializeRequest.params.capabilities.extensions["io.modelcontextprotocol/oauth-client-credentials"],
    {}
  );

  const toolsRequest = JSON.parse(requests[2]?.body ?? "{}") as Record<string, any>;
  assert.equal(toolsRequest.method, "tools/list");
});

async function readRequestBody(request: import("node:http").IncomingMessage): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of request) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  return Buffer.concat(chunks).toString("utf8");
}

const TEST_PRIVATE_KEY = `-----BEGIN PRIVATE KEY-----
MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCV78RxQ/CSw/it
6hDbXOx4fyIYeutCZg78n0zqXttADkqeqok5HXNTE4x01mQRfl01IrWk5jthf6em
YtwCtKwPRJbhKfyQXF9QnBNJ6HykrEeEHQr9GWGfxgMCwlkzN1hJgDxKCf5yl1It
RaREKmzpGEFNj93fVJwvjt/iMX5hA5wrLnDWxrBqQgucckRvGu4+G0AmJG5YfjvU
bbpNCSDgJ2ZEfcGprNUlS7f8H7ly3nNBFjAJ0gZcJeUGLW64C+PFIPpZCZzAVQN0
DTHQCknwHmYc8OpfiO98/0m2z1kUErGjymoFObPlpxMOj9XFkFeqXufoptV70Vbj
FoaFEdUpAgMBAAECggEAE/qayb/0lM3tu1ji7aQMc4L3S11Hr3WTfiiI8nr4yqiM
22cceWKZ/SIv91qhA26740pwe1xdYcDFmWd3axnhinhIhZDXcXIJll9xt4m14Ch/
sBRBpFenOUfEm2/DvI4dos+mWPRLdkABKHys5pNjp0y+2OO4fBuVY0XtwcF4FluV
OfVSUQ1feBSyrpMFwvMOg7rTQ/n1SilAtXZ+5Ew0JbQJ/HyA39DEybC3+UNq64Zp
qcxCo/nHoENHIK6at575lzxyddTI/M7MP1U9h1PNgeMwCvVfMn5zUR/UQmdb1t0X
evE40EmDPW7p10i8y5YlXV+SqKxB/GLQPpfnF96s7QKBgQDQarBu6jvsQD0P5ACV
XDAAMaDIwmNAJRahXjFImfkajNiVzWPgH/9WWqcnNm0fbVyDfOz6OguxlTUuSVMN
YzvNPSekn3M+VZuDRqihvZ4OIaw6EMkrLksbF5wUPrzGTE/S/5LremC+NyQgRq6s
eMa5EKz98wVWJF8sqnHjSvbZHQKBgQC4Kxg17rDvBiAxyo4Bxau8Ohjcx/uvbqRA
oJNWfnJioFAP3Yj9G0JCGoD8rln8C4WjsBUd2rnn7fQ2fG06nyR+gUn/GTZ8J3fA
xNlKpRchP7SycAEib0ZhadEv77QODOjq8Ca0OZ7ztFr4Kz9esAcWSQ0pu/iHYIKZ
daLHKLp6fQKBgEyEbwQ5sQhayVBVODWd4+2eStaKL6A0Pau/Bj8OcJtjzHyrLJjz
hm4w2B+YZtXb89Q+gE6aEwL+scitmPVYUnNWmYBiHhBro629ulmvYSD1EeM7mG/n
DiIDOAVixzHSgJgJxun3Qx9y5SuIZ8bgjK0TRz/xAiuPLPYcGbYGJrytAoGAatmd
31SP1O3B6gFx6HdODxPJ7vYcAQl5RIGlWg5cwPnv2XSXkPmqtH16Dp/9Vy08KN71
MXAAYh59jMsd+F/ypW7PhrCTGu8vHGlZBGTKCaFTbh9rmRXkSIpDMsOovGojDIOu
gOvZW91s1gUJbB9GzVguyeLj629D9lL40QHBR2UCgYBpdTzS8yVf/ezC6EVYZjKR
+WwVPoaUn38JfhwBdVyVIW10mGwbH7asStnpWyz8a+9lUbscq33mLNJskcbJGsNf
fUviBOtnMs2LF0YBS4mWmKhux6XDe40tukEHi7KLVoikyo4my+NSYaecHa9yrybn
JwAQuJ6j3g4rJ5A5z7IxrA==
-----END PRIVATE KEY-----`;

const TEST_CERTIFICATE = `-----BEGIN CERTIFICATE-----
MIIDCTCCAfGgAwIBAgIUNvKJ7/VXagKQs2avkO6SpEsDlyIwDQYJKoZIhvcNAQEL
BQAwFDESMBAGA1UEAwwJMTI3LjAuMC4xMB4XDTI2MDMyMjIxMjAzNFoXDTI2MDMy
MzIxMjAzNFowFDESMBAGA1UEAwwJMTI3LjAuMC4xMIIBIjANBgkqhkiG9w0BAQEF
AAOCAQ8AMIIBCgKCAQEAle/EcUPwksP4reoQ21zseH8iGHrrQmYO/J9M6l7bQA5K
nqqJOR1zUxOMdNZkEX5dNSK1pOY7YX+npmLcArSsD0SW4Sn8kFxfUJwTSeh8pKxH
hB0K/Rlhn8YDAsJZMzdYSYA8Sgn+cpdSLUWkRCps6RhBTY/d31ScL47f4jF+YQOc
Ky5w1sawakILnHJEbxruPhtAJiRuWH471G26TQkg4CdmRH3BqazVJUu3/B+5ct5z
QRYwCdIGXCXlBi1uuAvjxSD6WQmcwFUDdA0x0ApJ8B5mHPDqX4jvfP9Jts9ZFBKx
o8pqBTmz5acTDo/VxZBXql7n6KbVe9FW4xaGhRHVKQIDAQABo1MwUTAdBgNVHQ4E
FgQUMX8/PuB9iHI5uAVyTnNf3CYr6sIwHwYDVR0jBBgwFoAUMX8/PuB9iHI5uAVy
TnNf3CYr6sIwDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAPyia
ZCzlORcu7m8RKBdhYIpAPjqaD6sH0eKx5nem4+Wew2Zb8IEX/FTvDlG18IcneRuJ
8aSyGbgpofQpV6AIDxfON+8imdnSHN3bvAXZrlxiTH2moQZo6SydNjA0Y1/JtUB8
hDqbsMEDM8oS+pbKDe3xdWaeCQXh6foQi6TmHCAT9ZyaubLz8q5Q3biYWJy6qKXN
MHe1gTW1apjVQVWLSwcgjFHAtOTYqwlAIp8DxjuUuPqjKksNmqS3x5tZzVDeddjA
KOeL6RZ/cFO31PmkDRSFhfdcJKk7/qmDAtUBCx1UQm19ZkbAMeEw53evC2PxEJzd
qk0PE9cXZOyB8OE3vw==
-----END CERTIFICATE-----`;
