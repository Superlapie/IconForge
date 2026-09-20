#!/usr/bin/env node
import { createInterface } from "node:readline";

const rl = createInterface({ input: process.stdin, crlfDelay: Infinity });

rl.on("line", (line) => {
  const trimmed = line.trim();
  if (!trimmed) {
    return;
  }
  let request;
  try {
    request = JSON.parse(trimmed);
  } catch {
    process.stdout.write(`${JSON.stringify({ success: false, code: "INVALID_REQUEST" })}\n`);
    return;
  }
  const operation = request.operation;
  if (operation === "delay") {
    const ms = Number(request.ms ?? 50);
    setTimeout(() => {
      process.stdout.write(`${JSON.stringify({ success: true, operation: "delay", ms })}\n`);
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
    process.stdout.write(`${JSON.stringify({ success: true, status: "shutdown", schema_version: 1 })}\n`);
    rl.close();
    process.exit(0);
    return;
  }
  if (operation === "capabilities") {
    process.stdout.write(
      `${JSON.stringify({ success: true, schema_version: 1, operation: "capabilities", purposes: [] })}\n`,
    );
    return;
  }
  process.stdout.write(`${JSON.stringify({ success: true, operation, echo: request })}\n`);
});

process.stderr.write("fake service ready\n");
