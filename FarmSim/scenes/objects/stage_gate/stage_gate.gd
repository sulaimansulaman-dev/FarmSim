class_name StageGate
extends Node2D

## The bridge off the island, and the keeper who guards it.
##
## Stays shut until StageSession says every goal is done (the first star).
## Then the barrier lifts, the player walks out over the water, and the keeper
## at the far end starts the quiz battle. Passing it moves everyone to the next
## stage.
##
## Every stage is the same island, so the gate finds its own spot: it walks
## along `gate_row` to the easternmost grass tile and builds the bridge out from
## there. Move the gate to another row in the Inspector and it follows the
## coastline without any tile coordinates being typed in.
##
## The island had no shoreline collision, so a player could simply walk out
## across the sea and around any barrier. The gate also puts a collision edge on
## every water tile that touches the coast, leaving a gap only where the bridge
## is.

const QUIZ_SCENE := preload("res://scenes/ui/quiz_battle.tscn")
const BRIDGE_SHEET := preload("res://assets/game/objects/wood_bridge.png")
const UI_THEME := preload("res://scenes/ui/game_ui_theme.tres")

const TILE := 16
const WATER_COLOUR := Color("9bd4c3")

## wood_bridge.png: the long horizontal bridge is 43px wide. Its left post, a
## middle stretch of planks and its right post are cut out and tiled.
const PLANK_START := Rect2(34, 0, 16, 16)
const PLANK_MIDDLE := Rect2(46, 0, 16, 16)
const PLANK_END := Rect2(61, 0, 16, 16)
## The vertical bridge, used side by side for the landing the keeper stands on.
const DOCK_COLUMN := Rect2(0, 2, 16, 43)

## Which row of the island the bridge leaves from.
@export var gate_row: int = 12
## Tiles of bridge between the coast and the landing.
@export var bridge_length: int = 6
## The landing is this many tiles square.
@export var dock_size: int = 3

@onready var floor_root: Node2D = $Floor
@onready var boundary: StaticBody2D = $Boundary
@onready var barrier: StaticBody2D = $Barrier
@onready var barrier_shape: CollisionShape2D = $Barrier/CollisionShape2D
@onready var barrier_sprite: Sprite2D = $Barrier/Sprite2D
@onready var keeper: Node2D = $Keeper
@onready var keeper_trigger: Area2D = $KeeperTrigger
@onready var sign_label: Label = $SignLabel

var _start_cell := Vector2i.ZERO
var _footprint: Dictionary = {}
var _quiz_open := false


func _ready() -> void:
	if not _place_on_coast():
		push_warning("StageGate: no grass found on row %d, bridge not built." % gate_row)
		return

	_build_floor()
	_build_shoreline()

	keeper.position = Vector2((bridge_length + floori(dock_size / 2.0)) * TILE, 0)
	keeper_trigger.position = keeper.position + Vector2(-TILE, 0)
	keeper_trigger.body_entered.connect(_on_keeper_trigger_entered)

	# World labels pick up the game's pixel font rather than Godot's default.
	sign_label.theme = UI_THEME
	var name_label := keeper.get_node_or_null("NameLabel") as Label
	if name_label != null:
		name_label.theme = UI_THEME
		name_label.text = str(StageSession.definition(SceneManager.current_level).get("keeper", {}).get("name", "Keeper"))

	StageSession.bridge_opened.connect(_open)
	StageSession.session_started.connect(func(_id): _refresh())
	_refresh()


# --- building ---------------------------------------------------------------

## Finds the easternmost grass tile on the gate's row and sits just past it.
func _place_on_coast() -> bool:
	var grass := get_parent().get_node_or_null("GameTilemap/Grass") as TileMapLayer
	if grass == null:
		return false

	var east_edge := -1000000
	for cell: Vector2i in grass.get_used_cells():
		if cell.y == gate_row and cell.x > east_edge:
			east_edge = cell.x
	if east_edge == -1000000:
		return false

	_start_cell = Vector2i(east_edge + 1, gate_row)
	global_position = grass.to_global(grass.map_to_local(_start_cell))

	for i in bridge_length:
		_footprint[_start_cell + Vector2i(i, 0)] = true
	var half := floori(dock_size / 2.0)
	for dx in dock_size:
		for dy in range(-half, dock_size - half):
			_footprint[_start_cell + Vector2i(bridge_length + dx, dy)] = true
	return true


