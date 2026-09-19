extends RefCounted
class_name RecipeResolver

const _Purposes = preload("res://core/api/purpose_registry.gd")
const _ErrorCodes = preload("res://core/api/error_codes.gd")

## Deterministic recipe resolution from purpose + inspection.

var purposes: RefCounted = _Purposes.new()
var presets: PresetService = PresetService.new()

func resolve(purpose_id: String, inspection: Dictionary, hints: Dictionary = {}) -> Dictionary:
	presets.load_all()
	var purpose_def: Dictionary = purposes.get_purpose(purpose_id)
	if purpose_def.is_empty():
		return _failure("PURPOSE_UNSUPPORTED", "Purpose '%s' is not supported." % purpose_id, purpose_id)

	var kind: String = str(inspection.get("kind", "3d"))
	if not purposes.is_kind_compatible(purpose_id, kind):
		return _failure("PURPOSE_SOURCE_MISMATCH", "Purpose '%s' is not compatible with source kind '%s'." % [purpose_id, kind], purpose_id)

	var morphology: String = classify_morphology(inspection)
	var preset_id: String = _resolve_preset_id(purpose_id, purpose_def, morphology, inspection)
	var preset_result: Dictionary = presets.require_preset(preset_id)
	if not bool(preset_result.get("success", false)):
		return _failure("PRESET_NOT_FOUND", "Resolved preset '%s' was not found." % preset_id, purpose_id, {"preset_id": preset_id})

	var preset: PresetDefinition = preset_result["preset"]
	var compatible: Array = purpose_def.get("compatible_presets", [])
	if not compatible.has(preset_id):
		return _failure("PRESET_PURPOSE_MISMATCH", "Preset '%s' is not compatible with purpose '%s'." % [preset_id, purpose_id], purpose_id)

	var override_patch: Dictionary = _apply_safe_hints(hints, morphology)
	var reasons: Array[String] = [
		"purpose=%s" % purpose_id,
		"morphology=%s" % morphology,
		"preset=%s" % preset_id,
	]
	if not override_patch.is_empty():
		reasons.append("hints_applied=%s" % JSON.stringify(override_patch))

	return {
		"success": true,
		"purpose": purpose_id,
		"preset_id": preset_id,
		"preset_revision": preset.get_revision(),
		"preset": preset,
		"morphology": morphology,
		"override_patch": override_patch,
		"resolution_reasons": reasons,
	}

func classify_morphology(inspection: Dictionary) -> String:
	if str(inspection.get("kind", "")) == "image":
		return "static_2d"
	var dims: Vector3 = _array_to_vector(inspection.get("dimensions", [1.0, 1.0, 1.0]))
	var x: float = maxf(dims.x, 0.0001)
	var y: float = maxf(dims.y, 0.0001)
	var z: float = maxf(dims.z, 0.0001)
	var max_d: float = maxf(maxf(x, y), z)
	var min_d: float = minf(minf(x, y), z)
	var aspect: float = max_d / min_d

	if aspect >= 3.0 and (x >= y and x >= z or z >= y and z >= x):
		return "elongated"
	if maxf(x, z) >= y * 2.0 and y <= minf(x, z) * 0.5:
		return "flat_wide"
	if y >= x * 1.5 and y >= z * 1.5 and aspect >= 1.8:
		return "upright_tall"
	if max_d <= 0.5:
		return "tiny"
	if aspect <= 1.5 and max_d <= 1.2:
		return "compact_round"
	return "generic_3d"

func _resolve_preset_id(purpose_id: String, purpose_def: Dictionary, morphology: String, inspection: Dictionary) -> String:
	match purpose_id:
		"inventory_icon":
			return _resolve_inventory_preset(morphology, inspection, purpose_def)
		"equipment_preview":
			return _resolve_equipment_preset(morphology, inspection, purpose_def)
		"shop_thumbnail", "neutral_thumbnail":
			return str(purpose_def.get("default_preset", "neutral_asset_thumbnail"))
		"npc_portrait", "creature_portrait", "boss_portrait":
			return _resolve_portrait_preset(purpose_id, morphology, purpose_def)
	return str(purpose_def.get("default_preset", "inventory_item"))

func _resolve_inventory_preset(morphology: String, _inspection: Dictionary, purpose_def: Dictionary) -> String:
	match morphology:
		"elongated":
			return "weapon"
		"flat_wide":
			return "armor"
		"compact_round":
			return "consumable"
		"tiny":
			return "consumable"
		"upright_tall":
			return "inventory_item"
		"static_2d":
			return "inventory_item"
	return str(purpose_def.get("default_preset", "inventory_item"))

func _resolve_equipment_preset(morphology: String, _inspection: Dictionary, purpose_def: Dictionary) -> String:
	match morphology:
		"elongated":
			return "weapon"
		"flat_wide":
			return "armor"
	return str(purpose_def.get("default_preset", "equipment_preview"))

func _resolve_portrait_preset(purpose_id: String, morphology: String, purpose_def: Dictionary) -> String:
	if morphology == "upright_tall" and purpose_id == "creature_portrait":
		return "creature_portrait"
	if morphology == "upright_tall" and purpose_id == "boss_portrait":
		return "boss_portrait"
	return str(purpose_def.get("default_preset", purpose_id))

func _apply_safe_hints(hints: Dictionary, _morphology: String) -> Dictionary:
	var patch: Dictionary = {}
	var orientation_hint: String = str(hints.get("orientation_hint", "automatic"))
	if orientation_hint != "automatic":
		match orientation_hint:
			"upright":
				patch["camera"] = {"orientation_strategy": "upright"}
			"horizontal":
				patch["camera"] = {"orientation_strategy": "longest_axis_diagonal"}
			"diagonal":
				patch["camera"] = {"orientation_strategy": "weapon_diagonal"}
	var framing_bias: String = str(hints.get("framing_bias", "automatic"))
	if framing_bias != "automatic":
		var occupancy_delta: float = 0.0
		if framing_bias == "tighter":
			occupancy_delta = 0.06
		elif framing_bias == "looser":
			occupancy_delta = -0.06
		if not patch.has("camera"):
			patch["camera"] = {}
		var current: Dictionary = patch["camera"]
		current["occupancy"] = clampf(0.82 + occupancy_delta, 0.55, 0.95)
		patch["camera"] = current
	return patch

func _array_to_vector(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ONE

func _failure(code: String, message: String, purpose_id: String, details: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"error": {
			"code": code,
			"message": message,
			"purpose": purpose_id,
			"recommended_action": _ErrorCodes.recommended_action(code),
		},
	}
	for key in details.keys():
		result["error"][key] = details[key]
	return result
