import test from "node:test";
import assert from "node:assert/strict";
import { mkdir, symlink, writeFile } from "node:fs/promises";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

test("CLI entrypoint runs when invoked through a symlinked bin path", async () => {
  const tmpRoot = mkdtempSync(path.join(tmpdir(), "salesforce-mcp-lib-bin-test-"));
  const moduleDir = path.join(tmpRoot, "pkg");
  const binDir = path.join(tmpRoot, ".bin");
  const entryPath = fileURLToPath(new URL("../src/index.ts", import.meta.url));
  const binPath = path.join(binDir, "salesforce-mcp-lib");

  await mkdir(moduleDir, { recursive: true });
  await mkdir(binDir, { recursive: true });
  await writeFile(path.join(moduleDir, "package.json"), JSON.stringify({ type: "module" }));
  await symlink(entryPath, binPath);

  const child = spawn(
    process.execPath,
    ["--import", "tsx", binPath],
    {
      cwd: path.resolve(path.dirname(fileURLToPath(import.meta.url)), ".."),
      env: {
        ...process.env
      },
      stdio: ["ignore", "pipe", "pipe"]
    }
  );

  const stdoutChunks: Buffer[] = [];
  const stderrChunks: Buffer[] = [];
  child.stdout.on("data", chunk => stdoutChunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)));
  child.stderr.on("data", chunk => stderrChunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)));

  const [exitCode] = await new Promise<[number | null]>((resolve, reject) => {
    child.on("error", reject);
    child.on("close", code => resolve([code]));
  });

  assert.equal(Buffer.concat(stdoutChunks).toString("utf8"), "");
  assert.match(Buffer.concat(stderrChunks).toString("utf8"), /Missing --url/);
  assert.equal(exitCode, 2);
});
