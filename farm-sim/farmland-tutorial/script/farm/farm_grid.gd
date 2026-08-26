extends Control

## A playable field: pick an action, click a tile, end the day, watch it grow.
##
## This is the vertical slice (DEL-01 / MS-02) reduced to its smallest honest
## form - plant, water, treat, harvest, on a real grid, with weather driving the
## outcome. Everything visible here is placeholder: flat coloured rectangles
## standing in for tiles, built entirely in code.
##
## Why the UI is built in code rather than in the editor
## -----------------------------------------------------
## Godot .tscn files merge badly, and this project has ten contributors. A scene
## that is one node plus a script produces no merge conflicts; a scene with
## forty hand-placed nodes produces them constantly. When the art exists this
## should become a proper scene with a single named owner - but not before.

const GRID_COLUMNS := 4
const GRID_ROWS := 3
const TILE_SIZE := Vector2(74, 56)

enum Action { PLANT_MAIZE, PLANT_BEANS, WATER, TREAT, HARVEST }

var _library := CropLibrary.new()
var _weather := WeatherSystem.new(2026)
var _tiles: Array = []
var _buttons: Array = []
var _selected_action: int = Action.PLANT_MAIZE
var _day: int = 0
var _harvest_total: float = 0.0

var _day_label: Label
var _weather_label: Label
var _season_label: Label
var _forecast_label: Label
var _message_label: RichTextLabel
var _action_buttons: Dictionary = {}
var _season_buttons: Dictionary = {}


func _ready() -> void:
	if not _library.load_from():
		push_error(_library.load_error)
		return
	if not _weather.load_from():
		push_error(_weather.load_error)
		return

	_weather.set_season("summer")
	_weather.advance()

	for i in range(GRID_COLUMNS * GRID_ROWS):
		_tiles.append(Crop.new(_library, 1000 + i))

	_build_ui()
	_refresh()


# --- construction -----------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 8
	root.offset_top = 6
	root.offset_right = -8
	root.offset_bottom = -6
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	# --- status line
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 12)
	root.add_child(status)

	_day_label = _make_label("", 11)
	status.add_child(_day_label)

	_weather_label = _make_label("", 11)
	status.add_child(_weather_label)

	_season_label = _make_label("", 11)
	status.add_child(_season_label)

	_forecast_label = _make_label("", 9)
	_forecast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_forecast_label.custom_minimum_size.y = 22
	root.add_child(_forecast_label)

	# --- the field
	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	root.add_child(grid)

	for i in range(GRID_COLUMNS * GRID_ROWS):
		var button := Button.new()
		button.custom_minimum_size = TILE_SIZE
		button.add_theme_font_size_override("font_size", 8)
		button.clip_text = true
		button.pressed.connect(_on_tile_pressed.bind(i))
		grid.add_child(button)
		_buttons.append(button)

	# --- action toolbar
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 3)
	root.add_child(actions)

	_add_action_button(actions, Action.PLANT_MAIZE, "Maize")
	_add_action_button(actions, Action.PLANT_BEANS, "Beans")
	_add_action_button(actions, Action.WATER, "Water")
	_add_action_button(actions, Action.TREAT, "Treat")
	_add_action_button(actions, Action.HARVEST, "Harvest")

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)

	var next_day := Button.new()
	next_day.text = "End Day"
	next_day.add_theme_font_size_override("font_size", 9)
	next_day.pressed.connect(_on_end_day)
	actions.add_child(next_day)

	# Clicking "End Day" twenty-six times to see one crop cycle is fine when you
	# are testing and unbearable when you are demonstrating.
	var skip := Button.new()
	skip.text = "Skip 5"
	skip.add_theme_font_size_override("font_size", 9)
	skip.pressed.connect(_on_skip_days.bind(5))
	actions.add_child(skip)

	# --- season selector
	var seasons := HBoxContainer.new()
	seasons.add_theme_constant_override("separation", 3)
	root.add_child(seasons)

	seasons.add_child(_make_label("Season:", 9))
	for id in _weather.season_ids():
		var button := Button.new()
		button.text = id.capitalize()
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 9)
		button.pressed.connect(_on_season_selected.bind(id))
		seasons.add_child(button)
		_season_buttons[id] = button

	# --- message area
	_message_label = RichTextLabel.new()
	_message_label.bbcode_enabled = true
	_message_label.fit_content = false
	_message_label.scroll_active = true
	_message_label.custom_minimum_size.y = 64
	_message_label.add_theme_font_size_override("normal_font_size", 8)
	_message_label.add_theme_font_size_override("bold_font_size", 8)
	root.add_child(_message_label)

	_say("Pick an action below, then click a tile. Press [b]End Day[/b] to advance time.")


