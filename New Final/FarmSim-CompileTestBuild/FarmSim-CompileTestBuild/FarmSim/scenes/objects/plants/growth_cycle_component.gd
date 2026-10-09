class_name GrowthCycleComponent
extends Node

signal grew_up(growth_state: DataTypes.GrowthStates)
signal matured
signal spoiled

@export var current_state: DataTypes.GrowthStates = DataTypes.GrowthStates.Germination
@export_range(1, 100) var germination_period: int = 1
@export_range(1, 100) var vegetative_period: int = 1
@export_range(1, 100) var reproduction_period: int = 1
@export_range(1, 100) var mature_period: int = 1

var state_starting_day: int = -1
var is_watered: bool = false


func _ready() -> void:
    DayNightCycleManager.time_tick_day.connect(on_time_tick_day)


func on_time_tick_day(day: int) -> void:
    if state_starting_day == -1:
        state_starting_day = day

    var day_count = day - state_starting_day
    var next_state := current_state

    match current_state:
        DataTypes.GrowthStates.Germination:
            if day_count >= germination_period and is_watered:
                next_state = DataTypes.GrowthStates.Vegetative
        DataTypes.GrowthStates.Vegetative:
            if day_count >= vegetative_period and is_watered:
                next_state = DataTypes.GrowthStates.Reproduction
        DataTypes.GrowthStates.Reproduction:
            if day_count >= reproduction_period and is_watered:
                next_state = DataTypes.GrowthStates.Mature
        DataTypes.GrowthStates.Mature:
            if day_count >= mature_period:
                next_state = DataTypes.GrowthStates.Spoiled

    if next_state == current_state:
        return

    current_state = next_state
    state_starting_day = day
    is_watered = false
    grew_up.emit(current_state)

    if current_state == DataTypes.GrowthStates.Mature:
        matured.emit()
    elif current_state == DataTypes.GrowthStates.Spoiled:
        spoiled.emit()
