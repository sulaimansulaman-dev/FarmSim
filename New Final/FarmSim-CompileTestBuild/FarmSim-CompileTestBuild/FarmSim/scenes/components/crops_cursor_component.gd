class_name CropsCursorComponent
extends Node

const crop_plant_scene: PackedScene = preload('res://scenes/objects/plants/crop_plant.tscn')

## Which crop each planting tool sows.
## A stopgap until there is a seed picker. DataTypes.Tools has one entry per
## crop, which does not scale past the two the base game shipped with - adding
## wheat should not mean adding an enum value. Every id here must exist in
## crops.json.
const TOOL_CROPS := {
	DataTypes.Tools.PlantCorn: "maize",
	DataTypes.Tools.PlantTomato: "cabbage",
}

## Which market supply each treatment tool uses up (Stage 3).
const TOOL_TREATMENTS := {
	DataTypes.Tools.SprayPest: "spray",
	DataTypes.Tools.OrganicControl: "organic",
}

## The fruit trees a sapling can grow into (Stage 4). Cycled in order so a
## player planting several gets a mixed orchard.
const TREE_SCENES := [
	"res://scenes/objects/trees/apple_tree.tscn",
	"res://scenes/objects/trees/orange_tree.tscn",
	"res://scenes/objects/trees/peach_tree.tscn",
	"res://scenes/objects/trees/pear_tree.tscn",
]

## How far from the player, in world pixels, a click can act.
const REACH := 20.0

@export var tilled_soil_tilemap_layer: TileMapLayer

var player: Player
var mouse_position: Vector2
var cell_position: Vector2i
var cell_source_id: int
var local_cell_position: Vector2
var distance: float

var _trees_planted: int = 0


func _ready() -> void:
	await get_tree().process_frame
	player = StageSession.local_player()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed('remove_dirt'):
		if ToolManager.selected_tool == DataTypes.Tools.TillGround:
			if get_cell_under_mouse():
				remove_crop()
	elif event.is_action_pressed('hit'):
		var tool := ToolManager.selected_tool
		if TOOL_CROPS.has(tool):
			if get_cell_under_mouse():
				add_crop()
		elif TOOL_TREATMENTS.has(tool):
			if get_cell_under_mouse():
				treat_crop(TOOL_TREATMENTS[tool])
		elif tool == DataTypes.Tools.WaterCrops:
			if get_cell_under_mouse():
				water_crop()
		elif tool == DataTypes.Tools.PlantSapling:
			if get_cell_under_mouse():
				plant_sapling()


## Reads the tile under the mouse. False if there is no local player to measure
## reach from - a client whose player has not spawned yet.
func get_cell_under_mouse() -> bool:
	if player == null or not is_instance_valid(player):
		player = StageSession.local_player()
	if player == null:
		return false

	mouse_position = tilled_soil_tilemap_layer.get_local_mouse_position()
	cell_position = tilled_soil_tilemap_layer.local_to_map(mouse_position)
	cell_source_id = tilled_soil_tilemap_layer.get_cell_source_id(cell_position)
	local_cell_position = tilled_soil_tilemap_layer.map_to_local(cell_position)
	distance = player.global_position.distance_to(local_cell_position)
	return true


# --- sowing -----------------------------------------------------------------

func add_crop() -> void:
	if cell_source_id == -1 or distance > REACH:
		return

	if not TOOL_CROPS.has(ToolManager.selected_tool):
		return

	# One crop per tile. Without this, a second click stacks another plant on
	# the same square invisibly: watering and harvesting then hit both, and the
	# one underneath survives the harvest looking like a seed that will not go.
	if crop_at(local_cell_position) != null:
		return

	var crop_id: String = TOOL_CROPS[ToolManager.selected_tool]

	# Paid for before anything is built, so a refused sale leaves no half-planted
	# node behind. Returns true untouched when the economy is off.
	if not EconomyManager.charge_for_seed(crop_id):
		return

	# Seed viability, checked at the moment of sowing. This reports and lets the
	# player go ahead: being allowed to plant maize in winter and then watching
	# it sit in the ground is the lesson. A disabled button is just a puzzle.
	var warning := SeasonManager.viability_warning(crop_id)
	if not warning.is_empty():
		FarmEvents.advisory.emit(warning)

	var fertilised := EconomyManager.consume_fertiliser_if_held()
	_send("plant", cell_position, {"crop_id": crop_id, "fertilised": fertilised})


