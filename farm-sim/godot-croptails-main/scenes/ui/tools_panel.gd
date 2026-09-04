extends PanelContainer

## Hover text for the toolbar. The base game identifies its tools by sprite
## alone, which assumes the player already knows what a hoe is - not a safe
## assumption for an audience that is learning to farm.
const TOOL_HINTS := {
    DataTypes.Tools.AxeWood: "Axe - chop trees for wood",
    DataTypes.Tools.TillGround: "Hoe - break open grass to make a bed you can plant in",
    DataTypes.Tools.WaterCrops: "Watering can - dry soil costs you weight at harvest",
}

@onready var tool_axe: Button = $MarginContainer/HBoxContainer/ToolAxe
@onready var tool_tilling: Button = $MarginContainer/HBoxContainer/ToolTilling
@onready var tool_watering_can: Button = $MarginContainer/HBoxContainer/ToolWateringCan
@onready var tool_corn: Button = $MarginContainer/HBoxContainer/ToolCorn
@onready var tool_tomato: Button = $MarginContainer/HBoxContainer/ToolTomato


func _ready() -> void:
    ToolManager.tool_enabled.connect(on_tool_enabled)
    set_tool_hints()


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed('release_tool'):
        ToolManager.select_tool(DataTypes.Tools.None)
        tool_axe.release_focus()
        tool_tilling.release_focus()
        tool_watering_can.release_focus()
        tool_corn.release_focus()
        tool_tomato.release_focus()


func on_tool_enabled(tool: DataTypes.Tools) -> void:
    match tool:
        DataTypes.Tools.AxeWood:
            tool_axe.disabled = false
            tool_axe.focus_mode = Control.FOCUS_ALL
        DataTypes.Tools.TillGround:
            tool_tilling.disabled = false
            tool_tilling.focus_mode = Control.FOCUS_ALL
        DataTypes.Tools.WaterCrops:
            tool_watering_can.disabled = false
            tool_watering_can.focus_mode = Control.FOCUS_ALL
        DataTypes.Tools.PlantCorn:
            tool_corn.disabled = false
            tool_corn.focus_mode = Control.FOCUS_ALL
        DataTypes.Tools.PlantTomato:
            tool_tomato.disabled = false
            tool_tomato.focus_mode = Control.FOCUS_ALL


func _on_tool_axe_pressed() -> void:
    ToolManager.select_tool(DataTypes.Tools.AxeWood)


func _on_tool_tilling_pressed() -> void:
    ToolManager.select_tool(DataTypes.Tools.TillGround)


func _on_tool_watering_can_pressed() -> void:
    ToolManager.select_tool(DataTypes.Tools.WaterCrops)


func _on_tool_corn_pressed() -> void:
    ToolManager.select_tool(DataTypes.Tools.PlantCorn)


func _on_tool_tomato_pressed() -> void:
    ToolManager.select_tool(DataTypes.Tools.PlantTomato)


func set_tool_hints() -> void:
    tool_axe.tooltip_text = TOOL_HINTS[DataTypes.Tools.AxeWood]
    tool_tilling.tooltip_text = TOOL_HINTS[DataTypes.Tools.TillGround]
    tool_watering_can.tooltip_text = TOOL_HINTS[DataTypes.Tools.WaterCrops]
    tool_corn.tooltip_text = seed_hint(DataTypes.Tools.PlantCorn)
    tool_tomato.tooltip_text = seed_hint(DataTypes.Tools.PlantTomato)


## Reads the crop a seed tool actually sows, so reassigning a tool in
## TOOL_CROPS cannot leave the hover text describing the wrong plant.
func seed_hint(tool: DataTypes.Tools) -> String:
    var crop_id: String = CropsCursorComponent.TOOL_CROPS.get(tool, "")
    if crop_id.is_empty():
        return "Seeds"

    var definition: Dictionary = CropManager.library.get_definition(crop_id)
    var crop_name: String = definition.get("display_name", crop_id)
    var local_name: String = definition.get("local_name", "")
    if local_name.is_empty():
        return "%s seeds - plant in a dug bed" % crop_name
    return "%s (%s) seeds - plant in a dug bed" % [crop_name, local_name]
