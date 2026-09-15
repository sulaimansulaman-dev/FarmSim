extends DraftNodeState

@export var player: DraftPlayer
@export var animate_sprite_2d: AnimatedSprite2D

func _on_process(_delta : float) -> void:
	pass


func _on_physics_process(_delta : float) -> void:
	if player.player_direction == Vector2.UP:
		animate_sprite_2d.play("idle_back")
	elif player.player_direction == Vector2.RIGHT:
		animate_sprite_2d.play("idle_right")
	elif player.player_direction == Vector2.DOWN:
		animate_sprite_2d.play("idle_front")
	elif player.player_direction == Vector2.LEFT:
		animate_sprite_2d.play("idle_left")
	else:
		animate_sprite_2d.play("idle_front")
		


func _on_next_transitions() -> void:
	DraftGameInputEvent.is_movement_input()
	
	if DraftGameInputEvent.is_movement_input():
		transition.emit("walk")
	


func _on_enter() -> void:
	pass


func _on_exit() -> void:
	animate_sprite_2d.stop()
