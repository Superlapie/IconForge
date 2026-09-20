import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import test from "node:test";
import { IconForgeClient } from "../dist/iconforge-client.js";
import { BridgeError } from "../dist/errors.js";
import { isProcessAlive, killProcessIfAlive, pollUntilGone } from "./process-helpers.js";

const ROOT = dirname(fileURLToPath(import.meta.url));
const FAKE = join(ROOT, "fixtures", "fake-iconforge-service.mjs");

function makeClient(overrides = {}) {
  return new IconForgeClient({
    iconforgeCommand: process.execPath,
    iconforgeArgs: [FAKE],
    workspaceRoot: ROOT,
    timeoutMs: 2_000,
    debug: false,
    ...overrides,
  });
}

test("serializes concurrent requests in order", async () => {
  const client = makeClient();
  const [first, second] = await Promise.all([
    client.execute("echo", { n: 1 }),
    client.execute("echo", { n: 2 }),
  ]);
  assert.equal(first.echo.n, 1);
  assert.equal(second.echo.n, 2);
  await client.shutdown();
});

test("protocol corruption fails and restarts child", async () => {
  const client = makeClient();
  await assert.rejects(
    () => client.execute("garbage", {}),
    (error) => error instanceof BridgeError && error.body.code === "ICONFORGE_SERVICE_PROTOCOL_ERROR",
  );
  const ok = await client.execute("echo", { recovered: true });
  assert.equal(ok.echo.recovered, true);
  await client.shutdown();
});

test("child crash rejects in-flight request", async () => {
  const client = makeClient();
  await assert.rejects(
    () => client.execute("crash", {}),
    (error) => error instanceof BridgeError && error.body.code === "ICONFORGE_SERVICE_EXITED",
  );
  const ok = await client.execute("echo", { afterCrash: true });
  assert.equal(ok.echo.afterCrash, true);
  await client.shutdown();
});

test("timeout terminates child", async () => {
  const client = makeClient({ timeoutMs: 100 });
  await assert.rejects(
    () => client.execute("delay", { ms: 500 }),
    (error) => error instanceof BridgeError && error.body.code === "ICONFORGE_SERVICE_TIMEOUT",
  );
  const ok = await client.execute("echo", { afterTimeout: true });
  assert.equal(ok.echo.afterTimeout, true);
  await client.shutdown();
});

test("shutdown terminates the original MCP-owned child", async () => {
  const client = makeClient();
  const info = await client.execute("process_info", {});
  const servicePid = info.pid;
  assert.ok(typeof servicePid === "number" && servicePid > 0);
  assert.equal(isProcessAlive(servicePid), true);
  await client.shutdown();
  await pollUntilGone(servicePid);
});

test("forced timeout terminates service and descendant process tree", async () => {
  const client = makeClient({ timeoutMs: 150 });
  let servicePid;
  let descendantPid;
  try {
    const tree = await client.execute("prepare_process_tree", {});
    servicePid = tree.service_pid;
    descendantPid = tree.descendant_pid;
    assert.ok(isProcessAlive(servicePid));
    assert.ok(isProcessAlive(descendantPid));

    await assert.rejects(
      () => client.execute("delay", { ms: 5_000 }),
      (error) => error instanceof BridgeError && error.body.code === "ICONFORGE_SERVICE_TIMEOUT",
    );

    await pollUntilGone(servicePid);
    await pollUntilGone(descendantPid);
  } finally {
    killProcessIfAlive(descendantPid);
    killProcessIfAlive(servicePid);
    try {
      await client.shutdown();
    } catch {
      // service may already be forcibly terminated
    }
  }
});

if (process.platform !== "win32") {
  test("POSIX SIGTERM-resistant descendant is escalated to SIGKILL", async () => {
    const client = makeClient({ timeoutMs: 150 });
    let servicePid;
    let descendantPid;
    try {
      const tree = await client.execute("prepare_process_tree", { mode: "sigterm_resistant" });
      servicePid = tree.service_pid;
      descendantPid = tree.descendant_pid;
      assert.ok(isProcessAlive(descendantPid));

      await assert.rejects(
        () => client.execute("delay", { ms: 5_000 }),
        (error) => error instanceof BridgeError && error.body.code === "ICONFORGE_SERVICE_TIMEOUT",
      );

      await pollUntilGone(servicePid);
      await pollUntilGone(descendantPid, 3_000);
    } finally {
      killProcessIfAlive(descendantPid);
      killProcessIfAlive(servicePid);
      try {
        await client.shutdown();
      } catch {
        // service may already be forcibly terminated
      }
    }
  });
}
