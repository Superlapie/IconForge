import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import type { McpConfig } from "./config.js";
import { BridgeError, isRecord } from "./errors.js";

const SUPPORTED_SCHEMA_VERSION = 1;

export type IconForgeResponse = Record<string, unknown>;

interface QueueItem {
  request: Record<string, unknown>;
  signal?: AbortSignal | undefined;
  resolve: (value: IconForgeResponse) => void;
  reject: (error: Error) => void;
}

export class IconForgeClient {
  private readonly config: McpConfig;
  private child: ChildProcessWithoutNullStreams | null = null;
  private stdoutBuffer = "";
  private handshakeDone = false;
  private readonly queue: QueueItem[] = [];
  private active: QueueItem | null = null;
  private activeTimer: NodeJS.Timeout | null = null;
  private draining = false;
  private lineWaiter: ((line: string) => void) | null = null;
  private lineRejecter: ((error: Error) => void) | null = null;

  constructor(config: McpConfig) {
    this.config = config;
  }

  async execute(operation: string, payload: Record<string, unknown>, signal?: AbortSignal): Promise<IconForgeResponse> {
    const request = {
      schema_version: SUPPORTED_SCHEMA_VERSION,
      operation,
      ...payload,
    };
    return await new Promise<IconForgeResponse>((resolve, reject) => {
      const item: QueueItem = { request, signal, resolve, reject };
      if (signal?.aborted) {
        reject(new BridgeError("ICONFORGE_MCP_CANCELLED", "MCP tool call was cancelled.", "Retry the request."));
        return;
      }
      signal?.addEventListener(
        "abort",
        () => {
          if (this.active === item) {
            this.failActive(
              new BridgeError("ICONFORGE_MCP_CANCELLED", "MCP tool call was cancelled.", "Retry the request."),
            );
            this.terminateChild("cancelled");
          } else {
            const index = this.queue.indexOf(item);
            if (index >= 0) {
              this.queue.splice(index, 1);
              reject(new BridgeError("ICONFORGE_MCP_CANCELLED", "MCP tool call was cancelled.", "Retry the request."));
            }
          }
        },
        { once: true },
      );
      this.queue.push(item);
      void this.drainQueue();
    });
  }

  async shutdown(): Promise<void> {
    if (!this.child) {
      return;
    }
    try {
      await this.transact({ schema_version: SUPPORTED_SCHEMA_VERSION, operation: "shutdown" });
    } catch {
      this.terminateChild("shutdown");
    }
    await this.waitForExit(2_000);
    this.terminateChild("shutdown");
  }

  private async drainQueue(): Promise<void> {
    if (this.draining || this.active) {
      return;
    }
    this.draining = true;
    while (this.queue.length > 0) {
      const next = this.queue.shift();
      if (!next) {
        break;
      }
      this.active = next;
      try {
        await this.ensureChild();
        if (!this.handshakeDone) {
          await this.performHandshake();
        }
        const response = await this.transact(next.request);
        next.resolve(response);
      } catch (error) {
        next.reject(error instanceof Error ? error : new Error(String(error)));
      } finally {
        this.clearActiveTimer();
        this.active = null;
      }
    }
    this.draining = false;
  }

