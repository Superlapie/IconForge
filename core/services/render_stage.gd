extends RefCounted
class_name RenderStage

const AssetLoaderScript = preload("res://core/services/asset_loader.gd")

var framing: FramingService = FramingService.new()
var lighting: LightingRigService = LightingRigService.new()
var loader: RefCounted = AssetLoaderScript.new()

func load_scene(source_path: String) -> Dictionary:
	return loader.load_packed_scene(source_path)

func configure_viewport(viewport: SubViewport, render_size: Vector2i, msaa: Viewport.MSAA = Viewport.MSAA_4X) -> void:
	viewport.size = render_size
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = msaa

func resolve_params(preset: PresetDefinition, inspection: Dictionary, override: Dictionary) -> Dictionary:
	return framing.resolve_camera(preset, inspection, override)

func resolve_camera_size(params: Dictionary, preset: PresetDefinition) -> float:
	var is_perspective: bool = str(params.get("projection", "orthographic")) == "perspective"
	return float(params["distance"] if is_perspective else params["orthographic_size"])

func resolve_lighting(preset: PresetDefinition, override: Dictionary = {}) -> Dictionary:
	var merged: Dictionary = PresetDefinition.deep_merge(preset.data.get("lighting", {}), override.get("lighting", {}))
	return lighting.resolve(merged)

func populate_stage(stage: Node3D, packed_scene: PackedScene, inspection: Dictionary, preset: PresetDefinition, params: Dictionary, camera_size: float, override: Dictionary = {}) -> Dictionary:
	for child in stage.get_children():
		child.queue_free()
	var environment_node: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = _environment_color(preset)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.78, 0.92, 1.0)
	environment.ambient_light_energy = float(resolve_lighting(preset, override).get("ambient_energy", preset.data.get("lighting", {}).get("ambient_energy", 0.45)))
	environment_node.environment = environment
	stage.add_child(environment_node)
	_add_lights(stage, resolve_lighting(preset, override))
	var object: Node3D = packed_scene.instantiate() as Node3D
	if object == null:
		return {"success": false, "error": {"code": "RENDER_SOURCE_INSTANTIATE_FAILED", "message": "Godot could not instantiate the imported 3D scene."}}
	var original_center: Vector3 = _array_to_vector(inspection.get("center", [0.0, 0.0, 0.0]))
	object.position = -original_center
	object.rotation_degrees = params["orientation"]
	object.scale = Vector3.ONE * float(params.get("scale", 1.0))
	stage.add_child(object)
	var camera: Camera3D = Camera3D.new()
	camera.name = "StudioCamera"
	camera.current = true
	camera.near = 0.01
	camera.far = 10000.0
	_apply_camera_transform(camera, params, camera_size, original_center)
	stage.add_child(camera)
	return {
		"success": true,
		"camera": camera,
		"object": object,
		"target": params["target"],
		"original_center": original_center,
		"params": params
	}

func update_stage(camera: Camera3D, object: Node3D, inspection: Dictionary, params: Dictionary, camera_size: float) -> void:
	if object != null:
		object.rotation_degrees = params["orientation"]
		object.scale = Vector3.ONE * float(params.get("scale", 1.0))
	if camera != null:
		var original_center: Vector3 = _array_to_vector(inspection.get("center", [0.0, 0.0, 0.0]))
		_apply_camera_transform(camera, params, camera_size, original_center)

func update_lights(stage: Node3D, preset: PresetDefinition, override: Dictionary = {}) -> void:
	var resolved: Dictionary = resolve_lighting(preset, override)
	for type in ["key", "fill", "rim"]:
		var light: DirectionalLight3D = stage.get_node_or_null("%sLight" % type.capitalize()) as DirectionalLight3D
		if light == null:
			continue
		var definition: Dictionary = resolved.get(type, {})
		light.rotation_degrees = _array_to_vector(definition.get("angle", [0.0, 0.0, 0.0]))
		light.light_energy = float(definition.get("intensity", 0.5))
		light.light_color = _color_from_array(definition.get("color", [1.0, 1.0, 1.0]))
		light.shadow_enabled = bool(definition.get("shadow", false))
	var environment_node: WorldEnvironment = stage.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if environment_node == null:
		for child in stage.get_children():
			if child is WorldEnvironment:
				environment_node = child as WorldEnvironment
				break
	if environment_node != null and environment_node.environment != null:
		environment_node.environment.ambient_light_energy = float(resolved.get("ambient_energy", 0.45))

func capture_viewport_image(viewport: SubViewport) -> Image:
	RenderingServer.force_draw()
	return viewport.get_texture().get_image()

func _apply_camera_transform(camera: Camera3D, params: Dictionary, camera_size: float, original_center: Vector3) -> void:
	var target: Vector3 = params["target"] - original_center
	var projection: String = str(params.get("projection", "orthographic"))
	if projection == "perspective":
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = float(params.get("fov", 34.0))
		camera.position = target + Vector3(0.0, 0.0, camera_size)
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = camera_size
		camera.position = target + Vector3(0.0, 0.0, maxf(float(params.get("radius", 1.0)) * 4.0, 2.0))
	camera.look_at(target, Vector3.UP)

func _add_lights(stage: Node3D, resolved_lighting: Dictionary) -> void:
	for type in ["key", "fill", "rim"]:
		var definition: Dictionary = resolved_lighting.get(type, {})
		var light: DirectionalLight3D = DirectionalLight3D.new()
		light.name = "%sLight" % type.capitalize()
		light.rotation_degrees = _array_to_vector(definition.get("angle", [0.0, 0.0, 0.0]))
		light.light_energy = float(definition.get("intensity", 0.5))
		light.light_color = _color_from_array(definition.get("color", [1.0, 1.0, 1.0]))
		light.shadow_enabled = bool(definition.get("shadow", false))
		stage.add_child(light)

func _environment_color(preset: PresetDefinition) -> Color:
	var background_mode: String = str(preset.data.get("environment", {}).get("background", "transparent"))
	if background_mode == "transparent":
		return Color(0, 0, 0, 0)
	var color_array: Array = preset.data.get("environment", {}).get("color", [0.04, 0.05, 0.08, 1.0])
	return _color_from_array(color_array)

func _array_to_vector(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO

func _color_from_array(value: Variant) -> Color:
	if value is Array and value.size() >= 3:
		return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]) if value.size() > 3 else 1.0)
	return Color.WHITE
