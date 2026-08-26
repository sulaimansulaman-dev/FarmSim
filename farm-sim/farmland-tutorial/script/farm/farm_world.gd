extends Node2D

## The farm as a place you walk around, rather than a grid you click.
##
## Reuses the player character and tilesets already in the project and puts the
## crop simulation underneath them, so planting a seed and watching it come up
## is a thing that happens in the world.
##
## Controls
##   WASD / arrows   walk
##   E               do the sensible thing for this plot - open the seed
##                   picker on bare soil, water a growing crop, reap a ripe one
##   H               harvest (explicit, for when E would water instead)
##   T               treat a pest outbreak
##   Q               cycle season
##   Space           end the day
##
## W is deliberately NOT the water key: W walks north, and binding it to water
## would irrigate every time the player moved up.
##
## Demo shortcuts, on function keys so they do not squat on gameplay letters:
##   F1              ripen the nearest crop instantly (skips the simulation)
##   F2              run ten real days at once (does not skip anything)
##
## The interaction is contextual on purpose. A toolbar of modes means the
## player must first tell the game what they intend and then where; walking up
## to a plot and pressing one key is how the real action feels.

const PLOT_COLUMNS := 4
const PLOT_ROWS := 3
const PLOT_SPACING := 24.0
const PLOT_SCALE := 1.0
const FIELD_ORIGIN := Vector2(272.0, 124.0)
const INTERACT_RADIUS := 20.0

const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const SOIL_SHEET := "res://game/tilesets/tilled_dirt.png"
const GRASS_SHEET := "res://game/tilesets/grass.png"
## A plain, fully-opaque cell in each tileset. The rest of those sheets are
## autotile edge pieces, which would need bitmasking to use correctly.
const PLAIN_CELL := Rect2(16, 16, 16, 16)

var _library := CropLibrary.new()
var _weather := WeatherSystem.new(2026)
var _prices := PriceList.new()

var _tiles: Array = []
var _soil_sprites: Array = []
var _plant_sprites: Array = []
var _plot_positions: Array = []

var _player: Node2D
var _selected_crop: String = "maize"
var _day: int = 0
var _harvest_total: float = 0.0
var _nearest_plot: int = -1

var _balance: float = 0.0
var _pending_plot: int = -1
var _picker_crop_ids: Array = []

var _status_label: Label
var _message_label: RichTextLabel
var _picker: Control
var _picker_list: VBoxContainer
var _plant_sheet: Texture2D


func _ready() -> void:
	if not _library.load_from():
		push_error(_library.load_error)
		return
	if not _weather.load_from():
		push_error(_weather.load_error)
		return
	if not _prices.load_from():
		push_error(_prices.load_error)
		return

	_balance = _prices.starting_balance
	_plant_sheet = load(_library.sprite_sheet_path())
	_weather.set_season("summer")
	_weather.advance()

	_build_ground()
	_build_plots()
	_spawn_player()
	_build_hud()

	_say("Walk to a plot and press [b]E[/b] to plant, water, or harvest.  [b]H[/b] harvest  [b]T[/b] treat pests  [b]Q[/b] season  [b]Space[/b] end day")
	_refresh()


func _process(_delta: float) -> void:
	_update_nearest_plot()


# --- construction -----------------------------------------------------------

func _build_ground() -> void:
	var grass := TextureRect.new()
	grass.texture = _atlas(GRASS_SHEET, PLAIN_CELL)
	grass.stretch_mode = TextureRect.STRETCH_TILE
	grass.size = Vector2(640, 360)
	grass.position = Vector2.ZERO
	grass.z_index = -100
	grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grass)


func _build_plots() -> void:
	var soil_texture := _atlas(SOIL_SHEET, PLAIN_CELL)

	for i in range(PLOT_COLUMNS * PLOT_ROWS):
		var column := i % PLOT_COLUMNS
		var row := i / PLOT_COLUMNS
		var pos := FIELD_ORIGIN + Vector2(column * PLOT_SPACING, row * PLOT_SPACING)
		_plot_positions.append(pos)

		var soil := Sprite2D.new()
		soil.texture = soil_texture
		soil.position = pos
		soil.scale = Vector2(PLOT_SCALE, PLOT_SCALE)
		soil.z_index = -10
		add_child(soil)
		_soil_sprites.append(soil)

		# The plant sits slightly above the soil centre so it reads as growing
		# out of the plot rather than lying on it.
		var plant := Sprite2D.new()
		plant.position = pos + Vector2(0, -3)
		plant.scale = Vector2(PLOT_SCALE, PLOT_SCALE)
		plant.visible = false
		add_child(plant)
		_plant_sprites.append(plant)

		_tiles.append(Crop.new(_library, 1000 + i))


