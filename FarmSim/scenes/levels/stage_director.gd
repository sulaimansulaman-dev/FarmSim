extends CanvasLayer

## What one stage switches on, and what it tells the player.
##
## The stage-by-stage spec builds the game up in layers: Stage 1 is the bare
## crop lifecycle, and each stage after it adds exactly one system. That only
## teaches anything if the earlier stages genuinely do not have the later ones -
## a Stage 1 island with a market stall on it is not Stage 1.
##
## So this node is the switch. It is the only thing that turns the economy and
## the calendar on, it decides which tools the toolbar offers, and it puts a
## line on screen saying what the stage is about. Every stage scene has one,
## configured in the Inspector; the scenes are otherwise the same island.
##
## Why the managers are configured from here rather than autostarting
## ------------------------------------------------------------------
## EconomyManager and SeasonManager are autoloads, so they outlive any level.
## If they switched themselves on they would still be on when the player went
## back to Island 1, and the tutorial would start charging for the seed it hands
## out for free. Configuring them per stage means leaving a stage resets it.

const UI_THEME := preload("res://scenes/ui/game_ui_theme.tres")

## The notification card sits under the clock on the right.
const PANEL_WIDTH := 150.0
## Gap between the clock's speed buttons and the top of the card.
const GAP_BELOW_CLOCK := 4.0
## Used only if the clock cannot be found, e.g. a level without the HUD.
const FALLBACK_RIGHT_GAP := 10.0
const FALLBACK_TOP := 88.0

## Shown once when the stage opens.
@export_multiline var stage_title: String = ""
@export_multiline var stage_brief: String = ""

## Which tools this stage hands the player. A stage never offers an action it
## has no system for - there is no spray on the island with no pests.
@export var give_hoe: bool = true
@export var give_watering_can: bool = true
@export var give_seeds: bool = true
@export var give_spray: bool = false
@export var give_axe: bool = false

## Stage 2 onwards. Turns money, seed costs and the market stall on.
@export var economy_enabled: bool = false

## Stage 5. Turns the seasonal calendar on.
@export var seasons_enabled: bool = false
@export var starting_season_index: int = 0

## How long the opening brief stays up.
@export var brief_seconds: float = 14.0

var _panel: PanelContainer
var _label: Label
var _clear_timer: SceneTreeTimer = null


func _ready() -> void:
	layer = 3

	EconomyManager.configure(economy_enabled)
	SeasonManager.configure(seasons_enabled, starting_season_index)

	_build_banner()
	_grant_tools()

	FarmEvents.advisory.connect(_on_advisory)
	EconomyManager.transaction.connect(_on_transaction)
	SeasonManager.season_warning.connect(_on_season_warning)
	SeasonManager.season_changed.connect(_on_season_changed)

	if not stage_brief.is_empty():
		_say(_opening_text(), brief_seconds)


func _opening_text() -> String:
	if stage_title.is_empty():
		return stage_brief
	return "%s\n%s" % [stage_title, stage_brief]


## Tools arrive at the start of the stage rather than from the guide.
##
## Marlow's dialogue hands over the whole set at once, which suited a single
## sandbox level and defeats a staged build entirely. The stages grant their own
## and the guide on them is set to unlocks_all_tools = false.
func _grant_tools() -> void:
	if give_hoe:
		ToolManager.enable_tool(DataTypes.Tools.TillGround)
	if give_watering_can:
		ToolManager.enable_tool(DataTypes.Tools.WaterCrops)
	if give_seeds:
		ToolManager.enable_tool(DataTypes.Tools.PlantCorn)
		ToolManager.enable_tool(DataTypes.Tools.PlantTomato)
	if give_spray:
		ToolManager.enable_tool(DataTypes.Tools.SprayPest)
	if give_axe:
		ToolManager.enable_tool(DataTypes.Tools.AxeWood)


# --- the banner -------------------------------------------------------------

func _build_banner() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.theme = UI_THEME
	_panel.theme_type_variation = &"DarkWoodPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	# A small card on the right, tucked under the clock and speed buttons, so it
	# no longer covers the field, the toolbar or the stage label. Anchored to the
	# top-right corner and allowed to grow downward as the text wraps.
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_END
	_panel.custom_minimum_size.x = PANEL_WIDTH
	_panel.offset_right = -FALLBACK_RIGHT_GAP
	_panel.offset_left = -FALLBACK_RIGHT_GAP - PANEL_WIDTH
	_panel.offset_top = FALLBACK_TOP
	_panel.offset_bottom = FALLBACK_TOP
	root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	_panel.add_child(margin)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color("f4ead6"))
	margin.add_child(_label)


## Puts a line on the banner for a while.
##
## Each call cancels the previous timer rather than adding a second one. Without
## that, two messages in quick succession leave the first one's timer to clear
## the second one early, and the player loses a line they never finished reading.
func _say(text: String, seconds: float) -> void:
	_label.text = text
	_place_under_clock()
	_panel.visible = true

	_clear_timer = get_tree().create_timer(seconds)
	var this_timer := _clear_timer
	await this_timer.timeout
	if _clear_timer != this_timer:
		return
	_panel.visible = false


## Lines the card up with the clock's right edge, just below the speed buttons.
##
## The clock lives in the HUD in main_scene, not in this level, and its size
## comes from the theme, so it is measured rather than guessed. Re-measured on
## every message so a window resize never leaves the card behind.
func _place_under_clock() -> void:
	var clock := get_tree().root.find_child("DayNightPanel", true, false)
	if clock == null:
		return

	var time_panel := clock.get_node_or_null("TimePanel") as Control
	var speed := clock.get_node_or_null("SpeedControl") as Control
	if time_panel == null or speed == null:
		return

	var viewport_width := get_viewport().get_visible_rect().size.x
	var right_edge := time_panel.get_global_rect().end.x
	var top := speed.get_global_rect().end.y + GAP_BELOW_CLOCK

	_panel.offset_right = right_edge - viewport_width
	_panel.offset_left = _panel.offset_right - PANEL_WIDTH
	_panel.offset_top = top
	_panel.offset_bottom = top


func _on_advisory(message: String) -> void:
	_say(message, 8.0)


func _on_transaction(message: String, _success: bool) -> void:
	_say(message, 6.0)


func _on_season_warning(message: String, _next_season: Dictionary) -> void:
	_say(message, 12.0)


func _on_season_changed(season: Dictionary) -> void:
	if season.is_empty():
		return
	_say("%s has arrived. %s" % [
		season.get("display_name", ""), season.get("teaching_note", "")
	], 12.0)
