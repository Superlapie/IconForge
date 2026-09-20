export function isProcessAlive(pid) {
  if (!pid || pid <= 0) {
    return false;
  }
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    if (error && typeof error === "object" && "code" in error && error.code === "EPERM") {
      return true;
    }
    return false;
  }
}

export async function pollUntilGone(pid, timeoutMs = 5_000, intervalMs = 50) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (!isProcessAlive(pid)) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, intervalMs));
  }
  if (isProcessAlive(pid)) {
    throw new Error(`Process ${pid} still alive after ${timeoutMs}ms`);
  }
}
