extends RefCounted
class_name ApiErrorCodes

## Canonical machine-readable error codes with deterministic recovery guidance.

const CODES: Dictionary = {
	"INVALID_REQUEST": {"recommended_action": "retry_same_request", "status": "failed"},
	"UNSUPPORTED_SCHEMA_VERSION": {"recommended_action": "retry_same_request", "status": "failed"},
	"UNKNOWN_OPERATION": {"recommended_action": "retry_same_request", "status": "failed"},
	"UNKNOWN_FIELD": {"recommended_action": "retry_same_request", "status": "failed"},
	"INVALID_FIELD_TYPE": {"recommended_action": "retry_same_request", "status": "failed"},
	"INVALID_ENUM_VALUE": {"recommended_action": "retry_same_request", "status": "failed"},
	"SOURCE_NOT_FOUND": {"recommended_action": "provide_supported_source", "status": "failed"},
	"SOURCE_UNSUPPORTED": {"recommended_action": "provide_supported_source", "status": "failed"},
	"SOURCE_CORRUPT": {"recommended_action": "repair_source_asset", "status": "failed"},
	"SOURCE_IMPORT_FAILED": {"recommended_action": "repair_source_asset", "status": "failed"},
	"PURPOSE_UNSUPPORTED": {"recommended_action": "select_supported_purpose", "status": "failed"},
	"PURPOSE_SOURCE_MISMATCH": {"recommended_action": "select_supported_purpose", "status": "failed"},
	"PRESET_NOT_FOUND": {"recommended_action": "retry_same_request", "status": "failed"},
	"PRESET_PURPOSE_MISMATCH": {"recommended_action": "select_supported_purpose", "status": "failed"},
	"RECIPE_RESOLUTION_FAILED": {"recommended_action": "manual_composition_review", "status": "needs_review"},
	"RENDER_FAILED": {"recommended_action": "retry_same_request", "status": "failed"},
	"OUTPUT_MISSING": {"recommended_action": "retry_same_request", "status": "failed"},
	"OUTPUT_INVALID": {"recommended_action": "retry_same_request", "status": "failed"},
	"OUTPUT_EMPTY": {"recommended_action": "manual_composition_review", "status": "needs_review"},
	"OUTPUT_CLIPPED": {"recommended_action": "manual_composition_review", "status": "needs_review"},
	"OCCUPANCY_LOW": {"recommended_action": "manual_composition_review", "status": "needs_review"},
	"OCCUPANCY_HIGH": {"recommended_action": "manual_composition_review", "status": "needs_review"},
	"ALPHA_INVALID": {"recommended_action": "manual_composition_review", "status": "needs_review"},
	"QUALITY_FAILED": {"recommended_action": "manual_composition_review", "status": "needs_review"},
	"FRAMING_UNRESOLVED": {"recommended_action": "manual_composition_review", "status": "needs_review"},
	"WRITE_FAILED": {"recommended_action": "check_workspace_permissions", "status": "failed"},
	"PATH_NOT_ALLOWED": {"recommended_action": "check_workspace_permissions", "status": "failed"},
	"JOB_CANCELLED": {"recommended_action": "retry_same_request", "status": "failed"},
	"INTERNAL_ERROR": {"recommended_action": "retry_same_request", "status": "failed"},
	"DUPLICATE_OUTPUTS": {"recommended_action": "retry_same_request", "status": "failed"},
	"EMPTY_OUTPUT_LIST": {"recommended_action": "retry_same_request", "status": "failed"},
	"EXPERT_FIELD_IN_SAFE_MODE": {"recommended_action": "retry_same_request", "status": "failed"},
	"JOB_NOT_FOUND": {"recommended_action": "retry_same_request", "status": "failed"},
	"ASSET_ID_COLLISION": {"recommended_action": "provide_unique_asset_id", "status": "failed"},
	"MANIFEST_MISMATCH": {"recommended_action": "retry_same_request", "status": "failed"},
	"SOURCE_IMAGE_LOAD_FAILED": {"recommended_action": "repair_source_asset", "status": "failed"},
	"RENDER_EMPTY": {"recommended_action": "manual_composition_review", "status": "needs_review"},
	"OUTPUT_RESOLUTION_MISMATCH": {"recommended_action": "manual_composition_review", "status": "needs_review"},
	"OUTPUT_WRITE_FAILED": {"recommended_action": "check_workspace_permissions", "status": "failed"},
	"OUTPUT_EXISTS": {"recommended_action": "retry_same_request", "status": "failed"},
}

static func recommended_action(code: String) -> String:
	return str(CODES.get(code, {}).get("recommended_action", "retry_same_request"))

static func terminal_status(code: String) -> String:
	return str(CODES.get(code, {}).get("status", "failed"))

static func all_codes() -> Array[String]:
	var result: Array[String] = []
	for key in CODES.keys():
		result.append(str(key))
	result.sort()
	return result
