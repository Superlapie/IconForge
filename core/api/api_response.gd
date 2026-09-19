extends RefCounted
class_name ApiResponse

const _Schema = preload("res://core/api/api_schema.gd")
const _ErrorCodes = preload("res://core/api/error_codes.gd")

## Standard machine API response envelope builder.

static func success(operation: String, payload: Dictionary = {}) -> Dictionary:
	var response: Dictionary = {
		"schema_version": _Schema.CURRENT_SCHEMA_VERSION,
		"success": true,
		"status": str(payload.get("status", "validated")),
		"operation": operation,
	}
	for key in payload.keys():
		if key != "status":
			response[key] = payload[key]
	return response

static func failure(operation: String, code: String, message: String, details: Dictionary = {}) -> Dictionary:
	var status: String = _ErrorCodes.terminal_status(code)
	var response: Dictionary = {
		"schema_version": _Schema.CURRENT_SCHEMA_VERSION,
		"success": false,
		"status": status,
		"operation": operation,
		"code": code,
		"message": message,
		"recommended_action": _ErrorCodes.recommended_action(code),
	}
	for key in details.keys():
		response[key] = details[key]
	return response

static func from_validation_error(operation: String, error: Dictionary) -> Dictionary:
	return failure(
		operation,
		str(error.get("code", "INVALID_REQUEST")),
		str(error.get("message", "Request validation failed.")),
		error
	)
