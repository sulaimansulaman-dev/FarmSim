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

	# Set crop_id before add_child: _ready() runs the moment a node enters the
	# tree, and that is where crop_plant.gd reads it to decide what to sow.
	var crop_instance := crop_plant_scene.instantiate() as Node2D
	crop_instance.crop_id = TOOL_CROPS[ToolManager.selected_tool]
	crop_instance.global_position = local_cell_position
	get_parent().find_child('CropFields').add_child(crop_instance)


func remove_crop() -> void:
	if distance > 20:
		return

	var crop_nodes := get_parent().find_child('CropFields').get_children()
	for node: Node2D in crop_nodes:
		if node.global_position == local_cell_position:
			node.queue_free()
