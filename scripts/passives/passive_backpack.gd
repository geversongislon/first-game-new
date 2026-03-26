extends Node
class_name PassiveBackpack

@export var slot_bonus: int = 3

func setup(_player: CharacterBody2D) -> void:
	GameManager.expand_backpack(slot_bonus)

func can_unequip() -> bool:
	return false
