extends RefCounted
class_name PurposeRegistry

## Canonical semantic purposes for safe-mode machine requests.
## Each purpose maps to a production recipe family and output contract.

const TOOL_VERSION: String = "0.1.0"

const PURPOSES: Dictionary = {
	"inventory_icon": {
		"description": "Transparent inventory grid icon for items, weapons, armor, and consumables.",
		"default_preset": "inventory_item",
		"compatible_presets": ["inventory_item", "weapon", "armor", "consumable", "resource"],
		"compatible_kinds": ["3d", "image"],
		"output_role": "inventory_icon",
		"destination_category": "icons/inventory",
		"naming_strategy": "{asset_id}.png",
		"transparent_required": true,
		"occupancy_min": 0.45,
		"occupancy_max": 0.98,
		"max_correction_passes": 3,
		"expert_overrides_permitted": false,
		"animation_applicable": false,
	},
	"shop_thumbnail": {
		"description": "Shop listing thumbnail with slightly looser framing.",
		"default_preset": "shop_thumbnail",
		"compatible_presets": ["shop_thumbnail", "neutral_asset_thumbnail"],
		"compatible_kinds": ["3d", "image"],
		"output_role": "shop_thumbnail",
		"destination_category": "icons/shop",
		"naming_strategy": "{asset_id}.png",
		"transparent_required": true,
		"occupancy_min": 0.40,
		"occupancy_max": 0.98,
		"max_correction_passes": 3,
		"expert_overrides_permitted": false,
		"animation_applicable": false,
	},
	"equipment_preview": {
		"description": "Equipment slot preview with equipment-specific framing.",
		"default_preset": "equipment_preview",
		"compatible_presets": ["equipment_preview", "armor", "weapon"],
		"compatible_kinds": ["3d", "image"],
		"output_role": "equipment_preview",
		"destination_category": "previews/equipment",
		"naming_strategy": "{asset_id}.png",
		"transparent_required": true,
		"occupancy_min": 0.45,
		"occupancy_max": 0.98,
		"max_correction_passes": 3,
		"expert_overrides_permitted": false,
		"animation_applicable": false,
	},
	"npc_portrait": {
		"description": "NPC portrait frame for humanoid characters.",
		"default_preset": "npc_portrait",
		"compatible_presets": ["npc_portrait", "creature_portrait"],
		"compatible_kinds": ["3d", "image"],
		"output_role": "npc_portrait",
		"destination_category": "portraits/npc",
		"naming_strategy": "{asset_id}.png",
		"transparent_required": true,
		"occupancy_min": 0.50,
		"occupancy_max": 0.96,
		"max_correction_passes": 3,
		"expert_overrides_permitted": false,
		"animation_applicable": true,
	},
	"creature_portrait": {
		"description": "Creature portrait frame for non-humanoid entities.",
		"default_preset": "creature_portrait",
		"compatible_presets": ["creature_portrait", "npc_portrait"],
		"compatible_kinds": ["3d", "image"],
		"output_role": "creature_portrait",
		"destination_category": "portraits/creature",
		"naming_strategy": "{asset_id}.png",
		"transparent_required": true,
		"occupancy_min": 0.50,
		"occupancy_max": 0.96,
		"max_correction_passes": 3,
		"expert_overrides_permitted": false,
		"animation_applicable": true,
	},
	"boss_portrait": {
		"description": "Boss portrait with dramatic framing.",
		"default_preset": "boss_portrait",
		"compatible_presets": ["boss_portrait", "creature_portrait"],
		"compatible_kinds": ["3d", "image"],
		"output_role": "boss_portrait",
		"destination_category": "portraits/boss",
		"naming_strategy": "{asset_id}.png",
		"transparent_required": true,
		"occupancy_min": 0.50,
		"occupancy_max": 0.96,
		"max_correction_passes": 3,
		"expert_overrides_permitted": false,
		"animation_applicable": true,
	},
	"neutral_thumbnail": {
		"description": "Neutral asset thumbnail for generic content.",
		"default_preset": "neutral_asset_thumbnail",
		"compatible_presets": ["neutral_asset_thumbnail", "shop_thumbnail"],
		"compatible_kinds": ["3d", "image"],
		"output_role": "neutral_thumbnail",
		"destination_category": "icons/neutral",
		"naming_strategy": "{asset_id}.png",
		"transparent_required": true,
		"occupancy_min": 0.40,
		"occupancy_max": 0.98,
		"max_correction_passes": 3,
		"expert_overrides_permitted": false,
		"animation_applicable": false,
	},
}

const ORIENTATION_HINTS: Array[String] = ["automatic", "upright", "horizontal", "diagonal"]
const FRAMING_BIAS_HINTS: Array[String] = ["automatic", "tighter", "looser"]

func list_purposes() -> Array:
	var result: Array = []
	var ids: Array[String] = []
	for key in PURPOSES.keys():
		ids.append(str(key))
	ids.sort()
	for purpose_id in ids:
		var def: Dictionary = PURPOSES[purpose_id].duplicate(true)
		def["id"] = purpose_id
		result.append(def)
	return result

func get_purpose(purpose_id: String) -> Dictionary:
	if not PURPOSES.has(purpose_id):
		return {}
	return PURPOSES[purpose_id].duplicate(true)

func has_purpose(purpose_id: String) -> bool:
	return PURPOSES.has(purpose_id)

func purpose_ids() -> Array[String]:
	var result: Array[String] = []
	for key in PURPOSES.keys():
		result.append(str(key))
	result.sort()
	return result

func is_kind_compatible(purpose_id: String, kind: String) -> bool:
	var def: Dictionary = get_purpose(purpose_id)
	if def.is_empty():
		return false
	var kinds: Array = def.get("compatible_kinds", [])
	return kinds.has(kind)

func expected_dimensions(purpose_id: String, preset: PresetDefinition) -> Vector2i:
	var resolution: Dictionary = preset.data.get("resolution", {})
	return Vector2i(int(resolution.get("width", 256)), int(resolution.get("height", 256)))
