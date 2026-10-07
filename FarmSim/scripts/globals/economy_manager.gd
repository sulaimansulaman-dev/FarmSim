extends Node

## Money, seed costs and the market, for Stage 2.
##
## Off by default
## --------------
## Every island before the market stage played with no economy at all: seed was
## free and there was nothing to spend anything on. Turning that on globally
## would silently break Island 1, where the tutorial hands the player a seed
## tool and expects a click to sow. So `enabled` starts false, and a level opts
## in through StageDirector. When it is off, `charge_for_seed` always says yes
## and nothing is deducted.
##
## What is sold where
## ------------------
## Buying happens at the market stall (an interactable in the level). Selling
## happens there too, and takes whatever is in the inventory. Produce is graded:
## the same kilogram of cabbage is worth less if pests had a week at it, which
## is the whole point of Stage 3 and the reason grade travels with the item.

signal balance_changed(balance: float)
signal transaction(message: String, success: bool)

const DATA_PATH := "res://data/economy.json"

## Harvested crops go into the inventory as "cabbage (A)" rather than plain
## "cabbage", so Grade A and Grade B of the same crop stack separately and can
## be priced and sold separately. Everything else - eggs, logs, sprays - has no
## suffix. This is the one place that spelling is decided.
const GRADE_SUFFIX_RE := r"^(.*) \(([AB])\)$"


## Builds the inventory key for a harvested crop.
static func graded_key(crop_id: String, grade: String) -> String:
	if grade == "A" or grade == "B":
		return "%s (%s)" % [crop_id, grade]
	return crop_id

var enabled: bool = false
var symbol: String = "R"
var starting_balance: float = 0.0
var balance: float = 0.0

var load_error: String = ""

var _crops: Dictionary = {}
var _supplies: Dictionary = {}
var _produce: Dictionary = {}
var _fertiliser: Dictionary = {}


func _ready() -> void:
	if not _load():
		push_error("EconomyManager could not load economy data. " + load_error)
		return
	balance = starting_balance


func _load() -> bool:
	load_error = ""
	if not FileAccess.file_exists(DATA_PATH):
		load_error = "Economy data file not found at %s" % DATA_PATH
		return false

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		load_error = "Economy data at %s is not valid JSON." % DATA_PATH
		return false

	var currency: Dictionary = parsed.get("currency", {})
	symbol = str(currency.get("symbol", "R"))
	starting_balance = float(currency.get("starting_balance", 0.0))

	_crops = parsed.get("crops", {})
	_supplies = parsed.get("supplies", {})
	_produce = parsed.get("produce", {})
	_fertiliser = parsed.get("fertiliser", {})

	if _crops.is_empty():
		load_error = "Economy data defines no crop prices."
		return false
	return true


# --- lifecycle --------------------------------------------------------------

## Called by StageDirector when a level loads. A stage without an economy gets
## it switched off rather than hidden, so nothing charges behind the scenes.
func configure(economy_enabled: bool, reset_balance: bool = true) -> void:
	enabled = economy_enabled
	# An autoload outlives the level, so a bag left armed on one stage would
	# still be armed on the next one.
	fertiliser_armed = false
	if reset_balance:
		balance = starting_balance
	balance_changed.emit(balance)


# --- queries ----------------------------------------------------------------

func seed_cost(crop_id: String) -> float:
	return float(_crops.get(crop_id, {}).get("seed_cost", 0.0))


func price_per_kg(crop_id: String) -> float:
	return float(_crops.get(crop_id, {}).get("price_per_kg", 0.0))


func supply_cost(supply_id: String) -> float:
	return float(_supplies.get(supply_id, {}).get("cost", 0.0))


func supply_name(supply_id: String) -> String:
	return str(_supplies.get(supply_id, {}).get("display_name", supply_id.capitalize()))


func supply_ids() -> Array:
	return _supplies.keys()


