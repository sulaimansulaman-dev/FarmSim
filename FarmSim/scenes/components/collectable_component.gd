class_name CollectableComponent
extends Area2D

@export var collectable_name: String
@export var amount: int=1


func _on_body_entered(_body: Node2D) -> void:
	print('collected ',amount, " ", collectable_name)
	InventoryManager.add_collectable(collectable_name,amount)
	get_parent().queue_free()
