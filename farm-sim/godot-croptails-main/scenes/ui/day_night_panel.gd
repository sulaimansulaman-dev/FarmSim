extends Control

@export var normal_speed: int = 5
@export var fast_speed: int = 50
@export var fastest_speed: int = 200

@onready var day_label: Label = $DayPanel/MarginContainer/DayLabel
@onready var time_label: Label = $TimePanel/MarginContainer/TimeLabel
@onready var normal_speed_button: Button = $SpeedControl/NormalSpeedButton


func _ready() -> void:
    normal_speed_button.grab_focus()
    DayNightCycleManager.time_tick.connect(on_time_tick)


func on_time_tick(day: int, hour: int, minute: int) -> void:
    day_label.text = 'DAY ' + str(day)
    time_label.text = '%02d:%02d' % [hour, minute]


func _on_normal_speed_button_pressed() -> void:
    DayNightCycleManager.game_speed = normal_speed


func _on_fast_speed_button_pressed() -> void:
    DayNightCycleManager.game_speed = fast_speed


func _on_fastest_speed_button_pressed() -> void:
    DayNightCycleManager.game_speed = fastest_speed
