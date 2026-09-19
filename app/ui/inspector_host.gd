extends VBoxContainer

const UiStyles = preload("res://app/ui/ui_styles.gd")

signal property_reset(key: String)

var _search: LineEdit
var _sections: Dictionary = {}
var _property_nodes: Dictionary = {}
var _filter: String = ""

func _ready() -> void:
	add_theme_constant_override("separation", UiStyles.SECTION_GAP)
	_search = LineEdit.new()
	_search.placeholder_text = "Search properties…"
	_search.text_changed.connect(func(text: String) -> void:
		_filter = text.strip_edges().to_lower()
		_apply_filter()
	)
	add_child(_search)

func add_section(section: Control, keywords: PackedStringArray = PackedStringArray()) -> void:
	add_child(section)
	_sections[section] = keywords

func register_property(key: String, node: Control, keywords: PackedStringArray) -> void:
	_property_nodes[key] = {"node": node, "keywords": keywords}

func _apply_filter() -> void:
	for section in _sections.keys():
		var visible: bool = _filter.is_empty()
		if not visible:
			for keyword in _sections[section]:
				if str(keyword).to_lower().contains(_filter):
					visible = true
					break
		section.visible = visible
	for key in _property_nodes.keys():
		var entry: Dictionary = _property_nodes[key]
		var node: Control = entry["node"]
		var visible: bool = _filter.is_empty()
		if not visible:
			for keyword in entry["keywords"]:
				if str(keyword).to_lower().contains(_filter):
					visible = true
					break
			if key.to_lower().contains(_filter):
				visible = true
		node.visible = visible
