extends RefCounted

const HEADER = preload("res://heading.tres")
const BODY = preload("res://typeface.tres")
const GOLD := Color("#e4be82")
const CREAM := Color("#f0e6cd")
const MUTED := Color("#bdc4b5")
const EDGE := Color("#5d6453")
const PANEL := Color("#111c1b")

static func fill(parent: Control, rect: Rect2, color: Color) -> ColorRect:
	var result := ColorRect.new()
	result.position = rect.position
	result.size = rect.size
	result.color = color
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

static func panel(parent: Control, rect: Rect2, color: Color, border: Color = EDGE) -> Panel:
	var result := Panel.new()
	result.position = rect.position
	result.size = rect.size
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_stylebox_override("panel", box(color, border))
	parent.add_child(result)
	return result

static func label(parent: Control, text: String, rect: Rect2, points: int,
		color: Color = CREAM, heading := false) -> Label:
	var result := Label.new()
	result.text = text
	result.position = rect.position
	result.size = rect.size
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_override("font", HEADER if heading else BODY)
	result.add_theme_font_size_override("font_size", points)
	result.add_theme_color_override("font_color", color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(result)
	return result

static func button(parent: Control, text: String, rect: Rect2, callback: Callable,
		primary := false, points := 17) -> Button:
	var result := Button.new()
	result.text = text
	result.position = rect.position
	result.size = rect.size
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.add_theme_font_override("font", BODY)
	result.add_theme_font_size_override("font_size", points)
	result.add_theme_color_override("font_color", Color("#221a10") if primary else CREAM)
	result.add_theme_color_override("font_hover_color", Color("#21170b") if primary else Color.WHITE)
	result.add_theme_color_override("font_pressed_color", Color("#1a130b") if primary else CREAM)
	result.add_theme_color_override("font_focus_color", Color("#221a10") if primary else CREAM)
	result.add_theme_color_override("font_disabled_color", Color("#74796c"))
	result.add_theme_stylebox_override("normal", box(GOLD if primary else Color("#20302c"), Color("#ac8855") if primary else EDGE))
	result.add_theme_stylebox_override("hover", box(Color("#f0d198") if primary else Color("#33473b"), GOLD))
	result.add_theme_stylebox_override("pressed", box(Color("#c99a59") if primary else Color("#263631"), GOLD))
	result.add_theme_stylebox_override("disabled", box(Color("#26302a"), Color("#435045")))
	result.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, Color("#fff0ca")))
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

static func box(color: Color, edge: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.border_color = edge
	result.set_border_width_all(1)
	result.set_corner_radius_all(4)
	result.content_margin_left = 8
	result.content_margin_right = 8
	return result