# --- treating pests ---------------------------------------------------------

## Treats the crop under the mouse with a spray or organic control.
func treat_crop(supply_id: String) -> void:
	if distance > REACH:
		return

	var crop := crop_at(local_cell_position) as CropPlant
	if crop == null:
		return

	var result := crop.prepare_treatment(supply_id)
	if result == CropPlant.TREAT_REFUSED:
		return
	_send("treat", cell_position, {"result": result})


# --- watering ---------------------------------------------------------------

## Waters the crop under the mouse, if the player is close enough to reach it.
##
## The can used to work like the axe: a 3px hitbox pushed 21px out in whichever
## of four directions the player last walked. A click on the seedling only
## landed if the player happened to be facing it at exactly that distance, so
## most clicks did nothing. It now targets the tile you click, like sowing and
## spraying, and turns the player to face it so the animation still reads.
func water_crop() -> void:
	if distance > REACH:
		return

	var crop := crop_at(local_cell_position) as CropPlant
	if crop == null:
		return

	face_towards(local_cell_position)
	crop.watering_hurt_component.take_hit(1)


## Points the player at a spot, so the tool animation plays toward it.
func face_towards(target: Vector2) -> void:
	var offset := target - player.global_position
	if absf(offset.x) >= absf(offset.y):
		player.direction = Vector2.RIGHT if offset.x > 0.0 else Vector2.LEFT
	else:
		player.direction = Vector2.DOWN if offset.y > 0.0 else Vector2.UP


# --- saplings ---------------------------------------------------------------

## Plants a fruit tree sapling on open grass (Stage 4, FR-ENG-003).
##
## Trees go on grass, not in the tilled field - an orchard is not a vegetable
## bed - and never on the player's own feet, where the trunk would trap them.
func plant_sapling() -> void:
	if distance > REACH * 1.5 or distance < 10.0:
		return

	var grass := _level_layer("Grass")
	if grass == null:
		return
	var grass_cell := grass.local_to_map(grass.to_local(tilled_soil_tilemap_layer.to_global(local_cell_position)))
	if grass.get_cell_source_id(grass_cell) == -1 or cell_source_id != -1:
		FarmEvents.advisory.emit("Saplings go on open grass, not in the tilled field or the water.")
		return

	var objects := _level_layer("Objects")
	if objects != null and objects.get_cell_source_id(objects.local_to_map(objects.to_local(tilled_soil_tilemap_layer.to_global(local_cell_position)))) != -1:
		return

	if _tree_at(cell_position) != null:
		return

	if not EconomyManager.consume_supply("sapling"):
		return

	_send("tree", cell_position, {"index": _trees_planted})
	_trees_planted += 1


func _level_layer(layer_name: String) -> TileMapLayer:
	return get_parent().get_node_or_null("GameTilemap/" + layer_name) as TileMapLayer


func _tree_at(cell: Vector2i) -> Node:
	return get_parent().get_node_or_null(_tree_name(cell))


static func _tree_name(cell: Vector2i) -> String:
	return "tree_%d_%d" % [cell.x, cell.y]


# --- removing ---------------------------------------------------------------

func remove_crop() -> void:
	if distance > REACH:
		return
	if crop_at(local_cell_position) != null:
		_send("remove", cell_position, {})


## The crop standing on a tile, or null if it is free.
##
## Crops queued for deletion do not count: harvesting frees the plant but the
## node lingers until the end of the frame, and a tile you just cleared should
## be plantable straight away.
func crop_at(position: Vector2) -> Node2D:
	for node: Node2D in _crop_fields().get_children():
		if node.is_queued_for_deletion():
			continue
		if node.global_position == position:
			return node
	return null


