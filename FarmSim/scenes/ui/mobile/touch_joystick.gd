class_name TouchJoystick
extends TouchZone

## Virtual joystick for a game that walks in four directions.
##
## It presses walk_up / walk_down / walk_left / walk_right, the same actions as
## WASD, so GameInputEvents and the walk state need no changes. Because the
## player only has four walk animations, the stick resolves to whichever axis
## the thumb is pushing furthest along rather than reporting an analogue angle.
##
## The pad is "floating": it appears where the thumb lands, inside the zone, and
## follows the thumb if it drifts past the rim. That keeps it usable without
## looking at it, and on phones where the thumb never lands in the same place
## twice.

## Radius of the pad, in game pixels (the game is 640 x 360).
@export var base_radius: float = 34.0
@export var knob_radius: float = 13.0
## Fraction of the radius the thumb must leave the centre before it counts.
@export_range(0.0, 0.9) var dead_zone: float = 0.3
## Where the faint resting pad is drawn while nothing is touching it, in the
## zone's own coordinates.
@export var rest_position: Vector2 = Vector2(62.0, 166.0)

## Once walking along one axis, the thumb has to favour the other by this much
## before the stick switches. Stops the player stuttering on a diagonal.
const SWITCH_RATIO := 1.3

var _centre: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
var _held: Vector2 = Vector2.ZERO


func _ready() -> void:
	super._ready()
	cancel_on_pause = true
	_centre = rest_position


func _on_pointer_down(local: Vector2) -> void:
	var margin := base_radius + 2.0
	_centre = Vector2(
		clampf(local.x, margin, maxf(margin, size.x - margin)),
		clampf(local.y, margin, maxf(margin, size.y - margin))
	)
	_update(local)


func _on_pointer_move(local: Vector2) -> void:
	_update(local)


func _on_pointer_up() -> void:
	_knob = Vector2.ZERO
	_centre = rest_position
	_set_direction(Vector2.ZERO)
	queue_redraw()


func _update(local: Vector2) -> void:
	var offset := local - _centre
	if offset.length() > base_radius:
		# Drag the pad along behind the thumb rather than letting it escape.
		_centre += offset.normalized() * (offset.length() - base_radius)
		offset = local - _centre
	_knob = offset
	_set_direction(_four_way(offset))
	queue_redraw()


## Which of the four directions the thumb is asking for, or ZERO.
func _four_way(offset: Vector2) -> Vector2:
	if offset.length() < base_radius * dead_zone:
		return Vector2.ZERO

	var across := absf(offset.x)
	var down := absf(offset.y)
	var horizontal := across >= down
	if _held != Vector2.ZERO:
		if _held.x != 0.0:
			horizontal = not (down > across * SWITCH_RATIO)
		else:
			horizontal = across > down * SWITCH_RATIO

	if horizontal:
		return Vector2.RIGHT if offset.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if offset.y > 0.0 else Vector2.UP


func _set_direction(direction: Vector2) -> void:
	if direction == _held:
		return
	_apply(_held, false)
	_held = direction
	_apply(_held, true)


func _apply(direction: Vector2, pressed: bool) -> void:
	var action: StringName = &""
	if direction == Vector2.UP:
		action = &"walk_up"
	elif direction == Vector2.DOWN:
		action = &"walk_down"
	elif direction == Vector2.LEFT:
		action = &"walk_left"
	elif direction == Vector2.RIGHT:
		action = &"walk_right"
	if action == &"":
		return

	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _draw() -> void:
	var active := is_held()
	var rim := Color(0.96, 0.92, 0.84, 0.75 if active else 0.3)
	var fill := Color(0.16, 0.10, 0.06, 0.35 if active else 0.15)

	draw_circle(_centre, base_radius, fill)
	draw_arc(_centre, base_radius, 0.0, TAU, 40, rim, 2.0)

	if active:
		draw_circle(_centre + _knob.limit_length(base_radius), knob_radius, Color(0.96, 0.92, 0.84, 0.8))
		draw_arc(_centre + _knob.limit_length(base_radius), knob_radius, 0.0, TAU, 24, Color(0.16, 0.10, 0.06, 0.9), 1.0)
	else:
		draw_circle(_centre, knob_radius, Color(0.96, 0.92, 0.84, 0.3))
