extends RefCounted
class_name ApiRequest

const _Schema = preload("res://core/api/api_schema.gd")
const _Operations = preload("res://core/api/operation_registry.gd")
const _Purposes = preload("res://core/api/purpose_registry.gd")
const _ErrorCodes = preload("res://core/api/error_codes.gd")

## Strict request envelope validation. Rejects unknown fields and invalid types.

var purposes: RefCounted = _Purposes.new()

func validate(request: Dictionary, safe_mode: bool = true) -> Dictionary:
	if request.is_empty():
		return _error("INVALID_REQUEST", "Request must be a non-empty JSON object.")
	if not request.has("schema_version"):
		return _error("INVALID_REQUEST", "schema_version is required.")
	if typeof(request["schema_version"]) != TYPE_INT and typeof(request["schema_version"]) != TYPE_FLOAT:
		return _error("INVALID_FIELD_TYPE", "schema_version must be an integer.", "schema_version")
	var schema_version: int = int(request["schema_version"])
	if schema_version != _Schema.CURRENT_SCHEMA_VERSION:
		return _error("UNSUPPORTED_SCHEMA_VERSION", "Unsupported schema_version %d." % schema_version)
	if not request.has("operation"):
		return _error("INVALID_REQUEST", "operation is required.")
	if typeof(request["operation"]) != TYPE_STRING:
		return _error("INVALID_FIELD_TYPE", "operation must be a string.", "operation")
	var operation: String = str(request["operation"])
	if not _Operations.is_known_operation(operation):
		return _error("UNKNOWN_OPERATION", "Unknown operation '%s'." % operation)
	if safe_mode and not _Operations.is_safe_operation(operation):
		return _error("UNKNOWN_OPERATION", "Operation '%s' is not available in safe mode." % operation)

	var schema: Dictionary = _Schema.OPERATION_SCHEMAS.get(operation, {})
	if schema.is_empty():
		return _error("INTERNAL_ERROR", "No schema registered for operation '%s'." % operation)

	for key in request.keys():
		if not schema.get("fields", {}).has(key):
			if safe_mode and _Schema.EXPERT_FIELDS.has(key):
				return _error("EXPERT_FIELD_IN_SAFE_MODE", "Field '%s' is only permitted in expert mode." % key, key)
			return _error("UNKNOWN_FIELD", "Unknown field '%s'." % key, key)

	for required_key in schema.get("required", []):
		if not request.has(required_key):
			return _error("INVALID_REQUEST", "Required field '%s' is missing." % required_key, required_key)

	for field_name in schema.get("fields", {}).keys():
		if not request.has(field_name):
			continue
		var field_error: Dictionary = _validate_field(field_name, request[field_name], schema["fields"][field_name])
		if not field_error.is_empty():
			return field_error

	if operation in ["render_asset", "validate_output"] and request.has("purpose"):
		if not purposes.has_purpose(str(request["purpose"])):
			return _error("PURPOSE_UNSUPPORTED", "Purpose '%s' is not supported." % str(request["purpose"]), "purpose")

	if operation == "render_asset_set":
		var outputs: Variant = request.get("outputs", [])
		if not (outputs is Array):
			return _error("INVALID_FIELD_TYPE", "outputs must be an array.", "outputs")
		if outputs.is_empty():
			return _error("EMPTY_OUTPUT_LIST", "outputs must contain at least one purpose.", "outputs")
		var seen: Dictionary = {}
		for item in outputs:
			if typeof(item) != TYPE_STRING:
				return _error("INVALID_FIELD_TYPE", "Each output purpose must be a string.", "outputs")
			var purpose_id: String = str(item)
			if seen.has(purpose_id):
				return _error("DUPLICATE_OUTPUTS", "Duplicate purpose '%s' in outputs." % purpose_id, "outputs")
			seen[purpose_id] = true
			if not purposes.has_purpose(purpose_id):
				return _error("PURPOSE_UNSUPPORTED", "Purpose '%s' is not supported." % purpose_id, "outputs")

	if operation == "explain_result" and not request.has("job_id") and not request.has("manifest"):
		return _error("INVALID_REQUEST", "explain_result requires job_id or manifest.")

	return {"success": true, "operation": operation, "request": request}

func _validate_field(name: String, value: Variant, spec: Dictionary) -> Dictionary:
	var expected_type: String = str(spec.get("type", ""))
	match expected_type:
		"integer":
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
				return _error("INVALID_FIELD_TYPE", "%s must be an integer." % name, name)
		"string":
			if typeof(value) != TYPE_STRING:
				return _error("INVALID_FIELD_TYPE", "%s must be a string." % name, name)
			if spec.has("min_length") and str(value).length() < int(spec["min_length"]):
				return _error("INVALID_REQUEST", "%s must not be empty." % name, name)
			if spec.has("enum") and not spec["enum"].has(value):
				return _error("INVALID_ENUM_VALUE", "%s has invalid value '%s'." % [name, str(value)], name)
		"boolean":
			if typeof(value) != TYPE_BOOL:
				return _error("INVALID_FIELD_TYPE", "%s must be a boolean." % name, name)
		"array":
			if not (value is Array):
				return _error("INVALID_FIELD_TYPE", "%s must be an array." % name, name)
			if spec.has("min_length") and (value as Array).size() < int(spec["min_length"]):
				return _error("INVALID_REQUEST", "%s must contain at least %d items." % [name, int(spec["min_length"])], name)
			if spec.has("item_type") and str(spec["item_type"]) == "string":
				for item in value:
					if typeof(item) != TYPE_STRING:
						return _error("INVALID_FIELD_TYPE", "Each item in %s must be a string." % name, name)
		"object":
			if not (value is Dictionary):
				return _error("INVALID_FIELD_TYPE", "%s must be an object." % name, name)
			var nested_fields: Dictionary = spec.get("fields", {})
			for nested_key in value.keys():
				if not nested_fields.has(nested_key):
					return _error("UNKNOWN_FIELD", "Unknown field '%s.%s'." % [name, nested_key], "%s.%s" % [name, nested_key])
			for nested_name in nested_fields.keys():
				if not value.has(nested_name):
					continue
				var nested_error: Dictionary = _validate_field("%s.%s" % [name, nested_name], value[nested_name], nested_fields[nested_name])
				if not nested_error.is_empty():
					return nested_error
	return {}

func _error(code: String, message: String, field: String = "") -> Dictionary:
	var error: Dictionary = {
		"code": code,
		"message": message,
		"recommended_action": _ErrorCodes.recommended_action(code),
	}
	if not field.is_empty():
		error["field"] = field
	return {"success": false, "error": error}
