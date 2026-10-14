class_name FieldCursorComponent
extends Node

@export var grass_tilemap_layer: TileMapLayer
@export var tilled_soil_tilemap_layer: TileMapLayer
@export var terrain_set: int = 0
@export var terrain: int = 1

var player: Player
var mouse_position: Vector2
var cell_position: Vector2i
var cell_source_id: int
var local_cell_position: Vector2
var distance: float


func _ready() -> void:
	await get_tree().process_frame
	player = StageSession.local_player()


func _unhandled_input(event: InputEvent) -> void:
	if ToolManager.selected_tool != DataTypes.Tools.TillGround:
		return

	if event.is_action_pressed('remove_dirt'):
		if get_cell_under_mouse():
			remove_tilled_soil_cell()
	elif event.is_action_pressed('hit'):
		if get_cell_under_mouse():
			add_tilled_soil_cell()


func get_cell_under_mouse() -> bool:
	if player == null or not is_instance_valid(player):
		player = StageSession.local_player()
	if player == null:
		return false

	mouse_position = grass_tilemap_layer.get_local_mouse_position()
	cell_position = grass_tilemap_layer.local_to_map(mouse_position)
	cell_source_id = grass_tilemap_layer.get_cell_source_id(cell_position)
	local_cell_position = grass_tilemap_layer.map_to_local(cell_position)
	distance = player.global_position.distance_to(local_cell_position)
	return true


func add_tilled_soil_cell() -> void:
	if distance < 20 and cell_source_id != -1:
		_send(true, cell_position)


func remove_tilled_soil_cell() -> void:
	if distance < 20:
		_send(false, cell_position)


# --- LAN synchronisation (FR-ENG-006) ---------------------------------------
#
# Tilling edits the shared tilemap, so the host decides and every device
# applies. Singleplayer applies straight away.

func _send(till: bool, cell: Vector2i) -> void:
	if not multiplayer.has_multiplayer_peer():
		_apply_till(till, cell)
	elif multiplayer.is_server():
		_apply_till.rpc(till, cell)
	else:
		_request_till.rpc_id(1, till, cell)


@rpc("any_peer", "call_remote", "reliable")
func _request_till(till: bool, cell: Vector2i) -> void:
	if not multiplayer.is_server():
		return
	if till and grass_tilemap_layer.get_cell_source_id(cell) == -1:
		return
	_apply_till.rpc(till, cell)


@rpc("authority", "call_local", "reliable")
func _apply_till(till: bool, cell: Vector2i) -> void:
	if till:
		tilled_soil_tilemap_layer.set_cells_terrain_connect([cell], terrain_set, terrain, true)
		FarmEvents.soil_tilled.emit(grass_tilemap_layer.map_to_local(cell))
	else:
		tilled_soil_tilemap_layer.set_cells_terrain_connect([cell], 0, -1, true)
