class_name CropPlant
extends Node2D

## One planted crop on one tile
## there is one of these for every crop in the game
## not one scene per crop type
## which crop, time and sprite frame all comes from crops.json
## by way of CropManager.
## new crop = JSON entry, not a new scene

## basic_plants.png is 6 columns by 2 rows, and Sprite2D numbers frames left to
## right, top to bottom. So frame = row * 6 + column.
const SHEET_COLUMNS := 6

const crop_harvest_scene := preload("res://scenes/objects/plants/crop_harvest.tscn")

@export var crop_id : String = "maize"

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var crop_sim: CropSimComponent = $CropSimComponent
@onready var watering_particles: GPUParticles2D = $WateringParticles
@onready var status_icon: CropStatusIcon = $StatusIcon
@onready var pest_sprite: Sprite2D = $PestSprite
@onready var watering_hurt_component: HurtComponent = $WateringHurtComponent
@onready var tilling_hurt_component: HurtComponent = $TillingHurtComponent

func _ready() -> void:
	crop_sim.crop.stage_changed.connect(on_stage_changed)
	crop_sim.crop.matured.connect(on_matured)
	crop_sim.crop.died.connect(on_died)
	crop_sim.crop.pest_appeared.connect(on_pest_appeared)
	crop_sim.crop.pest_cleared.connect(on_pest_cleared)

	watering_hurt_component.hurt.connect(on_watered)
	tilling_hurt_component.hurt.connect(on_harvested)

	if not crop_sim.plant(crop_id):
		push_error("CropPlant: unknown crop id '%s'" % crop_id)
		queue_free()
		return

	add_to_group("crop_plant")
	status_icon.watch(crop_sim.crop)
	update_sprite()

func update_sprite() -> void:
	var definition: Dictionary = CropManager.library.get_definition(crop_id)
	var row: int = int(definition.get("sprite_row", 0))
	var column: int = int(crop_sim.crop.current_stage().get("sprite_col", 1))
	sprite_2d.frame = row * SHEET_COLUMNS + column


func on_stage_changed(_stage_id: String, _display_name: String) -> void:
	update_sprite()


func on_matured() -> void:
	update_sprite()


## A pest is a creature sitting on the plant, not a badge floating above it, so
## it gets its own sprite rather than a slot in the status icon. A crop can be
## infested and thirsty at the same time and the player needs to see both.
func on_pest_appeared() -> void:
	pest_sprite.visible = true


func on_pest_cleared() -> void:
	pest_sprite.visible = false


## Treats this plant. Nothing is returned - the crop's own signals drive the view.
##
## Spraying is not a "hit" like watering or harvesting. Those need a player
## animation state, and the character spritesheet has none for spraying, so this
## works the way planting does: the cursor finds the crop and acts on it.
func spray() -> void:
	if crop_sim.crop.treat_pest():
		return

	# Nothing to treat. Say so rather than silently swallowing the click - a
	# wasted treatment is itself the lesson, and the model already logs it.
	status_icon.refuse()


func on_watered(_hit_damage: int) -> void:
	if not crop_sim.water():
		return

		# Moisture just moved, so the thirsty badge may no longer be true.
	status_icon.refresh()
	FarmEvents.crop_watered.emit(self)

	watering_particles.emitting = true
	await get_tree().create_timer(2.0).timeout
	watering_particles.emitting = false


func on_harvested(_hit_damage: int) -> void:
	if not crop_sim.crop.is_ready_to_harvest():
		# The hoe now collides with a crop at every stage, so this is a real
		# swing that deserves an answer rather than a silent nothing.
		status_icon.refuse()
		return

	var summary: Dictionary = crop_sim.crop.harvest()
	print("Harvested %s: %s" % [crop_id, summary])
	FarmEvents.crop_harvested.emit(crop_id, float(summary["yield_kg"]))

	# Deferred, and before queue_free: we are inside the hurt component's
	# physics callback, where adding a body to the tree is not allowed yet.
	# This is the same ordering the base game's corn.gd uses.
	call_deferred("spawn_harvest", int(round(float(summary["yield_kg"]))))
	queue_free()


## Drops the produce as a pickup the player walks over — how every collectable
## in Croptails reaches the inventory.
func spawn_harvest(amount_kg: int) -> void:
	if amount_kg <= 0:
		return

	var harvest := crop_harvest_scene.instantiate()
	harvest.setup(crop_id, amount_kg)
	harvest.global_position = global_position
	get_parent().add_child(harvest)


func on_died() -> void:
	sprite_2d.modulate = Color.DARK_GOLDENROD
