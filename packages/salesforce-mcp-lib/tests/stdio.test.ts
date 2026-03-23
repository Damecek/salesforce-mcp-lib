import test from "node:test";
import assert from "node:assert/strict";
import { PassThrough } from "node:stream";
import { startStdioBridge } from "../src/stdio.js";

test("startStdioBridge accepts newline-delimited JSON and responds in the same framing", async () => {
  const input = new PassThrough();
  const output = new PassThrough();
  const error = new PassThrough();

  const outputChunks: Buffer[] = [];
  const errorChunks: Buffer[] = [];
  output.on("data", chunk => outputChunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)));
  error.on("data", chunk => errorChunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)));

  const bridge = startStdioBridge({
    input,
    output,
    error,
    handleMessage: async message => {
      const request = message as Record<string, any>;
      return {
        jsonrpc: "2.0",
        id: request.id,
        result: {
          ok: true
        }
      };
    }
  });

  input.end(
    `${JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      method: "tools/list",
      params: {}
    })}\n`
  );

  await bridge;

  assert.equal(errorChunks.length, 0, Buffer.concat(errorChunks).toString("utf8"));
  assert.equal(
    Buffer.concat(outputChunks).toString("utf8"),
    `${JSON.stringify({ jsonrpc: "2.0", id: 1, result: { ok: true } })}\n`
  );
});