func supply_description(supply_id: String) -> String:
	return str(_supplies.get(supply_id, {}).get("description", ""))


## Whether a treatment can clear this kind of pest at all (Stage 3).
func treatment_works_on(supply_id: String, pest_type: String) -> bool:
	var treats: Array = _supplies.get(supply_id, {}).get("treats", [])
	return pest_type in treats


## How often one application of a treatment actually clears the pest.
func treatment_success_chance(supply_id: String) -> float:
	return float(_supplies.get(supply_id, {}).get("success_chance", 1.0))


## Supplies that are pest treatments, in market order.
func treatment_ids() -> Array:
	var ids: Array = []
	for supply_id in _supplies:
		if _supplies[supply_id].has("treats"):
			ids.append(supply_id)
	return ids


## Treatments that clear this pest, by display name, in market order.
##
## The crop info panel names them, so a player who has just met birds is told
## what to buy rather than left to find out by wasting a can on them.
func treatments_for(pest_type: String) -> PackedStringArray:
	var names := PackedStringArray()
	for supply_id in treatment_ids():
		if treatment_works_on(str(supply_id), pest_type):
			names.append(supply_name(str(supply_id)))
	return names


func fertiliser_growth_multiplier() -> float:
	return float(_fertiliser.get("growth_multiplier", 1.0))


func fertiliser_starting_moisture() -> float:
	return float(_fertiliser.get("starting_moisture", 0.5))


func format_money(amount: float) -> String:
	return "%s%.0f" % [symbol, amount]


func can_afford(amount: float) -> bool:
	return balance >= amount


# --- buying -----------------------------------------------------------------

## Takes payment for one seed. Returns true if sowing may go ahead.
##
## With the economy off this always succeeds and costs nothing, which is what
## keeps every pre-market island playing exactly as it did before.
func charge_for_seed(crop_id: String) -> bool:
	if not enabled:
		return true

	var cost := seed_cost(crop_id)
	if not can_afford(cost):
		transaction.emit("Not enough money for %s seed (%s)." % [
			crop_id.capitalize(), format_money(cost)
		], false)
		return false

	_spend(cost)
	return true


## Buys one unit of a supply into the inventory.
func buy_supply(supply_id: String) -> bool:
	if not _supplies.has(supply_id):
		return false

	var cost := supply_cost(supply_id)
	if not can_afford(cost):
		transaction.emit("Not enough money for %s (%s)." % [
			supply_name(supply_id), format_money(cost)
		], false)
		return false

	_spend(cost)
	InventoryManager.add_collectable(supply_id, 1)
	FarmEvents.supply_bought.emit(supply_id)
	transaction.emit("Bought %s for %s." % [supply_name(supply_id), format_money(cost)], true)
	return true


## Consumes one unit of a supply. Returns false if the player has none.
##
## With the economy off supplies are unlimited, so Stage 3's spray keeps working
## on islands that never opened a market.
func consume_supply(supply_id: String) -> bool:
	if not enabled:
		return true

	if int(InventoryManager.inventory.get(supply_id, 0)) <= 0:
		transaction.emit("No %s left. Buy more at the market stall." % supply_name(supply_id).to_lower(), false)
		return false

	InventoryManager.remove_collectable(supply_id, 1)
	return true


## Whether the next seed sown gets a bag of fertiliser worked in with it.
##
## Armed by clicking the fertiliser slot and cleared as soon as a bag is spent,
## so one click buys one plant. It used to be automatic - holding a bag meant
## the next seed silently ate it, whichever crop that happened to be, with
## nothing on screen to say so. A bag costs money, so spending it is the
## player's decision to make.
var fertiliser_armed: bool = false


