extends PanelContainer

## The crop under the mouse, in words and numbers (FR-003, FR-004, FR-005).
##
## The icon on the plant answers "does this want something?" at a glance. This
## answers "why, and what is it costing me?" for one crop at a time.
##
## Built in code rather than as a .tscn, for the same reason inventory_panel.gd
## builds its crop slots in code: what goes in it is driven by crops.json, and a
## scene file would freeze a layout the data is allowed to change.

## How near the mouse must be to a crop, in world pixels, to inspect it.
## Tiles are 16 across, so this is half a tile.
const HOVER_RADIUS := 8.0
const BAR_SIZE := Vector2(96, 6)

const COLOUR_GOOD := Color("6ab04c")
const COLOUR_WARN := Color("f0932b")
const COLOUR_BAD := Color("eb4d4b")
const COLOUR_WATER := Color("5fa8d3")

var _name_label: Label
var _stage_label: Label
var _health_bar: ProgressBar
var _moisture_bar: ProgressBar
var _yield_label: Label
var _note_label: Label

## Kept as fields rather than rebuilt each frame - _refresh() runs every frame
## and only ever changes the colour.
var _health_fill := StyleBoxFlat.new()
var _moisture_fill := StyleBoxFlat.new()


func _ready() -> void:
	visible = false

	# Never swallow a click meant for a crop underneath. This is the same trap
	# that made walking change the game speed: UI that quietly eats input.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	add_child(margin)

	var rows := VBoxContainer.new()
	margin.add_child(rows)

	_name_label = _new_label(rows)
	_stage_label = _new_label(rows)
	_health_bar = _new_bar(rows, "Health", _health_fill)
	_moisture_bar = _new_bar(rows, "Water", _moisture_fill)
	_yield_label = _new_label(rows)

	_note_label = _new_label(rows)
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_label.custom_minimum_size.x = 190


func _process(_delta: float) -> void:
	var plant := _crop_under_mouse()
	visible = plant != null
	if plant != null:
		_refresh(plant.crop_sim.crop)


## The nearest crop to the mouse, or null.
##
## get_mouse_position() is in screen pixels; crops live in world coordinates and
## the camera moves between the two. The canvas transform is what converts.
func _crop_under_mouse() -> CropPlant:
	var world_mouse: Vector2 = (
		get_viewport().get_canvas_transform().affine_inverse()
		* get_viewport().get_mouse_position()
	)

	var closest: CropPlant = null
	var closest_distance := HOVER_RADIUS
	for plant: CropPlant in get_tree().get_nodes_in_group("crop_plant"):
		var distance := plant.global_position.distance_to(world_mouse)
		if distance < closest_distance:
			closest_distance = distance
			closest = plant
	return closest


func _refresh(crop: Crop) -> void:
	_name_label.text = crop.display_name

	if crop.state == Crop.State.DEAD:
		_stage_label.text = "Died on day %d" % crop.day
	elif crop.is_ready_to_harvest():
		_stage_label.text = "Ready to harvest, day %d" % crop.day
	else:
		_stage_label.text = "%s, day %d of %d" % [
			crop.current_stage_name(), crop.day,
			CropManager.library.days_to_maturity(crop.crop_id)
		]

	_health_fill.bg_color = _health_colour(crop.health)
	_health_bar.value = crop.health

	_moisture_fill.bg_color = COLOUR_BAD if crop.is_thirsty() else COLOUR_WATER
	_moisture_bar.value = clampf(crop.moisture, 0.0, 1.0) * 100.0

	_yield_label.text = "About %.0f kg if harvested now" % crop.projected_yield_kg()
	_note_label.text = str(crop.current_stage().get("teaching_note", ""))


func _health_colour(health: float) -> Color:
	if health >= 70.0:
		return COLOUR_GOOD
	if health >= 35.0:
		return COLOUR_WARN
	return COLOUR_BAD


func _new_label(parent: Node) -> Label:
	var label := Label.new()
	parent.add_child(label)
	return label


func _new_bar(parent: Node, caption: String, fill: StyleBoxFlat) -> ProgressBar:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 56
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = BAR_SIZE
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	return bar
