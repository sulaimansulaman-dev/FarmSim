class_name CropLibrary
extends RefCounted

## Loads and validates the agronomic crop definitions in data/crops.json.
##
## Nothing in the crop simulation hard-codes a growth rate, a water requirement
## or a damage value; it all comes from here (NFR-006). Tuning the game means
## editing JSON, not editing GDScript.

const DATA_PATH := "res://data/crops.json"

var simulation: Dictionary = {}
var sprites: Dictionary = {}
var _crops: Dictionary = {}


## Reads and validates the crop data file.
## Returns OK, or an error code. Check load_error for a human-readable reason.
var load_error: String = ""


func load_from(path: String = DATA_PATH) -> bool:
	load_error = ""
	_crops.clear()
	simulation.clear()
	sprites.clear()

	if not FileAccess.file_exists(path):
		load_error = "Crop data file not found at %s" % path
		return false

	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)

	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		load_error = "Crop data at %s is not valid JSON." % path
		return false

	if not parsed.has("crops") or typeof(parsed["crops"]) != TYPE_ARRAY:
		load_error = "Crop data is missing a 'crops' array."
		return false

	simulation = parsed.get("simulation", {})
	sprites = parsed.get("_sprites", {})

	for entry in parsed["crops"]:
		var problem := _validate_crop(entry)
		if problem != "":
			load_error = problem
			return false
		_crops[entry["id"]] = entry

	if _crops.is_empty():
		load_error = "Crop data contains no crops."
		return false

	return true


## Returns the raw definition dictionary for a crop id, or an empty dictionary.
func get_definition(crop_id: String) -> Dictionary:
	return _crops.get(crop_id, {})


func has_crop(crop_id: String) -> bool:
	return _crops.has(crop_id)


func crop_ids() -> Array:
	return _crops.keys()


## Total number of days a crop takes to reach maturity under perfect conditions.
func days_to_maturity(crop_id: String) -> int:
	var definition := get_definition(crop_id)
	if definition.is_empty():
		return 0
	var total := 0
	for stage in definition["stages"]:
		total += int(stage["days"])
	return total


func tuning(key: String, fallback: float) -> float:
	return float(simulation.get(key, fallback))


# --- art lookup -------------------------------------------------------------
# Which cell of the spritesheet a crop shows at a given stage is data, not code.
# When the real art pack replaces the placeholder, only crops.json changes.

func sprite_sheet_path() -> String:
	return str(sprites.get("sheet", "res://game/objects/basic_plants.png"))


func sprite_cell_size() -> int:
	return int(sprites.get("cell_size", 16))


## Optional placeholder tint for a crop's art, given in crops.json as a hex
## string or a colour name. White when the crop has none.
##
## This exists only because crops currently borrow each other's spritesheet
## rows - cabbage draws on the tomato row, so untinted it is indistinguishable
## from tomatoes. Delete this and the icon_tint entries when the real art lands.
func icon_tint(crop_id: String) -> Color:
	var value: String = str(get_definition(crop_id).get("icon_tint", ""))
	if value.is_empty():
		return Color.WHITE
	return Color.from_string(value, Color.WHITE)


## The region of the spritesheet to draw for this crop at its current stage.
func stage_sprite_region(crop: Crop) -> Rect2:
	var definition := get_definition(crop.crop_id)
	if definition.is_empty():
		return Rect2()

	var size := sprite_cell_size()
	var row := int(definition.get("sprite_row", 0))
	var column := int(crop.current_stage().get("sprite_col", 1))
	return Rect2(column * size, row * size, size, size)


# --- validation -------------------------------------------------------------
# A malformed data file should fail loudly at load with a message that names the
# problem, not silently produce a crop that never grows.

func _validate_crop(entry) -> String:
	if typeof(entry) != TYPE_DICTIONARY:
		return "Every entry in 'crops' must be an object."

	for field in ["id", "display_name", "base_yield_kg", "daily_water_use", "wilting_point", "stages"]:
		if not entry.has(field):
			return "Crop '%s' is missing required field '%s'." % [entry.get("id", "<no id>"), field]

	if typeof(entry["stages"]) != TYPE_ARRAY or entry["stages"].is_empty():
		return "Crop '%s' must define at least one growth stage." % entry["id"]

	for stage in entry["stages"]:
		for field in ["id", "display_name", "days", "water_sensitivity"]:
			if not stage.has(field):
				return "Crop '%s' has a stage missing required field '%s'." % [entry["id"], field]
		if int(stage["days"]) <= 0:
			return "Crop '%s' stage '%s' must last at least one day." % [entry["id"], stage["id"]]

	return ""