func _spawn_player() -> void:
	_player = load(PLAYER_SCENE).instantiate()
	_player.position = FIELD_ORIGIN + Vector2(PLOT_SPACING * 1.5, PLOT_SPACING * PLOT_ROWS + 8)
	add_child(_player)

	# The art is 16 pixels to a tile. At a 640x360 viewport that leaves the farm
	# as a postage stamp in a field of green, which is fine on a laptop and
	# useless on a projector. Zooming in is the whole difference.
	var camera := Camera2D.new()
	camera.zoom = Vector2(3.0, 3.0)
	camera.position = FIELD_ORIGIN + Vector2(
		PLOT_SPACING * (PLOT_COLUMNS - 1) * 0.5,
		PLOT_SPACING * PLOT_ROWS * 0.5 + 2.0
	)
	add_child(camera)
	camera.make_current()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)

	# Text sits over a moving world, so it needs its own ground rather than
	# relying on an outline. The character can and does walk behind it.
	_add_backing(panel, Rect2(0, 0, 640, 22))
	_add_backing(panel, Rect2(0, 302, 640, 58))

	_status_label = Label.new()
	_status_label.position = Vector2(6, 4)
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_status_label.add_theme_constant_override("outline_size", 4)
	panel.add_child(_status_label)

	_message_label = RichTextLabel.new()
	_message_label.bbcode_enabled = true
	_message_label.scroll_active = false
	_message_label.position = Vector2(6, 306)
	_message_label.size = Vector2(628, 50)
	_message_label.add_theme_font_size_override("normal_font_size", 10)
	_message_label.add_theme_font_size_override("bold_font_size", 10)
	_message_label.add_theme_color_override("default_color", Color.WHITE)
	_message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_message_label.add_theme_constant_override("outline_size", 4)
	panel.add_child(_message_label)

	# Demo controls, top right. Clickable for when the keyboard is busy driving
	# the character, and labelled DEMO so nobody watching mistakes them for
	# gameplay. Delete this row when the prototype stops being demonstrated.
	var demo_bar := HBoxContainer.new()
	demo_bar.add_theme_constant_override("separation", 4)
	demo_bar.position = Vector2(470, 2)
	panel.add_child(demo_bar)

	demo_bar.add_child(_demo_button("Ripen (F1)", _ripen_nearest))
	demo_bar.add_child(_demo_button("+10 Days (F2)", _skip_days.bind(10)))

	_build_crop_picker(panel)


func _build_crop_picker(parent: Control) -> void:
	_picker = Control.new()
	_picker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picker.visible = false
	parent.add_child(_picker)

	# Dim the farm behind, so it is obvious the world is waiting on a decision.
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.03, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picker.add_child(dim)

	_picker_list = VBoxContainer.new()
	_picker_list.position = Vector2(140, 96)
	_picker_list.add_theme_constant_override("separation", 6)
	_picker.add_child(_picker_list)


## The crop-selection screen the GDD asks for: "a simple crop selection wheel
## showing seed cost, growth duration, and expected payout".
##
## Built as a panel of cards rather than a literal radial wheel. At 640x360
## with two crops a wheel is harder to read and harder to label, and the three
## numbers the GDD actually cares about are what matter. Easy to change back if
## the team prefers the wheel.
##
## Rebuilt every time it opens, because affordability and season suitability
## both change between one planting and the next.
func _open_crop_picker(plot_index: int) -> void:
	_pending_plot = plot_index
	_picker_crop_ids.clear()

	for child in _picker_list.get_children():
		child.queue_free()

	var heading := Label.new()
	heading.text = "Choose a seed for plot %d          Balance: %s" % [
		plot_index + 1, _prices.format_money(_balance)
	]
	heading.add_theme_font_size_override("font_size", 12)
	_picker_list.add_child(heading)

	var number := 1
	for crop_id in _library.crop_ids():
		_picker_list.add_child(_crop_card(crop_id, number))
		_picker_crop_ids.append(crop_id)
		number += 1

	var hint := Label.new()
	hint.text = "Press 1-%d to plant, or Esc to cancel." % _picker_crop_ids.size()
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.72))
	_picker_list.add_child(hint)

	_picker.visible = true


