#!/usr/bin/env node
import { serveStdio } from "@modelcontextprotocol/server/stdio";
import { loadConfig } from "./config.js";
import { createServer } from "./server.js";

const config = loadConfig();

if (config.debug) {
  console.error(`[iconforge-mcp] workspace=${config.workspaceRoot} command=${config.iconforgeCommand}`);
}

void serveStdio(() => createServer(config));
