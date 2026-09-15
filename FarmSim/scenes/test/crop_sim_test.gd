extends Node2D

## Proves the seam works: a crop planted here grows, dries out, takes damage and
## matures, driven only by Croptails' day tick. No sprites, no tilemap, no
## player - if the numbers move correctly here, the simulation is sound and
## anything left wrong afterwards is a rendering problem.
##
## Open this scene and press F6. Watch the Output panel.

const TEST_CROP := "maize"

@onready var crop_sim: CropSimComponent = $CropSimComponent


func _ready() -> void:
	# A game day is 1440/game_speed real seconds, so the usual speed of 5 would
	# make this test take two hours. Run it far faster than the game ever does.
	DayNightCycleManager.game_speed = 1000.0

	crop_sim.crop.stage_changed.connect(on_stage_changed)
	crop_sim.crop.died.connect(on_died)

	if not crop_sim.plant(TEST_CROP):
		push_error("Could not plant %s" % TEST_CROP)
		return

	print("Planted %s - watching it grow" % TEST_CROP)
	DayNightCycleManager.time_tick_day.connect(on_day)


func on_day(day: int) -> void:
	var c := crop_sim.crop
	print("day %2d | %-12s | health %5.1f | moisture %.2f %s" % [
		day, c.current_stage_name(), c.health, c.moisture,
		"<- THIRSTY, watering" if c.is_thirsty() else ""
	])

	# Tend it properly, so this run shows a well-managed crop.
	if c.is_thirsty():
		c.water()


func on_stage_changed(stage_id: String, display_name: String) -> void:
	print("   -> now %s (%s)" % [display_name, stage_id])


func on_died() -> void:
	print("   -> the crop died")
