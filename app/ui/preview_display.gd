extends Control

const UiStyles = preload("res://app/ui/ui_styles.gd")

enum ViewMode { LIT, UNLIT, WIREFRAME, NORMAL, ALPHA }

var view_mode: ViewMode = ViewMode.LIT
var _texture_rect: TextureRect
var _wire_overlay: Control
var _base_texture: Texture2D

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texture_rect = TextureRect.new()
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texture_rect)
	_wire_overlay = Control.new()
	_wire_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wire_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wire_overlay.visible = false
	_wire_overlay.draw.connect(_draw_wire_overlay)
	add_child(_wire_overlay)

func get_base_texture() -> Texture2D:
	return _base_texture

func set_texture(texture: Texture2D) -> void:
	_base_texture = texture
	_texture_rect.texture = texture
	_apply_mode()

func set_view_mode(mode_name: String) -> void:
	match mode_name:
		"unlit":
			view_mode = ViewMode.UNLIT
		"wireframe":
			view_mode = ViewMode.WIREFRAME
		"normal":
			view_mode = ViewMode.NORMAL
		"alpha":
			view_mode = ViewMode.ALPHA
		_:
			view_mode = ViewMode.LIT
	_apply_mode()

func _apply_mode() -> void:
	_texture_rect.modulate = Color.WHITE
	_texture_rect.self_modulate = Color.WHITE
	_wire_overlay.visible = false
	match view_mode:
		ViewMode.UNLIT:
			_texture_rect.modulate = Color(0.82, 0.84, 0.88, 1.0)
		ViewMode.WIREFRAME:
			_texture_rect.modulate = Color(0.55, 0.75, 1.0, 0.35)
			_wire_overlay.visible = true
			_wire_overlay.queue_redraw()
		ViewMode.NORMAL:
			_texture_rect.modulate = Color(0.72, 0.76, 1.0, 1.0)
		ViewMode.ALPHA:
			if _base_texture != null:
				var image: Image = _base_texture.get_image()
				if image != null:
					var alpha_view: Image = Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
					for y in image.get_height():
						for x in image.get_width():
							var alpha: float = image.get_pixel(x, y).a
							alpha_view.set_pixel(x, y, Color(alpha, alpha, alpha, 1.0))
					_texture_rect.texture = ImageTexture.create_from_image(alpha_view)
		ViewMode.LIT:
			if _base_texture != null:
				_texture_rect.texture = _base_texture

func _draw_wire_overlay() -> void:
	var spacing: float = 18.0
	var color: Color = Color("8EA7FF", 0.18)
	var columns: int = ceili(_wire_overlay.size.x / spacing)
	var rows: int = ceili(_wire_overlay.size.y / spacing)
	for row in rows + 1:
		var y: float = row * spacing
		_wire_overlay.draw_line(Vector2(0, y), Vector2(_wire_overlay.size.x, y), color, 1.0, true)
	for column in columns + 1:
		var x: float = column * spacing
		_wire_overlay.draw_line(Vector2(x, 0), Vector2(x, _wire_overlay.size.y), color, 1.0, true)
