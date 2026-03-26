extends Node

@export var speed_bonus: float = 100.0
var _player = null

# O WeaponManager chama isso automaticamente ao equipar
func setup(player):
	_player = player
	_player.current_max_speed += speed_bonus
	print("Velocidade aumentada!")

# O Godot chama isso quando a carta é desequipada (o nó é removido)
func _exit_tree():
	if _player:
		_player.current_max_speed -= speed_bonus
		print("Velocidade normalizada.")

# Opcional: Impede desequipar se for perigoso (como na vida)
# func can_unequip() -> bool:
#     return true
