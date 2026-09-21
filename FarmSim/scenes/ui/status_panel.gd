extends PanelContainer

## Money and season, on the HUD.
##
## Both are stage-gated, and the panel follows suit: with no economy and no
## calendar running there is nothing to show, so it hides itself entirely rather
## than sitting there reading "R0" on islands that have no money. That keeps
## Stage 1's screen as bare as Stage 1 is meant to be.

var _money_icon: TextureRect
var _money_label: Label
var _season_label: Label


func _ready() -> void:
	theme_type_variation = &"DayNightCounterPanel"
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	add_child(margin)

	# Use an HBoxContainer to put the icon, money, and season side-by-side
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	margin.add_child(hbox)

	# 1. Setup the Coin Icon
	_money_icon = TextureRect.new()
	var coin_atlas := AtlasTexture.new()
	coin_atlas.atlas = preload("res://assets/ui/basic_ui_sprites.png") 
	coin_atlas.region = Rect2(628, 115, 7, 10)
	_money_icon.texture = coin_atlas
	_money_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_money_icon.custom_minimum_size = Vector2(7, 10)
	hbox.add_child(_money_icon)

	# 2. Setup the Money Label
	_money_label = Label.new()
	_money_label.add_theme_font_size_override("font_size", 8)
	_money_label.add_theme_color_override("font_color", Color("f4ead6"))
	hbox.add_child(_money_label)

	# 3. Setup the Season Label
	_season_label = Label.new()
	_season_label.add_theme_font_size_override("font_size", 8)
	_season_label.add_theme_color_override("font_color", Color("f4ead6"))
	hbox.add_child(_season_label)

	EconomyManager.balance_changed.connect(_on_changed)
	SeasonManager.season_changed.connect(_on_changed)
	
	# The stage configures both managers in its own _ready(), and node order
	# decides whether that has happened yet. One frame's wait removes the race.
	await get_tree().process_frame
	_refresh()


func _on_changed(_value) -> void:
	_refresh()


func _refresh() -> void:
	# Update Money Visibility and Text
	if EconomyManager.enabled:
		_money_icon.show()
		_money_label.show()
		_money_label.text = EconomyManager.format_money(EconomyManager.balance)
	else:
		_money_icon.hide()
		_money_label.hide()

	# Update Season Visibility and Text
	if SeasonManager.enabled:
		_season_label.show()
		# Add some spacing before the season text if the money text is also showing
		var spacing = "    " if EconomyManager.enabled else ""
		_season_label.text = "%s%s  %.0f degrees" % [
			spacing, SeasonManager.display_name(), SeasonManager.temperature_c()
		]
	else:
		_season_label.hide()

	# Hide the entire panel if both systems are disabled
	visible = EconomyManager.enabled or SeasonManager.enabled
