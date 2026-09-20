import * as z from "zod/v4";

export const hintsSchema = z
  .object({
    orientation_hint: z.enum(["automatic", "upright", "horizontal", "diagonal"]).optional(),
    framing_bias: z.enum(["automatic", "tighter", "looser"]).optional(),
    asset_class: z.enum(["automatic", "weapon", "armor", "consumable", "resource", "generic"]).optional(),
  })
  .strict()
  .optional();

export const inspectAssetInput = z
  .object({
    asset: z.string().min(1).describe("Workspace-relative path to a GLB/glTF/image source asset."),
    asset_id: z.string().optional().describe("Optional stable asset identifier used for output naming."),
  })
  .strict();

export const renderAssetInput = z
  .object({
    asset: z.string().min(1).describe("Workspace-relative path to the source asset to render."),
    purpose: z.string().min(1).describe("Semantic purpose such as inventory_icon. Call iconforge_capabilities to discover purposes."),
    asset_id: z.string().optional().describe("Optional stable asset identifier for output paths."),
    hints: hintsSchema,
    force: z.boolean().optional().describe("When true, bypass cache and produce a fresh validated render."),
  })
  .strict();

export const renderAssetSetInput = z
  .object({
    asset: z.string().min(1).describe("Workspace-relative path to the shared source asset."),
    outputs: z.array(z.string().min(1)).min(1).describe("Semantic purposes to render from the same source in one efficient batch."),
    asset_id: z.string().optional(),
    hints: hintsSchema,
    force: z.boolean().optional(),
  })
  .strict();

export const validateOutputInput = z
  .object({
    asset: z.string().min(1).describe("Workspace-relative source asset path tied to the output."),
    output: z.string().min(1).describe("Workspace-relative validated PNG path to check."),
    purpose: z.string().min(1).describe("Semantic purpose contract to validate against."),
  })
  .strict();

export const explainResultInput = z
  .object({
    job_id: z.string().optional().describe("Job identifier returned by a prior render operation."),
    manifest: z.string().optional().describe("Manifest path returned by a prior render operation."),
  })
  .strict()
  .refine((value) => Boolean(value.job_id || value.manifest), {
    message: "Provide job_id or manifest from a prior Icon Forge result.",
  });

export const iconForgeResponseSchema = z.record(z.string(), z.unknown());

export const wrappedResponseSchema = z.object({
  response: iconForgeResponseSchema,
});

export const MCP_TOOL_NAMES = [
  "iconforge_capabilities",
  "iconforge_schema",
  "iconforge_inspect_asset",
  "iconforge_render_asset",
  "iconforge_render_asset_set",
  "iconforge_validate_output",
  "iconforge_explain_result",
] as const;

export const EXPERT_FIELDS = [
  "preset",
  "yaw",
  "pitch",
  "roll",
  "occupancy",
  "padding",
  "scale",
  "fov",
  "output_path",
  "expert_override",
  "mode",
  "output",
] as const;
