extends Control

const UiStyles = preload("res://app/ui/ui_styles.gd")

var show_grid: bool = false
var show_safe_zone: bool = true
var show_occupancy_box: bool = true
var camera_yaw: float = 0.0
var camera_pitch: float = -8.0
var camera_roll: float = 0.0
var focal_length: String = "Ortho"
var lighting_rig: String = "studio"
var status_text: String = "Orbit to adjust yaw and pitch"
var target_occupancy: float = 0.82
var actual_occupancy: float = -1.0
var resolution_text: String = "256²"
var projection_text: String = "ORTHO"
var supersampling_text: String = "2× SS"
var render_status: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

func set_camera_stats(yaw: float, pitch: float, roll: float, focal: String, rig: String) -> void:
	camera_yaw = yaw
	camera_pitch = pitch
	camera_roll = roll
	focal_length = focal
	lighting_rig = rig
	queue_redraw()

func set_output_stats(resolution: String, projection: String, supersampling: String) -> void:
	resolution_text = resolution
	projection_text = projection
	supersampling_text = supersampling
	queue_redraw()

func set_occupancy(target: float, actual: float) -> void:
	target_occupancy = target
	actual_occupancy = actual
	queue_redraw()

func set_status(text: String) -> void:
	status_text = text
	queue_redraw()

func set_render_status(text: String) -> void:
	render_status = text
	queue_redraw()

func _draw() -> void:
	_draw_gizmo(Vector2(16, size.y - 16))
	_draw_bottom_hud()
	if show_grid:
		_draw_composition_grid()
	if show_safe_zone:
		_draw_safe_zone()
	if show_occupancy_box and actual_occupancy >= 0.0:
		_draw_occupancy_box()
	if not render_status.is_empty():
		_draw_render_banner()

func _draw_gizmo(origin: Vector2) -> void:
	var axis_length: float = 24.0
	var yaw_rad: float = deg_to_rad(camera_yaw)
	var pitch_rad: float = deg_to_rad(camera_pitch)
	var basis: Basis = Basis.from_euler(Vector3(pitch_rad, yaw_rad, 0.0))
	var axes: Array = [
		[Vector3.RIGHT, UiStyles.AXIS_X, "X"],
		[Vector3.UP, UiStyles.AXIS_Y, "Y"],
		[Vector3.BACK, UiStyles.AXIS_Z, "Z"]
	]
	for entry in axes:
		var axis: Vector3 = entry[0]
		var color: Color = entry[1]
		var label: String = entry[2]
		var rotated: Vector3 = basis * axis
		var projected: Vector2 = Vector2(rotated.x, -rotated.y).normalized() * axis_length
		draw_line(origin, origin + projected, Color(color, 0.75), 1.5, true)
		draw_string(ThemeDB.fallback_font, origin + projected + Vector2(3, 3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)

func _draw_bottom_hud() -> void:
	var hud_height: float = 24.0
	var origin: Vector2 = Vector2(0, size.y - hud_height)
	draw_rect(Rect2(origin, Vector2(size.x, hud_height)), Color("08090B", 0.78), true)
	var parts: PackedStringArray = PackedStringArray([resolution_text, projection_text])
	if actual_occupancy >= 0.0:
		var ok: bool = actual_occupancy >= target_occupancy * 0.96 and actual_occupancy <= target_occupancy * 1.08
		parts.append("ACTUAL %.1f%% %s" % [actual_occupancy * 100.0, "✓" if ok else "⚠"])
	parts.append(supersampling_text)
	parts.append("ALPHA")
	var x: float = 12.0
	for part in parts:
		var color: Color = UiStyles.MUTED
		if part.ends_with("✓"):
			color = UiStyles.SUCCESS
		elif part.ends_with("⚠"):
			color = UiStyles.WARNING
		draw_string(ThemeDB.fallback_font, Vector2(x, origin.y + 16), part, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)
		x += ThemeDB.fallback_font.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 18.0
	if not status_text.is_empty():
		var status_size: Vector2 = ThemeDB.fallback_font.get_string_size(status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		draw_string(ThemeDB.fallback_font, Vector2(size.x - status_size.x - 12, origin.y + 16), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiStyles.TERTIARY)

func _draw_composition_grid() -> void:
	var margin: float = 20.0
	var inner: Rect2 = Rect2(Vector2(margin, margin), size - Vector2(margin * 2.0, margin * 2.0 + 24.0))
	var third_x: float = inner.size.x / 3.0
	var third_y: float = inner.size.y / 3.0
	var grid_color: Color = Color("ffffff", 0.10)
	for i in [1, 2]:
		var x: float = inner.position.x + third_x * i
		var y: float = inner.position.y + third_y * i
		draw_line(Vector2(x, inner.position.y), Vector2(x, inner.position.y + inner.size.y), grid_color, 1.0, true)
		draw_line(Vector2(inner.position.x, y), Vector2(inner.position.x + inner.size.x, y), grid_color, 1.0, true)

func _draw_safe_zone() -> void:
	var margin: float = 20.0
	var outer: Rect2 = Rect2(Vector2(margin, margin), size - Vector2(margin * 2.0, margin * 2.0 + 24.0))
	var pad: float = outer.size.x * 0.08
	var inner: Rect2 = outer.grow_individual(-pad, -pad, -pad, -pad)
	draw_rect(outer, Color("ffffff", 0.06), false, 1.0)
	draw_rect(inner, Color(UiStyles.ACCENT, 0.18), false, 1.0)

func _draw_occupancy_box() -> void:
	var margin: float = 20.0
	var area: Rect2 = Rect2(Vector2(margin, margin), size - Vector2(margin * 2.0, margin * 2.0 + 24.0))
	var scale: float = clampf(sqrt(actual_occupancy / maxf(target_occupancy, 0.01)), 0.45, 0.98)
	var box_size: Vector2 = area.size * scale
	var box_origin: Vector2 = area.position + (area.size - box_size) * 0.5
	var ok: bool = actual_occupancy >= target_occupancy * 0.96 and actual_occupancy <= target_occupancy * 1.08
	var color: Color = UiStyles.SUCCESS if ok else UiStyles.WARNING
	draw_rect(Rect2(box_origin, box_size), Color(color, 0.12), false, 1.0)
	var label: String = "TARGET %.0f%%" % (target_occupancy * 100.0)
	draw_string(ThemeDB.fallback_font, Vector2(box_origin.x, box_origin.y - 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiStyles.TERTIARY)

func _draw_render_banner() -> void:
	var text_size: Vector2 = ThemeDB.fallback_font.get_string_size(render_status, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	var panel_size: Vector2 = Vector2(text_size.x + 20, 22)
	var origin: Vector2 = Vector2((size.x - panel_size.x) * 0.5, 12)
	draw_rect(Rect2(origin, panel_size), Color("08090B", 0.82), true)
	draw_rect(Rect2(origin, panel_size), Color("ffffff", 0.06), false, 1.0)
	draw_string(ThemeDB.fallback_font, origin + Vector2(10, 16), render_status, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyles.ACCENT_HOT)
