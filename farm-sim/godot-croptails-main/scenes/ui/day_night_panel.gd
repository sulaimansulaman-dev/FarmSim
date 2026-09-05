extends Control

@export var normal_speed: int = 5
@export var fast_speed: int = 50
@export var fastest_speed: int = 200

## Which speed is running is shown by drawing that button at full strength and
## dimming the other two. The panel previously had no selected state at all -
## the keyboard focus ring was doing that job by accident, which is what made
## walking look like it changed the speed.
const TINT_SELECTED := Color(1, 1, 1, 1)
const TINT_UNSELECTED := Color(1, 1, 1, 0.45)

@onready var day_label: Label = $DayPanel/MarginContainer/DayLabel
@onready var time_label: Label = $TimePanel/MarginContainer/TimeLabel
@onready var speed_buttons: Array = [
	$SpeedControl/NormalSpeedButton,
	$SpeedControl/FastSpeedButton,
	$SpeedControl/FastestSpeedButton,
]


func _ready() -> void:
	# Deliberately no grab_focus() here, and no focus at all.
	# walk_left and walk_right are bound to the arrow keys as well as A and D,
	# and the arrow keys are also Godot's built-in ui_left / ui_right. A focused
	# Button therefore walked the focus ring along this panel on every step the
	# player took. Nothing here is meant to be operated by keyboard, so nothing
	# here should be focusable.
	for button: Button in speed_buttons:
		button.focus_mode = Control.FOCUS_NONE

	DayNightCycleManager.time_tick.connect(on_time_tick)
	set_speed(normal_speed)


func on_time_tick(day: int, hour: int, minute: int) -> void:
	day_label.text = 'DAY ' + str(day)
	time_label.text = '%02d:%02d' % [hour, minute]


## Applies a speed and shows which button is responsible for it.
func set_speed(speed: int) -> void:
	DayNightCycleManager.game_speed = speed

	var speeds := [normal_speed, fast_speed, fastest_speed]
	for i in speed_buttons.size():
		speed_buttons[i].modulate = TINT_SELECTED if speeds[i] == speed else TINT_UNSELECTED


func _on_normal_speed_button_pressed() -> void:
	set_speed(normal_speed)


func _on_fast_speed_button_pressed() -> void:
	set_speed(fast_speed)


func _on_fastest_speed_button_pressed() -> void:
	set_speed(fastest_speed)