func _crop_card(crop_id: String, number: int) -> Control:
	var definition := _library.get_definition(crop_id)
	var base_yield: float = float(definition.get("base_yield_kg", 0.0))
	var cost := _prices.seed_cost(crop_id)
	var affordable := _balance >= cost
	var suits := _weather.season_suits_crop(crop_id)

	var card := Button.new()
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(360, 40)
	card.disabled = not affordable
	card.pressed.connect(_choose_crop.bind(crop_id))

	var text := "  %d.  %-7s   seed %-5s   %2d days   pays up to %s" % [
		number,
		definition.get("display_name", crop_id),
		_prices.format_money(cost),
		_library.days_to_maturity(crop_id),
		_prices.format_money(_prices.expected_payout(crop_id, base_yield)),
	]
	text += "\n     best-case profit %s" % _prices.format_money(
		_prices.expected_profit(crop_id, base_yield)
	)

	# "Pays up to" is the best case on purpose. The gap between that number and
	# what the player actually earns is the whole point of the harvest summary.
	if not affordable:
		text += "   -   cannot afford this"
	elif not suits:
		text += "   -   wrong season for it"

	card.text = text
	card.add_theme_font_size_override("font_size", 10)
	return card


func _choose_crop(crop_id: String) -> void:
	_selected_crop = crop_id
	_close_crop_picker()
	_plant_at(_pending_plot)
	_refresh()


func _close_crop_picker() -> void:
	_picker.visible = false


func _add_backing(parent: Node, area: Rect2) -> void:
	var backing := ColorRect.new()
	backing.color = Color(0.05, 0.06, 0.05, 0.62)
	backing.position = area.position
	backing.size = area.size
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(backing)


func _demo_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE  # keep WASD working after a click
	button.add_theme_font_size_override("font_size", 10)
	button.pressed.connect(func():
		action.call()
		_refresh()
	)
	return button