  private async ensureChild(): Promise<void> {
    if (this.child && this.child.exitCode === null && !this.child.killed) {
      return;
    }
    this.child = null;
    this.handshakeDone = false;
    this.stdoutBuffer = "";
    this.failLineWaiter(
      new BridgeError("ICONFORGE_SERVICE_EXITED", "Icon Forge service is not running.", "Retry the request."),
    );

    const args = [...this.config.iconforgeArgs, "--workspace-root", this.config.workspaceRoot];
    let child: ChildProcessWithoutNullStreams;
    try {
      child = spawn(this.config.iconforgeCommand, args, {
        stdio: ["pipe", "pipe", "pipe"],
        env: {
          ...process.env,
          ICONFORGE_WORKSPACE_ROOT: this.config.workspaceRoot,
        },
        shell: false,
        windowsHide: true,
      });
    } catch (error) {
      throw new BridgeError(
        "ICONFORGE_NOT_FOUND",
        `Failed to spawn Icon Forge service: ${error instanceof Error ? error.message : String(error)}`,
        "Set ICONFORGE_ROOT or ICONFORGE_COMMAND to a local Icon Forge installation.",
      );
    }

    child.stderr.on("data", (chunk: Buffer) => {
      if (this.config.debug) {
        console.error(`[iconforge stderr] ${chunk.toString("utf8").trimEnd()}`);
      }
    });

    child.stdout.on("data", (chunk: Buffer) => {
      this.stdoutBuffer += chunk.toString("utf8");
      this.consumeStdoutLines();
    });

    child.on("exit", (code, signal) => {
      if (this.child !== child) {
        return;
      }
      if (this.config.debug) {
        console.error(`[iconforge] child exited code=${code ?? "null"} signal=${signal ?? "null"}`);
      }
      this.failLineWaiter(
        new BridgeError(
          "ICONFORGE_SERVICE_EXITED",
          "Icon Forge service exited unexpectedly.",
          "Retry the request; Icon Forge will start a fresh service child.",
          { exitCode: code, signal },
        ),
      );
      if (this.active) {
        this.active.reject(
          new BridgeError(
            "ICONFORGE_SERVICE_EXITED",
            "Icon Forge service exited during an in-flight request.",
            "Retry the request.",
            { exitCode: code, signal },
          ),
        );
        this.active = null;
        this.clearActiveTimer();
      }
      while (this.queue.length > 0) {
        const queued = this.queue.shift();
        queued?.reject(
          new BridgeError(
            "ICONFORGE_SERVICE_EXITED",
            "Icon Forge service exited before the queued request ran.",
            "Retry the request.",
          ),
        );
      }
      this.child = null;
      this.handshakeDone = false;
    });

    this.child = child;
    if (this.config.debug) {
      console.error(`[iconforge] spawned pid=${child.pid ?? "unknown"} command=${this.config.iconforgeCommand}`);
    }
  }

  private async performHandshake(): Promise<void> {
    const capabilities = await this.transact({ schema_version: SUPPORTED_SCHEMA_VERSION, operation: "capabilities" });
    if (capabilities.schema_version !== SUPPORTED_SCHEMA_VERSION) {
      this.terminateChild("incompatible");
      throw new BridgeError(
        "ICONFORGE_MCP_INCOMPATIBLE_API",
        `Icon Forge schema_version ${String(capabilities.schema_version)} is not supported (expects ${SUPPORTED_SCHEMA_VERSION}).`,
        "Update Icon Forge or the MCP adapter so their Machine API versions overlap.",
      );
    }
    this.handshakeDone = true;
  }

  private async transact(request: Record<string, unknown>): Promise<IconForgeResponse> {
    if (!this.child?.stdin) {
      throw new BridgeError("ICONFORGE_SERVICE_START_FAILED", "Icon Forge stdin is unavailable.", "Retry the request.");
    }

    const operation = String(request.operation ?? "unknown");
    if (this.config.debug) {
      console.error(`[iconforge] request operation=${operation}`);
    }

    const linePromise = this.waitForLine();
    this.activeTimer = setTimeout(() => {
      this.failActive(
        new BridgeError(
          "ICONFORGE_SERVICE_TIMEOUT",
          `Icon Forge request timed out after ${this.config.timeoutMs}ms.`,
          "Retry the request or increase ICONFORGE_MCP_TIMEOUT_MS for long renders.",
          { operation },
        ),
      );
      this.terminateChild("timeout");
    }, this.config.timeoutMs);

    await new Promise<void>((resolve, reject) => {
      this.child!.stdin.write(`${JSON.stringify(request)}\n`, (error) => {
        if (error) {
          reject(
            new BridgeError(
              "ICONFORGE_SERVICE_START_FAILED",
              `Failed to write request to Icon Forge service: ${error.message}`,
              "Retry the request.",
            ),
          );
          return;
        }
        resolve();
      });
    });

    const line = await linePromise;
    this.clearActiveTimer();
    try {
      const parsed: unknown = JSON.parse(line);
      if (!isRecord(parsed)) {
        throw new Error("response was not a JSON object");
      }
      return parsed;
    } catch (error) {
      this.terminateChild("protocol");
      throw new BridgeError(
        "ICONFORGE_SERVICE_PROTOCOL_ERROR",
        `Icon Forge service returned non-JSON stdout: ${line.slice(0, 200)}`,
        "Retry the request; the MCP bridge will restart the service child.",
        { cause: error instanceof Error ? error.message : String(error) },
      );
    }
  }

