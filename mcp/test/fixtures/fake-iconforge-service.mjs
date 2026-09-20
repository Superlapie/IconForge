#!/usr/bin/env node
import { spawn } from "node:child_process";
import { createInterface } from "node:readline";

/** @type {import("node:child_process").ChildProcess | null} */
let descendant = null;

const rl = createInterface({ input: process.stdin, crlfDelay: Infinity });

function writeResponse(body) {
  process.stdout.write(`${JSON.stringify(body)}\n`);
}

function stopDescendant() {
  if (!descendant || descendant.exitCode !== null) {
    descendant = null;
    return;
  }
  try {
    descendant.kill("SIGKILL");
  } catch {
    // already exited
  }
  descendant = null;
}

function spawnDescendant(mode = "normal") {
  stopDescendant();
  const script =
    mode === "sigterm_resistant" && process.platform !== "win32"
      ? "process.on('SIGTERM',()=>{});setInterval(()=>{},1e6)"
      : "setInterval(()=>{},1e6)";
  descendant = spawn(process.execPath, ["-e", script], {
    stdio: "ignore",
    shell: false,
  });
  return descendant.pid;
}

rl.on("line", (line) => {
  const trimmed = line.trim();
  if (!trimmed) {
    return;
  }
  let request;
  try {
    request = JSON.parse(trimmed);
  } catch {
    writeResponse({ success: false, code: "INVALID_REQUEST" });
    return;
  }
  const operation = request.operation;
  if (operation === "delay") {
    const ms = Number(request.ms ?? 50);
    setTimeout(() => {
      writeResponse({ success: true, operation: "delay", ms });
    }, ms);
    return;
  }
  if (operation === "crash") {
    process.exit(7);
  }
  if (operation === "garbage") {
    process.stdout.write("not-json\n");
    return;
  }
  if (operation === "shutdown") {
    stopDescendant();
    writeResponse({ success: true, status: "shutdown", schema_version: 1 });
    rl.close();
    process.exit(0);
    return;
  }
  if (operation === "capabilities") {
    writeResponse({ success: true, schema_version: 1, operation: "capabilities", purposes: [] });
    return;
  }
  if (operation === "process_info") {
    writeResponse({ success: true, operation: "process_info", pid: process.pid });
    return;
  }
  if (operation === "prepare_process_tree") {
    const mode = request.mode === "sigterm_resistant" ? "sigterm_resistant" : "normal";
    const descendantPid = spawnDescendant(mode);
    writeResponse({
      success: true,
      operation: "prepare_process_tree",
      service_pid: process.pid,
      descendant_pid: descendantPid,
      mode,
    });
    return;
  }
  writeResponse({ success: true, operation, echo: request });
});

process.stderr.write("fake service ready\n");
