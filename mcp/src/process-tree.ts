import { spawn, type ChildProcess } from "node:child_process";

export interface TerminateProcessTreeOptions {
  reason: string;
  graceMs?: number;
  debug?: boolean;
}

const DEFAULT_GRACE_MS = 1_000;
const POLL_INTERVAL_MS = 50;
const TASKKILL_TIMEOUT_MS = DEFAULT_GRACE_MS + 2_000;
const GROUP_GONE_TIMEOUT_MS = DEFAULT_GRACE_MS + 2_000;

function debugLog(debug: boolean | undefined, message: string): void {
  if (debug) {
    console.error(`[process-tree] ${message}`);
  }
}

function isChildExited(child: ChildProcess): boolean {
  return child.exitCode !== null || child.signalCode !== null;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

function isProcessGroupAlive(pgid: number): boolean {
  try {
    process.kill(-pgid, 0);
    return true;
  } catch (error) {
    const code = (error as NodeJS.ErrnoException).code;
    if (code === "ESRCH") {
      return false;
    }
    if (code === "EPERM") {
      return true;
    }
    return false;
  }
}

async function pollUntilGroupGone(pgid: number, timeoutMs: number, debug?: boolean): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (!isProcessGroupAlive(pgid)) {
      return;
    }
    await sleep(POLL_INTERVAL_MS);
  }
  if (isProcessGroupAlive(pgid)) {
    debugLog(debug, `process group -${pgid} still alive after ${timeoutMs}ms poll`);
  }
}

async function waitGraceOrGroupGone(pgid: number, graceMs: number): Promise<boolean> {
  const deadline = Date.now() + graceMs;
  while (Date.now() < deadline) {
    if (!isProcessGroupAlive(pgid)) {
      return true;
    }
    await sleep(POLL_INTERVAL_MS);
  }
  return !isProcessGroupAlive(pgid);
}

async function terminateWindowsTree(child: ChildProcess, options: TerminateProcessTreeOptions): Promise<void> {
  const pid = child.pid;
  if (!pid || isChildExited(child)) {
    return;
  }

  debugLog(options.debug, `taskkill /T /F for pid=${pid} (${options.reason})`);

  await new Promise<void>((resolve) => {
    const killer = spawn("taskkill.exe", ["/PID", String(pid), "/T", "/F"], {
      windowsHide: true,
      stdio: "ignore",
      shell: false,
    });

    const timer = setTimeout(() => {
      debugLog(options.debug, `taskkill timed out for pid=${pid}`);
      try {
        killer.kill();
      } catch {
        // taskkill already finished
      }
      resolve();
    }, TASKKILL_TIMEOUT_MS);

    killer.on("exit", (code) => {
      clearTimeout(timer);
      debugLog(options.debug, `taskkill exited code=${code ?? "null"} for pid=${pid}`);
      resolve();
    });
    killer.on("error", (error) => {
      clearTimeout(timer);
      debugLog(options.debug, `taskkill failed: ${error.message}; falling back to child.kill()`);
      try {
        child.kill();
      } catch {
        // already exited
      }
      resolve();
    });
  });

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

  const goneDuringGrace = await waitGraceOrGroupGone(pid, graceMs);
  if (goneDuringGrace) {
    debugLog(options.debug, `process group -${pid} gone during SIGTERM grace (${options.reason})`);
    return;
  }

  sendPosixSignal(pid, "SIGKILL", options.debug, "escalation");
  await pollUntilGroupGone(pid, GROUP_GONE_TIMEOUT_MS, options.debug);
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
