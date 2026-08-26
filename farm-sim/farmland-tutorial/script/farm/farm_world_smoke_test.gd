extends Node

## Checks the farm world's failure states, which is where playtesting found
## real problems that the happy path never touched.
##
##   godot --headless --path . res://scenes/test/farm_world_test.tscn
##
## The bug that prompted this: a player spent all their money, pressed E on
## bare soil, and got a seed picker where every option was unaffordable. The
## picker itself closed fine, but there was no way to plant ever again and the
## game said nothing about it. Going broke is a legitimate outcome for a
## farming game; going broke silently is not.

const WORLD_SCENE := "res://scenes/farm/farm_world.tscn"

var _failures: Array = []


func _ready() -> void:
	var world = load(WORLD_SCENE).instantiate()
	add_child(world)
	await get_tree().process_frame

	# Stand on a plot so nearest-plot resolves the way it does in play.
	world._player.position = world._plot_positions[0]
	world._update_nearest_plot()
	_check("a plot is in reach", world._nearest_plot == 0)

	# --- the happy path still works
	_check("not stuck at the start", not world._is_stuck())
	_check("can afford seed at the start", world._can_afford_any_seed())

	# --- plant directly with the held seed, no menu in the way
	var starting: float = world._balance
	world._context_action()
	_check("E on bare soil plants straight away", world._tiles[0].state == Crop.State.GROWING)
	_check("planting costs money", world._balance < starting)
	_check("planting does not open a menu", not world._picker.visible)

	# --- the menu only changes which seed is held
	var held: String = world._selected_crop
	world._open_crop_picker()
	_check("C opens the seed menu", world._picker.visible)
	var before_choice: float = world._balance
	world._picker_key(KEY_2)
	_check("choosing closes the menu", not world._picker.visible)
	_check("choosing changes the held seed", world._selected_crop != held)
	_check("choosing a seed does not plant or charge", world._balance == before_choice)

	# --- the plot tells you what it needs without opening anything (FR-003)
	_check("no pest marker on a healthy crop", not world._pest_sprites[0].visible)
	_check("no tool marker on an unripe crop", not world._ready_sprites[0].visible)

	world._tiles[0].pest_active = true
	world._refresh()
	_check("a pest shows a bug on the crop", world._pest_sprites[0].visible)

	world._tiles[0].treat_pest()
	world._refresh()
	_check("treating clears the bug", not world._pest_sprites[0].visible)

	# --- exactly one key harvests
	world._nearest_plot = 0
	world._tiles[0].force_mature()
	var before_e: float = world._balance
	world._context_action()
	_check("E does NOT harvest a ripe crop", world._tiles[0].state == Crop.State.MATURE)
	_check("E on a ripe crop earns nothing", world._balance == before_e)
	# _refresh runs after every keypress in play; calling the action directly
	# bypasses that, so do it by hand before checking what is drawn.
	world._refresh()
	_check("a ripe crop shows the tool marker", world._ready_sprites[0].visible)
	world._harvest_nearest()
	_check("H harvests it", world._tiles[0].state == Crop.State.HARVESTED)
	world._refresh()
	_check("harvesting clears the tool marker", not world._ready_sprites[0].visible)
	_check("H pays out", world._balance > before_e)

	# --- the controls line is always on screen
	_check("controls line exists", world._controls_label != null)
	_check("controls line is never empty", world._controls_label.text.length() > 0)
	_check("controls line names H for harvest", world._controls_label.text.contains("H harvest"))

	# --- escape must always be a way out
	world._open_crop_picker()
	world._picker_key(KEY_ESCAPE)
	_check("Escape closes the menu", not world._picker.visible)

	# --- broke, but a harvest is still coming: not stuck
	# Put a crop back in the ground first: the harvest checks above emptied the
	# field, and "not stuck" only means anything while something is growing.
	world._nearest_plot = 2
	world._context_action()
	_check("a crop is growing again", world._tiles[2].state == Crop.State.GROWING)

	world._balance = 0.0
	_check("broke with a crop growing is not stuck", not world._is_stuck())
	var before: float = world._balance
	world._new_season_if_stuck()
	_check("N refuses while a crop is still in the ground", world._balance == before)

	# --- broke with nothing growing: stuck, and the game must say so
	for i in range(world._tiles.size()):
		world._tiles[i] = Crop.new(world._library, i)
	_check("broke with a bare field is stuck", world._is_stuck())

	world._nearest_plot = 3
	world._context_action()
	_check("planting broke does not open a menu", not world._picker.visible)
	_check("planting broke leaves the plot empty", world._tiles[3].state == Crop.State.EMPTY)

	world._new_season_if_stuck()
	_check("N starts a new season when genuinely stuck", world._balance == world._prices.starting_balance)
	_check("a new season clears the field", not world._has_crops_in_the_ground())
	_check("no longer stuck after a new season", not world._is_stuck())

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
