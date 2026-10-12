extends VBoxContainer

## The stage checklist and live star rating, top-left of the HUD beside the inventory.
##
## Reads everything from StageSession, which does the counting. Hidden on any
## level that is not one of the five stages.
##
## Shares an HBoxContainer with the inventory column, which is what keeps the two
## apart. They used to be anchored independently to the top and bottom of the
## same left edge, so a full inventory and a tall goal list grew into each other.
## Stacking them in one column instead does not fit either: at 360px high it runs
## off the bottom of the screen and pushes the whole HUD with it.

const UI_SHEET := preload("res://assets/ui/basic_ui_sprites.png")
const STAR_FULL := Rect2(531, 68, 10, 8)
const STAR_EMPTY := Rect2(563, 68, 10, 8)

const COLOUR_TEXT := Color("f4ead6")
const COLOUR_DONE := Color("a5d6a7")
const COLOUR_TODO := Color("d8cbb0")
const COLOUR_GOLD := Color("f2c94c")

var _panel: PanelContainer
var _rows: VBoxContainer
var _stars: Array[TextureRect] = []
var _time_label: Label
var _bridge_label: Label
var _time_refresh := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 0)
	_build()
	visible = false

	StageSession.objectives_changed.connect(_refresh)
	StageSession.bridge_opened.connect(_refresh)
	StageSession.session_started.connect(func(_id): _refresh())
	_refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	_time_refresh -= delta
	if _time_refresh <= 0.0:
		_time_refresh = 0.5
		_update_time()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"DarkWoodPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size.x = 150
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
	column.add_child(header)

	var title := _label("GOALS", COLOUR_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	for i in 3:
		var star := TextureRect.new()
		star.texture = _star_texture(false)
		star.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		star.custom_minimum_size = Vector2(10, 8)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(star)
		_stars.append(star)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 0)
	column.add_child(_rows)

	_time_label = _label("", COLOUR_TODO)
	column.add_child(_time_label)

	_bridge_label = _label("", COLOUR_GOLD)
	_bridge_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_bridge_label)


func _refresh() -> void:
	visible = StageSession.active
	if not visible:
		return

	for child in _rows.get_children():
		child.queue_free()

	for row in StageSession.objective_progress():
		var done: bool = row["done"]
		var text := "%s %d/%d  %s" % ["+" if done else "-", row["have"], row["target"], row["label"]]
		var label := _label(text, COLOUR_DONE if done else COLOUR_TODO)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 140
		_rows.add_child(label)

	var stars := StageSession.projected_stars()
	for i in _stars.size():
		_stars[i].texture = _star_texture(i < stars)

	if StageSession.bridge_open:
		_bridge_label.text = "Bridge open! Head east and face the keeper."
	else:
		_bridge_label.text = "Finish every goal to open the bridge."
	_update_time()


func _update_time() -> void:
	var par := int(StageSession.definition().get("par_time_sec", 0))
	_time_label.text = "Time %s  (par %s)" % [_clock(int(StageSession.elapsed_sec)), _clock(par)]


func _clock(seconds: int) -> String:
	return "%d:%02d" % [floori(seconds / 60.0), seconds % 60]


func _label(text: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", colour)
	return label


func _star_texture(full: bool) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = UI_SHEET
	texture.region = STAR_FULL if full else STAR_EMPTY
	return texture
