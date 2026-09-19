extends RefCounted
class_name UiIcons

static func label(action: String) -> String:
	match action:
		"undo":
			return "↶"
		"redo":
			return "↷"
		"add":
			return "+"
		"samples":
			return "◎"
		"palette":
			return "⌘K"
		"export":
			return "⤓"
		"collapse":
			return "◧"
		"expand":
			return "◨"
		"frame":
			return "⌖"
		"reset":
			return "⟲"
		_:
			return action
