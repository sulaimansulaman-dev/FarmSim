extends PanelContainer

## The base game's six slots are fixed nodes in this scene. Crop slots cannot
## be: which crops exist is decided by data/crops.json at runtime, so a crop's
## slot is built the first time the player harvests one, then reused.

const PLANTS_SHEET := preload("res://assets/game/objects/basic_plants.png")
const SPRAY_SHEET := preload("res://assets/game/objects/spray_can.png")
const TOOLS_SHEET := preload("res://assets/game/objects/basic_tools_and_materials.png")
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

## Inventory key -> its weight Label, so each slot is built only once.
##
## Keyed by the inventory key rather than the crop id, because Grade A and
## Grade B cabbage are two separate stacks that sell for different money and so
## need two separate slots.
var crop_labels: Dictionary = {}

## Market supplies, which are neither base collectables nor crops. Their icons
## come from their own sheets rather than basic_plants.png.
const SUPPLY_ICONS := {
	"spray": {"sheet": SPRAY_SHEET, "region": Rect2(0, 0, 16, 16)},
	"fertiliser": {"sheet": TOOLS_SHEET, "region": Rect2(32, 0, 16, 16)},
}


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


## Unlocking a seed no longer pre-builds a slot.
##
## It used to, so the player could see what they were working towards. Now that
## produce is graded the crop has no single slot to build - which of Grade A or
## Grade B the first harvest lands in is not known until it is harvested - so
## slots are built on arrival instead.
func on_tool_enabled(_tool: DataTypes.Tools) -> void:
	pass


## Anything in the inventory the panel can draw an icon for gets a slot: graded
## crops from crops.json, and market supplies. Corn and tomato are base-game
## collectables, not simulated crops, so they keep their fixed slots.
func update_crops(inventory: Dictionary) -> void:
	for item_name in inventory:
		var parts: Array = EconomyManager.split_grade(item_name)
		var base_name: String = parts[0]

		var is_crop: bool = CropManager.library.has_crop(base_name)
		var is_supply: bool = SUPPLY_ICONS.has(base_name)
		if not is_crop and not is_supply:
			continue

		if not crop_labels.has(item_name):
			crop_labels[item_name] = build_crop_slot(item_name) if is_crop else build_supply_slot(item_name)

		var quantity: int = int(inventory[item_name])
		crop_labels[item_name].text = str(quantity)
		# An emptied stack leaves its slot in place but greys it out, so the
		# toolbar does not jump around every time the last spray is used.
		crop_labels[item_name].get_parent().modulate.a = 1.0 if quantity > 0 else 0.4


## A slot for a market supply, icon taken from its own spritesheet.
func build_supply_slot(item_name: String) -> Label:
	var icon_data: Dictionary = SUPPLY_ICONS[item_name]
	var icon := AtlasTexture.new()
	icon.atlas = icon_data["sheet"]
	icon.region = icon_data["region"]
	return build_slot(item_name, icon, EconomyManager.display_label(item_name))


## Builds one slot matching the six already in the scene: the crop's harvested
## icon, with its weight sitting over the bottom of it. Grade A and Grade B of
## the same crop share the icon and are told apart by the tooltip.
func build_crop_slot(item_name: String) -> Label:
	var crop_id: String = EconomyManager.split_grade(item_name)[0]
	var definition: Dictionary = CropManager.library.get_definition(crop_id)
	var cell: int = CropManager.library.sprite_cell_size()
	var row: int = int(definition.get("sprite_row", 0))
	var column: int = int(definition.get("harvest_sprite_col", HARVEST_COLUMN))

	var icon := AtlasTexture.new()
	icon.atlas = PLANTS_SHEET
	icon.region = Rect2(column * cell, row * cell, cell, cell)

	return build_slot(item_name, icon, "%s, kg" % EconomyManager.display_label(item_name))


## The shared slot body, matching the six already placed in this scene.
func build_slot(item_name: String, icon: Texture2D, tooltip: String) -> Label:
	var slot := PanelContainer.new()
	slot.name = item_name.validate_node_name()
	slot.custom_minimum_size = SLOT_SIZE
	slot.theme_type_variation = &"InventoryItemPanel"
	# The label is 26px wide - room for a number, not a unit. So the unit
	# lives in the tooltip instead of being crammed in next to the figure.
	slot.tooltip_text = tooltip

	var texture_rect := TextureRect.new()
	texture_rect.texture = icon
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
