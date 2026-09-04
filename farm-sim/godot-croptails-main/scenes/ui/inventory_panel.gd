extends PanelContainer

## The base game's six slots are fixed nodes in this scene. Crop slots cannot
## be: which crops exist is decided by data/crops.json at runtime, so a crop's
## slot is built the first time the player harvests one, then reused.

const PLANTS_SHEET := preload("res://assets/game/objects/basic_plants.png")
## Column 5 of the sheet holds the harvested-item icon on every row.
const HARVEST_COLUMN := 5
const SLOT_SIZE := Vector2(26, 32)

@onready var log_label: Label = $MarginContainer/VBoxContainer/Log/LogLabel
@onready var stone_label: Label = $MarginContainer/VBoxContainer/Stone/StoneLabel
@onready var corn_label: Label = $MarginContainer/VBoxContainer/Corn/CornLabel
@onready var tomato_label: Label = $MarginContainer/VBoxContainer/Tomato/TomatoLabel
@onready var egg_label: Label = $MarginContainer/VBoxContainer/Egg/EggLabel
@onready var milk_label: Label = $MarginContainer/VBoxContainer/Milk/MilkLabel
@onready var slots: VBoxContainer = $MarginContainer/VBoxContainer

@onready var base_labels: Dictionary = {
	'log': log_label,
	'stone': stone_label,
	'corn': corn_label,
	'tomato': tomato_label,
	'egg': egg_label,
	'milk': milk_label,
}

## crop_id -> its weight Label, so each crop's slot is built only once.
var crop_labels: Dictionary = {}


func _ready() -> void:
	InventoryManager.inventory_changed.connect(on_inventory_changed)
	ToolManager.tool_enabled.connect(on_tool_enabled)

	# Island 1 has no trees, animals or corn, so these slots would only ever
	# read 0. A slot appears the first time the player actually holds one.
	for label: Label in base_labels.values():
		label.get_parent().visible = false


func on_inventory_changed(inventory: Dictionary) -> void:
	for item_name in base_labels:
		if not inventory.has(item_name):
			continue
		var label: Label = base_labels[item_name]
		label.text = str(inventory[item_name])
		label.get_parent().visible = true

	update_crops(inventory)


## A crop gets its slot as soon as the seeds are unlocked, so the player can
## see what they are working towards before the first harvest lands.
func on_tool_enabled(tool: DataTypes.Tools) -> void:
	var crop_id: String = CropsCursorComponent.TOOL_CROPS.get(tool, "")
	if crop_id.is_empty() or crop_labels.has(crop_id):
		return
	crop_labels[crop_id] = build_crop_slot(crop_id)


## Anything in the inventory that crops.json knows about gets a slot. Corn and
## tomato are base-game collectables, not crops, so they keep their fixed slots.
func update_crops(inventory: Dictionary) -> void:
	for item_name in inventory:
		if not CropManager.library.has_crop(item_name):
			continue
		if not crop_labels.has(item_name):
			crop_labels[item_name] = build_crop_slot(item_name)
		crop_labels[item_name].text = str(int(inventory[item_name]))


## Builds one slot matching the six already in the scene: the crop's harvested
## icon, with its weight sitting over the bottom of it.
func build_crop_slot(crop_id: String) -> Label:
	var definition: Dictionary = CropManager.library.get_definition(crop_id)
	var cell: int = CropManager.library.sprite_cell_size()
	var row: int = int(definition.get("sprite_row", 0))
	var column: int = int(definition.get("harvest_sprite_col", HARVEST_COLUMN))

	var icon := AtlasTexture.new()
	icon.atlas = PLANTS_SHEET
	icon.region = Rect2(column * cell, row * cell, cell, cell)

	var slot := PanelContainer.new()
	slot.name = crop_id.capitalize()
	slot.custom_minimum_size = SLOT_SIZE
	slot.theme_type_variation = &"InventoryItemPanel"
	# The label is 26px wide - room for a number, not a unit. So the unit
	# lives in the tooltip instead of being crammed in next to the figure.
	slot.tooltip_text = "%s (kg)" % definition.get("display_name", crop_id)

	var texture_rect := TextureRect.new()
	texture_rect.texture = icon
	texture_rect.modulate = CropManager.library.icon_tint(crop_id)
	texture_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	texture_rect.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	slot.add_child(texture_rect)

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_END
	label.theme_type_variation = &"InventoryLabel"
	label.text = "0"
	slot.add_child(label)

	slots.add_child(slot)
	return label
