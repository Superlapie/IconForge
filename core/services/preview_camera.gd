extends RefCounted
class_name PreviewCamera

const YAW_SENSITIVITY: float = 0.45
const PITCH_SENSITIVITY: float = 0.35
const ZOOM_SENSITIVITY: float = 0.018

static func apply_orbit_delta(override: Dictionary, preset: PresetDefinition, delta: Vector2) -> Dictionary:
	var result: Dictionary = override.duplicate(true)
	var camera: Dictionary = preset.data.get("camera", {})
	var yaw: float = float(result.get("yaw", camera.get("yaw", 0.0)))
	var pitch: float = float(result.get("pitch", camera.get("pitch", -8.0)))
	result["yaw"] = yaw + delta.x * YAW_SENSITIVITY
	result["pitch"] = clampf(pitch + delta.y * PITCH_SENSITIVITY, -90.0, 90.0)
	return result

static func apply_zoom_delta(override: Dictionary, preset: PresetDefinition, delta: float) -> Dictionary:
	var result: Dictionary = override.duplicate(true)
	var camera: Dictionary = preset.data.get("camera", {})
	var occupancy: float = float(result.get("occupancy", camera.get("occupancy", 0.82)))
	result["occupancy"] = clampf(occupancy + delta * ZOOM_SENSITIVITY, 0.4, 0.95)
	return result

static func preset_value(preset: PresetDefinition, key: String) -> float:
	if preset == null:
		return 0.0
	match key:
		"yaw":
			return float(preset.data.get("camera", {}).get("yaw", 0.0))
		"pitch":
			return float(preset.data.get("camera", {}).get("pitch", -8.0))
		"roll":
			return float(preset.data.get("camera", {}).get("roll", 0.0))
		"occupancy":
			return float(preset.data.get("camera", {}).get("occupancy", 0.82))
		"scale":
			return float(preset.data.get("composition", {}).get("scale", 1.0))
	return 0.0

static func effective_value(override: Dictionary, preset: PresetDefinition, key: String) -> float:
	if override.has(key):
		return float(override[key])
	return preset_value(preset, key)
