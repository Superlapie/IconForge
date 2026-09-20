import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { Client } from "@modelcontextprotocol/client";
import { StdioClientTransport } from "@modelcontextprotocol/client/stdio";
import { MCP_TOOL_NAMES } from "../dist/tool-schemas.js";
import { assertWrappedResponse } from "../dist/tool-results.js";

const MCP_ROOT = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(MCP_ROOT, "..", "..");
const MCP_ENTRY = join(MCP_ROOT, "..", "dist", "index.js");
const ICONFORGE_SH = join(REPO_ROOT, "scripts", "iconforge");

async function withMcpClient(run) {
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [MCP_ENTRY, "--iconforge-root", REPO_ROOT, "--workspace-root", REPO_ROOT],
    env: {
      ...process.env,
      ICONFORGE_ROOT: REPO_ROOT,
      ICONFORGE_WORKSPACE_ROOT: REPO_ROOT,
    },
  });
  const client = new Client({ name: "iconforge-mcp-e2e", version: "0.1.0" });
  await client.connect(transport);
  try {
    await run(client);
  } finally {
    await transport.close();
  }
}

function toolText(result) {
  const block = result.content?.[0];
  return block && block.type === "text" ? block.text : "";
}

test("real MCP e2e against Icon Forge service", { timeout: 600_000 }, async () => {
  assert.ok(existsSync(MCP_ENTRY));
  assert.ok(existsSync(ICONFORGE_SH));

  await withMcpClient(async (client) => {
    const tools = await client.listTools();
    const names = tools.tools.map((tool) => tool.name).sort();
    assert.deepEqual(names, [...MCP_TOOL_NAMES].sort());

    const caps = await client.callTool({ name: "iconforge_capabilities", arguments: {} });
    const capsBody = assertWrappedResponse(caps.structuredContent);
    assert.equal(capsBody.success, true);

    const schema = await client.callTool({ name: "iconforge_schema", arguments: {} });
    const schemaBody = assertWrappedResponse(schema.structuredContent);
    assert.equal(schemaBody.success, true);

    const inspect = await client.callTool({
      name: "iconforge_inspect_asset",
      arguments: { asset: "fixtures/sword.gltf", asset_id: "mcp_e2e_sword" },
    });
    const inspectBody = assertWrappedResponse(inspect.structuredContent);
    assert.equal(inspectBody.success, true);

    const render = await client.callTool({
      name: "iconforge_render_asset",
      arguments: {
        asset: "fixtures/sword.gltf",
        purpose: "inventory_icon",
        asset_id: "mcp_e2e_sword",
        force: true,
      },
    });
    const renderBody = assertWrappedResponse(render.structuredContent);
    assert.equal(renderBody.success, true);
    assert.equal(renderBody.status, "validated");
    const outputPath = renderBody.output?.path;
    assert.ok(typeof outputPath === "string" && existsSync(outputPath));
    assert.ok(typeof renderBody.manifest === "string" && existsSync(renderBody.manifest));

    const cache = await client.callTool({
      name: "iconforge_render_asset",
      arguments: {
        asset: "fixtures/sword.gltf",
        purpose: "inventory_icon",
        asset_id: "mcp_e2e_sword",
      },
    });
    const cacheBody = assertWrappedResponse(cache.structuredContent);
    assert.equal(cacheBody.cache_hit, true);

    const setResult = await client.callTool({
      name: "iconforge_render_asset_set",
      arguments: {
        asset: "fixtures/sword.gltf",
        outputs: ["shop_thumbnail", "equipment_preview"],
        asset_id: "mcp_e2e_set",
        force: true,
      },
    });
    const setBody = assertWrappedResponse(setResult.structuredContent);
    assert.equal(setBody.success, true);

    const relativeOutput = String(outputPath).startsWith(REPO_ROOT)
      ? String(outputPath).slice(REPO_ROOT.length + 1).replaceAll("\\", "/")
      : String(outputPath);

    const validate = await client.callTool({
      name: "iconforge_validate_output",
      arguments: {
        asset: "fixtures/sword.gltf",
        output: relativeOutput,
        purpose: "inventory_icon",
      },
    });
    const validateBody = assertWrappedResponse(validate.structuredContent);
    assert.equal(validateBody.success, true);

    const explain = await client.callTool({
      name: "iconforge_explain_result",
      arguments: { job_id: String(renderBody.job_id) },
    });
    const explainBody = assertWrappedResponse(explain.structuredContent);
    assert.equal(explainBody.success, true);

    const expertRejected = await client.callTool({
      name: "iconforge_render_asset",
      arguments: {
        asset: "fixtures/sword.gltf",
        purpose: "inventory_icon",
        yaw: 12,
      },
    });
    assert.equal(expertRejected.isError, true);
    assert.match(toolText(expertRejected), /unrecognized|invalid|unknown|additional/i);

    const [a, b] = await Promise.all([
      client.callTool({ name: "iconforge_capabilities", arguments: {} }),
      client.callTool({ name: "iconforge_schema", arguments: {} }),
    ]);
    assert.equal(assertWrappedResponse(a.structuredContent).success, true);
    assert.equal(assertWrappedResponse(b.structuredContent).success, true);
  });
});
