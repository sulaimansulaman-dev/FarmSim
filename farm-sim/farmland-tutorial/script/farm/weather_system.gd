class_name WeatherSystem
extends RefCounted

## Picks the weather for each day and hands the crop simulation the two numbers
## it actually cares about: how fast soil dries out, and how likely pests are.
##
## Scope note
## ----------
## Weather is Baseline work - FR-002 requires one environmental event, and
## drought is it. Seasons are Level 3 / Conditional (C2). Both are read from
## data/weather.json, so switching seasons on later is a data change, not a
## rewrite. Until then the game runs in a single season.
##
## The forecast is shown to the player BEFORE they act each day. That is
## deliberate: a hidden dice roll punishes the player, a visible forecast
## teaches them to plan. Only the second one is a serious game.

signal weather_changed(weather: Dictionary)

const DATA_PATH := "res://data/weather.json"

var load_error: String = ""
var current: Dictionary = {}
var season_id: String = "summer"

var _weather_types: Dictionary = {}
var _seasons: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init(rng_seed: int = 0) -> void:
	_rng.seed = rng_seed


func load_from(path: String = DATA_PATH) -> bool:
	load_error = ""
	_weather_types.clear()
	_seasons.clear()

	if not FileAccess.file_exists(path):
		load_error = "Weather data file not found at %s" % path
		return false

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		load_error = "Weather data at %s is not valid JSON." % path
		return false

	for entry in parsed.get("weather_types", []):
		_weather_types[entry["id"]] = entry
	for entry in parsed.get("seasons", []):
		_seasons[entry["id"]] = entry

	if _weather_types.is_empty():
		load_error = "Weather data defines no weather types."
		return false
	if not _seasons.has(season_id):
		# Fall back to whatever season is defined first rather than failing.
		season_id = _seasons.keys()[0] if not _seasons.is_empty() else ""

	return true


## Rolls tomorrow's weather using the current season's weights.
func advance() -> Dictionary:
	var weights: Dictionary = {}
	if _seasons.has(season_id):
		weights = _seasons[season_id].get("weather_weights", {})

	current = _pick_weighted(weights)
	weather_changed.emit(current)
	return current


func set_season(new_season_id: String) -> bool:
	if not _seasons.has(new_season_id):
		return false
	season_id = new_season_id
	return true


func season() -> Dictionary:
	return _seasons.get(season_id, {})


func season_ids() -> Array:
	return _seasons.keys()


## True if this crop is a sensible choice for the current season.
## Level 3 uses this to teach planting-time decisions (Conditional scope).
func season_suits_crop(crop_id: String) -> bool:
	var suits: Array = season().get("suits_crops", [])
	return crop_id in suits


# --- values the crop simulation consumes ------------------------------------

func evaporation_multiplier() -> float:
	return float(current.get("evaporation_multiplier", 1.0))


func rainfall() -> float:
	return float(current.get("rainfall", 0.0))


func pest_chance() -> float:
	return float(current.get("pest_chance", 0.0))


func forecast_text() -> String:
	return str(current.get("forecast_text", ""))


func display_name() -> String:
	return str(current.get("display_name", "Unknown"))


# --- internals --------------------------------------------------------------

func _pick_weighted(weights: Dictionary) -> Dictionary:
	if weights.is_empty():
		# No season data - fall back to the first defined weather type so the
		# simulation keeps running rather than dividing by zero.
		return _weather_types.values()[0]

	var total := 0.0
	for id in weights:
		if _weather_types.has(id):
			total += float(weights[id])

	if total <= 0.0:
		return _weather_types.values()[0]

	var roll := _rng.randf() * total
	var running := 0.0
	for id in weights:
		if not _weather_types.has(id):
			continue
		running += float(weights[id])
		if roll <= running:
			return _weather_types[id]

	return _weather_types.values()[0]
