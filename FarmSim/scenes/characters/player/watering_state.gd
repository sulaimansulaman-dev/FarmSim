extends NodeState

@export var player: Player
@export var animated_sprite_2d: AnimatedSprite2D
@export var hit_component_collision_shape: CollisionShape2D


func _on_next_transitions() -> void:
    if not animated_sprite_2d.is_playing():
        transition.emit('idle')


func _on_enter() -> void:
    if player.direction == Vector2.UP:
        animated_sprite_2d.play('watering_back')
        hit_component_collision_shape.position = Vector2i(5, -16)
    elif player.direction == Vector2.DOWN:
        animated_sprite_2d.play('watering_front')
        hit_component_collision_shape.position = Vector2i(-5, 2)
    elif player.direction == Vector2.LEFT:
        animated_sprite_2d.play('watering_left')
        hit_component_collision_shape.position = Vector2i(-21, 0)
    elif player.direction == Vector2.RIGHT:
        animated_sprite_2d.play('watering_right')
        hit_component_collision_shape.position = Vector2i(21, 0)

    hit_component_collision_shape.disabled = false


func _on_exit() -> void:
    animated_sprite_2d.stop()
    hit_component_collision_shape.disabled = true
