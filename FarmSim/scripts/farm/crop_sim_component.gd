class_name CropSimComponent
extends Node

## Drives one Crop through Croptails' day/night cycle.
##
## The Crop model knows nothing about Godot - it only wants to be advanced one
## day at a time by whoever owns it. This component is that owner, and it is
## the entire seam between the simulation and the game.
##
## Whatever renders this crop should connect to crop's own signals in its
## _ready(). Godot readies children before parents, so by then crop exists.

## Island settings, set per level in the Inspector.
##
## Island 1 is season-negligible and pest-free, which is exactly what these
## defaults describe. Island 3 is the same island with pest_chance raised.
@export var pest_chance: float = 0.0
@export var evaporation_multiplier: float = 1.0
@export var temperature_c: float = Crop.NO_TEMPERATURE

## How fast this one plant develops compared with the real crop calendar.
## Left at 1.0 everywhere except the tutorial crop, which the tutorial speeds up
## so a beginner can see a whole cycle in a couple of minutes.
@export var growth_multiplier: float = 1.0

## Soil moisture the crop goes into the ground with. Fertiliser raises it, which
## buys the player a day or two before the first watering is due.
@export var starting_moisture: float = 0.5

var crop: Crop


func _ready() -> void:
	# Seeded from the tile the crop stands on. Every crop used to share seed 0,
	# so every plant on the island rolled the same pest on the same day. A
	# position seed differs per plant but is identical on every LAN peer, which
	# keeps outbreaks in step across devices without sending them.
	var rng_seed := 0
	var parent_2d := get_parent() as Node2D
	if parent_2d != null:
		rng_seed = hash(Vector2i(parent_2d.global_position.round()))
	crop = Crop.new(CropManager.library, rng_seed)
	DayNightCycleManager.time_tick_day.connect(on_time_tick_day)


## Plants a crop on this tile. Returns false if the id is unknown.
func plant(crop_id: String) -> bool:
	return crop.plant(crop_id, starting_moisture)


## Waters this crop. Returns false if it was already watered today.
func water() -> bool:
	return crop.water()


func on_time_tick_day(_day: int) -> void:
	crop.advance_day(evaporation_multiplier, pest_chance, temperature_c, growth_multiplier)
