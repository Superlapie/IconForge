extends RefCounted
class_name ImageProcessor

func process(source: Image, preset: PresetDefinition, target_size: Vector2i = Vector2i.ZERO) -> Dictionary:
	var image: Image = source.duplicate()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var post: Dictionary = preset.data.get("post_process", {})
	var environment: Dictionary = preset.data.get("environment", {})
	var supersampling: int = int(preset.data.get("supersampling", 1))
	var warnings: Array = []

	_apply_color_adjustments(image, post)
	_apply_sharpen(image, clampf(float(post.get("sharpen", 0.0)), 0.0, 1.0))
	_apply_alpha_threshold(image, float(post.get("alpha_threshold", 0.01)))

	var outline: Dictionary = post.get("outline", {})
	if bool(outline.get("enabled", false)):
		image = _add_outline(image, int(outline.get("width", 2)) * supersampling, _color_from_array(outline.get("color", [0.03, 0.04, 0.08, 1.0])), float(outline.get("opacity", 0.85)))
	var shadow: Dictionary = post.get("drop_shadow", {})
	if bool(shadow.get("enabled", false)):
		image = _add_shadow(image, shadow, supersampling)
	else:
		var scene_shadow: Dictionary = preset.data.get("shadows", {})
		var shadow_mode: String = str(scene_shadow.get("mode", "none"))
		if shadow_mode in ["contact", "fake"] and float(scene_shadow.get("opacity", 0.0)) > 0.0:
			image = _add_shadow(image, {"offset": scene_shadow.get("offset", [0.0, 4.0]), "opacity": scene_shadow.get("opacity", 0.2), "color": [0.0, 0.0, 0.0, 1.0]}, supersampling)
	var bloom: float = clampf(float(post.get("bloom", 0.0)), 0.0, 1.0)
	if bloom > 0.0:
		image = _add_glow(image, bloom, supersampling)
	image = _apply_background(image, environment)
	image = _apply_presentation(image, preset.data.get("presentation", {}), supersampling)

	if target_size != Vector2i.ZERO and image.get_size() != target_size:
		image.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
	if str(environment.get("background", "transparent")) == "transparent":
		_clear_transparent_border(image)
	if image.get_width() <= 0 or image.get_height() <= 0:
		warnings.append({"code": "OUTPUT_EMPTY", "message": "Processed image has no pixels."})
	return {"success": warnings.is_empty(), "image": image, "warnings": warnings, "metrics": silhouette_metrics(image)}

func _clear_transparent_border(image: Image) -> void:
	if image.get_width() < 2 or image.get_height() < 2:
		return
	for x in image.get_width():
		var top: Color = image.get_pixel(x, 0)
		top.a = 0.0
		image.set_pixel(x, 0, top)
		var bottom: Color = image.get_pixel(x, image.get_height() - 1)
		bottom.a = 0.0
		image.set_pixel(x, image.get_height() - 1, bottom)
	for y in image.get_height():
		var left: Color = image.get_pixel(0, y)
		left.a = 0.0
		image.set_pixel(0, y, left)
		var right: Color = image.get_pixel(image.get_width() - 1, y)
		right.a = 0.0
		image.set_pixel(image.get_width() - 1, y, right)

func silhouette_metrics(image: Image) -> Dictionary:
	var width: int = image.get_width()
	var height: int = image.get_height()
	var threshold: float = 0.02
	var min_x: int = width
	var min_y: int = height
	var max_x: int = -1
	var max_y: int = -1
	var pixel_count: int = 0
	var weighted_x: float = 0.0
	var weighted_y: float = 0.0
	for y in height:
		for x in width:
			var alpha: float = image.get_pixel(x, y).a
			if alpha > threshold:
				pixel_count += 1
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
				weighted_x += float(x) * alpha
				weighted_y += float(y) * alpha
	if max_x < 0:
		return {"has_silhouette": false, "occupancy_x": 0.0, "occupancy_y": 0.0, "occupancy": 0.0, "clipped": false, "pixel_count": 0}
	var occupancy_x: float = float(max_x - min_x + 1) / float(width)
	var occupancy_y: float = float(max_y - min_y + 1) / float(height)
	var occupancy: float = maxf(occupancy_x, occupancy_y)
	var center_x: float = weighted_x / maxf(float(pixel_count), 1.0) / float(width)
	var center_y: float = weighted_y / maxf(float(pixel_count), 1.0) / float(height)
	return {
		"has_silhouette": true,
		"occupancy_x": occupancy_x,
		"occupancy_y": occupancy_y,
		"occupancy": occupancy,
		"clipped": min_x == 0 or min_y == 0 or max_x == width - 1 or max_y == height - 1,
		"pixel_count": pixel_count,
		"center": [center_x, center_y],
		"bounds": {"min": [min_x, min_y], "max": [max_x, max_y]}
	}

