extends Node

## Drives the farm grid without anyone clicking anything, so the whole
## plant -> water -> harvest path can be checked from the command line:
##
##   godot --headless --path . res://scenes/test/farm_grid_test.tscn
##
## Exits 0 if every check passes, 1 if any fails, so it can be wired into CI.
## This exists because "it opened without crashing" is not evidence that the
## loop works. QA needs something that fails loudly when it does not.

const GRID_SCENE := "res://scenes/farm/farm_grid.tscn"

var _failures: Array = []


func _ready() -> void:
	var grid = load(GRID_SCENE).instantiate()
	add_child(grid)

	_check("field has 12 tiles", grid._tiles.size() == 12)
	_check("weather rolled on start", grid._weather.display_name() != "Unknown")

	# --- planting
	grid._on_action_selected(grid.Action.PLANT_MAIZE)
	grid._on_tile_pressed(0)
	var crop = grid._tiles[0]
	_check("tile 1 planted with maize", crop.crop_id == "maize")
	_check("tile 1 is growing", crop.state == Crop.State.GROWING)

	# Planting on an occupied tile must be refused, not silently restart it.
	grid._on_tile_pressed(0)
	_check("cannot double-plant a tile", crop.day == 0 and crop.crop_id == "maize")

	# Harvesting before maturity must be refused.
	grid._on_action_selected(grid.Action.HARVEST)
	grid._on_tile_pressed(0)
	_check("cannot harvest an immature crop", crop.state != Crop.State.HARVESTED)

	# --- a full, well-tended cycle
	var days := 0
	while not crop.is_ready_to_harvest() and crop.state != Crop.State.DEAD and days < 200:
		if crop.moisture < 0.45:
			grid._on_action_selected(grid.Action.WATER)
			grid._on_tile_pressed(0)
		if crop.pest_active:
			grid._on_action_selected(grid.Action.TREAT)
			grid._on_tile_pressed(0)
		grid._on_end_day()
		days += 1

	_check("crop reached maturity", crop.is_ready_to_harvest())
	_check("cycle took a sane number of days (%d)" % days, days >= 20 and days <= 80)

	# --- harvesting
	var before: float = grid._harvest_total
	grid._on_action_selected(grid.Action.HARVEST)
	grid._on_tile_pressed(0)
	_check("harvest was recorded", grid._harvest_total > before)
	_check("tile is freed after harvest", crop.state == Crop.State.HARVESTED)
	_check(
		"a tended crop keeps most of its yield (%.1f kg of 100)" % grid._harvest_total,
		grid._harvest_total > 50.0
	)

	# --- neglect must cost the player something
	grid._on_action_selected(grid.Action.PLANT_BEANS)
	grid._on_tile_pressed(5)
	var neglected = grid._tiles[5]
	for i in range(40):
		if neglected.is_ready_to_harvest() or neglected.state == Crop.State.DEAD:
			break
		grid._on_end_day()
	_check(
		"a neglected crop is punished",
		neglected.state == Crop.State.DEAD or neglected.total_penalty_percent() > 10.0
	)

	# --- weather must actually vary rather than sticking on one type
	var seen := {}
	for i in range(60):
		grid._weather.advance()
		seen[grid._weather.display_name()] = true
	_check("weather varies across a season (%d types seen)" % seen.size(), seen.size() >= 3)

	print("")
	if _failures.is_empty():
		print("ALL CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("%d FAILURE(S):" % _failures.size())
		for failure in _failures:
			print("  - ", failure)
		get_tree().quit(1)


func _check(description: String, condition: bool) -> void:
	if condition:
		print("  ok    ", description)
	else:
		print("  FAIL  ", description)
		_failures.append(description)
