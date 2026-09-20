import { spawn, type ChildProcess } from "node:child_process";

export interface TerminateProcessTreeOptions {
  reason: string;
  graceMs?: number;
  debug?: boolean;
}

const DEFAULT_GRACE_MS = 1_000;

function debugLog(debug: boolean | undefined, message: string): void {
  if (debug) {
    console.error(`[process-tree] ${message}`);
  }
}

function isChildExited(child: ChildProcess): boolean {
  return child.exitCode !== null || child.signalCode !== null;
}

function waitForChildExit(child: ChildProcess, timeoutMs: number): Promise<void> {
  if (isChildExited(child)) {
    return Promise.resolve();
  }
  return new Promise((resolve) => {
    const timer = setTimeout(() => {
      cleanup();
      resolve();
    }, timeoutMs);
    const onExit = () => {
      cleanup();
      resolve();
    };
    const cleanup = () => {
      clearTimeout(timer);
      child.removeListener("exit", onExit);
      child.removeListener("close", onExit);
    };
    child.once("exit", onExit);
    child.once("close", onExit);
  });
}

async function terminateWindowsTree(child: ChildProcess, options: TerminateProcessTreeOptions): Promise<void> {
  const pid = child.pid;
  if (!pid || isChildExited(child)) {
    return;
  }

  debugLog(options.debug, `taskkill /T /F for pid=${pid} (${options.reason})`);

  await new Promise<void>((resolve) => {
    let settled = false;
    const finish = () => {
      if (settled) {
        return;
      }
      settled = true;
      resolve();
    };

    const killer = spawn("taskkill.exe", ["/PID", String(pid), "/T", "/F"], {
      windowsHide: true,
      stdio: "ignore",
      shell: false,
    });
    killer.on("exit", finish);
    killer.on("error", (error) => {
      debugLog(options.debug, `taskkill failed: ${error.message}; falling back to child.kill()`);
      try {
        child.kill();
      } catch {
        // already exited
      }
      finish();
    });
    child.once("exit", finish);
    child.once("close", finish);
  });

  await waitForChildExit(child, DEFAULT_GRACE_MS + 500);
  debugLog(options.debug, `Windows cleanup completed for pid=${pid}`);
}

function sendPosixSignal(pid: number, signal: NodeJS.Signals, debug: boolean | undefined, label: string): void {
  try {
    process.kill(-pid, signal);
    debugLog(debug, `${signal} sent to process group -${pid} (${label})`);
    return;
  } catch (error) {
    const code = (error as NodeJS.ErrnoException).code;
    if (code === "ESRCH") {
      return;
    }
  }
  try {
    process.kill(pid, signal);
    debugLog(debug, `${signal} sent to pid=${pid} (${label})`);
  } catch (error) {
    const code = (error as NodeJS.ErrnoException).code;
    if (code !== "ESRCH") {
      debugLog(debug, `${signal} failed for pid=${pid}: ${String(error)}`);
    }
  }
}

async function terminatePosixTree(child: ChildProcess, options: TerminateProcessTreeOptions): Promise<void> {
  const pid = child.pid;
  if (!pid || isChildExited(child)) {
    return;
  }

  const graceMs = options.graceMs ?? DEFAULT_GRACE_MS;

  sendPosixSignal(pid, "SIGTERM", options.debug, options.reason);

  // Wait the full grace window even if the direct wrapper child exits promptly.
  // Descendants in the same process group may ignore SIGTERM and must receive SIGKILL.
  await new Promise<void>((resolve) => {
    setTimeout(resolve, graceMs);
  });

  sendPosixSignal(pid, "SIGKILL", options.debug, "escalation");

  await waitForChildExit(child, 500);
  debugLog(options.debug, `POSIX cleanup completed for pid=${pid}`);
}

export async function terminateProcessTree(
  child: ChildProcess,
  options: TerminateProcessTreeOptions,
): Promise<void> {
  if (process.platform === "win32") {
    await terminateWindowsTree(child, options);
    return;
  }
  await terminatePosixTree(child, options);
}
