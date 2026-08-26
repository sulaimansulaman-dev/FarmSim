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

	quit()


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
