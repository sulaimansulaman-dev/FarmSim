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

@export var tilled_soil_tilemap_layer: TileMapLayer

var player: Player
var mouse_position: Vector2
var cell_position: Vector2i
var cell_source_id: int
var local_cell_position: Vector2
var distance: float

#@onready var player: Player = get_tree().get_first_node_in_group('player')


func _ready() -> void:
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group('player')


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed('remove_dirt'):
		if ToolManager.selected_tool == DataTypes.Tools.TillGround:
			get_cell_under_mouse()
			remove_crop()
	elif event.is_action_pressed('hit'):
		if TOOL_CROPS.has(ToolManager.selected_tool):
			get_cell_under_mouse()
			add_crop()


func get_cell_under_mouse() -> void:
	mouse_position = tilled_soil_tilemap_layer.get_local_mouse_position()
	cell_position = tilled_soil_tilemap_layer.local_to_map(mouse_position)
	cell_source_id = tilled_soil_tilemap_layer.get_cell_source_id(cell_position)
	local_cell_position = tilled_soil_tilemap_layer.map_to_local(cell_position)
	distance = player.global_position.distance_to(local_cell_position)


func add_crop() -> void:
	if cell_source_id == -1 or distance > 20.0:
		return

	if not TOOL_CROPS.has(ToolManager.selected_tool):
		return

	# One crop per tile. Without this, a second click stacks another plant on
	# the same square invisibly: watering and harvesting then hit both, and the
	# one underneath survives the harvest looking like a seed that will not go.
	if crop_at(local_cell_position) != null:
		return

	# Set crop_id before add_child: _ready() runs the moment a node enters the
	# tree, and that is where crop_plant.gd reads it to decide what to sow.
	var crop_instance := crop_plant_scene.instantiate() as CropPlant
	crop_instance.crop_id = TOOL_CROPS[ToolManager.selected_tool]
	crop_instance.global_position = local_cell_position
	get_parent().find_child('CropFields').add_child(crop_instance)

	# After add_child, not before: add_child runs the plant's _ready(), so by
	# now its simulation exists and a listener can act on it straight away.
	FarmEvents.crop_planted.emit(crop_instance)


func remove_crop() -> void:
	if distance > 20:
		return

	var crop := crop_at(local_cell_position)
	if crop != null:
		crop.queue_free()


## The crop standing on a tile, or null if it is free.
##
## Crops queued for deletion do not count: harvesting frees the plant but the
## node lingers until the end of the frame, and a tile you just cleared should
## be plantable straight away.
func crop_at(position: Vector2) -> Node2D:
	for node: Node2D in get_parent().find_child('CropFields').get_children():
		if node.is_queued_for_deletion():
			continue
		if node.global_position == position:
			return node
	return null
