extends NodeState

@export var character: CharacterBody2D
@export var animated_sprite_2d: AnimatedSprite2D
@export var navigation_agent_2d: NavigationAgent2D
@export var min_speed: float = 10.0
@export var max_speed: float = 10.0
@export var min_cycles: int = 1
@export var max_cycles: int = 1

var speed: float
var cycles: int
var current_cycle: int = 0


func _ready() -> void:
    navigation_agent_2d.velocity_computed.connect(apply_movement)


func _on_physics_process(_delta : float) -> void:
    if navigation_agent_2d.is_navigation_finished():
        current_cycle += 1
        set_movement_target()
        return

    var target_position: Vector2 = navigation_agent_2d.get_next_path_position()
    var target_direction: Vector2 = character.global_position.direction_to(target_position)
    var velocity: Vector2 = target_direction * speed

    if navigation_agent_2d.avoidance_enabled:
        navigation_agent_2d.velocity = velocity
    else:
        apply_movement(velocity)


func _on_next_transitions() -> void:
    if current_cycle >= cycles:
        character.velocity = Vector2.ZERO
        transition.emit('idle')


func _on_enter() -> void:
    cycles = randi_range(min_cycles, max_cycles)
    current_cycle = 0
    animated_sprite_2d.play('walk')
    set_movement_target()


func _on_exit() -> void:
    animated_sprite_2d.stop()


func set_movement_target() -> void:
    var target_position: Vector2 = NavigationServer2D.map_get_random_point(
        navigation_agent_2d.get_navigation_map(),
        navigation_agent_2d.navigation_layers,
        false
    )
    navigation_agent_2d.target_position = target_position
    speed = randf_range(min_speed, max_speed)


func apply_movement(velocity: Vector2) -> void:
    character.velocity = velocity
    animated_sprite_2d.flip_h = velocity.x < 0
    character.move_and_slide()
