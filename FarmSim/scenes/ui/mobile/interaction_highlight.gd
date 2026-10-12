class_name InteractionHighlight
extends Node2D

## Shows what the A button will act on.
##
## Two things can be marked:
##   - an object the player can interact with (the guide, a chest, the market),
##     boxed in corner brackets while its "A" prompt is showing; and
##   - the ground tile the held tool will land on, picked from the tiles within
##     reach in front of the player. Bright when the tool would do something
##     there, faint when it would not.
##
## It lives as a child of the local Player (MobileControls puts it there) and
## draws in world space. The tile it picks is also published in MobileInput, and
## the cursor components aim at that tile instead of at the mouse, so the
## square on screen is, by construction, the square that gets worked.

const TILE := 16.0
## Cursor components reject anything 20px or further away. Staying under that
## means the highlighted tile is never one the tool would refuse for reach.
const REACH := 19.0
## Saplings must go a little away from the player's feet.
const SAPLING_MIN := 10.0
const SAPLING_MAX := 29.0
const CHECK_INTERVAL := 0.1

const READY_COLOUR := Color("ffd84a")
const IDLE_COLOUR := Color(1.0, 1.0, 1.0, 0.5)
const SHADOW_COLOUR := Color(0.0, 0.0, 0.0, 0.5)

## The interactable in range, or null.
var object_target: Node2D = null
var object_rect: Rect2 = Rect2()

## The ground tile the held tool aims at.
var tile_active: bool = false
var tile_ready: bool = false
var tile_centre: Vector2 = Vector2.ZERO

var _player: Player
var _time: float = 0.0
var _check_timer: float = 0.0
var _last_cell: Vector2i = Vector2i(-99999, -99999)
var _last_tool: DataTypes.Tools = DataTypes.Tools.None


func _init() -> void:
	# World coordinates, drawn over everything in the world but under the HUD.
	top_level = true
	z_as_relative = false
	z_index = 100


func _process(delta: float) -> void:
	_time += delta
	_check_timer -= delta
	_player = get_parent() as Player
	if _player == null:
		return

	_find_object()
	_find_tile()
	queue_redraw()


# --- objects ----------------------------------------------------------------

func _find_object() -> void:
	object_target = null
	var nearest := INF
	for label: Control in MobileInput.prompt_labels:
		if not is_instance_valid(label) or not label.is_visible_in_tree():
			continue
		var owner_node := label.get_parent() as Node2D
		if owner_node == null:
			continue
		var distance := owner_node.global_position.distance_squared_to(_player.global_position)
		if distance < nearest:
			nearest = distance
			object_target = owner_node

	if object_target != null:
		object_rect = MobileInput.visual_rect(object_target)


# --- ground -----------------------------------------------------------------

func _find_tile() -> void:
	tile_active = false
	MobileInput.has_target = false
	MobileInput.has_front = false

	var tool: DataTypes.Tools = ToolManager.selected_tool

	# The axe is not aimed at a tile: it swings a hitbox that chopping_state
	# places just in front of the player. Mark where that lands.
	if tool == DataTypes.Tools.AxeWood:
		tile_centre = _player.global_position + _axe_offset(_player.direction)
		tile_active = true
		tile_ready = true
		return

	var layer := MobileInput.grid_layer()
	if layer == null:
		return

	var min_reach := SAPLING_MIN if tool == DataTypes.Tools.PlantSapling else 0.0
	var max_reach := SAPLING_MAX if tool == DataTypes.Tools.PlantSapling else REACH

	# Of the tiles within reach, take the one closest to the spot a tile's width
	# in front of the player. Standing on a tile boundary this resolves to the
	# tile you are facing; standing mid-tile it still picks a reachable one.
	var probe := _player.global_position + _player.direction * TILE
	var origin := layer.local_to_map(layer.to_local(_player.global_position))
	var best_cell := origin
	var best_score := INF
	var found := false
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var cell := origin + Vector2i(dx, dy)
			var local_centre := layer.map_to_local(cell)
			# Measured the way the cursor components measure it.
			var reach := _player.global_position.distance_to(local_centre)
			if reach < min_reach or reach > max_reach:
				continue
			var score := probe.distance_to(layer.to_global(local_centre))
			if score < best_score:
				best_score = score
				best_cell = cell
				found = true
	if not found:
		return

	var centre := layer.to_global(layer.map_to_local(best_cell))
	MobileInput.has_front = true
	MobileInput.front_position = centre
	if tool == DataTypes.Tools.None:
		return

	tile_centre = centre
	tile_active = true
	MobileInput.has_target = true
	MobileInput.target_position = centre

	if tool != _last_tool or best_cell != _last_cell or _check_timer <= 0.0:
		tile_ready = _would_work(tool, best_cell, centre)
		_last_tool = tool
		_last_cell = best_cell
		_check_timer = CHECK_INTERVAL


