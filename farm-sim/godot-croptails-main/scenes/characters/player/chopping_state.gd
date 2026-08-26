extends NodeState

@export var player: Player
@export var animated_sprite_2d: AnimatedSprite2D
@export var hit_component_collision_shape: CollisionShape2D


func _on_next_transitions() -> void:
    if not animated_sprite_2d.is_playing():
        transition.emit('idle')


func _on_enter() -> void:
    if player.direction == Vector2.UP:
        animated_sprite_2d.play('chopping_back')
        hit_component_collision_shape.position = Vector2i(0, -20)
    elif player.direction == Vector2.DOWN:
        animated_sprite_2d.play('chopping_front')
        hit_component_collision_shape.position = Vector2i(0, 3)
    elif player.direction == Vector2.LEFT:
        animated_sprite_2d.play('chopping_left')
        hit_component_collision_shape.position = Vector2i(-9, -1)
    elif player.direction == Vector2.RIGHT:
        animated_sprite_2d.play('chopping_right')
        hit_component_collision_shape.position = Vector2i(9, -1)

    hit_component_collision_shape.disabled = false


func _on_exit() -> void:
    animated_sprite_2d.stop()
    hit_component_collision_shape.disabled = true
