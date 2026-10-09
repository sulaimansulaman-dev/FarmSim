extends CanvasLayer

## Marlow coaching a first-time player through one whole crop cycle.
##
## Island 1 is the tutorial, and a tutorial that only talks is a slideshow. This
## walks the player through the loop by hand: it unlocks one tool at a time, so
## the wrong action is not merely discouraged but impossible, and it waits on
## FarmEvents for proof the player did the thing before it moves on.
##
## Marlow himself does not move. Making him follow would need pathfinding and a
## walk state on a character that has never taken a step; the banner speaks in
## his voice instead, which reads as coaching at a fraction of the cost.

const UI_THEME := preload("res://scenes/ui/game_ui_theme.tres")
const UI_SHEET := preload("res://assets/ui/basic_ui_sprites.png")

## The tutorial crop's private weather, applied to the one plant sown here.
##
## crops.json keeps the real agronomy untouched. These only bend this single
## plant's clock, so a beginner meets thirst and ripeness within a couple of
## game-days instead of the ten that cabbage honestly takes. Measured: thirsty
## on day 1, ripe on day 2.
const TUTORIAL_EVAPORATION := 6.0
const TUTORIAL_GROWTH := 10.0

## How long Marlow's closing line stays up before the banner clears.
const CLOSING_SECONDS := 12.0

## The arrow. The sheet only carries a triangle pointing right - the one the
## clock buttons use - so it gets a quarter turn to aim downward.
const ARROW_REGION := Rect2(261, 2, 7, 12)
const ARROW_TINT := Color("f2c94c")
const ARROW_BOB := 3.0
const ARROW_BOB_SECONDS := 0.6

## Gap between the arrow and what it points at. The screen figure is in pixels;
## the world figure is applied before the camera transform, so it keeps the same
## apparent distance whatever the camera zoom is doing.
const ARROW_SCREEN_GAP := 14.0
const ARROW_WORLD_GAP := 34.0

## A safety net, not the intended path. Space moves this beat on; the timer is
## only there so a player who presses nothing is never stuck.
const COUNTED_SECONDS := 15.0

## The order is the player's order, not the farm's. Marlow has already turned
## over a patch, so a beginner sows into it and sees a whole crop through before
## being taught to make ground of their own. Digging is the last lesson, not the
## first, and it doubles as the second use of a tool they have already held.
enum Step { BEFORE_MARLOW, SOW, WATER, THIRSTY, HARVEST, COLLECT, COUNTED, DIG, DONE }

const LINES := {
	Step.SOW: "Marlow: I have already turned over a patch of soil for you. Take the cabbage seeds and click one of the dug squares.",
	Step.WATER: "Marlow: Good. Now take the watering can and click the seedling. Soil that dries out costs you weight at harvest.",
	Step.THIRSTY: "Marlow: Let it grow now. A blue mark above it means the soil has dried out - water it again when you see one.\n(The clock buttons at the top right make the days pass faster.)",
	Step.HARVEST: "Marlow: A gold star bobbing above it means the cabbage is ripe. Take the hoe - the same tool brings a crop in - and swing it at the plant.",
	Step.COLLECT: "Marlow: It is lying where it fell. Walk over it to pick it up.",
	Step.COUNTED: "Marlow: And there it is - your cabbage, counted in the panel on the left. That is what the work was for.\n(Press Space when you are ready.)",
	Step.DIG: "Marlow: One thing left. That hoe does more than bring a crop in - swing it at bare grass and you open new ground.\nTake the hoe, walk to the square I am pointing at, and dig it.",
	Step.DONE: "Marlow: There you go - new ground, made by you. Hold Ctrl and click if you ever want to close ground again.\nI will put the field back the way I left it, and then the farm is yours. From here a crop takes the days it really takes.",
}

const DIED_LINE := "Marlow: That one dried out and died. It happens. Dig another bed and sow again - and this time water it when the blue mark shows."

