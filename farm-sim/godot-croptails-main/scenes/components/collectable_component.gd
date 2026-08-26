class_name CollectableComponent
extends Area2D

@export var collectable_name: String


func _on_body_entered(_body: Node2D) -> void:
    print('collected ', collectable_name)
    InventoryManager.add_collectable(collectable_name)
    get_parent().queue_free()
