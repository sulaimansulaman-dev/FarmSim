extends CanvasLayer

## The market, for Stage 2.
##
## Opened by walking up to the stall and pressing E. Buying and selling are both
## here, deliberately: the player should see what a bag of seed costs and what
## last week's cabbage fetched on the same screen, because the gap between those
## two numbers is the lesson the economy stage exists to teach.
##
## Built in code rather than as an authored scene for the same reason the title
## screen is - the rows depend on what crops.json and economy.json contain at
## runtime, so half of it could not be placed in the editor anyway.
##
## While this is open the world keeps running. Pausing the tree would stop the
## day/night clock, and a market that freezes time turns "sell before the crop
## spoils" into a non-decision.

const UI_THEME := preload("res://scenes/ui/game_ui_theme.tres")
const PLANTS_SHEET := preload("res://assets/game/objects/basic_plants.png")
const HARVEST_COLUMN := 5

signal closed()

var _balance_label: Label
var _basket_label: Label
var _root: Control


func _ready() -> void:
	layer = 20
	_build()
	EconomyManager.balance_changed.connect(_on_balance_changed)
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	_refresh()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# A dim behind the panel, and it swallows clicks so a stray shot does not
	# till the soil underneath the shop.
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.05, 0.03, 0.66)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(centre)

	var panel := PanelContainer.new()
	panel.theme = UI_THEME
	panel.theme_type_variation = &"DarkWoodPanel"
	centre.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)

	var title := Label.new()
	title.text = "MARKET"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color("f2c94c"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_balance_label = Label.new()
	_balance_label.add_theme_font_size_override("font_size", 10)
	_balance_label.add_theme_color_override("font_color", Color("a5d6a7"))
	header.add_child(_balance_label)

	column.add_child(_divider())

	# --- buying
	_add_heading(column, "SEED  (price per plant sown)")
	for crop_id in CropManager.library.crop_ids():
		_add_seed_row(column, str(crop_id))

	_add_heading(column, "SUPPLIES")
	for supply_id in EconomyManager.supply_ids():
		_add_supply_row(column, str(supply_id))

	column.add_child(_divider())

	# --- selling
	_add_heading(column, "SELL")

	_basket_label = Label.new()
	_basket_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_basket_label.custom_minimum_size = Vector2(300, 0)
	_basket_label.add_theme_font_size_override("font_size", 8)
	_basket_label.add_theme_color_override("font_color", Color("d8cbb0"))
	column.add_child(_basket_label)

	var sell_row := HBoxContainer.new()
	sell_row.add_theme_constant_override("separation", 6)
	column.add_child(sell_row)

	var sell_all := Button.new()
	sell_all.text = "SELL EVERYTHING"
	sell_all.focus_mode = Control.FOCUS_NONE
	sell_all.theme_type_variation = &"GameMenuButton"
	sell_all.custom_minimum_size = Vector2(150, 22)
	sell_all.pressed.connect(func(): EconomyManager.sell_all())
	sell_row.add_child(sell_all)

	var close := Button.new()
	close.text = "CLOSE  (Esc)"
	close.focus_mode = Control.FOCUS_NONE
	close.theme_type_variation = &"GameMenuButton"
	close.custom_minimum_size = Vector2(110, 22)
	close.pressed.connect(close_market)
	sell_row.add_child(close)


func _divider() -> Control:
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.14)
	line.custom_minimum_size = Vector2(0, 1)
	return line


func _add_heading(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color("c9a227"))
	parent.add_child(label)


func _add_seed_row(parent: Node, crop_id: String) -> void:
	var definition: Dictionary = CropManager.library.get_definition(crop_id)
	var cost := EconomyManager.seed_cost(crop_id)
	var days := CropManager.library.days_to_maturity(crop_id)
	var base_yield := float(definition.get("base_yield_kg", 0.0))
	var best_case := base_yield * EconomyManager.price_per_kg(crop_id)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	row.add_child(_crop_icon(crop_id))

	var text := Label.new()
	# "Pays up to" is the best case on purpose - a clean Grade A crop at full
	# weight. The distance between it and what the player actually banks is the
	# whole argument for watering on time and treating pests.
	text.text = "%-8s  seed %-5s  %2d days  pays up to %s" % [
		definition.get("display_name", crop_id),
		EconomyManager.format_money(cost),
		days,
		EconomyManager.format_money(best_case),
	]
	text.add_theme_font_size_override("font_size", 8)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)

	# Seed is charged for as it goes into the ground, not bought in advance.
	# One fewer stock to manage, and it keeps the cost attached to the decision
	# that incurs it.
	var note := Label.new()
	note.text = "charged when sown"
	note.add_theme_font_size_override("font_size", 8)
	note.add_theme_color_override("font_color", Color("8a8a7a"))
	row.add_child(note)


func _add_supply_row(parent: Node, supply_id: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var held: int = int(InventoryManager.inventory.get(supply_id, 0))
	var text := Label.new()
	text.text = "%-12s  %s     (you have %d)" % [
		EconomyManager.supply_name(supply_id),
		EconomyManager.format_money(EconomyManager.supply_cost(supply_id)),
		held,
	]
	text.add_theme_font_size_override("font_size", 8)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)

	var buy := Button.new()
	buy.text = "BUY"
	buy.focus_mode = Control.FOCUS_NONE
	buy.theme_type_variation = &"GameMenuButton"
	buy.custom_minimum_size = Vector2(54, 20)
	buy.pressed.connect(func():
		EconomyManager.buy_supply(supply_id)
		text.text = "%-12s  %s     (you have %d)" % [
			EconomyManager.supply_name(supply_id),
			EconomyManager.format_money(EconomyManager.supply_cost(supply_id)),
			int(InventoryManager.inventory.get(supply_id, 0)),
		]
	)
	row.add_child(buy)


func _crop_icon(crop_id: String) -> TextureRect:
	var definition: Dictionary = CropManager.library.get_definition(crop_id)
	var cell: int = CropManager.library.sprite_cell_size()
	var row_index: int = int(definition.get("sprite_row", 0))
	var column: int = int(definition.get("harvest_sprite_col", HARVEST_COLUMN))

	var icon := AtlasTexture.new()
	icon.atlas = PLANTS_SHEET
	icon.region = Rect2(column * cell, row_index * cell, cell, cell)

	var rect := TextureRect.new()
	rect.texture = icon
	rect.custom_minimum_size = Vector2(cell, cell)
	return rect


# --- state ------------------------------------------------------------------

func _on_balance_changed(_balance: float) -> void:
	_refresh()


func _on_inventory_changed(_inventory: Dictionary) -> void:
	_refresh()


func _refresh() -> void:
	_balance_label.text = "Balance: %s" % EconomyManager.format_money(EconomyManager.balance)

	var lines: Array = []
	var total := 0.0
	for item_name in InventoryManager.inventory:
		var quantity: int = int(InventoryManager.inventory[item_name])
		if quantity <= 0:
			continue
		var price := EconomyManager.unit_price(item_name)
		if price <= 0.0:
			continue
		total += price * float(quantity)
		lines.append("%d x %s at %s" % [
			quantity, EconomyManager.display_label(item_name), EconomyManager.format_money(price)
		])

	if lines.is_empty():
		_basket_label.text = "You have nothing the market will buy."
	else:
		_basket_label.text = "%s\nTotal: %s" % [
			"\n".join(lines), EconomyManager.format_money(total)
		]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("game_menu") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close_market()


func close_market() -> void:
	closed.emit()
	queue_free()
