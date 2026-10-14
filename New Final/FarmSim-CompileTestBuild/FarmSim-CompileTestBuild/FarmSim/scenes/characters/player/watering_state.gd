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
    elif player.direction == Vector2.DOWN:
        animated_sprite_2d.play('watering_front')
    elif player.direction == Vector2.LEFT:
        animated_sprite_2d.play('watering_left')
    elif player.direction == Vector2.RIGHT:
        animated_sprite_2d.play('watering_right')

    # The watering itself is done by CropsCursorComponent on the clicked tile.
    # The hitbox stays off here, otherwise a crop the swing happens to brush
    # would be watered twice for one click.


func _on_exit() -> void:
    animated_sprite_2d.stop()
    hit_component_collision_shape.disabled = true
