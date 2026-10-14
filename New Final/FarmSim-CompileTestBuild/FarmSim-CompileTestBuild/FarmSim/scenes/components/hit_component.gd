class_name HitComponent
extends Area2D

@export var current_tool: DataTypes.Tools = DataTypes.Tools.None
@export var damage: int = 1


func get_owning_player() -> Node:
	# HitComponent is instanced directly inside player.tscn, so its scene
	# owner is the Player root.
	return owner
