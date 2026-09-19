extends RefCounted
class_name AssetInspector

const AssetLoaderScript = preload("res://core/services/asset_loader.gd")

var loader: RefCounted = AssetLoaderScript.new()

static var inspect_count: int = 0

static func reset_inspect_count() -> void:
	inspect_count = 0

func inspect(source_path: String) -> Dictionary:
	inspect_count += 1
	if not FileAccess.file_exists(source_path):
		return _failure("SOURCE_NOT_FOUND", "Source asset does not exist.", source_path)
	var extension: String = source_path.get_extension().to_lower()
	if ["png", "jpg", "jpeg", "webp"].has(extension):
		return _inspect_image(source_path)
	if not ["glb", "gltf"].has(extension):
		return _failure("SOURCE_FORMAT_UNSUPPORTED", "Icon Forge supports GLB, glTF, PNG, JPEG, and WebP sources.", source_path)

	var loaded: Dictionary = loader.load_packed_scene(source_path)
	if not bool(loaded.get("success", false)):
		return loaded
	var packed_scene: PackedScene = loaded["packed_scene"]
	var instance: Node = packed_scene.instantiate()
	if instance == null:
		return _failure("SOURCE_INSTANTIATE_FAILED", "Godot could not instantiate the imported scene.", source_path)

	var metrics: Dictionary = {
		"source": source_path,
		"kind": "3d",
		"dimensions": [0.0, 0.0, 0.0],
		"center": [0.0, 0.0, 0.0],
		"aabb": {"position": [0.0, 0.0, 0.0], "size": [0.0, 0.0, 0.0]},
		"mesh_count": 0,
		"material_count": 0,
		"triangle_count": 0,
		"skeleton": false,
		"animation": false,
		"texture_dependencies": [],
		"orientation": {"longest_axis": "y", "suggested_strategy": "preserve"}
	}
	var materials: Dictionary = {}
	var texture_dependencies: Array[String] = []
	var aggregate: AABB = AABB()
	var has_bounds: bool = false
	_collect_node_metrics(instance, Transform3D.IDENTITY, metrics, materials, aggregate, has_bounds)
	# AABB is passed by value in GDScript, so rebuild it in a second traversal
	# using the same deterministic walk and return it from the helper.
	var collected: Dictionary = _collect_bounds(instance, Transform3D.IDENTITY)
	if bool(collected.get("has_bounds", false)):
		aggregate = collected["aabb"]
		has_bounds = true
	if is_instance_valid(instance):
		instance.free()

	if has_bounds:
		metrics["dimensions"] = _vector_to_array(aggregate.size)
		metrics["center"] = _vector_to_array(aggregate.get_center())
		metrics["aabb"] = {"position": _vector_to_array(aggregate.position), "size": _vector_to_array(aggregate.size)}
		metrics["orientation"] = _orientation_for(aggregate.size)
	metrics["material_count"] = materials.size()
	metrics["texture_dependencies"] = texture_dependencies
	var dependencies: PackedStringArray = ResourceLoader.get_dependencies(source_path)
	for dependency in dependencies:
		var dependency_text: String = str(dependency)
		if dependency_text.contains("::"):
			dependency_text = dependency_text.get_slice("::", 0)
		if not dependency_text.is_empty() and not texture_dependencies.has(dependency_text):
			texture_dependencies.append(dependency_text)
	metrics["texture_dependencies"] = texture_dependencies
	metrics["success"] = true
	return metrics

