class_name DayNightCycleComponent
extends CanvasModulate

@export var initial_day: int = 1:
    set(day):
        initial_day = day
        DayNightCycleManager.initial_day = day
        DayNightCycleManager.set_initial_time()

@export var initial_hour: int = 12:
    set(hour):
        initial_hour = hour
        DayNightCycleManager.initial_hour = hour
        DayNightCycleManager.set_initial_time()

@export var initial_minute: int = 0:
    set(minute):
        initial_minute = minute
        DayNightCycleManager.initial_minute = minute
        DayNightCycleManager.set_initial_time()

@export var day_night_gradient_texture: GradientTexture1D


func _ready() -> void:
    DayNightCycleManager.initial_day = initial_day
    DayNightCycleManager.initial_hour = initial_hour
    DayNightCycleManager.initial_minute = initial_minute
    DayNightCycleManager.set_initial_time()

    DayNightCycleManager.game_time.connect(on_game_time)


func on_game_time(time: float) -> void:
    #var sample_value := 0.5 * (cos(time * 0.5) + 1.0)
    var sample_value := float(int(time / DayNightCycleManager.GAME_MINUTE_DURATION) % DayNightCycleManager.MINUTES_PER_DAY) / DayNightCycleManager.MINUTES_PER_DAY
    color = day_night_gradient_texture.gradient.sample(sample_value)
