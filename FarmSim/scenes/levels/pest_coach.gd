extends CoachComponent

## Island 3's one new idea: a pest is a thing you can see and get rid of.
##
## Marlow explains it when you arrive, but a line read five minutes before the
## first caterpillar shows up is a line nobody remembers. This speaks at the
## moment it actually matters, once, and then stays quiet.

const CLEARED_SECONDS := 6.0

var _taught := false
var _plant: CropPlant = null


func _ready() -> void:
	# GDScript calls only the most-derived _ready(), so the banner and arrow
	# never get built unless this passes the call up.
	super._ready()

	FarmEvents.pest_appeared.connect(_on_pest_appeared)
	FarmEvents.pest_treated.connect(_on_pest_treated)


func _process(delta: float) -> void:
	super._process(delta)

	if not _taught or _plant == null or not is_instance_valid(_plant):
		return

	# The spray first, because you cannot act on the plant without it.
	if ToolManager.selected_tool != DataTypes.Tools.SprayPest:
		point_at_control(hud_node("ToolSpray") as Control)
	else:
		point_at_world(_plant.global_position)


func _on_pest_appeared(plant: CropPlant) -> void:
	if _taught:
		return

	_taught = true
	_plant = plant
	say("Marlow: There is your first one. Take the spray and click that plant - it costs you nothing, and every day it sits there costs you weight at harvest.")


func _on_pest_treated(_treated: CropPlant) -> void:
	if not _taught or _plant == null:
		return

	_plant = null
	stop_pointing()
	say("Marlow: That is all there is to it. Watch for them and they will hardly cost you anything.")
	get_tree().create_timer(CLEARED_SECONDS).timeout.connect(clear)
