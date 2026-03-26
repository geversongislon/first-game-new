extends Node
## Passiva: Trevo da Sorte
## Bônus de loot escalado por stacks. Configurável via Inspector desta cena.

@export var coin_multiplier_bonus: float = 0.5  # +50% moedas por trevo
@export var card_chance_bonus: float = 0.05     # +5% chance de carta por trevo

var _applied := false
var _companion: Node2D = null

func setup(player) -> void:
	_apply_buff()
	_spawn_visuals(player)

func _apply_buff() -> void:
	if _applied: return
	GameManager.luck_coin_multiplier += coin_multiplier_bonus
	GameManager.luck_card_chance_bonus += card_chance_bonus
	GameManager.luck_stack_count += 1
	_applied = true

func _spawn_visuals(player: Node2D) -> void:
	var companion_scene = preload("res://scenes/passives/passive_luck_companion.tscn")
	_companion = companion_scene.instantiate()
	# Adiciona como irmão do player (não filho) para movimento independente com delay
	var world = player.get_parent()
	if world:
		world.add_child(_companion)
		_companion.set_target(player)

func _exit_tree() -> void:
	if _companion and is_instance_valid(_companion):
		_companion.queue_free()
		_companion = null
	if not _applied: return
	GameManager.luck_coin_multiplier -= coin_multiplier_bonus
	GameManager.luck_card_chance_bonus -= card_chance_bonus
	GameManager.luck_stack_count -= 1
	_applied = false
