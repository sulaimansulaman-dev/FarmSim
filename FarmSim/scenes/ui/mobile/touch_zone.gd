class_name TouchZone
extends Control

## A rectangle of screen that follows one finger at a time.
##
## Touch is read from InputEventScreenTouch / ScreenDrag directly instead of
## from Button signals. Godot turns only the FIRST finger into a mouse event,
## so a button built on mouse input stops working the moment the other thumb is
## already holding the joystick. Reading touches by index keeps both thumbs
## independent.
##
## Mouse events are accepted too, so the controls can be tried on a desktop.
## On a touch screen Godot sends both a touch and an emulated mouse click for
## the same finger; the zone only ever follows one pointer, so the second
## arrival is ignored.

const NO_POINTER := -2
const MOUSE_POINTER := -1

## Let go of everything if the game pauses under the finger. A held joystick
## would otherwise keep the player walking through a pause screen.
@export var cancel_on_pause: bool = false

var _pointer: int = NO_POINTER


func _ready() -> void:
	# STOP on purpose: it swallows the emulated mouse click, so a thumb on the
	# pad never also presses a toolbar button or the world behind it.
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Keep listening while paused, so a release is never missed.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if cancel_on_pause and _pointer != NO_POINTER and get_tree().paused:
		_cancel()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_press(touch.index, touch.position, touch.pressed)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_move(drag.index, drag.position)
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_press(MOUSE_POINTER, button.position, button.pressed)
	elif event is InputEventMouseMotion:
		_move(MOUSE_POINTER, (event as InputEventMouseMotion).position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if not is_visible_in_tree():
			_cancel()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		# A finger lifted while the app was in the background never reports.
		_cancel()


func _exit_tree() -> void:
	_cancel()


func _press(index: int, screen_position: Vector2, pressed: bool) -> void:
	if pressed:
		if _pointer != NO_POINTER:
			return
		var local := _to_local(screen_position)
		if not Rect2(Vector2.ZERO, size).has_point(local):
			return
		_pointer = index
		get_viewport().set_input_as_handled()
		_on_pointer_down(local)
	elif index == _pointer:
		_pointer = NO_POINTER
		_on_pointer_up()


func _move(index: int, screen_position: Vector2) -> void:
	if index != _pointer:
		return
	_on_pointer_move(_to_local(screen_position))


func _cancel() -> void:
	if _pointer == NO_POINTER:
		return
	_pointer = NO_POINTER
	_on_pointer_up()


func _to_local(screen_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_position


## Whether a finger is down on this zone right now.
func is_held() -> bool:
	return _pointer != NO_POINTER


# Overridden by the joystick and the button.
func _on_pointer_down(_local: Vector2) -> void:
	pass


func _on_pointer_move(_local: Vector2) -> void:
	pass


func _on_pointer_up() -> void:
	pass
