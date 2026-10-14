extends PanelContainer

## Money and season, on the HUD.
##
## Both are stage-gated, and the panel follows suit: with no economy and no
## calendar running there is nothing to show, so it hides itself entirely rather
## than sitting there reading "R0" on islands that have no money. That keeps
## Stage 1's screen as bare as Stage 1 is meant to be.

var _label: Label


func _ready() -> void:
	theme_type_variation = &"DarkWoodPanel"

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	add_child(margin)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color("f4ead6"))
	margin.add_child(_label)

	EconomyManager.balance_changed.connect(_on_changed)
	SeasonManager.season_changed.connect(_on_changed)
	# The stage configures both managers in its own _ready(), and node order
	# decides whether that has happened yet. One frame's wait removes the race.
	await get_tree().process_frame
	_refresh()


func _on_changed(_value) -> void:
	_refresh()


func _refresh() -> void:
	var parts: Array = []

	if EconomyManager.enabled:
		parts.append("Money: %s" % EconomyManager.format_money(EconomyManager.balance))

	if SeasonManager.enabled:
		parts.append("%s  %.0f degrees" % [
			SeasonManager.display_name(), SeasonManager.temperature_c()
		])

	visible = not parts.is_empty()
	_label.text = "    ".join(parts)
