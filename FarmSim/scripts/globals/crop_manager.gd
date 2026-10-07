extends Node

## Loads the crop definitions once at startup and hands the same library to
## every crop in the game.
##
## This is an autoload because CropLibrary parses a JSON file. One library
## shared by the whole field costs one parse; a library per plant would cost
## one parse per plant, for identical data.

var library: CropLibrary


func _ready() -> void:
	library = CropLibrary.new()

	# A bad data file must fail loudly. Crops that silently never grow are far
	# harder to diagnose than an error on startup that names the problem.
	if not library.load_from():
		push_error("CropManager could not load crop data. " + library.load_error)
		return

	print("CropManager loaded %d crops: %s" % [library.crop_ids().size(), str(library.crop_ids())])