func _crop_fields() -> Node:
	return get_parent().find_child('CropFields')


## Every crop gets a name made from its tile. Crops are created at runtime on
## each LAN peer, and Godot's automatic names differ from device to device - so
## the watering and harvesting RPCs, which address a crop by node path, would
## miss. A tile name is the same everywhere.
static func _crop_name(cell: Vector2i) -> String:
	return "crop_%d_%d" % [cell.x, cell.y]


# --- LAN synchronisation (FR-ENG-006, Tech Spec 4.2) --------------------------
#
# A world edit is decided by the device that clicked (reach, money, the roll of
# a treatment) and then applied everywhere. Singleplayer applies it straight
# away. A client asks the host; the host re-checks that the tile is still free
# and broadcasts the change to every device, itself included.

func _send(action: String, cell: Vector2i, args: Dictionary) -> void:
	if not multiplayer.has_multiplayer_peer():
		_apply_action(action, cell, args)
	elif multiplayer.is_server():
		if _host_allows(action, cell):
			_apply_action.rpc(action, cell, args)
	else:
		_request_action.rpc_id(1, action, cell, args)


@rpc("any_peer", "call_remote", "reliable")
func _request_action(action: String, cell: Vector2i, args: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	if _host_allows(action, cell):
		_apply_action.rpc(action, cell, args)


func _host_allows(action: String, cell: Vector2i) -> bool:
	var position := tilled_soil_tilemap_layer.map_to_local(cell)
	match action:
		"plant":
			return tilled_soil_tilemap_layer.get_cell_source_id(cell) != -1 and crop_at(position) == null
		"tree":
			return _tree_at(cell) == null
		"treat", "remove":
			return crop_at(position) != null
	return false


@rpc("authority", "call_local", "reliable")
func _apply_action(action: String, cell: Vector2i, args: Dictionary) -> void:
	var position := tilled_soil_tilemap_layer.map_to_local(cell)
	match action:
		"plant":
			_do_plant(cell, position, str(args.get("crop_id", "")), bool(args.get("fertilised", false)))
		"treat":
			var crop := crop_at(position) as CropPlant
			if crop != null:
				crop.apply_treatment(int(args.get("result", CropPlant.TREAT_FAILED)))
		"remove":
			var crop := crop_at(position)
			if crop != null:
				crop.queue_free()
		"tree":
			_do_plant_tree(cell, position, int(args.get("index", 0)))


func _do_plant(cell: Vector2i, position: Vector2, crop_id: String, fertilised: bool) -> void:
	if crop_at(position) != null:
		return

	# Set crop_id before add_child: _ready() runs the moment a node enters the
	# tree, and that is where crop_plant.gd reads it to decide what to sow.
	var crop_instance := crop_plant_scene.instantiate() as CropPlant
	crop_instance.name = _crop_name(cell)
	crop_instance.crop_id = crop_id
	crop_instance.global_position = position
	crop_instance.fertilised = fertilised
	_crop_fields().add_child(crop_instance)

	# After add_child, not before: add_child runs the plant's _ready(), so by
	# now its simulation exists and a listener can act on it straight away.
	FarmEvents.crop_planted.emit(crop_instance)


func _do_plant_tree(cell: Vector2i, position: Vector2, index: int) -> void:
	if _tree_at(cell) != null:
		return

	var scene: PackedScene = load(TREE_SCENES[posmod(index, TREE_SCENES.size())])
	var tree := scene.instantiate() as Node2D
	tree.name = _tree_name(cell)
	tree.global_position = position
	# Saplings start at the bottom of the growth cycle and grow up over the days.
	tree.set("initial_growth_state", DataTypes.GrowthStates.Germination)
	get_parent().add_child(tree)
	FarmEvents.tree_planted.emit(tree)
