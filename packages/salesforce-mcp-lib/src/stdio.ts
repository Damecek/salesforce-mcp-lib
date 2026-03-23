import type { Readable, Writable } from "node:stream";

export interface StdioBridgeOptions {
  input: Readable;
  output: Writable;
  error: Writable;
  handleMessage: (message: unknown) => Promise<unknown | undefined>;
}

type MessageFraming = "content-length" | "newline-delimited";

export function startStdioBridge(options: StdioBridgeOptions): Promise<void> {
  const decoder = new TextDecoder();
  let buffer = Buffer.alloc(0);
  let chain = Promise.resolve();
  let outputFraming: MessageFraming = "newline-delimited";

  return new Promise((resolve, reject) => {
    options.input.on("data", chunk => {
      const nextChunk = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
      buffer = Buffer.concat([buffer, nextChunk]);

      while (true) {
        const parsed = tryReadMessage(buffer);
        if (!parsed) {
          break;
        }

        buffer = Buffer.from(parsed.remaining);
        outputFraming = parsed.framing;
        chain = chain
          .then(async () => {
            const payload = JSON.parse(decoder.decode(parsed.body));
            const response = await options.handleMessage(payload);
            if (response !== undefined) {
              writeMessage(options.output, response, outputFraming);
            }
          })
          .catch(error => {
            options.error.write(`${formatError(error)}\n`);
          });
      }
    });

    options.input.on("end", () => {
      chain.then(() => resolve()).catch(reject);
    });

    options.input.on("error", reject);
    options.output.on("error", reject);
  });
}

export function encodeMessage(message: unknown): Buffer {
  const body = Buffer.from(JSON.stringify(message), "utf8");
  return Buffer.concat([Buffer.from(`Content-Length: ${body.length}\r\n\r\n`, "utf8"), body]);
}

function encodeLineDelimitedMessage(message: unknown): Buffer {
  return Buffer.from(`${JSON.stringify(message)}\n`, "utf8");
}

function writeMessage(output: Writable, message: unknown, framing: MessageFraming): void {
  output.write(framing === "content-length" ? encodeMessage(message) : encodeLineDelimitedMessage(message));
}

function tryReadMessage(buffer: Buffer): { body: Uint8Array; remaining: Uint8Array; framing: MessageFraming } | undefined {
  const separatorIndex = buffer.indexOf("\r\n\r\n");
  if (separatorIndex >= 0) {
    const headerText = buffer.subarray(0, separatorIndex).toString("utf8");
    const contentLengthHeader = headerText
      .split("\r\n")
      .map(line => line.trim())
      .find(line => line.toLowerCase().startsWith("content-length:"));

    if (!contentLengthHeader) {
      throw new Error("Missing Content-Length header.");
    }

    const contentLength = Number.parseInt(contentLengthHeader.split(":")[1]?.trim() ?? "", 10);
    if (!Number.isFinite(contentLength) || contentLength < 0) {
      throw new Error("Invalid Content-Length header.");
    }

    const bodyStart = separatorIndex + 4;
    const bodyEnd = bodyStart + contentLength;
    if (buffer.length < bodyEnd) {
      return undefined;
    }

    return {
      body: buffer.subarray(bodyStart, bodyEnd),
      remaining: buffer.subarray(bodyEnd),
      framing: "content-length"
    };
  }

  const newlineIndex = buffer.indexOf("\n");
  if (newlineIndex < 0) {
    return undefined;
  }

  const line = buffer.subarray(0, newlineIndex).toString("utf8").trim();
  const remaining = buffer.subarray(newlineIndex + 1);
  if (!line) {
    return tryReadMessage(Buffer.from(remaining));
  }

  return {
    body: Buffer.from(line, "utf8"),
    remaining,
    framing: "newline-delimited"
  };
}

function formatError(error: unknown): string {
  if (error instanceof Error) {
    return error.stack ?? `${error.name}: ${error.message}`;
  }

  return String(error);
}