func _apply_color_adjustments(image: Image, post: Dictionary) -> void:
	var exposure: float = float(post.get("exposure", 0.0))
	var exposure_multiplier: float = pow(2.0, exposure)
	var brightness: float = float(post.get("brightness", 1.0))
	var contrast: float = float(post.get("contrast", 1.0))
	var saturation: float = float(post.get("saturation", 1.0))
	var gamma: float = maxf(float(post.get("gamma", 1.0)), 0.01)
	for y in image.get_height():
		for x in image.get_width():
			var color: Color = image.get_pixel(x, y)
			var red: float = clampf(pow(maxf(color.r * exposure_multiplier * brightness, 0.0), 1.0 / gamma), 0.0, 1.0)
			var green: float = clampf(pow(maxf(color.g * exposure_multiplier * brightness, 0.0), 1.0 / gamma), 0.0, 1.0)
			var blue: float = clampf(pow(maxf(color.b * exposure_multiplier * brightness, 0.0), 1.0 / gamma), 0.0, 1.0)
			red = clampf((red - 0.5) * contrast + 0.5, 0.0, 1.0)
			green = clampf((green - 0.5) * contrast + 0.5, 0.0, 1.0)
			blue = clampf((blue - 0.5) * contrast + 0.5, 0.0, 1.0)
			var luminance: float = red * 0.2126 + green * 0.7152 + blue * 0.0722
			red = clampf(lerpf(luminance, red, saturation), 0.0, 1.0)
			green = clampf(lerpf(luminance, green, saturation), 0.0, 1.0)
			blue = clampf(lerpf(luminance, blue, saturation), 0.0, 1.0)
			image.set_pixel(x, y, Color(red, green, blue, color.a))

func _apply_alpha_threshold(image: Image, threshold: float) -> void:
	if threshold <= 0.0:
		return
	for y in image.get_height():
		for x in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a < threshold:
				color.a = 0.0
			image.set_pixel(x, y, color)

func _apply_sharpen(image: Image, amount: float) -> void:
	if amount <= 0.0 or image.get_width() < 3 or image.get_height() < 3:
		return
	var source: Image = image.duplicate()
	for y in range(1, image.get_height() - 1):
		for x in range(1, image.get_width() - 1):
			var center: Color = source.get_pixel(x, y)
			var north: Color = source.get_pixel(x, y - 1)
			var south: Color = source.get_pixel(x, y + 1)
			var west: Color = source.get_pixel(x - 1, y)
			var east: Color = source.get_pixel(x + 1, y)
			var red: float = clampf(center.r * (1.0 + 4.0 * amount) - (north.r + south.r + west.r + east.r) * amount, 0.0, 1.0)
			var green: float = clampf(center.g * (1.0 + 4.0 * amount) - (north.g + south.g + west.g + east.g) * amount, 0.0, 1.0)
			var blue: float = clampf(center.b * (1.0 + 4.0 * amount) - (north.b + south.b + west.b + east.b) * amount, 0.0, 1.0)
			image.set_pixel(x, y, Color(red, green, blue, center.a))

func _add_outline(image: Image, width: int, color: Color, opacity: float) -> Image:
	if width <= 0:
		return image
	var result: Image = Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	result.fill(Color(0, 0, 0, 0))
	var radius: int = mini(width, 24)
	for y in image.get_height():
		for x in image.get_width():
			var source: Color = image.get_pixel(x, y)
			if source.a > 0.01:
				result.set_pixel(x, y, source)
				continue
			var nearest_alpha: float = 0.0
			for oy in range(-radius, radius + 1):
				for ox in range(-radius, radius + 1):
					if ox * ox + oy * oy > radius * radius:
						continue
					var sample_x: int = x + ox
					var sample_y: int = y + oy
					if sample_x >= 0 and sample_x < image.get_width() and sample_y >= 0 and sample_y < image.get_height():
						nearest_alpha = maxf(nearest_alpha, image.get_pixel(sample_x, sample_y).a)
			if nearest_alpha > 0.01:
				var outline_color: Color = color
				outline_color.a = clampf(nearest_alpha * opacity, 0.0, 1.0)
				result.set_pixel(x, y, outline_color)
	return result

func _add_shadow(image: Image, shadow: Dictionary, supersampling: int) -> Image:
	var result: Image = Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	result.fill(Color(0, 0, 0, 0))
	var offset: Array = shadow.get("offset", [0.0, 4.0])
	var offset_x: int = int(float(offset[0]) * supersampling)
	var offset_y: int = int(float(offset[1]) * supersampling)
	var opacity: float = clampf(float(shadow.get("opacity", 0.25)), 0.0, 1.0)
	var shadow_color: Color = _color_from_array(shadow.get("color", [0, 0, 0, 1]))
	for y in image.get_height():
		for x in image.get_width():
			var alpha: float = image.get_pixel(x, y).a
			if alpha <= 0.01:
				continue
			var shadow_x: int = x + offset_x
			var shadow_y: int = y + offset_y
			# Keep presentation-only shadow pixels off the outermost border so
			# alpha quality checks continue to describe the model silhouette.
			if shadow_x > 0 and shadow_x < result.get_width() - 1 and shadow_y > 0 and shadow_y < result.get_height() - 1:
				var shadow_pixel: Color = shadow_color
				shadow_pixel.a = alpha * opacity
				result.set_pixel(shadow_x, shadow_y, shadow_pixel)
	return _composite(image, result)

