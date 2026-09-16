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

## The same harvest, with the market grade the produce came in at. Kept apart
## from crop_harvested so the tutorial, which predates grading and only counts
## harvests, does not have to care about it.
signal crop_graded(crop_id: String, grade: String, yield_kg: float)

## A pest outbreak started on this plant, or was just cleared from it.
signal pest_appeared(plant: CropPlant)
signal pest_treated(plant: CropPlant)

## Something the player should be told, in one line, on the HUD.
##
## Used for seed-viability warnings, refused purchases and season turns. It is a
## signal rather than a direct call into a UI node because the thing raising the
## advisory - the crops cursor, the economy, the calendar - has no business
## knowing whether a HUD exists. On a level with no banner, nothing listens and
## nothing breaks.
signal advisory(message: String)

## Something was picked up off the ground - produce, fruit, a log. Carries the
## inventory key, so graded crops arrive as "cabbage (A)".
signal item_collected(item_name: String, amount: int)

## Money came in at the market, and how much.
signal produce_sold(amount: float)

## A supply (spray, organic control, fertiliser, sapling) was bought.
signal supply_bought(supply_id: String)

## A sapling went into the ground (Stage 4).
signal tree_planted(tree: Node2D)

## An old tree was felled for timber (Stage 4).
signal tree_chopped()
