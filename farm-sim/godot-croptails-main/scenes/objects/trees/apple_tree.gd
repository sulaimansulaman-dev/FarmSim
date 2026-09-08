extends Sprite2D

## A perennial fruit tree.
##
## Unlike a crop (Tomato, Corn), this tree is never consumed. It grows up
## through the same stage progression as a crop (using the existing
## GrowthCycleComponent), but once it reaches Mature it stays on the map
## forever and instead cycles between "bare" and "bearing fruit":
##
##   Sapling -> Young -> Growing -> Mature (bare)
##                                     |
##                                     v
##                    +---- fruit_regrow_days pass ----+
##                    |                                |
##                    v                                |
##             Bearing fruit  --- harvested by player --+
##
## fruit_tree_growth.png holds the bare growth-stage art (12x4 grid, 48px
## cells): row 0 = sapling (1 frame), row 1 = young (4 frames), row 2 =
## growing (6 frames), row 3 = full-grown/mature (12 frames).
##
## apple_tree_fruiting.png is the same tree at the same four sizes, but with
## fruit/blossom art layered on top (12x5 grid, 48px cells). We only use its
## row 3 (full-grown) and row 4 (just-harvested) here.

const fruit_harvest_scene: PackedScene = preload("res://scenes/objects/trees/apple_harvest.tscn")
const growth_texture: Texture2D = preload("res://assets/game/objects/trees/fruit_tree_growth.png")
const fruiting_texture: Texture2D = preload("res://assets/game/objects/trees/apple_tree_fruiting.png")

const GRID_COLUMNS := 12

## Row 3 in both sheets is the full-grown tree.
const ROW_MATURE := 3
## Frame within row 3 of apple_tree_fruiting.png that clearly shows fruit.
const FRUITING_COLUMN := 6
## Row 4 of apple_tree_fruiting.png: fruit just fell, hearts still on the ground.
const ROW_JUST_HARVESTED := 4

## How many in-game days a harvested tree takes to grow fruit again.
@export var fruit_regrow_days: int = 3

## Lets a level designer drop this scene in already fully grown, instead of
## always starting as a sapling.
@export var initial_growth_state: DataTypes.GrowthStates:
	set(state):
		if growth_cycle_component:
			growth_cycle_component.current_state = state

@onready var growth_cycle_component: GrowthCycleComponent = $GrowthCycleComponent
@onready var harvest_hurt_component: HurtComponent = $HarvestHurtComponent

var is_mature: bool = false
var has_fruit: bool = false
var _days_since_last_harvest: int = 0


func _ready() -> void:
	texture = growth_texture
	hframes = GRID_COLUMNS
	vframes = 4

	growth_cycle_component.grew_up.connect(on_grew_up)
	harvest_hurt_component.hurt.connect(on_harvested)
	DayNightCycleManager.time_tick_day.connect(on_time_tick_day)
	
	growth_cycle_component.is_watered = true
	
	on_grew_up(growth_cycle_component.current_state)


func on_grew_up(growth_state: DataTypes.GrowthStates) -> void:
	growth_cycle_component.is_watered = true
	if is_mature:
		return

	if growth_state == DataTypes.GrowthStates.Mature:
		_become_mature()
		return

	# Germination/Vegetative/Reproduction map to rows 0/1/2. Show column 0
	# of that row as a simple static frame for the stage.
	frame = int(growth_state) * GRID_COLUMNS


func _become_mature() -> void:
	is_mature = true
	texture = fruiting_texture
	vframes = 5
	frame = ROW_MATURE * GRID_COLUMNS
	# A newly-grown tree starts bearing fruit right away instead of making
	# the player wait through a first, fruitless regrow cycle.
	_days_since_last_harvest = fruit_regrow_days


func on_time_tick_day(_day: int) -> void:
	if not is_mature or has_fruit:
		return

	_days_since_last_harvest += 1
	if _days_since_last_harvest >= fruit_regrow_days:
		_grow_fruit()


func _grow_fruit() -> void:
	has_fruit = true
	frame = ROW_MATURE * GRID_COLUMNS + FRUITING_COLUMN
	harvest_hurt_component.monitoring = true


func on_harvested(_hit_damage: int) -> void:
	if not has_fruit:
		return

	call_deferred("spawn_fruit")

	has_fruit = false
	_days_since_last_harvest = 0
	harvest_hurt_component.monitoring = false

	frame = ROW_JUST_HARVESTED * GRID_COLUMNS
	await get_tree().create_timer(0.6).timeout
	if not has_fruit:
		frame = ROW_MATURE * GRID_COLUMNS


func spawn_fruit() -> void:
	var fruit_instance := fruit_harvest_scene.instantiate() as Node2D
	fruit_instance.global_position = global_position
	get_parent().add_child(fruit_instance)
