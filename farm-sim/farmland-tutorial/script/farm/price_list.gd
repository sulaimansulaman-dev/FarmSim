class_name PriceList
extends RefCounted

## Seed costs and market prices, read from data/economy.json.
##
## SCOPE WARNING
## -------------
## The economy is DEL-05 and belongs to the Economy developer, not to the crop
## simulation. This class is deliberately the smallest thing that works: it
## looks up a price and it does arithmetic. It has no shop, no transactions, no
## market fluctuation and no persistence, because building those here would be
## taking someone else's deliverable.
##
## It exists because the GDD requires the crop-selection screen to show seed
## cost, growth duration and expected payout, and a selection screen cannot
## show a price that does not exist anywhere.
##
## When DEL-05 lands, this should be replaced rather than extended.

const DATA_PATH := "res://data/economy.json"

var load_error: String = ""
var symbol: String = "R"
var starting_balance: float = 0.0

var _crops: Dictionary = {}


func load_from(path: String = DATA_PATH) -> bool:
	load_error = ""
	_crops.clear()

	if not FileAccess.file_exists(path):
		load_error = "Economy data file not found at %s" % path
		return false

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		load_error = "Economy data at %s is not valid JSON." % path
		return false

	var currency: Dictionary = parsed.get("currency", {})
	symbol = str(currency.get("symbol", "R"))
	starting_balance = float(currency.get("starting_balance", 0.0))

	var crops = parsed.get("crops", {})
	if typeof(crops) != TYPE_DICTIONARY or crops.is_empty():
		load_error = "Economy data defines no crop prices."
		return false
	_crops = crops

	return true


func has_price(crop_id: String) -> bool:
	return _crops.has(crop_id)


func seed_cost(crop_id: String) -> float:
	return float(_crops.get(crop_id, {}).get("seed_cost", 0.0))


func price_per_kg(crop_id: String) -> float:
	return float(_crops.get(crop_id, {}).get("price_per_kg", 0.0))


## What a perfectly grown crop would sell for. This is the headline number on
## the planting screen, and it is deliberately the BEST case - the gap between
## it and what the player actually earns is the lesson.
func expected_payout(crop_id: String, base_yield_kg: float) -> float:
	return base_yield_kg * price_per_kg(crop_id)


## Best-case profit: what the crop pays less what the seed cost.
func expected_profit(crop_id: String, base_yield_kg: float) -> float:
	return expected_payout(crop_id, base_yield_kg) - seed_cost(crop_id)


func format_money(amount: float) -> String:
	return "%s%.0f" % [symbol, amount]
