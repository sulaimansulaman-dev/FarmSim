class_name DamageComponent
extends Node

signal max_damage_reached

@export var max_damage: int = 1
@export var current_damage: int = 0


func apply_damage(damage: int) -> void:
    current_damage = clamp(current_damage + damage, 0, max_damage)

    if current_damage == max_damage:
        max_damage_reached.emit()
