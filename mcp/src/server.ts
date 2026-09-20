import { McpServer, type ServerContext } from "@modelcontextprotocol/server";
import type { McpConfig } from "./config.js";
import { IconForgeClient } from "./iconforge-client.js";
import {
  explainResultInput,
  inspectAssetInput,
  renderAssetInput,
  renderAssetSetInput,
  validateOutputInput,
} from "./tool-schemas.js";
import { bridgeErrorResult, toToolResult } from "./tool-results.js";

export function createServer(config: McpConfig): McpServer {
  const client = new IconForgeClient(config);
  const server = new McpServer(
    { name: "iconforge-mcp", version: "0.1.0" },
    { capabilities: { tools: {} } },
  );

  const run = async (
    operation: string,
    payload: Record<string, unknown>,
    ctx: ServerContext,
  ) => {
    try {
      const response = await client.execute(operation, payload, ctx.mcpReq.signal);
      return toToolResult(response);
    } catch (error) {
      return bridgeErrorResult(error);
    }
  };

  server.registerTool(
    "iconforge_capabilities",
    {
      description: "Discover supported semantic operations, purposes, and safe-mode authorable capabilities.",
      annotations: { readOnlyHint: true, destructiveHint: false },
    },
    async (ctx: ServerContext) => await run("capabilities", {}, ctx),
  );

  server.registerTool(
    "iconforge_schema",
    {
      description: "Retrieve the canonical Machine API schema for advanced integration or debugging.",
      annotations: { readOnlyHint: true, destructiveHint: false },
    },
    async (ctx: ServerContext) => await run("schema", {}, ctx),
  );

  server.registerTool(
    "iconforge_inspect_asset",
    {
      description:
        "Inspect a source asset without rendering. Rendering already inspects internally, so this is optional before render.",
      annotations: { readOnlyHint: true, destructiveHint: false },
      inputSchema: inspectAssetInput,
    },
    async (args, ctx) => await run("inspect_asset", args as Record<string, unknown>, ctx),
  );

  server.registerTool(
    "iconforge_render_asset",
    {
      description:
        "Generate one production-validated image for one semantic purpose. Prefer this over any renderer-level controls.",
      annotations: { readOnlyHint: false, destructiveHint: false },
      inputSchema: renderAssetInput,
    },
    async (args, ctx) => await run("render_asset", args as Record<string, unknown>, ctx),
  );

  server.registerTool(
    "iconforge_render_asset_set",
    {
      description:
        "Generate multiple semantic image purposes from one source while reusing inspection efficiently.",
      annotations: { readOnlyHint: false, destructiveHint: false },
      inputSchema: renderAssetSetInput,
    },
    async (args, ctx) => await run("render_asset_set", args as Record<string, unknown>, ctx),
  );

  server.registerTool(
    "iconforge_validate_output",
    {
      description: "Validate an existing image against the applicable production contract without rendering a new image.",
      annotations: { readOnlyHint: true, destructiveHint: false },
      inputSchema: validateOutputInput,
    },
    async (args, ctx) => await run("validate_output", args as Record<string, unknown>, ctx),
  );

  server.registerTool(
    "iconforge_explain_result",
    {
      description: "Explain provenance, decisions, correction trace, or outcome for a previous Icon Forge job.",
      annotations: { readOnlyHint: true, destructiveHint: false },
      inputSchema: explainResultInput,
    },
    async (args, ctx) => await run("explain_result", args as Record<string, unknown>, ctx),
  );

  const shutdown = async () => {
    try {
      await client.shutdown();
    } catch (error) {
      if (config.debug) {
        console.error(`[iconforge-mcp] shutdown error: ${error instanceof Error ? error.message : String(error)}`);
      }
    }
  };

  process.once("SIGINT", () => {
    void shutdown().finally(() => process.exit(0));
  });
  process.once("SIGTERM", () => {
    void shutdown().finally(() => process.exit(0));
  });

  return server;
}
