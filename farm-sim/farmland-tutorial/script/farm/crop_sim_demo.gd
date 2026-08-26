extends SceneTree

## Headless demonstration of the crop simulation.
##
## Run it from the project folder with:
##
##   godot --headless --script res://script/farm/crop_sim_demo.gd
##
## It plays three complete crop cycles with different player behaviour and
## prints the end-of-cycle summary for each. No scene, no UI, no art required -
## which means the crop model can be built and verified before any of that
## exists, and QA can check DEL-02's "responds correctly and repeatably" without
## clicking through the game.


func _initialize() -> void:
	var library := CropLibrary.new()
	if not library.load_from():
		push_error(library.load_error)
		print("FAILED TO LOAD CROP DATA: ", library.load_error)
		quit(1)
		return

	print("Crops loaded: ", library.crop_ids())
	for id in library.crop_ids():
		print("  %s takes %d days to mature" % [id, library.days_to_maturity(id)])

	_run_attentive_farmer(library)
	_run_neglectful_farmer(library)
	_run_untreated_pest(library)
	_compare_seasons(library)

	quit()


## Plants the same crop, tended the same way, in each season - so the only
## variable is the weather. This is the evidence behind the Level 3 lesson:
## the season you plant in decides the harvest before you touch a watering can.
func _compare_seasons(library: CropLibrary) -> void:
	_header("SCENARIO 4 - same maize, same care, four seasons")
	print("")

	var weather := WeatherSystem.new(7)
	if not weather.load_from():
		print("  could not load weather data: ", weather.load_error)
		return

	for season_id in weather.season_ids():
		# Averaged over several runs, because one roll of the weather proves
		# nothing. If the season lesson only shows up on a lucky seed, it is not
		# a lesson, it is noise.
		var total_yield := 0.0
		var total_days := 0
		var deaths := 0
		var runs := 5

		for run in range(runs):
			var season_weather := WeatherSystem.new(run * 31 + 7)
			season_weather.load_from()
			season_weather.set_season(season_id)

			var crop := Crop.new(library, run * 31 + 7)
			crop.plant("maize", 0.55)

			var days := 0
			while not crop.is_ready_to_harvest() and crop.state != Crop.State.DEAD and days < 200:
				season_weather.advance()
				crop.moisture = clampf(crop.moisture + season_weather.rainfall(), 0.0, 1.0)
				if crop.moisture < 0.45:
					crop.water(0.35)
				crop.advance_day(
					season_weather.evaporation_multiplier(),
					season_weather.pest_chance(),
					season_weather.temperature_c()
				)
				days += 1

			if crop.state == Crop.State.DEAD:
				deaths += 1
			var summary := crop.harvest()
			total_yield += float(summary["yield_kg"])
			total_days += days

		var suits := "suits maize" if weather_suits(season_id) else "WRONG SEASON"
		print("  %-8s %6.1f kg avg   %3d days avg   %d/%d died   %s" % [
			season_id.capitalize(), total_yield / runs, total_days / runs, deaths, runs, suits,
		])


## True if the named season lists maize as one of its suitable crops.
func weather_suits(season_id: String) -> bool:
	var probe := WeatherSystem.new(0)
	probe.load_from()
	probe.set_season(season_id)
	return probe.season_suits_crop("maize")


## The player waters whenever the soil starts drying out.
func _run_attentive_farmer(library: CropLibrary) -> void:
	_header("SCENARIO 1 - attentive farmer, maize")
	var crop := Crop.new(library)
	crop.plant("maize", 0.6)

	while not crop.is_ready_to_harvest() and crop.state != Crop.State.DEAD:
		if crop.moisture < 0.45:
			crop.water(0.35)
		crop.advance_day()

	_print_summary(crop.harvest())


## The player waters early on, then stops paying attention around tasselling -
## the stage where maize is most sensitive to water stress.
func _run_neglectful_farmer(library: CropLibrary) -> void:
	_header("SCENARIO 2 - stops watering at tasselling, maize")
	var crop := Crop.new(library)
	crop.plant("maize", 0.6)

	while not crop.is_ready_to_harvest() and crop.state != Crop.State.DEAD:
		var neglecting := crop.current_stage_id() in ["tasselling", "grain_fill"]
		if crop.moisture < 0.45 and not neglecting:
			crop.water(0.35)
		crop.advance_day()

	_print_summary(crop.harvest())


## Pests appear and the player never treats them.
func _run_untreated_pest(library: CropLibrary) -> void:
	_header("SCENARIO 3 - pest outbreak, never treated, beans")
	# Fixed seed, so this scenario produces the same outbreak every single run.
	var crop := Crop.new(library, 12345)
	crop.plant("beans", 0.6)

	while not crop.is_ready_to_harvest() and crop.state != Crop.State.DEAD:
		if crop.moisture < 0.45:
			crop.water(0.30)
		crop.advance_day(1.0, 0.08)

	_print_summary(crop.harvest())


func _header(title: String) -> void:
	print("")
	print("=".repeat(72))
	print(title)
	print("=".repeat(72))


func _print_summary(summary: Dictionary) -> void:
	print("")
	print("  Crop:            %s" % summary["display_name"])
	print("  Days taken:      %d" % summary["days_taken"])
	print("  Final state:     %s" % summary["state"])
	print("  Final health:    %.1f / 100" % summary["final_health"])
	print("  Potential yield: %.1f kg" % summary["potential_yield_kg"])
	print("  Actual yield:    %.1f kg  (%.1f%% lost)" % [
		summary["yield_kg"], summary["yield_lost_percent"]
	])
	print("")
	print("  %s" % summary["headline"])

	if not summary["penalties"].is_empty():
		print("")
		print("  What went wrong, and when (this is what FR-005 needs):")
		# Only the first few, so the point is visible without a wall of text.
		var shown := 0
		for penalty in summary["penalties"]:
			if shown >= 5:
				print("    ... and %d more" % (summary["penalties"].size() - shown))
				break
			print("    -%.1f%%  %s" % [penalty["percent"], penalty["explanation"]])
			shown += 1
