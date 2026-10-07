extends Node2D

const tomato_harvest_scene := preload("res://scenes/objects/plants/tomato_harvest.tscn")

@export var initial_growth_state: DataTypes.GrowthStates:
    set(state):
        $GrowthCycleComponent.current_state = state

var current_growth_state: DataTypes.GrowthStates
var watering_time: float = 3.0
var frame_offset: int = 7

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var watering_particles: GPUParticles2D = $WateringParticles
@onready var flowering_particles: GPUParticles2D = $FloweringParticles
@onready var growth_cycle_component: GrowthCycleComponent = $GrowthCycleComponent
@onready var watering_hurt_component: HurtComponent = $WateringHurtComponent
@onready var tilling_hurt_component: HurtComponent = $TillingHurtComponent


func _ready() -> void:
    on_grew_up(growth_cycle_component.current_state)
    growth_cycle_component.grew_up.connect(on_grew_up)
    watering_hurt_component.hurt.connect(on_watered)
    tilling_hurt_component.hurt.connect(on_harvested)


func on_grew_up(growth_state: DataTypes.GrowthStates) -> void:
    current_growth_state = growth_state
    sprite_2d.frame = int(growth_state) + frame_offset
    sprite_2d.modulate = Color.WHITE

    match growth_state:
        DataTypes.GrowthStates.Mature:
            flowering_particles.emitting = true
            tilling_hurt_component.monitoring = true
        DataTypes.GrowthStates.Spoiled:
            flowering_particles.emitting = false
            sprite_2d.frame = int(DataTypes.GrowthStates.Mature) + frame_offset
            sprite_2d.modulate = Color.DARK_GOLDENROD


func on_watered(_hit_damage: int) -> void:
    if current_growth_state == DataTypes.GrowthStates.Mature or current_growth_state == DataTypes.GrowthStates.Spoiled:
        return

    if growth_cycle_component.is_watered:
        return

    watering_particles.emitting = true
    await get_tree().create_timer(watering_time).timeout
    watering_particles.emitting = false
    growth_cycle_component.is_watered = true
    sprite_2d.modulate = Color.LIGHT_GRAY


func on_harvested(_hit_damage: int) -> void:
    if current_growth_state == DataTypes.GrowthStates.Mature:
        call_deferred('spawn_harvest')
    queue_free()


func spawn_harvest() -> void:
    var tomato_harvest_instance = tomato_harvest_scene.instantiate() as Node2D
    tomato_harvest_instance.global_position = global_position
    get_parent().add_child(tomato_harvest_instance)
