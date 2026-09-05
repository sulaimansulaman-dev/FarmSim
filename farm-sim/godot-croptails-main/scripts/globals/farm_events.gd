extends Node

## One place for "something happened on the farm".
##
## The tutorial needs to know when the player tills, sows, waters and harvests.
## None of those systems know about each other and none of them should: the
## field cursor, the crops cursor and the plant itself each announce what they
## did and carry on. Whatever wants to listen - the tutorial today, quests or
## the anonymised session log later - connects here instead.
##
## Kept separate from CropManager on purpose. CropManager loads and owns the
## crop data; folding gameplay events into it would make it two things at once.

## World position of the cell that was just turned over.
signal soil_tilled(position: Vector2)

signal crop_planted(plant: CropPlant)
signal crop_watered(plant: CropPlant)
signal crop_harvested(crop_id: String, yield_kg: float)
