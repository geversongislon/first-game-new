extends Node
## Passiva Elemental — registra elemento ativo no player e spawna companion visual.
## Visual (element_type, element_color, companion_texture) configurado no .tscn via Inspector.
## Dados de gameplay (dot_damage, dot_ticks, tick_interval) vêm do CardData (.tres).
## Cada instância gerencia seu próprio dict — sem dependência entre instâncias do mesmo tipo.
## Stacking é calculado ao disparar (agregação em set_element_list no projétil).

@export var element_type: String = "poison"
@export var element_color: Color = Color(0.2, 1.0, 0.1)
## Sprite exibido no companion — set via Inspector em cada passive_X.tscn
@export var companion_texture: Texture2D = null

## Injetado pelo WeaponManager antes de setup() — fonte dos dados de gameplay
var card_data: CardData = null

var _player: Node = null
var _companion: Node2D = null
var _data: Dictionary = {}

func setup(player: CharacterBody2D) -> void:
	if card_data == null:
		push_error("passive_element: card_data não foi injetado antes de setup(). Verifique WeaponManager.")
		return
	_player = player
	_data = {
		type          = element_type,
		color         = element_color,
		dot_damage    = card_data.dot_damage,
		dot_ticks     = card_data.dot_ticks,
		tick_interval = card_data.dot_tick_interval
	}
	_player.active_elements.append(_data)
	_spawn_companion()

func _exit_tree() -> void:
	if _player and _data in _player.active_elements:
		_player.active_elements.erase(_data)
	if _companion and is_instance_valid(_companion):
		_companion.queue_free()
		_companion = null

func _spawn_companion() -> void:
	var scene := preload("res://scenes/passives/passive_element_companion.tscn") as PackedScene
	_companion = scene.instantiate() as Node2D
	_companion.element_type      = element_type
	_companion.element_color     = element_color
	_companion.companion_texture = companion_texture
	var world := _player.get_parent()
	if world:
		world.add_child(_companion)
		_companion.set_target(_player)
