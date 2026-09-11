class_name HurtComponent
extends Area2D

signal hurt(damage: int)

@export var tool: DataTypes.Tools = DataTypes.Tools.None


func _on_area_entered(area: Area2D) -> void:
	var hit_component := area as HitComponent
	if hit_component == null or tool != hit_component.current_tool:
		return

	# Area2D overlap is detected locally on *every* peer (using replicated
	# positions), so without this guard every observer - and the server -
	# would each try to register the hit independently. Only the client
	# that actually owns/controls the attacking player is allowed to be
	# the one that reports it.
	var attacking_player := hit_component.get_owning_player()
	if attacking_player and multiplayer.has_multiplayer_peer() \
			and not attacking_player.is_multiplayer_authority():
		return

	if multiplayer.has_multiplayer_peer():
		request_hit.rpc_id(1, hit_component.damage)
	else:
		_apply_hit(hit_component.damage)


## Runs only on whoever receives it as id 1 (the host). World objects keep
## their default multiplayer authority (peer 1), so the host is the single
## source of truth for this object's damage state.
@rpc("any_peer", "call_remote", "reliable")
func request_hit(damage: int) -> void:
	if not multiplayer.is_server():
		return
	_apply_hit.rpc(damage)


## Broadcast from the host to every peer (call_local means the host applies
## it too), so all clients see the exact same hit at the exact same time.
@rpc("authority", "call_local", "reliable")
func _apply_hit(damage: int) -> void:
	hurt.emit(damage)
