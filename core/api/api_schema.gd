extends RefCounted
class_name ApiSchema

const _Operations = preload("res://core/api/operation_registry.gd")
const _Purposes = preload("res://core/api/purpose_registry.gd")
const _ErrorCodes = preload("res://core/api/error_codes.gd")
const _Version = preload("res://core/api/icon_forge_version.gd")

## Executable source of truth for machine API request validation and discovery.

const CURRENT_SCHEMA_VERSION: int = 1

const SAFE_HINT_FIELDS: Dictionary = {
	"orientation_hint": {"type": "string", "enum": ["automatic", "upright", "horizontal", "diagonal"]},
	"framing_bias": {"type": "string", "enum": ["automatic", "tighter", "looser"]},
	"asset_class": {"type": "string", "enum": ["automatic", "weapon", "armor", "consumable", "resource", "generic"]},
}

const EXPERT_FIELDS: Array[String] = [
	"preset", "yaw", "pitch", "roll", "occupancy", "padding", "scale",
	"fov", "output", "output_path", "expert_override", "mode",
]

const OPERATION_SCHEMAS: Dictionary = {
	"inspect_asset": {
		"required": ["schema_version", "operation", "asset"],
		"optional": ["asset_id"],
		"fields": {
			"schema_version": {"type": "integer", "enum": [1]},
			"operation": {"type": "string", "enum": ["inspect_asset"]},
			"asset": {"type": "string", "min_length": 1},
			"asset_id": {"type": "string"},
		},
	},
	"render_asset": {
		"required": ["schema_version", "operation", "asset", "purpose"],
		"optional": ["asset_id", "hints", "force"],
		"fields": {
			"schema_version": {"type": "integer", "enum": [1]},
			"operation": {"type": "string", "enum": ["render_asset"]},
			"asset": {"type": "string", "min_length": 1},
			"purpose": {"type": "string"},
			"asset_id": {"type": "string"},
			"hints": {"type": "object", "fields": SAFE_HINT_FIELDS},
			"force": {"type": "boolean"},
		},
	},
	"render_asset_set": {
		"required": ["schema_version", "operation", "asset", "outputs"],
		"optional": ["asset_id", "hints", "force"],
		"fields": {
			"schema_version": {"type": "integer", "enum": [1]},
			"operation": {"type": "string", "enum": ["render_asset_set"]},
			"asset": {"type": "string", "min_length": 1},
			"outputs": {"type": "array", "min_length": 1, "item_type": "string"},
			"asset_id": {"type": "string"},
			"hints": {"type": "object", "fields": SAFE_HINT_FIELDS},
			"force": {"type": "boolean"},
		},
	},
	"validate_output": {
		"required": ["schema_version", "operation", "asset", "output", "purpose"],
		"optional": [],
		"fields": {
			"schema_version": {"type": "integer", "enum": [1]},
			"operation": {"type": "string", "enum": ["validate_output"]},
			"asset": {"type": "string", "min_length": 1},
			"output": {"type": "string", "min_length": 1},
			"purpose": {"type": "string"},
		},
	},
	"explain_result": {
		"required": ["schema_version", "operation"],
		"optional": ["job_id", "manifest"],
		"fields": {
			"schema_version": {"type": "integer", "enum": [1]},
			"operation": {"type": "string", "enum": ["explain_result"]},
			"job_id": {"type": "string"},
			"manifest": {"type": "string"},
		},
	},
	"capabilities": {
		"required": ["schema_version", "operation"],
		"optional": [],
		"fields": {
			"schema_version": {"type": "integer", "enum": [1]},
			"operation": {"type": "string", "enum": ["capabilities"]},
		},
	},
	"schema": {
		"required": ["schema_version", "operation"],
		"optional": [],
		"fields": {
			"schema_version": {"type": "integer", "enum": [1]},
			"operation": {"type": "string", "enum": ["schema"]},
		},
	},
	"render_expert": {
		"required": ["schema_version", "operation", "asset", "preset", "output"],
		"optional": ["yaw", "pitch", "roll", "occupancy", "padding", "scale", "fov", "force"],
		"fields": {
			"schema_version": {"type": "integer", "enum": [1]},
			"operation": {"type": "string", "enum": ["render_expert"]},
			"asset": {"type": "string", "min_length": 1},
			"preset": {"type": "string"},
			"output": {"type": "string", "min_length": 1},
			"yaw": {"type": "number", "min": -360.0, "max": 360.0},
			"pitch": {"type": "number", "min": -90.0, "max": 90.0},
			"roll": {"type": "number", "min": -180.0, "max": 180.0},
			"occupancy": {"type": "number", "min": 0.05, "max": 0.99},
			"padding": {"type": "number", "min": 0.0, "max": 0.5},
			"scale": {"type": "number", "min": 0.1, "max": 4.0},
			"fov": {"type": "number", "min": 10.0, "max": 120.0},
			"force": {"type": "boolean"},
		},
	},
}

static func describe() -> Dictionary:
	var operations: Dictionary = {}
	for operation in OPERATION_SCHEMAS.keys():
		operations[operation] = OPERATION_SCHEMAS[operation].duplicate(true)
	var purpose_registry: RefCounted = _Purposes.new()
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"tool_version": _Version.VERSION,
		"description": "Icon Forge canonical machine API schema.",
		"operations": operations,
		"purposes": purpose_registry.list_purposes(),
		"error_codes": _ErrorCodes.all_codes(),
		"statuses": ["validated", "partial_success", "needs_review", "failed"],
		"safe_mode": {"operations": _Operations.SAFE_OPERATIONS.duplicate()},
		"expert_mode": {"operations": _Operations.EXPERT_OPERATIONS.duplicate(), "fields": EXPERT_FIELDS.duplicate()},
	}

static func capabilities() -> Dictionary:
	var purpose_registry: RefCounted = _Purposes.new()
	var roles: Array = []
	for entry in purpose_registry.list_purposes():
		roles.append(str(entry.get("output_role", "")))
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"tool_version": _Version.VERSION,
		"operations": _Operations.list_operations(),
		"purposes": purpose_registry.purpose_ids(),
		"supported_extensions": ["glb", "gltf", "png", "jpg", "jpeg", "webp"],
		"safe_mode_available": true,
		"expert_mode_available": true,
		"output_roles": roles,
	}
