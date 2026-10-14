extends NodeState

@export var player: Player
@export var animated_sprite_2d: AnimatedSprite2D


func _on_physics_process(_delta : float) -> void:
    if player.direction == Vector2.UP:
        animated_sprite_2d.play('idle_back')
    elif player.direction == Vector2.DOWN:
        animated_sprite_2d.play('idle_front')
    elif player.direction == Vector2.LEFT:
        animated_sprite_2d.play('idle_left')
    elif player.direction == Vector2.RIGHT:
        animated_sprite_2d.play('idle_right')


func _on_next_transitions() -> void:
    if GameInputEvents.use_tool():
        match player.current_tool:
            DataTypes.Tools.AxeWood:
                transition.emit('chopping')
            DataTypes.Tools.TillGround:
                transition.emit('tilling')
            DataTypes.Tools.WaterCrops:
                transition.emit('watering')
    elif GameInputEvents.has_movement_input():
        transition.emit('walk')



func _on_exit() -> void:
    animated_sprite_2d.stop()
