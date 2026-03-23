import process from "node:process";
import { spawn } from "node:child_process";
import { pathToFileURL } from "node:url";
import { encodeMessage } from "./stdio.js";

async function run(): Promise<void> {
  const cliPath = new URL("./index.js", import.meta.url);
  const url = process.env.SF_MCP_URL;

  if (!url) {
    throw new Error("Missing SF_MCP_URL for smoke run.");
  }

  const child = spawn(process.execPath, [cliPath.pathname, "--url", url], {
    env: process.env,
    stdio: ["pipe", "pipe", "inherit"]
  });

  const initialize = {
    jsonrpc: "2.0",
    id: 1,
    method: "initialize",
    params: {
      protocolVersion: "2025-06-18",
      capabilities: {},
      clientInfo: {
        name: "salesforce-mcp-lib-smoke",
        version: "1.0.0"
      }
    }
  };

  const toolsList = {
    jsonrpc: "2.0",
    id: 2,
    method: "tools/list",
    params: {}
  };

  child.stdin.end(Buffer.concat([encodeMessage(initialize), encodeMessage(toolsList)]));

  const chunks: Buffer[] = [];
  child.stdout.on("data", chunk => chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)));

  const exitCode = await new Promise<number>((resolve, reject) => {
    child.on("error", reject);
    child.on("close", code => resolve(code ?? 0));
  });

  if (exitCode !== 0) {
    throw new Error(`Smoke CLI exited with code ${exitCode}.`);
  }

  const output = Buffer.concat(chunks).toString("utf8");
  if (!output.includes('"method":"initialize"') && !output.includes('"protocolVersion"')) {
    throw new Error("Smoke output did not include an initialize response.");
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await run();
}
