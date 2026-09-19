extends RefCounted
class_name GuiSession

signal history_changed

const MAX_UNDO: int = 64
const MAX_HISTORY: int = 32

var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var render_history: Array[Dictionary] = []
var render_log: PackedStringArray = PackedStringArray()
var variants: Dictionary = {}
var snapshot_a: Dictionary = {}
var snapshot_b: Dictionary = {}

func push_undo(state: Dictionary) -> void:
	undo_stack.append(state.duplicate(true))
	if undo_stack.size() > MAX_UNDO:
		undo_stack.pop_front()
	redo_stack.clear()

func undo(current: Dictionary) -> Dictionary:
	if undo_stack.is_empty():
		return {}
	redo_stack.append(current.duplicate(true))
	return undo_stack.pop_back()

func redo(current: Dictionary) -> Dictionary:
	if redo_stack.is_empty():
		return {}
	undo_stack.append(current.duplicate(true))
	return redo_stack.pop_back()

func can_undo() -> bool:
	return not undo_stack.is_empty()

func can_redo() -> bool:
	return not redo_stack.is_empty()

func record_render(entry: Dictionary) -> void:
	render_history.insert(0, entry.duplicate(true))
	if render_history.size() > MAX_HISTORY:
		render_history.resize(MAX_HISTORY)
	history_changed.emit()

func append_log(line: String) -> void:
	render_log.insert(0, line)
	if render_log.size() > 200:
		render_log.resize(200)
	history_changed.emit()

func get_variants(source_path: String) -> Array:
	return variants.get(source_path, _default_variants())

func set_variants(source_path: String, entries: Array) -> void:
	variants[source_path] = entries

func _default_variants() -> Array:
	return [
		{"id": "A", "name": "Default", "override": {}, "active": true},
		{"id": "B", "name": "More dramatic", "override": {"occupancy": 0.86}, "active": false},
		{"id": "C", "name": "Front facing", "override": {"yaw": 0.0, "pitch": 0.0}, "active": false},
		{"id": "D", "name": "Heavy outline", "override": {}, "active": false}
	]

func store_snapshot(slot: String, state: Dictionary) -> void:
	if slot == "B":
		snapshot_b = state.duplicate(true)
	else:
		snapshot_a = state.duplicate(true)

func get_snapshot(slot: String) -> Dictionary:
	return snapshot_a if slot == "A" else snapshot_b
