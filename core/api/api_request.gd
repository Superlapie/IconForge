extends RefCounted
class_name ApiRequest

const _Schema = preload("res://core/api/api_schema.gd")
const _Operations = preload("res://core/api/operation_registry.gd")
const _Purposes = preload("res://core/api/purpose_registry.gd")
const _ErrorCodes = preload("res://core/api/error_codes.gd")
const _AssetIdentity = preload("res://core/api/asset_identity.gd")

## Strict request envelope validation. Rejects unknown fields and invalid types.

var purposes: RefCounted = _Purposes.new()

func validate(request: Dictionary, safe_mode: bool = true) -> Dictionary:
	if request.is_empty():
		return _error("INVALID_REQUEST", "Request must be a non-empty JSON object.")
	if not request.has("schema_version"):
		return _error("INVALID_REQUEST", "schema_version is required.")
	var schema_version: int = _coerce_strict_integer(request["schema_version"], "schema_version")
	if schema_version < 0:
		return _error("INVALID_FIELD_TYPE", "schema_version must be an integer.", "schema_version")
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

	if request.has("asset_id"):
		var asset_id_result: Dictionary = _AssetIdentity.validate_asset_id(str(request["asset_id"]))
		if not bool(asset_id_result.get("success", false)):
			return asset_id_result

	return {"success": true, "operation": operation, "request": request}

func _validate_field(name: String, value: Variant, spec: Dictionary) -> Dictionary:
	var expected_type: String = str(spec.get("type", ""))
	match expected_type:
		"integer":
			var int_value: int = _coerce_strict_integer(value, name)
			if int_value < 0:
				return _error("INVALID_FIELD_TYPE", "%s must be an integer." % name, name)
			if spec.has("enum") and not spec["enum"].has(int_value):
				return _error("INVALID_ENUM_VALUE", "%s has invalid value '%s'." % [name, str(value)], name)
		"number":
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
				return _error("INVALID_FIELD_TYPE", "%s must be a number." % name, name)
			var numeric_value: float = float(value)
			if spec.has("min") and numeric_value < float(spec["min"]):
				return _error("INVALID_REQUEST", "%s is below minimum %s." % [name, str(spec["min"])], name)
			if spec.has("max") and numeric_value > float(spec["max"]):
				return _error("INVALID_REQUEST", "%s exceeds maximum %s." % [name, str(spec["max"])], name)
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

func _coerce_strict_integer(value: Variant, _field: String) -> int:
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) == TYPE_FLOAT:
		var as_float: float = float(value)
		if not is_equal_approx(as_float, floor(as_float)):
			return -1
		return int(as_float)
	return -1

func _error(code: String, message: String, field: String = "") -> Dictionary:
	var error: Dictionary = {
		"code": code,
		"message": message,
		"recommended_action": _ErrorCodes.recommended_action(code),
	}
	if not field.is_empty():
		error["field"] = field
	return {"success": false, "error": error}
