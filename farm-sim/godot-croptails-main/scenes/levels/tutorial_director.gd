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

## The order is the player's order, not the farm's. Marlow has already turned
## over a patch, so a beginner sows into it and sees a whole crop through before
## being taught to make ground of their own. Digging is the last lesson, not the
## first, and it doubles as the second use of a tool they have already held.
enum Step { BEFORE_MARLOW, SOW, WATER, THIRSTY, HARVEST, COLLECT, DIG, DONE }

const LINES := {
	Step.SOW: "Marlow: I have already turned over a patch of soil for you. Take the cabbage seeds and click one of the dug squares.",
	Step.WATER: "Marlow: Good. Now take the watering can and click the seedling. Soil that dries out costs you weight at harvest.",
	Step.THIRSTY: "Marlow: Let it grow now. A blue mark above it means the soil has dried out - water it again when you see one.\n(The clock buttons at the top right make the days pass faster.)",
	Step.HARVEST: "Marlow: A gold star bobbing above it means the cabbage is ripe. Take the hoe - the same tool brings a crop in - and swing it at the plant.",
	Step.COLLECT: "Marlow: It is lying where it fell. Walk over it to pick it up.",
	Step.DIG: "Marlow: There it is, counted in the panel on the left. That is yours now.\nAnd the hoe does one more thing: swing it at bare grass and you open new ground. Go on - make your patch bigger.",
	Step.DONE: "Marlow: That is the whole of it - sow, water, harvest, and dig when you want more room. The seeds are yours, and from here a crop takes the days it really takes.",
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

var _step: Step = Step.BEFORE_MARLOW
var _plant: CropPlant = null

var _panel: PanelContainer
var _label: Label


func _ready() -> void:
	_build_banner()

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
	if _step == Step.HARVEST:
		_enter(Step.COLLECT)


## Cutting a crop does not feed you - the produce drops where it stood and has
## to be walked over. Waiting on the inventory rather than on the harvest is
## what makes the player find that out.
func _on_inventory_changed(_inventory: Dictionary) -> void:
	if _step == Step.COLLECT:
		_enter(Step.DIG)


func _on_tutorial_crop_died() -> void:
	if _step == Step.BEFORE_MARLOW or _step == Step.DONE:
		return

	_plant = null
	_step = Step.SOW
	_say(DIED_LINE)


func _enter(step: Step) -> void:
	_step = step
	_say(str(LINES.get(step, "")))

	if UNLOCKS.has(step):
		ToolManager.enable_tool(UNLOCKS[step])

	if step == Step.DONE:
		get_tree().create_timer(CLOSING_SECONDS).timeout.connect(_clear)


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
