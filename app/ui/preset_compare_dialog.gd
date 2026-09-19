extends AcceptDialog

const UiStyles = preload("res://app/ui/ui_styles.gd")

signal preset_chosen(preset_id: String)

var _grid: GridContainer
var _results: Array[Dictionary] = []

func _ready() -> void:
	title = "Preset Comparison"
	ok_button_text = "Use Selected"
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	margin.add_child(_grid)
	confirmed.connect(_on_confirmed)

func show_results(results: Array) -> void:
	_results = results
	for child in _grid.get_children():
		child.queue_free()
	for index in results.size():
		var result: Dictionary = results[index]
		var card: Button = Button.new()
		card.toggle_mode = true
		card.custom_minimum_size = Vector2(120, 140)
		var occupancy: float = float(result.get("metrics", {}).get("occupancy", 0.0)) * 100.0
		card.text = "%s\n\n%.1f%%" % [str(result.get("display_name", result.get("preset", ""))), occupancy]
		card.pressed.connect(_select_card.bind(index))
		if index == 0:
			card.button_pressed = true
		_grid.add_child(card)
	popup_centered(Vector2i(640, 420))

func _select_card(index: int) -> void:
	for child_index in _grid.get_child_count():
		var child: Button = _grid.get_child(child_index) as Button
		if child:
			child.button_pressed = child_index == index

func _on_confirmed() -> void:
	for child_index in _grid.get_child_count():
		var child: Button = _grid.get_child(child_index) as Button
		if child and child.button_pressed and child_index < _results.size():
			preset_chosen.emit(str(_results[child_index].get("preset", "")))
			return
