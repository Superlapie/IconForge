extends RefCounted

# Enigma Foundry — Icon Forge design tokens
const CANVAS: Color = Color("08090B")
const SIDEBAR: Color = Color("0E1013")
const RAISED: Color = Color("15181D")
const HOVER: Color = Color("1D2128")
const VIEWPORT: Color = Color("08090B")

const BORDER: Color = Color("ffffff", 0.055)
const SEPARATOR: Color = Color("ffffff", 0.04)

const TEXT: Color = Color("F1F3F5")
const MUTED: Color = Color("979DA7")
const TERTIARY: Color = Color("626974")

const ACCENT: Color = Color("8EA7FF")
const ACCENT_HOT: Color = Color("B4C3FF")
const SUCCESS: Color = Color("6BC9A0")
const WARNING: Color = Color("E8B86D")
const ERROR: Color = Color("E07A6A")

const AXIS_X: Color = Color("E07A6A")
const AXIS_Y: Color = Color("6BC9A0")
const AXIS_Z: Color = Color("8EA7FF")

# Legacy aliases used by existing components during migration
const INK: Color = CANVAS
const SURFACE: Color = SIDEBAR
const SURFACE_RAISED: Color = RAISED
const SURFACE_HOVER: Color = HOVER
const SURFACE_PREVIEW: Color = VIEWPORT
const BORDER_SOFT: Color = BORDER
const ACCENT_BRIGHT: Color = ACCENT_HOT

const ROW_HEIGHT: int = 28
const TOOLBAR_HEIGHT: int = 44
const DOCK_PADDING: int = 10
const SECTION_GAP: int = 12
const PROPERTY_GAP: int = 5

static func flat(color: Color, radius: int = 4, shadow: bool = false) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = BORDER
	if shadow:
		style.shadow_color = Color(0, 0, 0, 0.22)
		style.shadow_size = 6
		style.shadow_offset = Vector2(0, 2)
	return style

static func panel(color: Color = SIDEBAR, radius: int = 4) -> StyleBoxFlat:
	return flat(color, radius, false)

static func dock(color: Color = SIDEBAR) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = SEPARATOR
	style.border_width_right = 1
	return style

static func dock_right(color: Color = SIDEBAR) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = SEPARATOR
	style.border_width_left = 1
	return style

static func inset(radius: int = 4) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(CANVAS, 0.65)
	style.set_corner_radius_all(radius)
	style.border_color = Color("ffffff", 0.035)
	style.set_border_width_all(1)
	return style

static func pill(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(color, 0.10)
	style.border_color = Color(color, 0.22)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style

static func toolbar_button(active: bool = false) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(ACCENT, 0.14) if active else Color("ffffff", 0.03)
	style.border_color = Color(ACCENT, 0.35) if active else Color("ffffff", 0.06)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style

static func separator_horizontal() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = SEPARATOR
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

static func build_theme() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = 12
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", ACCENT_HOT)
	theme.set_color("font_pressed_color", "Button", TEXT)
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_color", "OptionButton", TEXT)
	theme.set_color("font_color", "ItemList", TEXT)
	theme.set_color("font_selected_color", "ItemList", TEXT)
	theme.set_color("font_color", "CheckButton", MUTED)
	theme.set_stylebox("normal", "Button", flat(RAISED, 4, false))
	theme.set_stylebox("hover", "Button", flat(HOVER, 4, false))
	theme.set_stylebox("pressed", "Button", flat(Color("252930"), 4, false))
	theme.set_stylebox("normal", "OptionButton", flat(RAISED, 4, false))
	theme.set_stylebox("hover", "OptionButton", flat(HOVER, 4, false))
	theme.set_stylebox("normal", "LineEdit", inset(4))
	theme.set_stylebox("focus", "LineEdit", inset(4))
	theme.set_stylebox("grabber_area", "HSlider", flat(Color("ffffff", 0.04), 2, false))
	theme.set_stylebox("grabber_area_highlight", "HSlider", flat(Color(ACCENT, 0.25), 2, false))
	theme.set_stylebox("grabber", "HSlider", flat(ACCENT, 3, false))
	return theme

static func label(text: String, font_size: int = 12, color: Color = TEXT) -> Label:
	var node: Label = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	return node

static func heading(text: String, font_size: int = 13) -> Label:
	return label(text, font_size, TEXT)

static func caption(text: String) -> Label:
	return label(text, 10, TERTIARY)

static func section_title(text: String) -> Label:
	return label(text, 11, MUTED)

static func status_ok(text: String) -> Label:
	return label(text, 11, SUCCESS)

static func status_warn(text: String) -> Label:
	return label(text, 11, WARNING)

static func status_err(text: String) -> Label:
	return label(text, 11, ERROR)