## Which tool arrives as each step begins. One at a time, so the toolbar itself
## is the instruction and there is nothing else to click.
const UNLOCKS := {
	Step.SOW: DataTypes.Tools.PlantTomato,
	Step.WATER: DataTypes.Tools.WaterCrops,
	Step.HARVEST: DataTypes.Tools.TillGround,
	Step.DONE: DataTypes.Tools.PlantCorn,
}

## The tool a step needs *in hand*, as opposed to UNLOCKS, which is the tool
## that arrives. They differ: the hoe arrives for the harvest and is then wanted
## again for digging, and the watering can is wanted twice.
const STEP_TOOL := {
	Step.SOW: DataTypes.Tools.PlantTomato,
	Step.WATER: DataTypes.Tools.WaterCrops,
	Step.THIRSTY: DataTypes.Tools.WaterCrops,
	Step.HARVEST: DataTypes.Tools.TillGround,
	Step.DIG: DataTypes.Tools.TillGround,
}

## Set in island_1.tscn. Used only to find the middle of the patch Marlow dug,
## so the arrow can send the player to the right corner of the island.
@export var tilled_soil: TileMapLayer

## Also set in island_1.tscn. Needed to find a square of bare grass beside the
## patch, which is what the arrow points at for the digging lesson.
@export var grass: TileMapLayer

var _step: Step = Step.BEFORE_MARLOW
var _plant: CropPlant = null

var _panel: PanelContainer
var _label: Label
var _arrow: Sprite2D
var _tools_panel: Node = null
var _inventory_panel: Control = null

## Where the produce fell, noted at the moment of harvest because the plant
## frees itself immediately afterwards.
## The field exactly as the level was authored, taken before the player has
## touched anything, and put back when the tutorial ends.
var _soil_snapshot: PackedByteArray

var _fallen_at := Vector2.INF
## The square chosen for the digging lesson. Picked once and kept, so the arrow
## does not wander to a different square while the player walks over to it.
var _dig_target := Vector2.INF


func _ready() -> void:
	_build_banner()
	_build_arrow()

	if tilled_soil != null:
		_soil_snapshot = tilled_soil.tile_map_data.duplicate()

	GameDialogueManager.gave_crop_seeds.connect(_on_marlow_gave_seeds)
	FarmEvents.soil_tilled.connect(_on_soil_tilled)
	FarmEvents.crop_planted.connect(_on_crop_planted)
	FarmEvents.crop_watered.connect(_on_crop_watered)
	FarmEvents.crop_harvested.connect(_on_crop_harvested)
	InventoryManager.inventory_changed.connect(_on_inventory_changed)


# --- the steps --------------------------------------------------------------

func _on_marlow_gave_seeds() -> void:
	if _step == Step.BEFORE_MARLOW:
		_enter(Step.SOW)


func _on_soil_tilled(_position: Vector2) -> void:
	if _step == Step.DIG:
		_enter(Step.DONE)


func _on_crop_planted(plant: CropPlant) -> void:
	if _step != Step.SOW:
		return

	_plant = plant
	# Dry this one plant out fast, so thirst arrives within a game-day and the
	# blue mark becomes something the player actually witnesses.
	plant.crop_sim.evaporation_multiplier = TUTORIAL_EVAPORATION

	# A tutorial that dead-ends is worse than a hard one. If this plant dies of
	# thirst there is no harvest to wait for, so the sequence rewinds instead.
	plant.crop_sim.crop.died.connect(_on_tutorial_crop_died)

	_enter(Step.WATER)


func _on_crop_watered(plant: CropPlant) -> void:
	# Only the plant this tutorial is about. Anything the player sows on the
	# side runs at the game's real pace.
	if plant != _plant:
		return

	if _step == Step.WATER:
		_enter(Step.THIRSTY)
	elif _step == Step.THIRSTY:
		# The lesson landed. Hand the crop its normal weather back and let it run.
		plant.crop_sim.evaporation_multiplier = 1.0
		plant.crop_sim.growth_multiplier = TUTORIAL_GROWTH
		_enter(Step.HARVEST)


