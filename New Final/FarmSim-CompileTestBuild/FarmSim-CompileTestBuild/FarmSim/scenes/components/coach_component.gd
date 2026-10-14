class_name CoachComponent
extends CanvasLayer

## A banner in the guide's voice, and an arrow that points at things.
##
## Lifted out of the Island 1 tutorial so every island after it can coach the
## player without copying the interface. Subclass it and drive say() and the
## point_at_* methods from whatever that island has to teach.
##
## The tutorial director still carries its own copy of all this. Moving it onto
## this component is a follow-up, deliberately not done in the week the tutorial
## is being demonstrated.

const UI_THEME := preload("res://scenes/ui/game_ui_theme.tres")
const UI_SHEET := preload("res://assets/ui/basic_ui_sprites.png")

## The sheet only carries a triangle pointing right - the one the clock buttons
## use - so it gets a quarter turn to aim downward.
const ARROW_REGION := Rect2(261, 2, 7, 12)
const ARROW_TINT := Color("f2c94c")
const ARROW_BOB := 3.0
const ARROW_BOB_SECONDS := 0.6

## The screen figure is in pixels; the world figure is applied before the camera
## transform, so it keeps its apparent size whatever the zoom is doing.
const ARROW_SCREEN_GAP := 14.0
const ARROW_WORLD_GAP := 34.0

var _panel: PanelContainer
var _label: Label
var _arrow: Sprite2D

var _target_control: Control = null
var _target_world := Vector2.INF


func _ready() -> void:
	_build()


## Puts a line in the banner. An empty string hides it.
func say(text: String) -> void:
	_label.text = text
	_panel.visible = not text.is_empty()


func clear() -> void:
	_panel.visible = false


## Points the arrow at something in the HUD - a tool button, a panel.
func point_at_control(control: Control) -> void:
	_target_control = control
	_target_world = Vector2.INF


## Points the arrow at a spot in the world.
func point_at_world(position: Vector2) -> void:
	_target_control = null
	_target_world = position


func stop_pointing() -> void:
	_target_control = null
	_target_world = Vector2.INF


## Finds a piece of the interface by name. The HUD lives in main_scene, not in
## the level, so a coach sitting in a level cannot reach it by path.
func hud_node(node_name: String) -> Node:
	return get_tree().root.find_child(node_name, true, false)


func _process(_delta: float) -> void:
	var target := _arrow_target()
	_arrow.visible = target != Vector2.INF
	if not _arrow.visible:
		return

	var phase := fmod(Time.get_ticks_msec() / 1000.0, ARROW_BOB_SECONDS) / ARROW_BOB_SECONDS
	_arrow.position = target + Vector2(0.0, sin(phase * TAU) * ARROW_BOB)


func _arrow_target() -> Vector2:
	if _target_control != null and is_instance_valid(_target_control) and _target_control.is_visible_in_tree():
		var rect := _target_control.get_global_rect()
		return Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y - ARROW_SCREEN_GAP)

	if _target_world != Vector2.INF:
		return get_viewport().get_canvas_transform() * (_target_world + Vector2(0.0, -ARROW_WORLD_GAP))

	return Vector2.INF


func _build() -> void:
	var anchor := MarginContainer.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anchor.add_theme_constant_override("margin_top", 8)
	anchor.theme = UI_THEME
	# Nothing here may ever eat a click meant for the field beneath it.
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)

	_panel = PanelContainer.new()
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	anchor.add_child(_panel)

	var pad := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 6)
	_panel.add_child(pad)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = 280
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(_label)

	_arrow = Sprite2D.new()
	_arrow.texture = UI_SHEET
	_arrow.region_enabled = true
	_arrow.region_rect = ARROW_REGION
	_arrow.rotation = PI / 2.0
	_arrow.modulate = ARROW_TINT
	_arrow.visible = false
	add_child(_arrow)