  private waitForLine(): Promise<string> {
    const buffered = this.takeBufferedLine();
    if (buffered !== null) {
      return Promise.resolve(buffered);
    }
    return new Promise<string>((resolve, reject) => {
      this.lineWaiter = resolve;
      this.lineRejecter = reject;
    });
  }

  private takeBufferedLine(): string | null {
    const newline = this.stdoutBuffer.indexOf("\n");
    if (newline < 0) {
      return null;
    }
    let line = this.stdoutBuffer.slice(0, newline);
    this.stdoutBuffer = this.stdoutBuffer.slice(newline + 1);
    if (line.endsWith("\r")) {
      line = line.slice(0, -1);
    }
    if (!line.trim()) {
      return this.takeBufferedLine();
    }
    return line;
  }

  private consumeStdoutLines(): void {
    while (true) {
      const line = this.takeBufferedLine();
      if (line === null) {
        return;
      }
      if (this.lineWaiter) {
        const resolve = this.lineWaiter;
        this.lineWaiter = null;
        this.lineRejecter = null;
        resolve(line);
        return;
      }
      this.terminateChild("protocol");
      if (this.config.debug) {
        console.error(`[iconforge] unexpected stdout line: ${line.slice(0, 200)}`);
      }
      this.failActive(
        new BridgeError(
          "ICONFORGE_SERVICE_PROTOCOL_ERROR",
          "Icon Forge service emitted an unexpected stdout line.",
          "Retry the request; the MCP bridge will restart the service child.",
        ),
      );
      return;
    }
  }

  private failLineWaiter(error: Error): void {
    if (this.lineRejecter) {
      const reject = this.lineRejecter;
      this.lineWaiter = null;
      this.lineRejecter = null;
      reject(error);
    }
  }

  private failActive(error: Error): void {
    this.clearActiveTimer();
    if (this.active) {
      this.active.reject(error);
      this.active = null;
    }
    this.failLineWaiter(error);
  }

  private clearActiveTimer(): void {
    if (this.activeTimer) {
      clearTimeout(this.activeTimer);
      this.activeTimer = null;
    }
  }

  private terminateChild(reason: string): void {
    if (this.config.debug) {
      console.error(`[iconforge] terminate child (${reason})`);
    }
    const child = this.child;
    this.child = null;
    this.handshakeDone = false;
    this.stdoutBuffer = "";
    this.failLineWaiter(
      new BridgeError("ICONFORGE_SERVICE_EXITED", "Icon Forge service was terminated.", "Retry the request."),
    );
    if (!child || child.killed) {
      return;
    }
    child.kill("SIGTERM");
    setTimeout(() => {
      if (child.exitCode === null && !child.killed) {
        child.kill("SIGKILL");
      }
    }, 1_000).unref();
  }

  private async waitForExit(timeoutMs: number): Promise<void> {
    const child = this.child;
    if (!child || child.exitCode !== null) {
      return;
    }
    await new Promise<void>((resolve) => {
      const timer = setTimeout(resolve, timeoutMs);
      child.once("exit", () => {
        clearTimeout(timer);
        resolve();
      });
    });
  }
}