func _inspect_image(source_path: String) -> Dictionary:
	var image: Image = Image.new()
	var error: Error = image.load(source_path)
	if error != OK:
		return _failure("SOURCE_IMAGE_LOAD_FAILED", "Godot could not decode the image source.", source_path)
	var size: Vector2i = image.get_size()
	return {
		"success": true,
		"source": source_path,
		"kind": "image",
		"dimensions": [float(size.x), float(size.y), 0.0],
		"center": [float(size.x) / 2.0, float(size.y) / 2.0, 0.0],
		"aabb": {"position": [0.0, 0.0, 0.0], "size": [size.x, size.y, 0]},
		"width": size.x,
		"height": size.y,
		"mesh_count": 0,
		"material_count": 0,
		"triangle_count": 0,
		"skeleton": false,
		"animation": false,
		"texture_dependencies": [],
		"orientation": {"longest_axis": "2d", "suggested_strategy": "preserve"}
	}

func _collect_node_metrics(node: Node, parent_transform: Transform3D, metrics: Dictionary, materials: Dictionary, aggregate: AABB, has_bounds: bool) -> void:
	var current_transform: Transform3D = parent_transform
	if node is Node3D:
		current_transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null:
			metrics["mesh_count"] = int(metrics.get("mesh_count", 0)) + 1
			var mesh: Mesh = mesh_instance.mesh
			for surface_index in mesh.get_surface_count():
				var arrays: Array = mesh.surface_get_arrays(surface_index)
				if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var indices: PackedInt32Array = PackedInt32Array()
					if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
						indices = arrays[Mesh.ARRAY_INDEX]
					metrics["triangle_count"] = int(metrics.get("triangle_count", 0)) + (indices.size() / 3 if not indices.is_empty() else vertices.size() / 3)
				var material: Material = mesh_instance.get_active_material(surface_index)
				var material_key: String = material.resource_path if material != null and not material.resource_path.is_empty() else "%s:%d" % [mesh.resource_path, surface_index]
				materials[material_key] = true
	if node is Skeleton3D:
		metrics["skeleton"] = true
	if node is AnimationPlayer:
		metrics["animation"] = true
	for child in node.get_children():
		_collect_node_metrics(child, current_transform, metrics, materials, aggregate, has_bounds)

func _collect_bounds(node: Node, parent_transform: Transform3D) -> Dictionary:
	var current_transform: Transform3D = parent_transform
	if node is Node3D:
		current_transform = parent_transform * (node as Node3D).transform
	var result: Dictionary = {"has_bounds": false, "aabb": AABB()}
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null:
			result["aabb"] = _transform_aabb(mesh_instance.mesh.get_aabb(), current_transform)
			result["has_bounds"] = true
	for child in node.get_children():
		var child_result: Dictionary = _collect_bounds(child, current_transform)
		if bool(child_result.get("has_bounds", false)):
			if not bool(result["has_bounds"]):
				result = child_result
			else:
				var current_aabb: AABB = result["aabb"]
				current_aabb = current_aabb.merge(child_result["aabb"])
				result["aabb"] = current_aabb
	return result

func _transform_aabb(local_aabb: AABB, transform: Transform3D) -> AABB:
	var corners: Array[Vector3] = []
	for x in [local_aabb.position.x, local_aabb.end.x]:
		for y in [local_aabb.position.y, local_aabb.end.y]:
			for z in [local_aabb.position.z, local_aabb.end.z]:
				corners.append(transform * Vector3(float(x), float(y), float(z)))
	var result: AABB = AABB(corners[0], Vector3.ZERO)
	for corner in corners:
		result = result.expand(corner)
	return result

func _orientation_for(size: Vector3) -> Dictionary:
	var axes: Array = [[size.x, "x"], [size.y, "y"], [size.z, "z"]]
	axes.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var longest: String = str(axes[0][1])
	var strategy: String = "preserve"
	if longest == "y" and max(size.x, size.z) < size.y * 0.45:
		strategy = "upright"
	elif longest == "x" or longest == "z":
		strategy = "longest_axis_diagonal"
	return {"longest_axis": longest, "suggested_strategy": strategy}

func _vector_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _failure(code: String, message: String, source_path: String) -> Dictionary:
	return {"success": false, "source": source_path, "error": {"code": code, "message": message, "source": source_path}}
