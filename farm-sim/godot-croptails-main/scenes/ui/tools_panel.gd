extends PanelContainer

## Hover text for the toolbar. The base game identifies its tools by sprite
## alone, which assumes the player already knows what a hoe is - not a safe
## assumption for an audience that is learning to farm.
const TOOL_HINTS := {
	DataTypes.Tools.AxeWood: "Axe - chop trees for wood",
	DataTypes.Tools.TillGround: "Hoe - break open grass to make a bed you can plant in",
	DataTypes.Tools.WaterCrops: "Watering can - dry soil costs you weight at harvest",
}

## Which tool is in hand is shown by dimming the others.
##
## The base game used the keyboard focus ring as that highlight - which is why
## releasing a tool called release_focus() on every button. It cannot stay that
## way. walk_left and walk_right are bound to the arrow keys as well as A and D,
## and the arrows are also Godot's built-in ui_left / ui_right, so every step the
## player took slid the highlight onto a neighbouring tool while the tool
## actually in hand never moved. The panel was lying about the game's state.
const TINT_SELECTED := Color(1, 1, 1, 1)
const TINT_UNSELECTED := Color(1, 1, 1, 0.45)

var _buttons: Dictionary = {}


func _ready() -> void:
	_buttons = {
		DataTypes.Tools.AxeWood: $MarginContainer/HBoxContainer/ToolAxe,
		DataTypes.Tools.TillGround: $MarginContainer/HBoxContainer/ToolTilling,
		DataTypes.Tools.WaterCrops: $MarginContainer/HBoxContainer/ToolWateringCan,
		DataTypes.Tools.PlantCorn: $MarginContainer/HBoxContainer/ToolCorn,
		DataTypes.Tools.PlantTomato: $MarginContainer/HBoxContainer/ToolTomato,
	}

	for tool in _buttons:
		var button: Button = _buttons[tool]
		# Nothing here is meant to be operated by keyboard, so nothing here
		# should be able to hold focus.
		button.focus_mode = Control.FOCUS_NONE
		# A tool appears only once something unlocks it, so a stage never offers
		# an action it cannot support.
		button.visible = false
		button.tooltip_text = hint_for(tool)

	ToolManager.tool_enabled.connect(on_tool_enabled)
	ToolManager.tool_selected.connect(on_tool_selected)
	on_tool_selected(ToolManager.selected_tool)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed('release_tool'):
		ToolManager.select_tool(DataTypes.Tools.None)


func on_tool_enabled(tool: DataTypes.Tools) -> void:
	if not _buttons.has(tool):
		return

	var button: Button = _buttons[tool]
	button.disabled = false
	button.visible = true


func on_tool_selected(tool: DataTypes.Tools) -> void:
	# With nothing in hand there is nothing to contrast against, so dimming
	# every button would only make the whole toolbar look disabled.
	var nothing_held: bool = tool == DataTypes.Tools.None

	for candidate in _buttons:
		var button: Button = _buttons[candidate]
		if nothing_held or candidate == tool:
			button.modulate = TINT_SELECTED
		else:
			button.modulate = TINT_UNSELECTED

## The button that selects a tool, so anything needing to point at one can.
## Null for a tool with no button, which is only DataTypes.Tools.None.
func button_for(tool: DataTypes.Tools) -> Button:
	return _buttons.get(tool)


func hint_for(tool: DataTypes.Tools) -> String:
	if TOOL_HINTS.has(tool):
		return TOOL_HINTS[tool]
	return seed_hint(tool)


## Reads the crop a seed tool actually sows, so reassigning a tool in
## TOOL_CROPS cannot leave the hover text describing the wrong plant.
func seed_hint(tool: DataTypes.Tools) -> String:
	var crop_id: String = CropsCursorComponent.TOOL_CROPS.get(tool, "")
	if crop_id.is_empty():
		return "Seeds"

	var definition: Dictionary = CropManager.library.get_definition(crop_id)
	var crop_name: String = definition.get("display_name", crop_id)
	var local_name: String = definition.get("local_name", "")
	var days: int = CropManager.library.days_to_maturity(crop_id)

	if local_name.is_empty():
		return "%s seeds - %d days to harvest" % [crop_name, days]
	return "%s (%s) seeds - %d days to harvest" % [crop_name, local_name, days]


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
