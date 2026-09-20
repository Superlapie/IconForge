import { existsSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { BridgeError } from "./errors.js";

export interface McpConfig {
  iconforgeCommand: string;
  iconforgeArgs: string[];
  workspaceRoot: string;
  timeoutMs: number;
  debug: boolean;
}

const DEFAULT_TIMEOUT_MS = 300_000;
const MIN_TIMEOUT_MS = 1_000;
const MAX_TIMEOUT_MS = 3_600_000;

function parseTimeout(raw: string | undefined): number {
  if (!raw) {
    return DEFAULT_TIMEOUT_MS;
  }
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed)) {
    return DEFAULT_TIMEOUT_MS;
  }
  return Math.min(MAX_TIMEOUT_MS, Math.max(MIN_TIMEOUT_MS, parsed));
}

function isIconForgeRoot(root: string): boolean {
  return (
    existsSync(join(root, "project.godot")) &&
    existsSync(join(root, "core", "api", "api_service.gd")) &&
    existsSync(join(root, "scripts", "iconforge"))
  );
}

function detectPackageRoot(): string {
  return resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
}

function resolveIconForgeInvocation(explicitCommand: string | undefined, explicitRoot: string | undefined): {
  command: string;
  args: string[];
} {
  if (explicitCommand) {
    return { command: explicitCommand, args: ["service"] };
  }

  const rootCandidates: string[] = [];
  if (explicitRoot) {
    rootCandidates.push(resolve(explicitRoot));
  }
  rootCandidates.push(detectPackageRoot());

  for (const root of rootCandidates) {
    if (!isIconForgeRoot(root)) {
      continue;
    }
    if (process.platform === "win32") {
      const ps1 = join(root, "scripts", "iconforge.ps1");
      if (existsSync(ps1)) {
        return { command: resolvePowerShell(), args: ["-NoProfile", "-File", ps1, "service"] };
      }
    }
    const sh = join(root, "scripts", "iconforge");
    if (existsSync(sh)) {
      return { command: sh, args: ["service"] };
    }
  }

  const pathFallback = process.platform === "win32" ? "iconforge.exe" : "iconforge";
  return { command: pathFallback, args: ["service"] };
}

function resolvePowerShell(): string {
  if (process.env.ProgramFiles) {
    const pwsh = join(process.env.ProgramFiles, "PowerShell", "7", "pwsh.exe");
    if (existsSync(pwsh)) {
      return pwsh;
    }
  }
  return "powershell.exe";
}

function resolveWorkspaceRoot(explicit: string | undefined): string {
  const candidate = resolve(explicit ?? process.env.ICONFORGE_WORKSPACE_ROOT ?? process.cwd());
  if (!existsSync(candidate) || !statSync(candidate).isDirectory()) {
    throw new BridgeError(
      "ICONFORGE_WORKSPACE_INVALID",
      `Workspace root does not exist: ${candidate}`,
      "Set ICONFORGE_WORKSPACE_ROOT to an existing project directory.",
    );
  }
  return candidate;
}

export function loadConfig(argv: string[] = process.argv.slice(2)): McpConfig {
  const options = parseArgv(argv);
  const invocation = resolveIconForgeInvocation(
    options.iconforgeCommand ?? process.env.ICONFORGE_COMMAND,
    options.iconforgeRoot ?? process.env.ICONFORGE_ROOT,
  );

  if (!existsSync(invocation.command) && !invocation.command.includes("/") && !invocation.command.includes("\\")) {
    // PATH fallback — validated on first spawn attempt.
  } else if (!existsSync(invocation.command) && (invocation.command.includes("/") || invocation.command.includes("\\"))) {
    throw new BridgeError(
      "ICONFORGE_NOT_FOUND",
      `Icon Forge executable not found: ${invocation.command}`,
      "Set ICONFORGE_ROOT or ICONFORGE_COMMAND to a local Icon Forge installation.",
    );
  }

  return {
    iconforgeCommand: invocation.command,
    iconforgeArgs: invocation.args,
    workspaceRoot: resolveWorkspaceRoot(options.workspaceRoot),
    timeoutMs: parseTimeout(options.timeoutMs ?? process.env.ICONFORGE_MCP_TIMEOUT_MS),
    debug: options.debug ?? process.env.ICONFORGE_MCP_DEBUG === "1",
  };
}

interface ParsedArgv {
  iconforgeCommand?: string;
  iconforgeRoot?: string;
  workspaceRoot?: string;
  timeoutMs?: string;
  debug?: boolean;
}

function parseArgv(argv: string[]): ParsedArgv {
  const result: ParsedArgv = {};
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--debug") {
      result.debug = true;
      continue;
    }
    if (arg === "--iconforge-command") {
      const value = argv[index + 1];
      if (value) {
        result.iconforgeCommand = value;
        index += 1;
      }
      continue;
    }
    if (arg === "--iconforge-root") {
      const value = argv[index + 1];
      if (value) {
        result.iconforgeRoot = value;
        index += 1;
      }
      continue;
    }
    if (arg === "--workspace-root") {
      const value = argv[index + 1];
      if (value) {
        result.workspaceRoot = value;
        index += 1;
      }
      continue;
    }
    if (arg === "--timeout-ms") {
      const value = argv[index + 1];
      if (value) {
        result.timeoutMs = value;
        index += 1;
      }
    }
  }
  return result;
}
