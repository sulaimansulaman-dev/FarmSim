class_name InteractableComponent
extends Area2D

signal interactable_activated(body: Node2D)
signal interactable_deactivated(body: Node2D)


func _on_body_entered(body: Node2D) -> void:
    interactable_activated.emit(body)


func _on_body_exited(body: Node2D) -> void:
    interactable_deactivated.emit(body)
