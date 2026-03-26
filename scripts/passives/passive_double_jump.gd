extends Node
class_name PassiveDoubleJump

var _player: CharacterBody2D = null
var _applied: bool = false

func setup(player: CharacterBody2D) -> void:
	_player = player
	_apply_buff()

func _apply_buff() -> void:
	if _applied or _player == null: return

	_player.max_jumps += 1
	_applied = true
	print("PassiveDoubleJump: Pulo extra ativado!")

func _exit_tree() -> void:
	if not _applied or _player == null: return

	_player.max_jumps -= 1
	_applied = false
	print("PassiveDoubleJump: Pulo extra removido.")

func can_unequip() -> bool:
	return true