func _on_crop_harvested(_crop_id: String, _yield_kg: float) -> void:
	if _step != Step.HARVEST:
		return

	# The plant is still alive at this instant - it frees itself on the next
	# line of its own handler - so this is the last chance to note where the
	# produce is about to land.
	if _plant != null and is_instance_valid(_plant):
		_fallen_at = _plant.global_position

	_enter(Step.COLLECT)


## Cutting a crop does not feed you - the produce drops where it stood and has
## to be walked over. Waiting on the inventory rather than on the harvest is
## what makes the player find that out.
func _on_inventory_changed(_inventory: Dictionary) -> void:
	if _step == Step.COLLECT:
		_enter(Step.COUNTED)


func _on_tutorial_crop_died() -> void:
	if _step == Step.BEFORE_MARLOW or _step == Step.DONE:
		return

	_plant = null
	_step = Step.SOW
	_say(DIED_LINE)


## Space moves the tutorial on from the one step the world cannot finish.
##
## Only COUNTED listens. Every other step is gated on the player actually doing
## something, and letting a keypress skip those would defeat the whole point.
func _unhandled_input(event: InputEvent) -> void:
	if _step != Step.COUNTED:
		return

	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_leave_counted()


## Ends the "look at your cabbage" pause. Guarded, because a crop dying during
## it would have rewound the tutorial already.
func _leave_counted() -> void:
	if _step == Step.COUNTED:
		_enter(Step.DIG)


func _enter(step: Step) -> void:
	_step = step
	_say(str(LINES.get(step, "")))

	if UNLOCKS.has(step):
		ToolManager.enable_tool(UNLOCKS[step])

	if step == Step.COUNTED:
		# The only step nothing in the world can finish - the player has already
		# done the thing, and this beat exists so they see where it went.
		get_tree().create_timer(COUNTED_SECONDS).timeout.connect(_leave_counted)

	if step == Step.DONE:
		_restore_field()
		get_tree().create_timer(CLOSING_SECONDS).timeout.connect(_clear)


## Puts the field back the way Marlow left it.
##
## Digging is the last lesson, so the player ends the tutorial standing over
## ground they opened themselves - and it goes again a moment later. That is
## deliberate, not tidiness: every player then begins the island proper from
## the same field, which is what makes one play session comparable with the
## next. Marlow says it out loud, or it reads as the game eating your work.
func _restore_field() -> void:
	if tilled_soil == null:
		return

	tilled_soil.tile_map_data = _soil_snapshot

	# Anything sown on ground that has just gone back to grass has nowhere left
	# to stand. Crops inside the original patch are not touched.
	var fields := get_parent().find_child("CropFields")
	if fields == null:
		return

	for crop: Node2D in fields.get_children():
		var cell := tilled_soil.local_to_map(tilled_soil.to_local(crop.global_position))
		if tilled_soil.get_cell_source_id(cell) == -1:
			crop.queue_free()


# --- the banner -------------------------------------------------------------

func _say(text: String) -> void:
	_label.text = text
	_panel.visible = not text.is_empty()


func _clear() -> void:
	_panel.visible = false


func _build_banner() -> void:
	var anchor := MarginContainer.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anchor.add_theme_constant_override("margin_top", 8)
	anchor.theme = UI_THEME
	# Nothing in this banner may ever eat a click meant for the field beneath
	# it - the same trap that made walking change the game speed.
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
	
	# --- the arrow --------------------------------------------------------------

func _process(_delta: float) -> void:
	var target := _arrow_target()
	_arrow.visible = target != Vector2.INF
	if not _arrow.visible:
		return

	var phase := fmod(Time.get_ticks_msec() / 1000.0, ARROW_BOB_SECONDS) / ARROW_BOB_SECONDS
	_arrow.position = target + Vector2(0.0, sin(phase * TAU) * ARROW_BOB)


