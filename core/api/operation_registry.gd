extends RefCounted
class_name OperationRegistry

## Supported machine API operations and their capability levels.

const SAFE_OPERATIONS: Array[String] = [
	"inspect_asset",
	"render_asset",
	"render_asset_set",
	"validate_output",
	"explain_result",
	"capabilities",
	"schema",
]

const EXPERT_OPERATIONS: Array[String] = [
	"render_expert",
]

const ALL_OPERATIONS: Array[String] = [
	"inspect_asset",
	"render_asset",
	"render_asset_set",
	"validate_output",
	"explain_result",
	"capabilities",
	"schema",
	"render_expert",
]

static func is_safe_operation(operation: String) -> bool:
	return SAFE_OPERATIONS.has(operation)

static func is_known_operation(operation: String) -> bool:
	return ALL_OPERATIONS.has(operation)

static func list_operations() -> Dictionary:
	return {
		"safe": SAFE_OPERATIONS.duplicate(),
		"expert": EXPERT_OPERATIONS.duplicate(),
	}