func _add_glow(image: Image, strength: float, supersampling: int) -> Image:
	var glow: Image = _add_outline(image, maxi(1, int(5.0 * strength * supersampling)), Color(0.75, 0.86, 1.0, 1.0), 0.24 * strength)
	return _composite(image, glow)

func _apply_background(image: Image, environment: Dictionary) -> Image:
	var mode: String = str(environment.get("background", "transparent"))
	if mode == "transparent":
		return image
	var background: Image = Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	if mode == "gradient":
		var top: Color = _color_from_array(environment.get("gradient_top", [0.1, 0.12, 0.2, 1.0]))
		var bottom: Color = _color_from_array(environment.get("gradient_bottom", [0.02, 0.025, 0.045, 1.0]))
		for y in background.get_height():
			var t: float = float(y) / maxf(float(background.get_height() - 1), 1.0)
			var row: Color = top.lerp(bottom, t)
			for x in background.get_width():
				background.set_pixel(x, y, row)
	else:
		background.fill(_color_from_array(environment.get("color", [0.04, 0.05, 0.08, 1.0])))
	return _composite(image, background)

func _apply_presentation(image: Image, presentation: Dictionary, supersampling: int) -> Image:
	if not bool(presentation.get("enabled", false)):
		return image
	var rarity_color: Color = _color_from_array(presentation.get("rarity_color", [0.45, 0.65, 1.0, 1.0]))
	var aura: Dictionary = presentation.get("aura", {})
	if bool(aura.get("enabled", false)):
		var aura_image: Image = _add_outline(image, maxi(1, int(aura.get("radius", 12)) * supersampling), rarity_color, float(aura.get("opacity", 0.18)))
		image = _composite(image, aura_image)
	var border: Dictionary = presentation.get("border", {})
	if bool(border.get("enabled", false)):
		image = _add_border(image, int(border.get("width", 3)) * supersampling, _color_from_array(border.get("color", presentation.get("rarity_color", [0.45, 0.65, 1.0, 1.0]))), float(border.get("opacity", 0.7)))
	var badge: Dictionary = presentation.get("corner_badge", {})
	if bool(badge.get("enabled", false)):
		image = _add_corner_badge(image, int(badge.get("size", 22)) * supersampling, _color_from_array(badge.get("color", presentation.get("rarity_color", [0.45, 0.65, 1.0, 1.0]))))
	return image

func _add_border(image: Image, width: int, color: Color, opacity: float) -> Image:
	var result: Image = image.duplicate()
	var border_width: int = mini(maxi(width, 1), mini(int(image.get_width() / 2), int(image.get_height() / 2)))
	for y in image.get_height():
		for x in image.get_width():
			if x < border_width or y < border_width or x >= image.get_width() - border_width or y >= image.get_height() - border_width:
				var border_color: Color = color
				border_color.a = opacity
				var current: Color = image.get_pixel(x, y)
				result.set_pixel(x, y, border_color if current.a < 0.05 else current)
	return result

func _add_corner_badge(image: Image, size: int, color: Color) -> Image:
	var result: Image = image.duplicate()
	var badge_size: int = mini(maxi(size, 2), int(mini(image.get_width(), image.get_height()) / 3))
	var start_x: int = image.get_width() - badge_size - maxi(2, int(badge_size / 6))
	var start_y: int = maxi(2, int(badge_size / 6))
	for y in badge_size:
		for x in badge_size:
			if Vector2(x - badge_size / 2.0, y - badge_size / 2.0).length() > badge_size / 2.0:
				continue
			var badge_color: Color = color
			badge_color.a = 0.9
			result.set_pixel(start_x + x, start_y + y, badge_color)
	return result

func _composite(foreground: Image, background: Image) -> Image:
	var result: Image = background.duplicate()
	for y in result.get_height():
		for x in result.get_width():
			var front: Color = foreground.get_pixel(x, y)
			var back: Color = result.get_pixel(x, y)
			var out_alpha: float = front.a + back.a * (1.0 - front.a)
			if out_alpha <= 0.0001:
				result.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var out_color: Color = (front * front.a + back * back.a * (1.0 - front.a)) / out_alpha
			out_color.a = out_alpha
			result.set_pixel(x, y, out_color)
	return result

func _color_from_array(value: Variant) -> Color:
	if value is Color:
		return value
	if value is Array and value.size() >= 3:
		return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]) if value.size() > 3 else 1.0)
	return Color.WHITE
