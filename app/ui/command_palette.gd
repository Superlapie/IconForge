extends PopupPanel

const UiStyles = preload("res://app/ui/ui_styles.gd")

signal command_invoked(command_id: String)

var _search: LineEdit
var _list: ItemList
var _commands: Array[Dictionary] = []

func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyles.flat(UiStyles.RAISED, 6, false))
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(420, 280)
	margin.add_child(column)
	_search = LineEdit.new()
	_search.placeholder_text = "Search commands…"
	_search.text_submitted.connect(func(_text: String) -> void: _invoke_selected())
	_search.text_changed.connect(_filter)
	column.add_child(_search)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_activated.connect(_invoke_selected)
	column.add_child(_list)

func set_commands(commands: Array) -> void:
	_commands.clear()
	for entry in commands:
		_commands.append(entry)
	_filter("")

func open_centered() -> void:
	_search.text = ""
	_filter("")
	popup_centered(Vector2i(460, 320))
	_search.grab_focus()

func _filter(query: String) -> void:
	_list.clear()
	var needle: String = query.strip_edges().to_lower()
	for entry in _commands:
		var label: String = str(entry.get("label", ""))
		var keywords: String = str(entry.get("keywords", ""))
		if needle.is_empty() or label.to_lower().contains(needle) or keywords.to_lower().contains(needle):
			_list.add_item(label)
			_list.set_item_metadata(_list.item_count - 1, str(entry.get("id", "")))

func _invoke_selected() -> void:
	var selected: PackedInt32Array = _list.get_selected_items()
	if selected.is_empty() and _list.item_count > 0:
		_list.select(0)
		selected = _list.get_selected_items()
	if selected.is_empty():
		return
	var command_id: String = str(_list.get_item_metadata(selected[0]))
	hide()
	command_invoked.emit(command_id)
