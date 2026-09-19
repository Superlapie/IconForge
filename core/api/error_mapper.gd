extends RefCounted
class_name ApiErrorMapper

const _ErrorCodes = preload("res://core/api/error_codes.gd")

## Maps internal service error codes to canonical machine API vocabulary.

const INTERNAL_TO_API: Dictionary = {
	"SOURCE_NOT_FOUND": "SOURCE_NOT_FOUND",
	"SOURCE_FORMAT_UNSUPPORTED": "SOURCE_UNSUPPORTED",
	"SOURCE_IMAGE_LOAD_FAILED": "SOURCE_IMPORT_FAILED",
	"SOURCE_INSTANTIATE_FAILED": "SOURCE_IMPORT_FAILED",
	"SOURCE_INSPECTION_FAILED": "SOURCE_IMPORT_FAILED",
	"SOURCE_CORRUPT": "SOURCE_CORRUPT",
	"RENDER_FAILED": "RENDER_FAILED",
	"RENDER_EMPTY": "RENDER_FAILED",
	"RENDER_NO_SCENE_TREE": "INTERNAL_ERROR",
	"IMAGE_PROCESS_FAILED": "RENDER_FAILED",
	"OUTPUT_MISSING": "OUTPUT_MISSING",
	"OUTPUT_INVALID": "OUTPUT_INVALID",
	"OUTPUT_EMPTY": "OUTPUT_EMPTY",
	"OUTPUT_TRANSPARENT": "OUTPUT_EMPTY",
	"OUTPUT_CLIPPED": "OUTPUT_CLIPPED",
	"OUTPUT_RESOLUTION_MISMATCH": "QUALITY_FAILED",
	"OUTPUT_OCCUPANCY_LOW": "OCCUPANCY_LOW",
	"OUTPUT_OCCUPANCY_HIGH": "OCCUPANCY_HIGH",
	"OUTPUT_EXISTS": "WRITE_FAILED",
	"OUTPUT_WRITE_FAILED": "WRITE_FAILED",
	"PRESET_NOT_FOUND": "PRESET_NOT_FOUND",
	"OVERRIDE_INVALID": "OVERRIDE_INVALID",
	"OVERRIDE_UNKNOWN_FIELD": "OVERRIDE_INVALID",
	"BATCH_NO_SOURCES": "SOURCE_NOT_FOUND",
	"ASSET_ID_COLLISION": "ASSET_ID_COLLISION",
	"MANIFEST_MISMATCH": "QUALITY_FAILED",
}

static func map_code(internal_code: String) -> String:
	return str(INTERNAL_TO_API.get(internal_code, internal_code if _ErrorCodes.all_codes().has(internal_code) else "INTERNAL_ERROR"))

static func map_error(error: Dictionary) -> Dictionary:
	var internal_code: String = str(error.get("code", "INTERNAL_ERROR"))
	var api_code: String = map_code(internal_code)
	return {
		"code": api_code,
		"message": str(error.get("message", "Operation failed.")),
		"recommended_action": _ErrorCodes.recommended_action(api_code),
		"internal_code": internal_code,
	}
