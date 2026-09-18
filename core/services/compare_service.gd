extends RefCounted
class_name CompareService

func compare(first_path: String, second_path: String) -> Dictionary:
	if not FileAccess.file_exists(first_path) or not FileAccess.file_exists(second_path):
		return {"success": false, "error": {"code": "COMPARE_INPUT_MISSING", "message": "Both comparison images must exist.", "first": first_path, "second": second_path}}
	var first: Image = Image.new()
	var second: Image = Image.new()
	if first.load(first_path) != OK or second.load(second_path) != OK:
		return {"success": false, "error": {"code": "COMPARE_INPUT_INVALID", "message": "One or both comparison images could not be decoded."}}
	var common_size: Vector2i = Vector2i(mini(first.get_width(), second.get_width()), mini(first.get_height(), second.get_height()))
	var total_delta: float = 0.0
	var max_delta: float = 0.0
	var changed_pixels: int = 0
	var samples: int = 0
	for y in common_size.y:
		for x in common_size.x:
			var a: Color = first.get_pixel(x, y)
			var b: Color = second.get_pixel(x, y)
			var delta: float = absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) + absf(a.a - b.a)
			total_delta += delta / 4.0
			max_delta = maxf(max_delta, delta / 4.0)
			if delta > 0.04:
				changed_pixels += 1
			samples += 1
	return {
		"success": true,
		"first": first_path,
		"second": second_path,
		"same_resolution": first.get_size() == second.get_size(),
		"resolution_first": [first.get_width(), first.get_height()],
		"resolution_second": [second.get_width(), second.get_height()],
		"mean_absolute_delta": total_delta / maxf(float(samples), 1.0),
		"max_delta": max_delta,
		"changed_pixel_ratio": float(changed_pixels) / maxf(float(samples), 1.0)
	}