func _make_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	return label


func _add_action_button(parent: Node, action: int, text: String) -> void:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.add_theme_font_size_override("font_size", 9)
	button.pressed.connect(_on_action_selected.bind(action))
	parent.add_child(button)
	_action_buttons[action] = button


# --- input ------------------------------------------------------------------

func _on_action_selected(action: int) -> void:
	_selected_action = action
	for key in _action_buttons:
		_action_buttons[key].button_pressed = (key == action)


## Switching season is Level 3 / Conditional scope. It is wired up now because
## the season lesson - that maize planted in winter fails - is the clearest
## thing this simulation teaches, and it costs one line to show it.
func _on_season_selected(season_id: String) -> void:
	if not _weather.set_season(season_id):
		return
	_weather.advance()

	var season := _weather.season()
	var suits: Array = season.get("suits_crops", [])
	var suits_text := "Nothing grows well now."
	if not suits.is_empty():
		var names: Array = []
		for id in suits:
			names.append(str(id).capitalize())
		suits_text = "Suits: %s." % ", ".join(names)

	_say("[b]%s.[/b] %s %s" % [
		season.get("display_name", season_id),
		suits_text,
		season.get("teaching_note", ""),
	])
	_refresh()


func _on_skip_days(count: int) -> void:
	for i in range(count):
		_on_end_day()


func _on_tile_pressed(index: int) -> void:
	var crop: Crop = _tiles[index]

	match _selected_action:
		Action.PLANT_MAIZE:
			_try_plant(crop, "maize", index)
		Action.PLANT_BEANS:
			_try_plant(crop, "beans", index)
		Action.WATER:
			if crop.water(0.35):
				_say("Tile %d watered - soil now %d%%." % [index + 1, int(crop.moisture * 100.0)])
			else:
				_say("Tile %d has nothing growing to water." % (index + 1))
		Action.TREAT:
			if crop.treat_pest():
				_say("Tile %d treated. The outbreak is over." % (index + 1))
			else:
				_say("Tile %d had no pest outbreak - the treatment was wasted." % (index + 1))
		Action.HARVEST:
			_try_harvest(crop, index)

	_refresh()


func _try_plant(crop: Crop, crop_id: String, index: int) -> void:
	if crop.state == Crop.State.GROWING or crop.state == Crop.State.MATURE:
		_say("Tile %d already has a crop on it." % (index + 1))
		return
	if crop.state == Crop.State.DEAD:
		# Clearing a dead crop resets the tile so it can be replanted.
		_tiles[index] = Crop.new(_library, 1000 + index)
		crop = _tiles[index]

	if crop.plant(crop_id, 0.55):
		var line := "Planted %s on tile %d." % [crop.display_name, index + 1]
		# The game warns rather than refuses. Being allowed to make the mistake
		# and then watching it cost you the harvest teaches far more than a
		# blocked button ever will.
		if not _weather.season_suits_crop(crop_id):
			line += "\n[color=#d88]%s is the wrong crop for %s.[/color] %s" % [
				crop.display_name,
				_weather.season().get("display_name", "this season"),
				_weather.season().get("teaching_note", ""),
			]
		_say(line)


func _try_harvest(crop: Crop, index: int) -> void:
	if not crop.is_ready_to_harvest():
		if crop.state == Crop.State.GROWING:
			_say("Tile %d is not ready - %s, %d%% grown." % [
				index + 1, crop.current_stage_name(), int(crop.growth_progress() * 100.0)
			])
		else:
			_say("Nothing to harvest on tile %d." % (index + 1))
		return

	var summary := crop.harvest()
	_harvest_total += float(summary["yield_kg"])
	_show_summary(index, summary)


