import process from "node:process";
import { pathToFileURL } from "node:url";
import { resolveConfig } from "./config.js";
import { CliUsageError } from "./errors.js";
import { RemoteMcpProxy } from "./mcpBridge.js";
import { SalesforceTokenClient } from "./oauth.js";
import { startStdioBridge } from "./stdio.js";

export async function runCli(argv: string[], env: NodeJS.ProcessEnv): Promise<void> {
  const config = resolveConfig(argv, env);
  const tokenClient = new SalesforceTokenClient({
    tokenUrl: config.tokenUrl,
    clientId: config.clientId,
    clientSecret: config.clientSecret,
    scope: config.scope,
    resource: config.serverUrl.href
  });
  const bridge = new RemoteMcpProxy({
    serverUrl: config.serverUrl,
    tokenProvider: tokenClient
  });

  await startStdioBridge({
    input: process.stdin,
    output: process.stdout,
    error: process.stderr,
    handleMessage: message => bridge.forwardMessage(message)
  });
}

async function main(): Promise<void> {
  try {
    await runCli(process.argv.slice(2), process.env);
  } catch (error) {
    if (error instanceof CliUsageError) {
      process.stderr.write(`${error.message}\n`);
      process.exitCode = 2;
      return;
    }

    if (error instanceof Error) {
      process.stderr.write(`${error.message}\n`);
    } else {
      process.stderr.write(`${String(error)}\n`);
    }
    process.exitCode = 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