func _atlas(sheet_path: String, region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = load(sheet_path)
	texture.region = region
	return texture


# --- input ------------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	# While the seed picker is open it owns the keyboard. Letting the world keep
	# reading keys underneath a modal is how you end up planting twice.
	if _picker != null and _picker.visible:
		_picker_key(event.keycode)
		get_viewport().set_input_as_handled()
		return

	match event.keycode:
		KEY_E:
			_context_action()
		KEY_H:
			_harvest_nearest()
		KEY_T:
			_treat_nearest()
		KEY_Q:
			_cycle_season()
		KEY_SPACE:
			_end_day()
		KEY_F1:
			_ripen_nearest()
		KEY_F2:
			_skip_days(10)
		_:
			return

	get_viewport().set_input_as_handled()
	_refresh()


func _picker_key(keycode: int) -> void:
	if keycode == KEY_ESCAPE:
		_close_crop_picker()
		_say("Planting cancelled.")
		return

	var choice := keycode - KEY_1
	if choice >= 0 and choice < _picker_crop_ids.size():
		var crop_id: String = _picker_crop_ids[choice]
		if _balance < _prices.seed_cost(crop_id):
			_say("[color=#e88]Not enough money for %s seed.[/color]" % crop_id.capitalize())
			return
		_choose_crop(crop_id)


## One key does the sensible thing for whatever the player is standing next to.
func _context_action() -> void:
	if _nearest_plot < 0:
		_say("Walk closer to a plot first.")
		return

	var crop: Crop = _tiles[_nearest_plot]
	var label := "Plot %d" % (_nearest_plot + 1)

	match crop.state:
		Crop.State.EMPTY, Crop.State.HARVESTED:
			_open_crop_picker(_nearest_plot)
		Crop.State.GROWING:
			_water_nearest()
		Crop.State.MATURE:
			_harvest_nearest()
		Crop.State.DEAD:
			_tiles[_nearest_plot] = Crop.new(_library, 1000 + _nearest_plot)
			_say("%s cleared. Press E again to replant." % label)


func _water_nearest() -> void:
	if _nearest_plot < 0:
		_say("Walk closer to a plot first.")
		return
	var crop: Crop = _tiles[_nearest_plot]
	if crop.water(0.35):
		_say("Plot %d watered - soil now %d%%." % [_nearest_plot + 1, int(crop.moisture * 100.0)])
	else:
		_say("Plot %d has nothing growing to water." % (_nearest_plot + 1))


func _harvest_nearest() -> void:
	if _nearest_plot < 0:
		_say("Walk closer to a plot first.")
		return

	var crop: Crop = _tiles[_nearest_plot]
	if not crop.is_ready_to_harvest():
		if crop.state == Crop.State.GROWING:
			_say("Plot %d is not ready - %s, %d%% grown." % [
				_nearest_plot + 1, crop.current_stage_name(), int(crop.growth_progress() * 100.0)
			])
		else:
			_say("Nothing to harvest on plot %d." % (_nearest_plot + 1))
		return

	var summary := crop.harvest()
	_harvest_total += float(summary["yield_kg"])
	# Placeholder economics - see PriceList. The Economy developer owns DEL-05.
	var earned := float(summary["yield_kg"]) * _prices.price_per_kg(crop.crop_id)
	_balance += earned
	_show_harvest("Plot %d" % (_nearest_plot + 1), summary, earned)


func _plant_at(index: int) -> void:
	var crop: Crop = _tiles[index]
	if crop.state == Crop.State.HARVESTED:
		_tiles[index] = Crop.new(_library, 1000 + index)
		crop = _tiles[index]

	var cost := _prices.seed_cost(_selected_crop)
	if _balance < cost:
		_say("[color=#e88]Not enough money for %s seed.[/color]" % _selected_crop.capitalize())
		return

	if not crop.plant(_selected_crop, 0.55):
		return

	_balance -= cost
	var line := "Planted [b]%s[/b] on plot %d for %s. Balance %s." % [
		crop.display_name, index + 1,
		_prices.format_money(cost), _prices.format_money(_balance),
	]
	# The game warns but does not refuse. Being allowed to make the mistake and
	# then watching it cost you the harvest teaches more than a blocked button.
	if not _weather.season_suits_crop(_selected_crop):
		line += "\n[color=#e88]%s is the wrong crop for %s.[/color] %s" % [
			crop.display_name,
			_weather.season().get("display_name", "this season"),
			_weather.season().get("teaching_note", ""),
		]
	_say(line)


## Demo shortcuts. Both are marked clearly on screen when used, so nobody
## watching mistakes a skipped simulation for a real result.

func _ripen_nearest() -> void:
	if _nearest_plot < 0:
		_say("Stand next to a plot first, then press F.")
		return

	var crop: Crop = _tiles[_nearest_plot]
	if not crop.force_mature():
		_say("Plot %d has nothing growing to ripen." % (_nearest_plot + 1))
		return

	_say("[color=#9cf][DEMO][/color] Plot %d skipped ahead to harvest. Press [b]E[/b] to reap it.\n[color=#aaa]The simulation was skipped, so this yield only reflects damage taken so far.[/color]" % (_nearest_plot + 1))


## Runs real days, quickly. Unlike F this does not cheat - crops still dry out,
## pests still arrive - it just saves pressing Space ten times.
func _skip_days(count: int) -> void:
	for i in range(count):
		_end_day()
	# _end_day already wrote the last day's report; just mark how we got here.
	_message_label.text = "[color=#9cf][DEMO][/color] Ran %d days.\n" % count + _message_label.text


func _treat_nearest() -> void:
	if _nearest_plot < 0:
		return
	var crop: Crop = _tiles[_nearest_plot]
	if crop.treat_pest():
		_say("Plot %d treated. The outbreak is over." % (_nearest_plot + 1))
	else:
		_say("Plot %d had no pest outbreak - the treatment was wasted." % (_nearest_plot + 1))


func _cycle_season() -> void:
	var ids: Array = _weather.season_ids()
	var next: int = (ids.find(_weather.season_id) + 1) % ids.size()
	_weather.set_season(ids[next])
	_weather.advance()

	var season := _weather.season()
	var suits: Array = season.get("suits_crops", [])
	var suits_text := "Nothing grows well now."
	if not suits.is_empty():
		var names: Array = []
		for id in suits:
			names.append(str(id).capitalize())
		suits_text = "Suits: %s." % ", ".join(names)

	_say("[b]%s, about %.0f degrees.[/b] %s %s" % [
		season.get("display_name", ""),
		_weather.temperature_c(),
		suits_text,
		season.get("teaching_note", ""),
	])


func _end_day() -> void:
	_day += 1
	_weather.advance()

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
			events.append("[color=#e99]Pests on plot %d.[/color]" % (i + 1))
		if crop.state == Crop.State.DEAD:
			events.append("[color=#e77]Plot %d died.[/color]" % (i + 1))
		elif crop.state == Crop.State.MATURE and was_growing:
			events.append("[color=#9e9]Plot %d is ready.[/color]" % (i + 1))

	var line := "[b]Day %d - %s, %.0f degrees.[/b] %s" % [
		_day, _weather.display_name(), _weather.temperature_c(), _weather.forecast_text()
	]
	if not events.is_empty():
		line += "\n" + "  ".join(events)
	_say(line)


# --- display ----------------------------------------------------------------

func _update_nearest_plot() -> void:
	if _player == null:
		return

	var best := -1
	var best_distance := INTERACT_RADIUS
	for i in range(_plot_positions.size()):
		var distance: float = _player.position.distance_to(_plot_positions[i])
		if distance < best_distance:
			best_distance = distance
			best = i

	if best != _nearest_plot:
		_nearest_plot = best
		_refresh()


func _refresh() -> void:
	_status_label.text = "Day %d    %s %.0fC    %s    %s    Harvested: %.0f kg" % [
		_day,
		_weather.display_name(),
		_weather.temperature_c(),
		_weather.season().get("display_name", ""),
		_prices.format_money(_balance),
		_harvest_total,
	]

	for i in range(_tiles.size()):
		_refresh_plot(i)


func _refresh_plot(index: int) -> void:
	var crop: Crop = _tiles[index]
	var soil: Sprite2D = _soil_sprites[index]
	var plant: Sprite2D = _plant_sprites[index]

	# Dry soil reads lighter, wet soil darker - the same cue a real field gives
	# you, and one of the things FR-003 asks the player to be able to see.
	var wetness := 1.0
	if crop.state == Crop.State.GROWING or crop.state == Crop.State.MATURE:
		wetness = lerpf(1.15, 0.66, clampf(crop.moisture, 0.0, 1.0))
	soil.modulate = Color(wetness, wetness, wetness)

	# Highlight whichever plot the player would act on.
	if index == _nearest_plot:
		soil.modulate = soil.modulate.lightened(0.25)

	if crop.state == Crop.State.EMPTY or crop.state == Crop.State.HARVESTED:
		plant.visible = false
		return

	plant.visible = true
	plant.texture = _atlas(_library.sprite_sheet_path(), _library.stage_sprite_region(crop))

	if crop.state == Crop.State.DEAD:
		plant.modulate = Color(0.45, 0.36, 0.30)
	elif crop.pest_active:
		plant.modulate = Color(1.0, 0.72, 0.72)
	else:
		# Unhealthy plants yellow off rather than staying green.
		var health_ratio := crop.health / Crop.MAX_HEALTH
		plant.modulate = Color(1.0, 0.80, 0.55).lerp(Color.WHITE, health_ratio)


func _show_harvest(label: String, summary: Dictionary, earned: float = 0.0) -> void:
	var lines: Array = []
	lines.append("[b]%s harvested - %.1f kg of %s[/b] (%.0f%% lost over %d days). Earned [b]%s[/b], balance %s." % [
		label, summary["yield_kg"], summary["display_name"],
		summary["yield_lost_percent"], summary["days_taken"],
		_prices.format_money(earned), _prices.format_money(_balance),
	])
	lines.append(str(summary["headline"]))

	# FR-005: the costliest day says more than the full list.
	var penalties: Array = summary["penalties"].duplicate()
	penalties.sort_custom(func(a, b): return float(a["percent"]) > float(b["percent"]))
	if not penalties.is_empty():
		lines.append("[color=#e99]%s[/color]" % penalties[0]["explanation"])

	_say("\n".join(lines))


func _say(text: String) -> void:
	_message_label.text = text