## Where the arrow belongs this frame, in screen pixels, or INF for nowhere.
##
## Three questions in order. Is Marlow currently talking about the inventory?
## Is there a tool the player has not picked up yet - then point at the button,
## which is the "show me where to choose it" half. Otherwise, where in the world
## is the thing they should be clicking.
func _arrow_target() -> Vector2:
	var wanted: int = STEP_TOOL.get(_step, DataTypes.Tools.None)
	if wanted != DataTypes.Tools.None and ToolManager.selected_tool != wanted:
		return _above_control(_hud_tool_button(wanted))

	match _step:
		Step.SOW:
			return _above_world(_patch_centre())
		Step.WATER, Step.THIRSTY, Step.HARVEST:
			if _plant != null and is_instance_valid(_plant):
				return _above_world(_plant.global_position)
		Step.COLLECT:
			return _above_world(_fallen_at)
		Step.COUNTED:
			return _above_control(_hud_inventory())
		Step.DIG:
			return _above_world(_bare_grass_beside_patch())

	return Vector2.INF


func _above_control(control: Control) -> Vector2:
	if control == null or not is_instance_valid(control) or not control.is_visible_in_tree():
		return Vector2.INF

	var rect := control.get_global_rect()
	return Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y - ARROW_SCREEN_GAP)


## World coordinates to screen pixels. The canvas transform is the camera, and
## the offset goes in before it so the gap does not change with zoom.
func _above_world(world: Vector2) -> Vector2:
	if world == Vector2.INF:
		return Vector2.INF
	return get_viewport().get_canvas_transform() * (world + Vector2(0.0, -ARROW_WORLD_GAP))


## A square of bare grass next to the dug patch, for the digging lesson.
##
## One ring around the patch, and the first square that is grass and has not
## already been turned over wins. Remembered once: an arrow that jumps to a
## different square as the player walks is worse than no arrow.
func _bare_grass_beside_patch() -> Vector2:
	if _dig_target != Vector2.INF:
		return _dig_target
	if tilled_soil == null or grass == null:
		return Vector2.INF

	var rect := tilled_soil.get_used_rect()
	if rect.size == Vector2i.ZERO:
		return Vector2.INF

	for y in range(rect.position.y - 1, rect.end.y + 1):
		for x in range(rect.position.x - 1, rect.end.x + 1):
			var cell := Vector2i(x, y)
			if tilled_soil.get_cell_source_id(cell) != -1:
				continue
			if grass.get_cell_source_id(cell) == -1:
				continue
			_dig_target = grass.to_global(grass.map_to_local(cell))
			return _dig_target

	return Vector2.INF


## The middle of the dug patch. Good enough - the player only needs telling
## which part of the island to walk to, not which square.
func _patch_centre() -> Vector2:
	if tilled_soil == null:
		return Vector2.INF

	var cells := tilled_soil.get_used_cells()
	if cells.is_empty():
		return Vector2.INF

	var total := Vector2.ZERO
	for cell: Vector2i in cells:
		total += tilled_soil.map_to_local(cell)
	return tilled_soil.to_global(total / float(cells.size()))


# The HUD lives in main_scene, not in this level, so these are looked up by name
# once and cached. Nothing here owns them and nothing here may keep them alive.

func _hud_tool_button(tool: DataTypes.Tools) -> Control:
	if _tools_panel == null or not is_instance_valid(_tools_panel):
		_tools_panel = get_tree().root.find_child("ToolsPanel", true, false)
	if _tools_panel == null:
		return null
	return _tools_panel.button_for(tool)


func _hud_inventory() -> Control:
	if _inventory_panel == null or not is_instance_valid(_inventory_panel):
		_inventory_panel = get_tree().root.find_child("InventoryPanel", true, false) as Control
	return _inventory_panel


func _build_arrow() -> void:
	_arrow = Sprite2D.new()
	_arrow.texture = UI_SHEET
	_arrow.region_enabled = true
	_arrow.region_rect = ARROW_REGION
	_arrow.rotation = PI / 2.0
	_arrow.modulate = ARROW_TINT
	_arrow.visible = false
	add_child(_arrow)