func _build_floor() -> void:
	# The floor draws beneath the tilemap so players walk on top of it, which
	# means the sea tiles under the bridge have to go or they would cover it.
	var water := get_parent().get_node_or_null("GameTilemap/Water") as TileMapLayer
	if water != null:
		for cell: Vector2i in _footprint:
			water.erase_cell(cell)

	# Water-coloured backing, so the gaps between planks read as sea rather than
	# the empty background where the bridge sits over nothing.
	for cell: Vector2i in _footprint:
		var backing := ColorRect.new()
		backing.color = WATER_COLOUR
		backing.size = Vector2(TILE, TILE)
		backing.position = _cell_to_local(cell) - Vector2(TILE, TILE) * 0.5
		backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		floor_root.add_child(backing)

	for i in bridge_length:
		var region := PLANK_MIDDLE
		if i == 0:
			region = PLANK_START
		elif i == bridge_length - 1:
			region = PLANK_END
		_add_piece(region, Vector2(i * TILE, 0))

	for dx in dock_size:
		_add_piece(DOCK_COLUMN, Vector2((bridge_length + dx) * TILE, 0))


func _add_piece(region: Rect2, local_position: Vector2) -> void:
	var piece := Sprite2D.new()
	var texture := AtlasTexture.new()
	texture.atlas = BRIDGE_SHEET
	texture.region = region
	piece.texture = texture
	piece.position = local_position
	floor_root.add_child(piece)


## Collision along the coast: one square on every water tile next to grass,
## except where the bridge is.
func _build_shoreline() -> void:
	var grass := get_parent().get_node_or_null("GameTilemap/Grass") as TileMapLayer
	if grass == null:
		return

	var land: Dictionary = {}
	for cell: Vector2i in grass.get_used_cells():
		land[cell] = true
	for cell in _footprint:
		land[cell] = true

	var edge: Dictionary = {}
	for cell: Vector2i in land:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var neighbour := cell + Vector2i(dx, dy)
				if not land.has(neighbour):
					edge[neighbour] = true

	for cell: Vector2i in edge:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(TILE, TILE)
		shape.shape = rect
		shape.position = _cell_to_local(cell)
		boundary.add_child(shape)


func _cell_to_local(cell: Vector2i) -> Vector2:
	return Vector2(cell - _start_cell) * TILE


# --- state ------------------------------------------------------------------

func _refresh() -> void:
	if StageSession.bridge_open:
		_open()
	else:
		barrier_shape.set_deferred("disabled", false)
		barrier_sprite.visible = true
		sign_label.text = "Bridge closed\nFinish your goals"


func _open() -> void:
	barrier_shape.set_deferred("disabled", true)
	barrier_sprite.visible = false
	sign_label.text = "Bridge open!"


func _on_keeper_trigger_entered(body: Node2D) -> void:
	if _quiz_open or not (body is Player):
		return
	if body != StageSession.local_player():
		return
	if StageSession.quiz_passed:
		return
	if not StageSession.bridge_open:
		FarmEvents.advisory.emit("The keeper will not see you until every goal is done.")
		return

	_quiz_open = true
	var quiz := QUIZ_SCENE.instantiate()
	quiz.name = "QuizBattle"
	quiz.keeper_texture_source = keeper.get_node("AnimatedSprite2D")
	quiz.closed.connect(_on_quiz_closed.bind(body))
	get_tree().root.add_child(quiz)


## The quiz closed without a pass (the player ran out of hearts and stepped
## away). Walk them back off the landing so stepping forward again re-opens it.
func _on_quiz_closed(passed: bool, player: Player) -> void:
	_quiz_open = false
	if passed or not is_instance_valid(player):
		return
	player.global_position = keeper_trigger.global_position + Vector2(-TILE * 2, 0)
