class_name HurtComponent
extends Area2D

signal hurt

@export var tool: DataTypes.Tools = DataTypes.Tools.None


func _on_area_entered(area: Area2D) -> void:
    var hit_component = area as HitComponent
    if tool == hit_component.current_tool:
        hurt.emit(hit_component.damage)
