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

@export var crop_id : String = "maize"

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var crop_sim: CropSimComponent = $CropSimComponent
@onready var watering_particles: GPUParticles2D = $WateringParticles
@onready var flowering_particles: GPUParticles2D = $FloweringParticles
@onready var watering_hurt_component: HurtComponent = $WateringHurtComponent
@onready var tilling_hurt_component: HurtComponent = $TillingHurtComponent

func _ready() -> void:
	crop_sim.crop.stage_changed.connect(on_stage_changed)
	crop_sim.crop.matured.connect(on_matured)
	crop_sim.crop.died.connect(on_died)

	watering_hurt_component.hurt.connect(on_watered)
	tilling_hurt_component.hurt.connect(on_harvested)

	if not crop_sim.plant(crop_id):
		push_error("CropPlant: unknown crop id '%s'" % crop_id)
		queue_free()
		return

	update_sprite()

func update_sprite() -> void:
	var definition: Dictionary = CropManager.library.get_definition(crop_id)
	var row: int = int(definition.get("sprite_row", 0))
	var column: int = int(crop_sim.crop.current_stage().get("sprite_col", 1))
	sprite_2d.frame = row * SHEET_COLUMNS + column


func on_stage_changed(_stage_id: String, _display_name: String) -> void:
	update_sprite()


## Only a mature crop can be harvested, so only now does the hoe collide with it.
func on_matured() -> void:
	update_sprite()
	tilling_hurt_component.monitoring = true
	flowering_particles.emitting = true


func on_watered(_hit_damage: int) -> void:
	if not crop_sim.water():
		return

	watering_particles.emitting = true
	await get_tree().create_timer(2.0).timeout
	watering_particles.emitting = false


func on_harvested(_hit_damage: int) -> void:
	if not crop_sim.crop.is_ready_to_harvest():
		return

	var summary: Dictionary = crop_sim.crop.harvest()
	print("Harvested %s: %s" % [crop_id, summary])
	queue_free()


func on_died() -> void:
	sprite_2d.modulate = Color.DARK_GOLDENROD