func _on_end_day() -> void:
	_day += 1
	_weather.advance()

	# Rain waters every tile before the day is simulated, which is why the
	# forecast matters: irrigating ahead of rain wastes effort and can waterlog.
	var rain := _weather.rainfall()

	var events: Array = []
	for i in range(_tiles.size()):
		var crop: Crop = _tiles[i]
		if crop.state != Crop.State.GROWING and crop.state != Crop.State.MATURE:
			continue

		if rain > 0.0:
			crop.moisture = clampf(crop.moisture + rain, 0.0, 1.0)

		var had_pest := crop.pest_active
		var was_growing := crop.state == Crop.State.GROWING

		crop.advance_day(
			_weather.evaporation_multiplier(),
			_weather.pest_chance(),
			_weather.temperature_c()
		)

		if crop.pest_active and not had_pest:
			events.append("[color=#d88]Pests on tile %d.[/color]" % (i + 1))
		if crop.state == Crop.State.DEAD:
			events.append("[color=#d66]The crop on tile %d died.[/color]" % (i + 1))
		elif crop.state == Crop.State.MATURE and was_growing:
			events.append("[color=#8d8]Tile %d is ready to harvest.[/color]" % (i + 1))

	var line := "[b]Day %d - %s, %.0fC.[/b] %s" % [
		_day, _weather.display_name(), _weather.temperature_c(), _weather.forecast_text()
	]
	if not events.is_empty():
		line += "\n" + "  ".join(events)
	_say(line)
	_refresh()


# --- display ----------------------------------------------------------------

func _refresh() -> void:
	_day_label.text = "Day %d" % _day
	_weather_label.text = "Weather: %s  %.0fC" % [_weather.display_name(), _weather.temperature_c()]
	_season_label.text = "Season: %s" % _weather.season().get("display_name", "-")
	_forecast_label.text = _weather.forecast_text()

	for id in _season_buttons:
		_season_buttons[id].button_pressed = (id == _weather.season_id)

	for i in range(_tiles.size()):
		var crop: Crop = _tiles[i]
		var button: Button = _buttons[i]
		button.text = _tile_text(crop)
		button.modulate = _tile_colour(crop)


func _tile_text(crop: Crop) -> String:
	match crop.state:
		Crop.State.EMPTY, Crop.State.HARVESTED:
			return "empty"
		Crop.State.DEAD:
			return "%s\nDEAD" % crop.display_name
		Crop.State.MATURE:
			return "%s\nREADY\n%.0f kg" % [crop.display_name, crop.projected_yield_kg()]
		_:
			var pest := "\nPESTS" if crop.pest_active else ""
			return "%s\n%s\nW %d%%  H %d%s" % [
				crop.display_name,
				crop.current_stage_name(),
				int(crop.moisture * 100.0),
				int(crop.health),
				pest,
			]


## Tile colour carries two signals at once: how healthy the crop is, and
## whether the soil is dry. Both are things FR-003 requires the player to be
## able to see without opening a menu.
func _tile_colour(crop: Crop) -> Color:
	match crop.state:
		Crop.State.EMPTY, Crop.State.HARVESTED:
			return Color(0.62, 0.55, 0.45)
		Crop.State.DEAD:
			return Color(0.45, 0.32, 0.30)
		Crop.State.MATURE:
			return Color(1.0, 0.92, 0.45)
		_:
			var health_ratio := crop.health / Crop.MAX_HEALTH
			var healthy := Color(0.42, 0.80, 0.40)
			var failing := Color(0.78, 0.62, 0.28)
			var colour := failing.lerp(healthy, health_ratio)
			if crop.pest_active:
				colour = colour.lerp(Color(0.85, 0.45, 0.45), 0.4)
			return colour


func _show_summary(index: int, summary: Dictionary) -> void:
	var lines: Array = []
	lines.append("[b]Harvested tile %d - %s[/b]" % [index + 1, summary["display_name"]])
	lines.append("Yield: [b]%.1f kg[/b] of a possible %.0f kg (%.0f%% lost) in %d days." % [
		summary["yield_kg"], summary["potential_yield_kg"],
		summary["yield_lost_percent"], summary["days_taken"],
	])
	lines.append(str(summary["headline"]))

	# FR-005: show the player why they got the result they got. The three
	# costliest days say more than a full list would.
	var penalties: Array = summary["penalties"].duplicate()
	penalties.sort_custom(func(a, b): return float(a["percent"]) > float(b["percent"]))
	if not penalties.is_empty():
		lines.append("")
		for i in range(mini(3, penalties.size())):
			lines.append("[color=#c88]-%.1f%%[/color]  %s" % [
				penalties[i]["percent"], penalties[i]["explanation"]
			])

	lines.append("")
	lines.append("Total harvested this session: [b]%.1f kg[/b]" % _harvest_total)
	_say("\n".join(lines))


func _say(text: String) -> void:
	_message_label.text = text
