extends Control
class_name BridgePointerControl

## NodePath pointing to the target StageGate or its Sprite2D node
@export var target_node_path: NodePath = NodePath("")
var target_node: Node2D:
	get:
		return _target_node
	set(value):
		_target_node = value

## Texture orientation correction offset (e.g., 0, 90, 180, or -90 depending on original PNG art direction)
@export var sprite_rotation_offset_deg: float = 0.0

## Padding in pixels from the viewport edges when off-screen
@export var screen_margin: float = 24.0

## Hide the pointer when the player is close enough to the target
@export var hide_distance_threshold: float = 80.0

var _target_node: Node2D = null

func _ready() -> void:
	# Resolve target node if path is valid
	if not target_node_path.is_empty():
		_target_node = get_node_or_null(target_node_path) as Node2D
	
	# Fallback: attempt to find a StageGate automatically if unassigned
	if _target_node == null:
		var gate = get_tree().get_first_node_in_group("stage_gate")
		if gate is Node2D:
			_target_node = gate

func _process(_delta: float) -> void:
	if _target_node == null or not _target_node.is_inside_tree():
		visible = false
		return

	# 1. Get viewport and canvas transform
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
		
	var canvas_transform: Transform2D = viewport.get_canvas_transform()
	var viewport_rect: Rect2 = viewport.get_visible_rect()
	
	# 2. Convert target world position into screen-space coordinates
	var target_world_pos: Vector2 = _target_node.global_position
	var target_screen_pos: Vector2 = canvas_transform * target_world_pos
	
	# 3. Define clamped screen boundary inset by screen_margin
	var boundary: Rect2 = viewport_rect.grow(-screen_margin)
	
	# Check if the target is currently within visible viewport bounds
	var is_on_screen: bool = boundary.has_point(target_screen_pos)
	
	# 4. Clamp pointer position along screen edges if off-screen
	var clamped_screen_pos: Vector2 = Vector2(
		clamp(target_screen_pos.x, boundary.position.x, boundary.end.x),
		clamp(target_screen_pos.y, boundary.position.y, boundary.end.y)
	)

	global_position = clamped_screen_pos
	
	# 5. Point arrow towards the target screen position
	var angle_to_target: float = global_position.angle_to_point(target_screen_pos)
	rotation = angle_to_target + deg_to_rad(sprite_rotation_offset_deg)
	
	# 6. Toggle visibility based on distance / offscreen state
	var distance_to_target: float = global_position.distance_to(target_screen_pos)
	if is_on_screen and distance_to_target < hide_distance_threshold:
		visible = false
	else:
		visible = true

## Setter to update the target dynamically from another script (e.g., SceneManager)
func set_target(new_target: Node2D) -> void:
	_target_node = new_target
