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

	world._context_action()
	_check("E on bare soil opens the seed picker", world._picker.visible)

	var starting: float = world._balance
	world._picker_key(KEY_1)
	_check("choosing a seed closes the picker", not world._picker.visible)
	_check("planting costs money", world._balance < starting)
	_check("the plot now has a crop", world._tiles[0].state == Crop.State.GROWING)

	# --- escape must always be a way out
	world._context_action()   # crop is growing now, so this waters rather than opening
	world._open_crop_picker(1)
	_check("picker opens on a second plot", world._picker.visible)
	world._picker_key(KEY_ESCAPE)
	_check("Escape closes the picker", not world._picker.visible)

	# --- broke, but a harvest is still coming: not stuck
	world._balance = 0.0
	_check("broke with a crop growing is not stuck", not world._is_stuck())
	var before: float = world._balance
	world._new_season_if_stuck()
	_check("N refuses while a crop is still in the ground", world._balance == before)

	# --- broke with nothing growing: stuck, and the game must say so
	for i in range(world._tiles.size()):
		world._tiles[i] = Crop.new(world._library, i)
	_check("broke with a bare field is stuck", world._is_stuck())

	world._nearest_plot = 0
	world._context_action()
	_check("the picker does NOT open when nothing is affordable", not world._picker.visible)

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
