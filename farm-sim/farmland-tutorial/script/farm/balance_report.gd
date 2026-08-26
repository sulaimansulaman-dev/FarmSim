extends Node

## Balance report. Not a pass/fail test - a measuring tool.
##
##   godot --headless --path . res://scenes/test/balance_report.tscn
##
## Plays a full season several times over under different play styles and
## reports how many crops died, how many reached harvest, and what share of the
## damage came from each cause. Run it after changing anything in crops.json or
## weather.json; a tuning change that looks harmless in the file can make the
## game unwinnable or trivial, and neither shows up in the unit tests.
##
## What it caught when it was written: waterlogging was over half of all damage
## in the game, because a single storm drowned any reasonably-watered crop.
## Soil now drains, and pests are the dominant cause of loss - which is the
## lesson the game is meant to teach.

# Reproduces the world scene's day loop exactly: rain first, then the day.
func run(lib, threshold: float, treat: bool, water_per_day: int, seed_v: int, heed_forecast: bool = false) -> Dictionary:
	var w := WeatherSystem.new(seed_v); w.load_from(); w.set_season("summer")
	var crops: Array = []
	for i in range(12):
		var c := Crop.new(lib, seed_v * 100 + i)
		c.plant("maize" if i % 2 == 0 else "beans", 0.55)
		crops.append(c)

	for day in range(200):
		var alive := 0
		for c in crops:
			if c.state == Crop.State.GROWING: alive += 1
		if alive == 0: break

		# The player only manages so many plots a day.
		var watered := 0
		for c in crops:
			if c.state != Crop.State.GROWING: continue
			if treat and c.pest_active: c.treat_pest()
			# A player who reads the forecast skips irrigating before rain.
			var rain_coming: bool = heed_forecast and w.rainfall() > 0.0
			if c.moisture < threshold and watered < water_per_day and not rain_coming:
				c.water(0.35); watered += 1
		for c in crops:
			if c.state != Crop.State.GROWING and c.state != Crop.State.MATURE: continue
			c.moisture = clampf(c.moisture + w.rainfall(), 0.0, 1.0)
			c.advance_day(w.evaporation_multiplier(), w.pest_chance(), w.temperature_c())
		w.advance()

	var dead := 0; var ripe := 0; var causes := {}
	for c in crops:
		if c.state == Crop.State.DEAD: dead += 1
		if c.state == Crop.State.MATURE: ripe += 1
		for p in c.yield_penalties:
			causes[p["cause"]] = float(causes.get(p["cause"], 0.0)) + float(p["percent"])
	return {"dead": dead, "ripe": ripe, "causes": causes}

func _ready() -> void:
	var lib := CropLibrary.new(); lib.load_from()
	print("%-46s %6s %6s   %s" % ["play style", "died", "ripe", "damage by cause"])
	var styles = [
		["waters all 12 daily, treats pests",      0.5, true,  12],
		["waters all 12 daily, ignores pests",     0.5, false, 12],
		["waters 6 a day, treats pests",           0.5, true,  6],
		["waters 3 a day, treats pests",           0.5, true,  3],
		["waters only when nearly dry (0.3), all", 0.3, true,  12],
		["never waters, treats pests",             0.0, true,  0],
		["READS FORECAST: skips watering before rain", 0.5, true, 12, true],
		["READS FORECAST but ignores pests",       0.5, false, 12, true],
	]
	for st in styles:
		var d := 0; var r := 0; var agg := {}
		for s in range(6):
			var heed: bool = st.size() > 4 and st[4]
			var out := run(lib, st[1], st[2], st[3], s * 13 + 5, heed)
			d += int(out["dead"]); r += int(out["ripe"])
			for k in out["causes"]: agg[k] = float(agg.get(k, 0.0)) + float(out["causes"][k])
		var parts: Array = []
		var total := 0.0
		for k in agg: total += float(agg[k])
		for k in agg:
			parts.append("%s %d%%" % [k, round(float(agg[k]) / max(total, 1.0) * 100.0)])
		print("%-46s %5.1f  %5.1f   %s" % [st[0], d / 6.0, r / 6.0, "  ".join(parts)])
	get_tree().quit()
