extends Node2D

const RUN_DURATION: float = 300.0  # 5 minutos

## Área inicial que será carregada ao começar a run.
@export var initial_area: PackedScene

@onready var player: CharacterBody2D = $Player
@onready var world_container: Node2D = $WorldContainer

var run_time_left: float = RUN_DURATION
var timer_label: Label = null
var run_active: bool = false
var difficulty: float = 0.0

var _difficulty_apply_timer: float = 0.0

func _enter_tree() -> void:
	GameManager.runs_started += 1

func _ready() -> void:
	GameManager.reset_run()
	_ensure_starting_weapon()
	_setup_player_loadout()
	# Registra loadout inicial no histórico (cartas com que o player veio equipado)
	for card_id in LoadoutManager.get_equipped_cards():
		if card_id != "":
			GameManager.run_cards_history.append(card_id)
	_setup_run_timer()
	if initial_area:
		var entry_id := GameManager.current_run_start_point
		if entry_id.is_empty():
			entry_id = "ext_0"
		await SceneManager.swap_area_now(self, initial_area, entry_id)

func _process(delta: float) -> void:
	if not run_active:
		return
	if not is_instance_valid(player) or player.is_dead:
		return

	run_time_left -= delta
	run_time_left = maxf(run_time_left, 0.0)
	GameManager.run_elapsed += delta

	difficulty = 1.0 - (run_time_left / RUN_DURATION)
	_tick_difficulty_apply(delta)

	if is_instance_valid(player) and player.hud:
		player.hud.set_difficulty(difficulty)

	_update_timer_label()

	if run_time_left <= 0.0:
		run_active = false
		player.die()

## Carrega uma nova área no WorldContainer sem recarregar Player/HUD.
func load_area(area_scene: PackedScene, entry_id: String) -> void:
	SceneManager.load_area(self, area_scene, entry_id)

## Retorna o WorldContainer onde a área atual está instanciada.
func get_world_container() -> Node2D:
	return world_container

func _tick_difficulty_apply(delta: float) -> void:
	_difficulty_apply_timer -= delta
	if _difficulty_apply_timer > 0.0:
		return
	_difficulty_apply_timer = 5.0
	if not is_instance_valid(world_container):
		return
	for area in world_container.get_children():
		var enemy_container: Node = null
		if area.has_method("get_enemy_container"):
			enemy_container = area.get_enemy_container()
		else:
			enemy_container = area.get_node_or_null("Enemys")
		if not enemy_container:
			continue
		for enemy in enemy_container.get_children():
			if enemy.has_method("apply_difficulty"):
				enemy.apply_difficulty(difficulty)

func _setup_run_timer() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	timer_label = Label.new()
	timer_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	timer_label.offset_top = 3.0
	timer_label.add_theme_font_size_override("font_size", 7)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	timer_label.add_theme_constant_override("shadow_offset_x", 2)
	timer_label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(timer_label)

	run_active = true
	_update_timer_label()

func _update_timer_label() -> void:
	if not timer_label:
		return
	var minutes: int = floori(run_time_left / 60.0)
	var seconds: int = floori(run_time_left) % 60
	var text := "%02d:%02d" % [minutes, seconds]

	if run_time_left <= 30.0:
		var blink := int(run_time_left * 2) % 2 == 0
		timer_label.add_theme_color_override("font_color", Color.RED if blink else Color.WHITE)

	timer_label.text = text

func _ensure_starting_weapon() -> void:
	if GameManager.runs_started < 2:
		return
	for card_id in GameManager.equipped_cards:
		if card_id == "":
			continue
		var card := CardDB.get_card(card_id)
		if card and card.type == "Weapon":
			return
	# Nenhuma arma — equipa SMG no primeiro slot vazio
	var empty_slot := GameManager.equipped_cards.find("")
	if empty_slot != -1:
		LoadoutManager.equip_card(empty_slot + 1, "card_smg")

func _setup_player_loadout() -> void:
	if not player:
		return

	var ids = [
		LoadoutManager.equipped_card_1_id,
		LoadoutManager.equipped_card_2_id,
		LoadoutManager.equipped_card_3_id
	]

	player.weapons.unlocked_weapons.clear()

	for card_id in ids:
		player.weapons.unlocked_weapons.append(card_id)

	if player.weapons.unlocked_weapons[0] != "":
		player.weapons.equip_by_index(0)
	elif player.weapons.unlocked_weapons[1] != "":
		player.weapons.equip_by_index(1)
	elif player.weapons.unlocked_weapons[2] != "":
		player.weapons.equip_by_index(2)

	# Restaura cargas salvas dos consumíveis no loadout
	# (feito AQUI porque player._ready() roda antes de unlocked_weapons ser populado)
	var _had_consumable := false
	for i in range(player.weapons.unlocked_weapons.size()):
		var _cid: String = player.weapons.unlocked_weapons[i]
		var _cdata := CardDB.get_card(_cid)
		if _cdata and _cdata.type == "Consumable":
			var saved_charges := GameManager.equipped_card_charges[i] if i < GameManager.equipped_card_charges.size() else 0
			if saved_charges > 0:
				player.loadout_charges[i] = saved_charges
			elif player.loadout_charges[i] <= 0:
				player.loadout_charges[i] = 1
			_had_consumable = true
	if _had_consumable:
		print("[Run] Cargas restauradas: ", player.loadout_charges)

	player.weapons.loadout_changed.emit()
	player.hud.refresh_all_icons()
