class_name CollectableComponent
extends Area2D

@export var collectable_name: String
@export var amount: int=1

var _collected: bool = false


func _on_body_entered(body: Node2D) -> void:
	# Pickups overlap on every peer, because every peer sees every player. Only
	# the device whose own player walked over it banks the item - otherwise a
	# LAN game hands one cabbage to everybody.
	if _collected or not (body is Player):
		return
	if multiplayer.has_multiplayer_peer() and not body.is_multiplayer_authority():
		# Someone else's player took it: it still disappears here.
		_collected = true
		get_parent().queue_free()
		return

	_collected = true
	InventoryManager.add_collectable(collectable_name, amount)
	FarmEvents.item_collected.emit(collectable_name, amount)
	get_parent().queue_free()
