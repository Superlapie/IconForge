import type { CallToolResult } from "@modelcontextprotocol/server";
import { BridgeError, isRecord } from "./errors.js";
import type { IconForgeResponse } from "./iconforge-client.js";
import { wrappedResponseSchema } from "./tool-schemas.js";

export function toToolResult(response: IconForgeResponse): CallToolResult {
  const wrapped = { response };
  const status = typeof response.status === "string" ? response.status : undefined;
  const success = response.success === true;
  const textPrefix =
    status === "needs_review"
      ? "NEEDS_REVIEW: "
      : status === "partial_success"
        ? "PARTIAL_SUCCESS: "
        : "";

  const isError =
    response.success === false &&
    status !== "needs_review" &&
    status !== "partial_success";

  return {
    content: [{ type: "text", text: `${textPrefix}${JSON.stringify(response)}` }],
    structuredContent: wrapped,
    isError,
  };
}

export function bridgeErrorResult(error: unknown): CallToolResult {
  const body =
    error instanceof BridgeError
      ? error.body
      : {
          source: "iconforge_mcp" as const,
          success: false as const,
          code: "ICONFORGE_SERVICE_START_FAILED" as const,
          message: error instanceof Error ? error.message : String(error),
          recommended_action: "Inspect MCP stderr logs and retry.",
        };
  const wrapped = { response: body };
  return {
    content: [{ type: "text", text: JSON.stringify(body) }],
    structuredContent: wrapped,
    isError: true,
  };
}

export function assertWrappedResponse(value: unknown): IconForgeResponse {
  const parsed = wrappedResponseSchema.safeParse(value);
  if (!parsed.success || !isRecord(parsed.data.response)) {
    throw new Error("structured MCP response missing Icon Forge payload");
  }
  return parsed.data.response;
}
