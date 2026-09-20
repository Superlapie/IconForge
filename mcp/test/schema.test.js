import assert from "node:assert/strict";
import test from "node:test";
import {
  EXPERT_FIELDS,
  renderAssetInput,
  renderAssetSetInput,
  validateOutputInput,
} from "../dist/tool-schemas.js";

for (const field of EXPERT_FIELDS) {
  test(`render_asset rejects expert field ${field}`, () => {
    const result = renderAssetInput.safeParse({
      asset: "fixtures/sword.gltf",
      purpose: "inventory_icon",
      [field]: "bad",
    });
    assert.equal(result.success, false);
  });

  test(`render_asset_set rejects expert field ${field}`, () => {
    const result = renderAssetSetInput.safeParse({
      asset: "fixtures/sword.gltf",
      outputs: ["inventory_icon"],
      [field]: "bad",
    });
    assert.equal(result.success, false);
  });
}

test("validate_output accepts output field", () => {
  const result = validateOutputInput.safeParse({
    asset: "fixtures/sword.gltf",
    output: "generated/icons/inventory/example.png",
    purpose: "inventory_icon",
  });
  assert.equal(result.success, true);
});
