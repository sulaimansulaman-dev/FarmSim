extends Node


func _ready() -> void:
    call_deferred('enable_tools')


func enable_tools() -> void:
    ToolManager.enable_tool(DataTypes.Tools.AxeWood)
    ToolManager.enable_tool(DataTypes.Tools.TillGround)
    ToolManager.enable_tool(DataTypes.Tools.WaterCrops)
    ToolManager.enable_tool(DataTypes.Tools.PlantCorn)
    ToolManager.enable_tool(DataTypes.Tools.PlantTomato)
