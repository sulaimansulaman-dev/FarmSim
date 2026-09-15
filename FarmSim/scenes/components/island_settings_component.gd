class_name IslandSettingsComponent
extends Node

## The conditions of one island, applied to every crop sown on it.
##
## CropSimComponent carries pest chance, evaporation and temperature as exports -
## but it lives inside crop_plant.tscn, one scene shared by every crop in the
## game, so those values are global defaults. There is no way from there to say
## "this island has pests" or "this island is hotter".
##
## This component is that missing seam. It sits in a level, listens for
## FarmEvents.crop_planted, and stamps the island's conditions onto each new
## plant as it goes into the ground.
##
## Island 1 has none, so its crops keep the gentle defaults and no pest can ever
## appear there. Island 3 turns pests on. Whoever builds the seasons and weather
## islands sets temperature and evaporation here rather than touching the crop
## scene, which would change every island at once.

## Chance per day that an outbreak starts, before the crop's own
## pest_susceptibility is applied. 0.0 is a pest-free island.
@export_range(0.0, 1.0, 0.01) var pest_chance: float = 0.0

## Scales daily water loss. Above 1.0 is a hotter, drier island.
@export var evaporation_multiplier: float = 1.0

## Crop.NO_TEMPERATURE means this island does not model temperature at all, and
## crops develop at full rate whatever the season.
@export var temperature_c: float = Crop.NO_TEMPERATURE


func _ready() -> void:
	FarmEvents.crop_planted.connect(_on_crop_planted)


func _on_crop_planted(plant: CropPlant) -> void:
	# Anything wanting to override an island - the tutorial's fast crop, for one -
	# must connect after this, and then wins: callbacks run in connection order.
	plant.crop_sim.pest_chance = pest_chance
	plant.crop_sim.evaporation_multiplier = evaporation_multiplier
	plant.crop_sim.temperature_c = temperature_c
