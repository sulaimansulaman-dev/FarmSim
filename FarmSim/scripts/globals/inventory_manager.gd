extends Node

signal inventory_changed(inventory: Dictionary)

var inventory: Dictionary = {}

## amount defaults to 1 so every existing pickup keeps working unchanged.
## Crops pass a harvest weight in kilograms instead.
func add_collectable(collectable_name: String, amount: int = 1) -> void:
	inventory[collectable_name] = inventory.get(collectable_name, 0) + amount
	inventory_changed.emit(inventory)

func remove_collectable(collectable_name: String, amount: int = 1) -> void:
	inventory[collectable_name] = max(inventory.get(collectable_name, 0) - amount, 0)
	inventory_changed.emit(inventory)
