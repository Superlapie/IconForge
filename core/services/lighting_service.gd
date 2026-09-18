extends RefCounted
class_name LightingRigService

## Named rigs are data-driven defaults. Explicit light dictionaries in a
## preset override the profile, so a studio can tune a shipped rig safely.

func resolve(lighting: Dictionary) -> Dictionary:
	var rig_name: String = str(lighting.get("rig", "neutral_studio"))
	var profile: Dictionary = _profile(rig_name)
	return PresetDefinition.deep_merge(profile, lighting)

func _profile(rig_name: String) -> Dictionary:
	var neutral: Dictionary = {
		"rig": rig_name,
		"ambient_energy": 0.46,
		"key": {"angle": [-35.0, -35.0, 0.0], "intensity": 1.25, "color": [1.0, 0.96, 0.9, 1.0], "shadow": true},
		"fill": {"angle": [-20.0, 135.0, 0.0], "intensity": 0.5, "color": [0.76, 0.84, 1.0, 1.0], "shadow": false},
		"rim": {"angle": [20.0, 155.0, 0.0], "intensity": 0.75, "color": [0.6, 0.72, 1.0, 1.0], "shadow": false}
	}
	match rig_name:
		"stylized_inventory":
			neutral["ambient_energy"] = 0.48
			neutral["key"] = {"angle": [-35.0, -35.0, 0.0], "intensity": 1.2, "color": [1.0, 0.9, 0.76, 1.0], "shadow": true}
			neutral["fill"] = {"angle": [-20.0, 135.0, 0.0], "intensity": 0.55, "color": [0.65, 0.78, 1.0, 1.0], "shadow": false}
		"warm_fantasy":
			neutral["ambient_energy"] = 0.5
			neutral["key"] = {"angle": [-40.0, -28.0, 0.0], "intensity": 1.3, "color": [1.0, 0.72, 0.42, 1.0], "shadow": true}
			neutral["fill"] = {"angle": [-15.0, 135.0, 0.0], "intensity": 0.42, "color": [1.0, 0.48, 0.24, 1.0], "shadow": false}
			neutral["rim"] = {"angle": [18.0, 150.0, 0.0], "intensity": 0.9, "color": [1.0, 0.82, 0.44, 1.0], "shadow": false}
		"cold_magic":
			neutral["ambient_energy"] = 0.4
			neutral["key"] = {"angle": [-30.0, -45.0, 0.0], "intensity": 1.12, "color": [0.55, 0.72, 1.0, 1.0], "shadow": true}
			neutral["fill"] = {"angle": [-12.0, 130.0, 0.0], "intensity": 0.36, "color": [0.34, 0.5, 1.0, 1.0], "shadow": false}
			neutral["rim"] = {"angle": [22.0, 155.0, 0.0], "intensity": 1.05, "color": [0.72, 0.46, 1.0, 1.0], "shadow": false}
		"dramatic_boss":
			neutral["ambient_energy"] = 0.3
			neutral["key"] = {"angle": [-42.0, -52.0, 0.0], "intensity": 1.55, "color": [1.0, 0.74, 0.62, 1.0], "shadow": true}
			neutral["fill"] = {"angle": [-10.0, 128.0, 0.0], "intensity": 0.22, "color": [0.3, 0.38, 0.75, 1.0], "shadow": false}
			neutral["rim"] = {"angle": [18.0, 145.0, 0.0], "intensity": 1.25, "color": [1.0, 0.18, 0.22, 1.0], "shadow": false}
		"flat_ui":
			neutral["ambient_energy"] = 0.7
			neutral["key"] = {"angle": [-25.0, -30.0, 0.0], "intensity": 0.92, "color": [1.0, 1.0, 1.0, 1.0], "shadow": false}
			neutral["fill"] = {"angle": [-15.0, 140.0, 0.0], "intensity": 0.82, "color": [0.9, 0.94, 1.0, 1.0], "shadow": false}
			neutral["rim"] = {"angle": [15.0, 160.0, 0.0], "intensity": 0.2, "color": [0.8, 0.86, 1.0, 1.0], "shadow": false}
	return neutral

