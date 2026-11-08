class_name UiTheme
extends RefCounted
## Builds the shared UI theme in code so there are no binary theme assets to maintain.

const AMBER := Color("f2b84b")
const AMBER_DIM := Color("a8802f")
const INK := Color("0b1a20")
const PANEL := Color("12303a")
const TEAL := Color("2f8f83")
const TEXT := Color("e9f3ee")


static func _box(bg: Color, border: Color, border_w: int = 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb


static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 28
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", AMBER)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.58, 0.58))
	t.set_stylebox("normal", "Button", _box(PANEL, TEAL))
	t.set_stylebox("hover", "Button", _box(Color("1a4551"), AMBER))
	t.set_stylebox("pressed", "Button", _box(Color("0e252d"), AMBER))
	t.set_stylebox("disabled", "Button", _box(Color("0e1d22"), Color("23383d")))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), AMBER, 4))
	t.set_stylebox("panel", "PanelContainer", _box(Color(INK, 0.94), AMBER_DIM, 3))
	return t
