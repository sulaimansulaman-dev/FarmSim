extends Node

## The seasonal calendar, for Stage 5.
##
## Off by default, same as the economy: the earlier islands are written as
## "season-negligible" and their crops carry Crop.NO_TEMPERATURE, which means
## they develop at full rate whatever the weather. Switching seasons on globally
## would quietly make Island 1's tutorial cabbage stop growing in winter, so a
## level opts in through StageDirector.
##
## How a season reaches a crop
## ---------------------------
## SeasonManager owns the calendar and nothing else. It does not touch plants.
## IslandSettingsComponent is still the thing that stamps conditions onto a new
## plant - it just asks here for the temperature instead of using a fixed export
## when the level is a seasonal one. One seam, not two.
##
## The pre-season warning fires a day before the turn, not on it. A warning that
## arrives with the frost is not a warning, it is a bereavement notice.

signal season_changed(season: Dictionary)
signal season_warning(message: String, next_season: Dictionary)

const DATA_PATH := "res://data/seasons.json"

var enabled: bool = false
var load_error: String = ""

var days_per_season: int = 8
var season_index: int = 0

var _seasons: Array = []
var _last_day: int = -1
var _warned_for_index: int = -1


func _ready() -> void:
	if not _load():
		push_error("SeasonManager could not load season data. " + load_error)
		return
	DayNightCycleManager.time_tick_day.connect(_on_day)


func _load() -> bool:
	load_error = ""
	if not FileAccess.file_exists(DATA_PATH):
		load_error = "Season data file not found at %s" % DATA_PATH
		return false

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		load_error = "Season data at %s is not valid JSON." % DATA_PATH
		return false

	days_per_season = int(parsed.get("days_per_season", 8))
	_seasons = parsed.get("seasons", [])
	if _seasons.is_empty():
		load_error = "Season data defines no seasons."
		return false
	return true


## Called by StageDirector. start_index lets a stage open in a chosen season -
## the seasons island starts in spring so the first turn the player sees is a
## kind one.
func configure(seasons_enabled: bool, start_index: int = 0) -> void:
	enabled = seasons_enabled
	season_index = start_index % maxi(_seasons.size(), 1)
	_last_day = -1
	_warned_for_index = -1
	if enabled:
		season_changed.emit(season())


# --- the calendar -----------------------------------------------------------

func _on_day(day: int) -> void:
	if not enabled or _seasons.is_empty():
		return

	# The clock starts at whatever day the level was authored with, so measure
	# from the first tick this stage saw rather than from day zero.
	if _last_day < 0:
		_last_day = day
		return

	var elapsed := day - _last_day
	if elapsed <= 0:
		return
	_last_day = day

	var day_in_season := day % days_per_season

	# One day left in this season: warn, once.
	if day_in_season == days_per_season - 1 and _warned_for_index != season_index:
		_warned_for_index = season_index
		var upcoming: Dictionary = _seasons[(season_index + 1) % _seasons.size()]
		season_warning.emit(str(upcoming.get("warning", "")), upcoming)

	if day_in_season == 0:
		season_index = (season_index + 1) % _seasons.size()
		season_changed.emit(season())


# --- queries ----------------------------------------------------------------

func season() -> Dictionary:
	if _seasons.is_empty():
		return {}
	return _seasons[season_index]


func season_id() -> String:
	return str(season().get("id", ""))


func display_name() -> String:
	return str(season().get("display_name", "-"))


func next_season() -> Dictionary:
	if _seasons.is_empty():
		return {}
	return _seasons[(season_index + 1) % _seasons.size()]


## The temperature to hand the crop simulation. Crop.NO_TEMPERATURE when seasons
## are off, which is the "does not model temperature" case the model already
## understands.
func temperature_c() -> float:
	if not enabled:
		return Crop.NO_TEMPERATURE
	return float(season().get("temperature_c", 22.0))


func evaporation_multiplier() -> float:
	if not enabled:
		return 1.0
	return float(season().get("evaporation_multiplier", 1.0))


func teaching_note() -> String:
	return str(season().get("teaching_note", ""))


## Whether this season is a sensible one to sow this crop in.
func season_suits_crop(crop_id: String) -> bool:
	if not enabled:
		return true
	var suits: Array = season().get("suits_crops", [])
	return crop_id in suits


## Seed viability check, run before planting (the "crop seed viability
## validation" in the stage spec).
##
## It reports rather than refuses. Being allowed to plant maize in winter and
## then watching it sit in the ground doing nothing teaches the lesson; a
## disabled button just puzzles the player. Returns a warning string, empty when
## the choice is a sound one.
func viability_warning(crop_id: String) -> String:
	if not enabled:
		return ""

	var definition: Dictionary = CropManager.library.get_definition(crop_id)
	if definition.is_empty():
		return ""

	var crop_name := str(definition.get("display_name", crop_id))
	var minimum := float(definition.get("min_growth_temp_c", -999.0))
	var temperature := temperature_c()

	if temperature <= minimum:
		return "%s will not develop at all in %s - %.0f degrees is below the %.0f it needs." % [
			crop_name, display_name(), temperature, minimum
		]

	if not season_suits_crop(crop_id):
		return "%s is out of season in %s. It will grow, but slowly, and yield less." % [
			crop_name, display_name()
		]

	return ""
