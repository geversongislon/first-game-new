extends Node
class_name PassiveHealth

@export var health_bonus: int = 50

var _player: CharacterBody2D = null
var _applied: bool = false

func setup(player: CharacterBody2D) -> void:
	_player = player
	_apply_buff()

func _apply_buff() -> void:
	if _applied or _player == null: return

	_player.max_health += health_bonus
	_player.current_health += health_bonus
	_applied = true

	print("PassiveHealth Equipada: +", health_bonus, " Vida Máxima. Status Atual: ", _player.current_health, "/", _player.max_health)

func _exit_tree() -> void:
	if not _applied or _player == null: return

	# Retira o buff
	_player.max_health -= health_bonus
	_player.current_health -= health_bonus
	_applied = false

	print("PassiveHealth Removida: -", health_bonus, " Vida Máxima. Status Atual: ", _player.current_health, "/", _player.max_health)

# Função obrigatória para a Trava de Segurança da UI
func can_unequip() -> bool:
	if _player == null: return true

	# Se tirar a carta vai matar o jogador, bloqueia
	if _player.current_health - health_bonus <= 0:
		return false

	return true
