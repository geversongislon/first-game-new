@tool
extends Node2D
class_name LootBox

## LootBox: Baú interativo que requer segurar E para abrir.
## Após abrir, exibe um popup com cartas para escolha.

@export_group("Hold to Open")
@export var required_time: float = 2.0

@export_group("Loot Config")
@export_enum("Any", "Weapon", "Active", "Passive", "Consumable") var card_type: String = "Any"
@export_flags("Common", "Uncommon", "Rare", "Epic", "Legendary") var rarity_flags: int = 0
@export_flags("Lv1", "Lv2", "Lv3") var level_flags: int = 1
@export var card_count: int = 3

var hold_time: float = 0.0
var opened: bool = false
var _player_nearby: Node2D = null
var once_per_save: bool = false
var chest_id: String = ""

@onready var _interact_area: Area2D = $InteractArea
@onready var _interact_label: Label = $InteractLabel
@onready var _progress_bar: ProgressBar = $ProgressBar
@onready var _sprite: AnimatedSprite2D = $Sprite2D
@onready var _light: PointLight2D = $PointLight2D

const _RARITIES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_interact_label.visible = false
	_progress_bar.visible = false
	if once_per_save and chest_id != "" and chest_id in GameManager.opened_loot_boxes:
		_spawn_as_already_opened()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or opened or not _player_nearby:
		return
	if Input.is_key_pressed(KEY_E):
		hold_time += delta
		_progress_bar.value = hold_time / required_time
		if hold_time >= required_time:
			_open()
	else:
		hold_time = 0.0
		_progress_bar.value = 0.0

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_nearby = body
		if not opened:
			_interact_label.visible = true
			_progress_bar.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body == _player_nearby:
		_player_nearby = null
		_interact_label.visible = false
		_progress_bar.visible = false
		hold_time = 0.0
		_progress_bar.value = 0.0

func _spawn_as_already_opened() -> void:
	opened = true
	set_process(false)
	if _interact_area:
		_interact_area.monitoring = false
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation(&"aberto"):
		_sprite.play(&"aberto")
	if _light:
		_light.energy = 0.0

func deactivate() -> void:
	if once_per_save and chest_id != "" and not (chest_id in GameManager.opened_loot_boxes):
		GameManager.opened_loot_boxes.append(chest_id)
		GameManager.save_game()
	_player_nearby = null
	_interact_label.visible = false
	_progress_bar.visible = false
	set_process(false)
	if _interact_area:
		_interact_area.monitoring = false
	if _light:
		var tw: Tween = create_tween()
		tw.tween_property(_light, "energy", 0.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _open() -> void:
	opened = true
	_interact_label.visible = false
	_progress_bar.visible = false

	# Visual: toca animação "aberto"
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation(&"aberto"):
		_sprite.play(&"aberto")

	# Gera cartas
	var type_filter := "" if card_type == "Any" else card_type
	var rarity_arr := _flags_to_rarity_array(rarity_flags)
	# Boost de raridade: 2+ Trevos da Sorte → exclui Common se não houver filtro
	if rarity_arr.is_empty() and GameManager.luck_stack_count >= 2:
		rarity_arr.append("Uncommon")
		rarity_arr.append("Rare")
		rarity_arr.append("Epic")
		rarity_arr.append("Legendary")
	var cards: Array = []
	for i in card_count:
		var data = CardDB.get_random_card(type_filter, rarity_arr)
		if data:
			var lvl := _pick_level(level_flags) if data.type == "Weapon" else 1
			cards.append({"card_id": data.id, "card_level": lvl})
	# Garantia lendária: 3+ Trevos da Sorte → força o primeiro slot para Lendário
	if GameManager.luck_stack_count >= 3 and not cards.is_empty():
		var leg_filter: Array[String] = []
		leg_filter.append("Legendary")
		var leg_data = CardDB.get_random_card("", leg_filter)
		if leg_data:
			cards[0] = {"card_id": leg_data.id, "card_level": 1}

	if cards.is_empty():
		queue_free()
		return

	# Spawna UI de escolha
	var choice_ui_scene: PackedScene = load("res://scenes/ui/loot_box_choice_ui.tscn")
	if choice_ui_scene:
		var ui = choice_ui_scene.instantiate() as LootBoxChoiceUI
		get_tree().root.add_child(ui)
		ui.setup(cards, self)

func _flags_to_rarity_array(flags: int) -> Array[String]:
	if flags == 0: return []
	var arr: Array[String] = []
	for i in _RARITIES.size():
		if flags & (1 << i): arr.append(_RARITIES[i])
	return arr

func _pick_level(flags: int) -> int:
	var pool := []
	if flags & 1: pool.append(1)
	if flags & 2: pool.append(2)
	if flags & 4: pool.append(3)
	return pool[randi() % pool.size()] if not pool.is_empty() else 1
