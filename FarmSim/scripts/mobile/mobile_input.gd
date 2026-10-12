class_name MobileInput
extends RefCounted

## Shared state and helpers for the touch controls.
##
## The touch layer (MobileControls) does not replace the game's input code. It
## presses the same actions the keyboard does - walk_left, hit, show_dialogue -
## so the player, the chests, the guide and the market all work unchanged. This
## class holds the few things that have to be shared between the touch layer
## and the two cursor components that decide which tile a tool lands on.

## True once MobileControls has switched the touch layer on.
static var enabled: bool = false

## The tile the held tool will act on, in world coordinates. Set every frame by
## InteractionHighlight and only meaningful while has_target is true.
static var has_target: bool = false
static var target_position: Vector2 = Vector2.ZERO

## The tile in front of the player whether or not a tool is held. The crop info
## panel reads this, so walking up to a plant shows its details without a tool.
static var has_front: bool = false
static var front_position: Vector2 = Vector2.ZERO

## Every "E" prompt currently in the world. An object whose prompt is showing is
## one the player can interact with right now.
static var prompt_labels: Array[Control] = []

## The cursor components of the loaded level. They own the tile layers, so they
## are how the highlight finds the grid.
static var crops_cursor: Node = null
static var field_cursor: Node = null

## Where a pointer that should miss everything is aimed.
const OFF_MAP := Vector2(-100000.0, -100000.0)

## How long a tapped action stays pressed. Long enough for a physics frame to
## see it, short enough that it can never read as a hold.
const TAP_SECONDS := 0.12

static var _removed_hit_events: Array[InputEvent] = []


## Whether the touch layer should be on for this run.
static func should_enable(force: bool) -> bool:
	if force:
		return true
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	if OS.has_feature("web") and DisplayServer.is_touchscreen_available():
		return true
	return OS.get_cmdline_user_args().has("--touch")


static func enable() -> void:
	enabled = true

	# A finger on the screen is also delivered as a left mouse click, and 'hit'
	# is bound to that click. Left in place, every stray tap on the world would
	# swing the tool at whatever tile happened to be under the finger. On a
	# touch build the A button is the only thing that should press 'hit'.
	_removed_hit_events.clear()
	for event: InputEvent in InputMap.action_get_events(&"hit"):
		if event is InputEventMouseButton:
			_removed_hit_events.append(event)
			InputMap.action_erase_event(&"hit", event)


static func disable() -> void:
	enabled = false
	has_target = false
	has_front = false
	for event: InputEvent in _removed_hit_events:
		if not InputMap.action_has_event(&"hit", event):
			InputMap.action_add_event(&"hit", event)
	_removed_hit_events.clear()


## Where the cursor components should treat the pointer as being, in the local
## space of the given tile layer. On a desktop build that is the mouse; on a
## touch build it is the tile the highlight has picked.
static func local_pointer(layer: TileMapLayer) -> Vector2:
	if not enabled:
		return layer.get_local_mouse_position()
	if has_target:
		return layer.to_local(target_position)
	return OFF_MAP


## Presses an action for a moment and lets go. Goes through the input pipeline
## as a real event, so _unhandled_input listeners see it as well as polling.
static func tap(owner: Node, action: StringName) -> void:
	var tree := owner.get_tree()
	_send(action, true)
	# Process-always, so the release still arrives if the game is paused.
	await tree.create_timer(TAP_SECONDS, true, false, true).timeout
	_send(action, false)


static func _send(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


## The layer the tile grid is read from.
static func grid_layer() -> TileMapLayer:
	var soil := soil_layer()
	if soil != null:
		return soil
	return grass_layer()


static func soil_layer() -> TileMapLayer:
	for cursor: Node in [crops_cursor, field_cursor]:
		if cursor != null and is_instance_valid(cursor):
			var layer := cursor.get("tilled_soil_tilemap_layer") as TileMapLayer
			if layer != null:
				return layer
	return null


static func grass_layer() -> TileMapLayer:
	if field_cursor != null and is_instance_valid(field_cursor):
		return field_cursor.get("grass_tilemap_layer") as TileMapLayer
	return null


## Whether there is grass under a world position.
static func grass_at(world_position: Vector2) -> bool:
	var grass := grass_layer()
	if grass == null:
		return false
	var cell := grass.local_to_map(grass.to_local(world_position))
	return grass.get_cell_source_id(cell) != -1


## The on-screen box of an object, in world coordinates. Uses the first sprite
## it finds; falls back to a person-sized box on the object's origin.
static func visual_rect(node: Node2D) -> Rect2:
	for child in node.get_children():
		if child is AnimatedSprite2D:
			var animated := child as AnimatedSprite2D
			var frames := animated.sprite_frames
			if frames != null and frames.has_animation(animated.animation):
				var texture := frames.get_frame_texture(animated.animation, animated.frame)
				if texture != null:
					var size := texture.get_size()
					var top_left := animated.offset - size * 0.5 if animated.centered else animated.offset
					return _world_rect(animated, Rect2(top_left, size))
		elif child is Sprite2D:
			var sprite := child as Sprite2D
			if sprite.texture != null:
				return _world_rect(sprite, sprite.get_rect())
	return Rect2(node.global_position + Vector2(-10.0, -16.0), Vector2(20.0, 20.0))


static func _world_rect(item: Node2D, local_rect: Rect2) -> Rect2:
	var transform := item.global_transform
	var first := transform * local_rect.position
	var second := transform * local_rect.end
	return Rect2(first, Vector2.ZERO).expand(second)
