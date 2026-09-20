export type BridgeErrorCode =
  | "ICONFORGE_NOT_FOUND"
  | "ICONFORGE_WORKSPACE_INVALID"
  | "ICONFORGE_SERVICE_START_FAILED"
  | "ICONFORGE_SERVICE_EXITED"
  | "ICONFORGE_SERVICE_TIMEOUT"
  | "ICONFORGE_SERVICE_PROTOCOL_ERROR"
  | "ICONFORGE_MCP_INCOMPATIBLE_API"
  | "ICONFORGE_MCP_CANCELLED";

export interface BridgeErrorBody {
  source: "iconforge_mcp";
  success: false;
  code: BridgeErrorCode;
  message: string;
  recommended_action: string;
  details?: Record<string, unknown>;
}

export class BridgeError extends Error {
  readonly body: BridgeErrorBody;

  constructor(code: BridgeErrorCode, message: string, recommended_action: string, details?: Record<string, unknown>) {
    super(message);
    this.name = "BridgeError";
    this.body = {
      source: "iconforge_mcp",
      success: false,
      code,
      message,
      recommended_action,
      ...(details ? { details } : {}),
    };
  }
}

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
