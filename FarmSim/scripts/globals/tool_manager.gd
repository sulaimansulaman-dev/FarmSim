extends Node

signal tool_enabled(tool: DataTypes.Tools)
signal tool_selected(tool: DataTypes.Tools)

var selected_tool: DataTypes.Tools = DataTypes.Tools.None


func enable_tool(tool: DataTypes.Tools) -> void:
    tool_enabled.emit(tool)


func select_tool(tool: DataTypes.Tools) -> void:
    selected_tool = tool
    tool_selected.emit(tool)
