
extends NodeState

@export var player: Player
@export var animate_sprite_2d: AnimatedSprite2D
@export var speed: int = 50

func _on_process(_delta : float) -> void:
	pass


func _on_physics_process(_delta : float) -> void:
	var direction: Vector2  =GameInputEvent.movement_input()
	
	if direction == Vector2.UP:
		animate_sprite_2d.play("walk_back")
	elif direction == Vector2.RIGHT:
		animate_sprite_2d.play("walk_right")
	elif direction == Vector2.DOWN:
		animate_sprite_2d.play("walk_front")
	elif direction == Vector2.LEFT:
		animate_sprite_2d.play("walk_left")
	else:
		animate_sprite_2d.play("walk_front")
	
	if direction != Vector2.ZERO:
		player.player_direction = direction
	
	player.velocity = direction * speed
	player.move_and_slide()



func _on_next_transitions() -> void:
	GameInputEvent.is_movement_input()
	if !GameInputEvent.is_movement_input():
		transition.emit("idle")


func _on_enter() -> void:
	pass


func _on_exit() -> void:
	animate_sprite_2d.stop()
