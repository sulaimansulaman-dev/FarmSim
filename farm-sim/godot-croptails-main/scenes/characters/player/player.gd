class_name Player
extends CharacterBody2D

@export var current_tool: DataTypes.Tools = DataTypes.Tools.None

var direction: Vector2 = Vector2.DOWN

@onready var hit_component: HitComponent = $HitComponent


func _ready() -> void:
    hit_component.current_tool = current_tool
    ToolManager.tool_selected.connect(on_tool_selected)


func on_tool_selected(tool: DataTypes.Tools) -> void:
    current_tool = tool
    hit_component.current_tool = tool
