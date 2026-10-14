extends Sprite2D

@onready var hurt_component: HurtComponent = $HurtComponent
@onready var damage_component: DamageComponent = $DamageComponent

const stone_scene: PackedScene = preload("res://scenes/objects/rocks/stone.tscn")


func _ready() -> void:
    hurt_component.hurt.connect(on_hurt)
    damage_component.max_damage_reached.connect(on_max_damage_reached)


func on_hurt(damage: int) -> void:
    damage_component.apply_damage(damage)
    (material as ShaderMaterial).set_shader_parameter('intensity', 0.05)
    await get_tree().create_timer(0.5).timeout
    (material as ShaderMaterial).set_shader_parameter('intensity', 0.0)


func on_max_damage_reached() -> void:
    print('max damage reached')
    call_deferred('spawn_stone')
    queue_free()


func spawn_stone() -> void:
    var stone_instance = stone_scene.instantiate() as Node2D
    stone_instance.global_position = global_position
    get_parent().add_child(stone_instance)