## Whether the held tool would do anything on this tile. Mirrors the rules in
## the cursor components closely enough to colour the highlight; the components
## stay the authority on what actually happens.
func _would_work(tool: DataTypes.Tools, cell: Vector2i, centre: Vector2) -> bool:
	var soil := MobileInput.soil_layer()
	var tilled := soil != null and soil.get_cell_source_id(cell) != -1

	match tool:
		DataTypes.Tools.TillGround:
			return MobileInput.grass_at(centre) and not tilled
		DataTypes.Tools.PlantCorn, DataTypes.Tools.PlantTomato:
			return tilled and not _crop_at(centre)
		DataTypes.Tools.WaterCrops, DataTypes.Tools.SprayPest, DataTypes.Tools.OrganicControl:
			return _crop_at(centre)
		DataTypes.Tools.PlantSapling:
			return MobileInput.grass_at(centre) and not tilled
	return false


func _crop_at(world_position: Vector2) -> bool:
	for plant: Node2D in get_tree().get_nodes_in_group("crop_plant"):
		if plant.is_queued_for_deletion():
			continue
		if plant.global_position.distance_to(world_position) < TILE * 0.5:
			return true
	return false


## Where chopping_state puts the axe's hitbox for each facing.
func _axe_offset(direction: Vector2) -> Vector2:
	if direction == Vector2.UP:
		return Vector2(0.0, -20.0)
	if direction == Vector2.LEFT:
		return Vector2(-9.0, -1.0)
	if direction == Vector2.RIGHT:
		return Vector2(9.0, -1.0)
	return Vector2(0.0, 3.0)


# --- drawing ----------------------------------------------------------------

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 6.0)

	if object_target != null:
		_brackets(object_rect.grow(2.0 + pulse * 1.5), READY_COLOUR, 5.0)

	if tile_active:
		var rect := Rect2(tile_centre - Vector2(TILE, TILE) * 0.5, Vector2(TILE, TILE))
		if tile_ready:
			draw_rect(rect, Color(READY_COLOUR, 0.14 + 0.10 * pulse), true)
			_brackets(rect, READY_COLOUR, 4.0)
		else:
			_brackets(rect, IDLE_COLOUR, 3.0)


## Four corner brackets around a rectangle, drawn as whole-pixel bars with a
## dark edge so they read on both grass and soil.
func _brackets(rect: Rect2, colour: Color, length: float) -> void:
	var left := roundf(rect.position.x)
	var top := roundf(rect.position.y)
	var right := roundf(rect.end.x)
	var bottom := roundf(rect.end.y)

	# Shadow first, offset by a pixel, then the coloured bracket on top.
	for pass_index in 2:
		var shift := Vector2(1.0, 1.0) if pass_index == 0 else Vector2.ZERO
		var tint := SHADOW_COLOUR if pass_index == 0 else colour
		_corner(Vector2(left, top) + shift, length, tint, false, false)
		_corner(Vector2(right, top) + shift, length, tint, true, false)
		_corner(Vector2(left, bottom) + shift, length, tint, false, true)
		_corner(Vector2(right, bottom) + shift, length, tint, true, true)


## One bracket: two one-pixel bars meeting at a corner. The flags mirror it for
## the right-hand and lower corners.
func _corner(at: Vector2, length: float, colour: Color, flip_x: bool, flip_y: bool) -> void:
	var bar_x := at.x - length if flip_x else at.x
	var bar_y := at.y - 1.0 if flip_y else at.y
	draw_rect(Rect2(bar_x, bar_y, length, 1.0), colour)

	var post_x := at.x - 1.0 if flip_x else at.x
	var post_y := at.y - length if flip_y else at.y
	draw_rect(Rect2(post_x, post_y, 1.0, length), colour)
