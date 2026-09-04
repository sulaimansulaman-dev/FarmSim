extends Sprite2D

## The produce a crop drops when the player hoes down a mature plant.

## basic_plants.png is 6 columns by 2 rows; frame = row * 6 + column.
const SHEET_COLUMNS := 6
## Column 5 holds the harvested-item icon on every row of the sheet.
const HARVEST_COLUMN := 5

@onready var collectable_component: CollectableComponent = $CollectableComponent

var crop_id: String = ""
var amount_kg: int = 0


## Call this on the instance BEFORE adding it to the tree, so _ready() has the
## values it needs.
func setup(new_crop_id: String, new_amount_kg: int) -> void:
	crop_id = new_crop_id
	amount_kg = new_amount_kg


func _ready() -> void:
	var definition: Dictionary = CropManager.library.get_definition(crop_id)
	var row: int = int(definition.get("sprite_row", 0))
	var column: int = int(definition.get("harvest_sprite_col", HARVEST_COLUMN))
	frame = row * SHEET_COLUMNS + column

	collectable_component.collectable_name = crop_id
	collectable_component.amount = amount_kg
	modulate = CropManager.library.icon_tint(crop_id)
