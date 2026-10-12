class_name TouchActionButton
extends TouchZone

## A round (or pill-shaped) on-screen button.
##
## The zone is deliberately bigger than the circle drawn in it, so a thumb that
## lands near the button still counts.

signal pressed
signal released

## Big letter in the middle.
@export var glyph: String = "A"
## Pill-shaped and small, for secondary buttons such as Menu.
@export var pill: bool = false
@export var radius: float = 24.0

## Small word under the glyph, naming what pressing the button will do now.
var caption: String = "":
	set(value):
		if value == caption:
			return
		caption = value
		queue_redraw()

## Drawn faint when pressing it would not do anything useful right now.
var dimmed: bool = false:
	set(value):
		if value == dimmed:
			return
		dimmed = value
		queue_redraw()

var _down: bool = false
var _pill_style := StyleBoxFlat.new()


func _ready() -> void:
	super._ready()
	_pill_style.set_corner_radius_all(7)
	_pill_style.set_border_width_all(1)
	_pill_style.anti_aliasing = false


func _on_pointer_down(_local: Vector2) -> void:
	_down = true
	queue_redraw()
	pressed.emit()


func _on_pointer_up() -> void:
	_down = false
	queue_redraw()
	released.emit()


func _draw() -> void:
	var rim := Color(0.96, 0.92, 0.84, 0.4 if dimmed else 0.85)
	var fill := Color(0.16, 0.10, 0.06, 0.8 if _down else 0.5)
	var font := get_theme_default_font()
	var text_colour := Color(0.96, 0.92, 0.84, 0.5 if dimmed else 1.0)
	var centre := size * 0.5

	if pill:
		_pill_style.bg_color = fill
		_pill_style.border_color = rim
		draw_style_box(_pill_style, Rect2(Vector2.ZERO, size).grow(-1.0))
		draw_string(font, Vector2(0.0, centre.y + 3.0), glyph, HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, text_colour)
		return

	draw_circle(centre, radius, fill)
	draw_arc(centre, radius, 0.0, TAU, 40, rim, 2.0)
	if caption.is_empty():
		draw_string(font, Vector2(0.0, centre.y + 6.0), glyph, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, text_colour)
	else:
		draw_string(font, Vector2(0.0, centre.y + 1.0), glyph, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, text_colour)
		draw_string(font, Vector2(0.0, centre.y + 14.0), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, text_colour)