## Turns the next-sowing fertiliser on or off. Returns the new state.
func toggle_fertiliser() -> bool:
	if not enabled or int(InventoryManager.inventory.get("fertiliser", 0)) <= 0:
		fertiliser_armed = false
		FarmEvents.advisory.emit("No fertiliser left. The market stall sells it by the bag.")
		return false

	fertiliser_armed = not fertiliser_armed
	if fertiliser_armed:
		FarmEvents.advisory.emit("Fertiliser ready - the next seed you sow gets a bag worked in with it.")
	else:
		FarmEvents.advisory.emit("Fertiliser put away. Seeds go in on their own.")
	return fertiliser_armed


## Spends a bag of fertiliser on the crop about to go in, if one is armed.
##
## Unlike a spray, fertiliser is never demanded - sowing without it is allowed
## and normal. So this reports whether a bag was used rather than whether the
## action may proceed, and with the economy off it is always false: an island
## with no market has no fertiliser to spend.
func consume_fertiliser_if_held() -> bool:
	if not enabled or not fertiliser_armed:
		return false
	if int(InventoryManager.inventory.get("fertiliser", 0)) <= 0:
		fertiliser_armed = false
		return false
	InventoryManager.remove_collectable("fertiliser", 1)
	# Disarmed every time, so each bag spent is its own decision rather than a
	# setting left on that quietly drains the stack.
	fertiliser_armed = false
	return true


func has_supply(supply_id: String) -> bool:
	if not enabled:
		return true
	return int(InventoryManager.inventory.get(supply_id, 0)) > 0


# --- selling ----------------------------------------------------------------

## What one unit of an inventory item fetches, grade included.
##
## Returns 0.0 for anything with no price, which is how the market decides what
## it is willing to take - tools and supplies are not sellable and simply price
## at nothing.
func unit_price(item_name: String) -> float:
	var parts := split_grade(item_name)
	var base_name: String = parts[0]
	var grade: String = parts[1]

	if CropManager.library.has_crop(base_name):
		var multiplier := 1.0
		if grade == "B":
			multiplier = CropManager.library.tuning("grade_b_price_multiplier", 0.6)
		return price_per_kg(base_name) * multiplier

	return float(_produce.get(base_name, 0.0))


## Sells every sellable thing in the inventory in one go.
func sell_all() -> float:
	var earned := 0.0
	var lines: Array = []

	for item_name in InventoryManager.inventory.keys():
		var quantity: int = int(InventoryManager.inventory[item_name])
		if quantity <= 0:
			continue
		var price := unit_price(item_name)
		if price <= 0.0:
			continue

		var value := price * float(quantity)
		earned += value
		lines.append("%d x %s" % [quantity, display_label(item_name)])
		InventoryManager.remove_collectable(item_name, quantity)

	if earned <= 0.0:
		transaction.emit("Nothing in the basket the market will take.", false)
		return 0.0

	balance += earned
	balance_changed.emit(balance)
	FarmEvents.produce_sold.emit(earned)
	transaction.emit("Sold %s for %s." % [", ".join(lines), format_money(earned)], true)
	return earned


# --- naming helpers ---------------------------------------------------------

## "cabbage (B)" -> ["cabbage", "B"]. Anything without a suffix grades as "".
func split_grade(item_name: String) -> Array:
	var regex := RegEx.new()
	regex.compile(GRADE_SUFFIX_RE)
	var result := regex.search(item_name)
	if result == null:
		return [item_name, ""]
	return [result.get_string(1), result.get_string(2)]


## A player-facing name for an inventory key, grade included.
func display_label(item_name: String) -> String:
	var parts := split_grade(item_name)
	var base_name: String = parts[0]
	var grade: String = parts[1]

	var label := base_name.capitalize()
	if CropManager.library.has_crop(base_name):
		label = str(CropManager.library.get_definition(base_name).get("display_name", label))
	elif _supplies.has(base_name):
		label = supply_name(base_name)

	if grade.is_empty():
		return label
	return "%s (Grade %s)" % [label, grade]


func _spend(amount: float) -> void:
	balance = maxf(balance - amount, 0.0)
	balance_changed.emit(balance)
