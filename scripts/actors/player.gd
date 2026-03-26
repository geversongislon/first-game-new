extends CharacterBody2D
"""
Player controller (2D platformer / pixel art)
- Hollow-like responsiveness: accel/decel ground/air + jump cut
- Quality of life: coyote time + jump buffer
- Ranged attack: charged shot + recoil
- Cosmetic: eyes offset based on movement direction (does not affect physics)
"""

# ============================================================
# CONFIG - STATS (base values)
# ============================================================
@export var base_max_speed: float = 70.0
@export var base_max_health: int = 100

# ============================================================
# CONFIG - MOVEMENT (tweak in Inspector)
# ============================================================
@export var accel_ground: float = 650.0
@export var decel_ground: float = 800.0
@export var accel_air: float = 350.0
@export var decel_air: float = 225.0

@export var jump_velocity: float = -130.0
@export var gravity: float = 400.0
@export var jump_cut_multiplier: float = 0.45
@export var max_fall_speed: float = 300.0

# ============================================================
# CONFIG - JUMP ASSISTS
# ============================================================
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.15

# ============================================================
# SCENES / REFERENCES
# ============================================================
@onready var visual: Node2D = $Visual
@onready var sprite: AnimatedSprite2D = $Visual/Sprite2D
@onready var eye_sprite: AnimatedSprite2D = $Visual/Sprite2D/Sprite2D

@onready var hand_pivot: Node2D = $HandPivot
var weapon_sprite: AnimatedSprite2D = null
var muzzle_light: PointLight2D = null
var weapon_ambient_light: PointLight2D = null
var _current_weapon_visual: WeaponVisual = null

@onready var weapons: WeaponManager = $WeaponManager
@onready var hud: CanvasLayer = $HUD

# ============================================================
# RUNTIME STATE
# ============================================================
var current_max_speed: float = 70.0
## Ativo durante o Slow Mo — compensa o delta reduzido para o player se mover normalmente
var slow_mo_compensation: bool = false
var max_health: int = 100
var current_health: int = 100

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

# --- MECH: EXTRA JUMPS ---
var max_jumps: int = 1
var jumps_left: int = 1

var is_charging: bool = false
var _just_double_jumped: bool = false
var charge_time: float = 0.0

@export var eye_max_offset: Vector2 = Vector2(2.0, 1.0)
@export var eye_blink_interval: Vector2 = Vector2(2.0, 5.0)
var _eye_base_pos: Vector2 = Vector2.ZERO
var _hand_pivot_base_x: float = 0.0
var _hand_pivot_base_y: float = 0.0
var _eye_x_history: Array[float] = []
var _eye_y_history: Array[float] = []
var _eye_damaged: bool = false
var _eye_blinking: bool = false
var _blink_timer: float = 0.0


var in_knockback: bool = false
@export var knockback_damp: float = 450.0
var flash_tween: Tween
var _muzzle_tween: Tween
var is_dead: bool = false
var is_invulnerable: bool = false


# ============================================================
# LIFECYCLE
# ============================================================
func _ready() -> void:
	current_max_speed = base_max_speed
	add_to_group("player")
	randomize()
	if sprite.material:
		sprite.material = sprite.material.duplicate()

	if hud and weapons:
		hud.connect_to_weapon_manager(weapons)
		weapons.weapon_equipped.connect(_on_weapon_equipped)
		weapons.loadout_changed.connect(update_stats_from_loadout)

	# Inicializa os status com base no que está equipado
	update_stats_from_loadout()

	_eye_base_pos = eye_sprite.position
	_hand_pivot_base_x = hand_pivot.position.x
	_hand_pivot_base_y = hand_pivot.position.y
	_blink_timer = randf_range(eye_blink_interval.x, eye_blink_interval.y)
	eye_sprite.sprite_frames = eye_sprite.sprite_frames.duplicate()
	eye_sprite.sprite_frames.set_animation_loop("piscar", false)
	eye_sprite.sprite_frames.set_animation_loop("dano", false)
	eye_sprite.play("idle")
	eye_sprite.animation_finished.connect(_on_eye_animation_finished)
	_speed_trail_loop()
	_idle_sweat_loop()

func update_stats_from_loadout() -> void:
	# Agora o recálculo bruto das Passivas não ocorre varrendo um dicionário e multiplicando aqui.
	# As passivas instanciadas (via _sync_passives no WeaponManager) vão manualmente 
	# somar/subtrair `max_health` e `current_max_speed` da referência do Player no _ready() e _exit_tree()
	# Só precisamos garantir a sanidade da vida atual (não deixar passar do máximo)
	if current_health > max_health:
		current_health = max_health
		
		
	# Se a vida atual for maior que a nova vida máxima, ajusta o teto
	if current_health > max_health:
		current_health = max_health
		
	print("Player Stats Atualizados: Speed=", current_max_speed, " MaxHealth=", max_health)

func can_unequip_card(card_id: String, slot_index: int) -> bool:
	if card_id == "": return true
	
	# Busca no WeaponManager a instância específica daquela slot
	var instance_id = card_id + "_" + str(slot_index)
	if weapons and weapons.active_passives.has(instance_id):
		var passive_node = weapons.active_passives[instance_id]
		if passive_node.has_method("can_unequip"):
			return passive_node.can_unequip()
	return true


func _on_eye_animation_finished() -> void:
	match eye_sprite.animation:
		"dano":
			_eye_damaged = false
			eye_sprite.play("idle")
		"piscar":
			_eye_blinking = false
			eye_sprite.play("idle")

func _trigger_eye_blink() -> void:
	if _eye_damaged or _eye_blinking: return
	if not eye_sprite.sprite_frames.has_animation("piscar"): return
	_eye_blinking = true
	eye_sprite.play("piscar")

func _update_eye_follow() -> void:
	if _eye_damaged:
		return
	var diff := get_global_mouse_position() - global_position
	var dir_x := clampf(diff.x / 40.0, -1.0, 1.0)
	var dir_y := clampf(diff.y / 40.0, -1.0, 1.0)

	_eye_x_history.append(dir_x)
	if _eye_x_history.size() > 10:
		_eye_x_history.pop_front()

	_eye_y_history.append(dir_y)
	if _eye_y_history.size() > 1:
		_eye_y_history.pop_front()

	var lx := _eye_x_history[0] if _eye_x_history.size() >= 10 else dir_x
	var ly := _eye_y_history[0]
	var flip := -1.0 if sprite.flip_h else 1.0
	eye_sprite.position = Vector2(
		roundf(_eye_base_pos.x * flip + lx * eye_max_offset.x),
		roundf(_eye_base_pos.y + ly * eye_max_offset.y)
	)

func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO, kb: float = 0.0, _is_crit: bool = false) -> void:
	if is_dead: return
	if is_invulnerable: return
	flash_white()
	_show_damage_number(amount)
	_spawn_hit_smoke()
	if eye_sprite.sprite_frames.has_animation("dano"):
		_eye_damaged = true
		eye_sprite.play("dano")
	GameManager.run_damage_taken += amount
	current_health -= amount
	print("Player recebeu dano! Health: ", current_health)
	if hit_direction != Vector2.ZERO and kb > 0.0:
		in_knockback = true
		velocity.x = sign(hit_direction.x) * kb
	if current_health <= 0:
		die(amount)

func heal(amount: int) -> void:
	if is_dead: return
	current_health = min(current_health + amount, max_health)

func muzzle_flash() -> void:
	if not muzzle_light: return
	if _muzzle_tween and _muzzle_tween.is_running():
		_muzzle_tween.kill()
	muzzle_light.energy = 2.35
	_muzzle_tween = create_tween()
	_muzzle_tween.tween_property(muzzle_light, "energy", 0.0, 0.08)

func flash_white() -> void:
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		return
	if flash_tween and flash_tween.is_running():
		flash_tween.kill()
	mat.set_shader_parameter("flash_amount", 0.5)
	flash_tween = create_tween()
	flash_tween.tween_property(mat, "shader_parameter/flash_amount", 0.0, 0.12)

func _show_damage_number(amount: int) -> void:
	if not damage_number_scene: return
	var dn = damage_number_scene.instantiate()
	var world_pos := global_position + Vector2(randf_range(-8.0, 8.0), randf_range(-18.0, -10.0))
	var par := get_parent()
	dn.position = par.to_local(world_pos)
	par.add_child(dn)
	dn.setup(amount, Color(1.0, 0.18, 0.18))

func _spawn_hit_smoke() -> void:
	var root := get_parent()
	if not root: return
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for i in range(10):
		var p := ColorRect.new()
		var sz := randi_range(1, 3)
		p.size = Vector2(sz, sz)
		var shade := randf_range(0.0, 0.15)
		p.color = Color(shade, shade, shade, 1.0)
		p.material = mat
		root.add_child(p)
		p.global_position = global_position + Vector2(randf_range(-6.0, 6.0), randf_range(-12.0, 0.0))
		var angle := randf_range(deg_to_rad(-150), deg_to_rad(-30))
		var dist := randf_range(6.0, 18.0)
		var target := p.global_position + Vector2(cos(angle) * dist, sin(angle) * dist)
		var dur := randf_range(0.3, 0.6)
		var tw := p.create_tween().set_parallel(true)
		tw.tween_property(p, "global_position", target, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, dur).set_delay(dur * 0.4)
		tw.finished.connect(p.queue_free)

@onready var coin_scene = preload("res://scenes/loot/pickup_coin.tscn")
@onready var damage_number_scene = preload("res://scenes/ui/damage_number.tscn")

func die(killing_damage: int = 0) -> void:
	is_dead = true
	print("Player morreu!")
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("slow_motion"):
		var slow_ms: int = clamp(800 + killing_damage * 12, 1000, 3000)
		cam.slow_motion(slow_ms)
	# Desativa processamento e física para evitar erros de callback
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0

	# Efeito visual de sumiço (opcional, pode ser uma animação)
	visual.visible = false
	if hand_pivot: hand_pivot.visible = false

	_spawn_death_fx()

	# Dropa tudo que o player tem (Loot Fountain)
	drop_all_loot()

	# Registra o inimigo que matou
	GameManager.run_killing_enemy = GameManager._last_hit_source

	# Espera o loot "espirrar" antes de ir para a tela de fim de run (ignora time_scale)
	await get_tree().create_timer(2.0, true, false, true).timeout

	# Sincroniza weapons atuais da run → GameManager antes de mostrar run_end
	if weapons:
		for i in range(3):
			var card_id := weapons.unlocked_weapons[i] if i < weapons.unlocked_weapons.size() else ""
			GameManager.equipped_cards[i] = card_id

	SceneManager.go_to("res://scenes/ui/ui_run_end.tscn")

func _spawn_death_fx() -> void:
	var root := get_parent()
	if not root: return

	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	for i in range(110):
		var p := ColorRect.new()
		p.size = Vector2(2, 2) if randf() < 0.5 else Vector2(3, 3) if randf() < 0.25 else Vector2(1, 1)
		var shade := randf_range(0.0, 0.12)
		p.color = Color(shade, shade, shade, 1.0)
		p.material = mat
		root.add_child(p)
		p.global_position = global_position + Vector2(randf_range(-12.0, 12.0), randf_range(-16.0, 4.0))

		var angle := randf_range(deg_to_rad(-180), deg_to_rad(0))
		var dist := randf_range(25.0, 80.0)
		var target := p.global_position + Vector2(cos(angle) * dist, sin(angle) * dist)
		var dur := randf_range(1.2, 3.2)

		var tw := p.create_tween().set_parallel(true)
		tw.tween_property(p, "global_position", target, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, dur).set_delay(dur * 0.35)
		tw.finished.connect(p.queue_free)

func drop_all_loot() -> void:
	print("Player: Iniciando Loot Fountain na morte...")

	# 1. Drop de Moedas da Run
	var coins = GameManager.run_coins
	for i in range(coins):
		_spawn_loot_item(coin_scene, "")

	# 2. Drop de Itens da Mochila
	for i in range(GameManager.run_backpack.size()):
		var card_id = GameManager.run_backpack[i]
		if card_id != "":
			var lvl = GameManager.run_backpack_levels[i] if i < GameManager.run_backpack_levels.size() else 1
			_spawn_loot_item(dropped_card_scene, card_id, lvl)

	# 3. Drop de Itens Equipados (Loadout — slots 1, 2, 3)
	if weapons:
		for i in range(weapons.unlocked_weapons.size()):
			var card_id = weapons.unlocked_weapons[i]
			if card_id != "":
				var lvl = GameManager.equipped_card_levels[i] if i < GameManager.equipped_card_levels.size() else 1
				_spawn_loot_item(dropped_card_scene, card_id, lvl)

	# Nota: reset_run() é chamado em run._ready() ao iniciar a próxima run,
	# para preservar os stats até o jogador fechar a tela de fim de run.
	GameManager.equipped_cards = ["", "", ""]
	LoadoutManager.sync_from_game_manager(["", "", ""])
	GameManager.save_game()

func _spawn_loot_item(scene: PackedScene, card_id: String, card_level: int = 1) -> void:
	if not scene: return
	var item = scene.instantiate()

	# Configura antes de adicionar à cena para evitar conflito com queries de física
	if card_id != "" and item.has_method("set_card_id"):
		item.set_card_id(card_id)
	if "card_level" in item:
		item.card_level = card_level
	if "velocity" in item:
		item.velocity = Vector2(randf_range(-80, 80), randf_range(-80, -220))
	if "is_dynamic" in item:
		item.is_dynamic = true

	var parent = get_parent()
	var spawn_pos = global_position
	parent.call_deferred("add_child", item)
	item.set_deferred("global_position", spawn_pos)

func _on_weapon_equipped(_weapon_id: String, _slot_index: int) -> void:
	if _current_weapon_visual:
		_current_weapon_visual.queue_free()
		_current_weapon_visual = null
		weapon_sprite = null
		muzzle_light = null
		weapon_ambient_light = null

	var w = weapons.get_current_weapon()
	if not w or not w.card_data or not w.card_data.weapon_visual_scene:
		return

	_current_weapon_visual = w.card_data.weapon_visual_scene.instantiate() as WeaponVisual
	hand_pivot.position.x = _hand_pivot_base_x + _current_weapon_visual.pivot_offset.x
	hand_pivot.position.y = _hand_pivot_base_y + _current_weapon_visual.pivot_offset.y
	hand_pivot.add_child(_current_weapon_visual)

	weapon_sprite = _current_weapon_visual.sprite
	muzzle_light = _current_weapon_visual.muzzle_light
	weapon_ambient_light = _current_weapon_visual.ambient_light

	if weapon_sprite:
		weapon_sprite.visible = false
		if sprite.material:
			weapon_sprite.material = sprite.material.duplicate()
		weapon_sprite.animation_finished.connect(_on_weapon_animation_finished)
		await get_tree().process_frame
		if is_instance_valid(weapon_sprite):
			weapon_sprite.visible = true
			weapon_sprite.play("idle")
		
func _on_weapon_animation_finished() -> void:
	if weapon_sprite and weapon_sprite.animation != "idle" and weapon_sprite.sprite_frames.has_animation("idle"):
		weapon_sprite.play("idle")

func collect_card(card_id: String, card_level: int = 1, card_charges: int = 1) -> bool:
	"""Função universal para coletar qualquer tipo de carta (Arma, Passiva, Ativa)."""
	GameManager.run_cards_history.append(card_id)
	var data = CardDB.get_card(card_id)
	if not data:
		# Fallback para IDs legados se necessário
		var converted = CardDB.get_card_id_from_weapon(card_id)
		if converted != "":
			card_id = converted
			data = CardDB.get_card(card_id)
		if not data: return false

	# Se for uma arma, tenta colocar nos slots principais (1, 2, 3)
	if data.type == "Weapon":
		var added = weapons.unlock(card_id)
		if added:
			# Aplica nível da carta recolhida ao slot que acabou de ser ocupado
			var slot_idx := weapons.unlocked_weapons.find(card_id)
			if slot_idx != -1 and slot_idx < GameManager.equipped_card_levels.size():
				GameManager.equipped_card_levels[slot_idx] = card_level
				weapons.equip_by_index(slot_idx)
				weapons.loadout_changed.emit() # HUD precisa re-ler o nível correto
			else:
				weapons.equip_by_id(card_id)
			return true

	# Consumível: preenche slot existente antes de abrir novo
	if data.type == "Consumable":
		var remaining: int = card_charges

		# Prioridade 1: preencher slot já existente no loadout com espaço
		for i in range(weapons.unlocked_weapons.size()):
			if weapons.unlocked_weapons[i] == card_id and remaining > 0:
				var space: int = data.max_charges - loadout_charges[i]
				if space > 0:
					var added: int = mini(remaining, space)
					loadout_charges[i] += added
					remaining -= added
					if hud: hud.refresh_all_icons()
					if remaining <= 0:
						return true
					break

		# Prioridade 2: preencher slot já existente na mochila com espaço
		if remaining > 0:
			for i in range(GameManager.run_backpack.size()):
				if GameManager.run_backpack[i] == card_id:
					while GameManager.run_backpack_charges.size() <= i:
						GameManager.run_backpack_charges.append(0)
					var space: int = data.max_charges - GameManager.run_backpack_charges[i]
					if space > 0:
						var added: int = mini(remaining, space)
						GameManager.run_backpack_charges[i] += added
						remaining -= added
						GameManager.run_backpack_changed.emit()
						if remaining <= 0:
							return true
						break

		# Prioridade 3: slot vazio no loadout
		if remaining > 0:
			for i in range(weapons.unlocked_weapons.size()):
				if weapons.unlocked_weapons[i] == "":
					weapons.unlocked_weapons[i] = card_id
					loadout_charges[i] = remaining
					if i < GameManager.equipped_card_levels.size():
						GameManager.equipped_card_levels[i] = card_level
					weapons.loadout_changed.emit()
					if hud: hud.refresh_all_icons()
					return true

		# Prioridade 4: mochila (slot vazio)

	# Se for Passiva, Ativa, Consumível (sem slot) ou slots cheios, vai para a mochila
	if GameManager.add_to_run_backpack(card_id, card_level, card_charges):
		return true
	else:
		print("Mochila Cheia! Não é possível pegar a carta: ", card_id)
		return false

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("open_backpack"):
		toggle_backpack()
		
	# --- Physics core ---
	# Durante slow-mo o delta é reduzido pelo time_scale — compensar para o player mover normalmente
	var eff_delta := delta / Engine.time_scale if slow_mo_compensation and Engine.time_scale > 0.0 and Engine.time_scale < 1.0 else delta

	_apply_gravity(eff_delta)
	_update_coyote(eff_delta)
	_update_jump_buffer(eff_delta)

	# Só processa pulo se a mochila estiver fechada
	if not is_backpack_open:
		_handle_jump()

	# --- Knockback / Horizontal movement ---
	if in_knockback:
		# Desacelera apenas pelo knockback_damp — _handle_horizontal não roda para não cancelar
		velocity.x = move_toward(velocity.x, 0.0, knockback_damp * eff_delta)
		if abs(velocity.x) < 5.0:
			in_knockback = false
	else:
		var input_x := _get_move_input() if not is_backpack_open else 0.0
		_handle_horizontal(eff_delta, input_x)
		_flip_sprite(input_x)

	# --- Commit movement ---
	# Durante slow-mo, move_and_slide usa o physics delta reduzido internamente.
	# Escalar velocity compensa isso e mantém o player em velocidade normal.
	var _ts_comp := 1.0 / Engine.time_scale if slow_mo_compensation and Engine.time_scale > 0.0 and Engine.time_scale < 1.0 else 1.0
	velocity *= _ts_comp
	move_and_slide()
	velocity /= _ts_comp
	_update_animation()

	# --- Attacks & Active Abilities (Bloqueados se mochila aberta) ---
	if not is_backpack_open and not is_loot_ui_open:
		if Input.is_action_just_pressed("mouse_click"):
			if weapons.current_card_data and weapons.current_card_data.type == "Active":
				execute_active_ability(weapons.current_card_data)
			else:
				weapons.handle_attack_pressed()
				
		if Input.is_action_pressed("mouse_click"):
			weapons.handle_attack_held(delta)
			
		if Input.is_action_just_released("mouse_click"):
			weapons.handle_attack_released()

		if Input.is_action_just_pressed("aim"):
			weapons.handle_aim_pressed()
		if Input.is_action_pressed("aim"):
			weapons.handle_aim_held(delta)
		if Input.is_action_just_released("aim"):
			weapons.handle_aim_released()

		if Input.is_action_just_pressed("reload"):
			var current_weapon = weapons.get_current_weapon()
			if current_weapon and current_weapon.has_method("start_reload"):
				current_weapon.start_reload()

		# Habilidades Ativas por hotkey dedicada (SHIFT / F / C / V)
		for action in ["active_ability_dash", "active_ability_f", "active_ability_c", "active_ability_v"]:
			if Input.is_action_just_pressed(action):
				_try_activate_by_action(action)

		if Input.is_action_just_pressed("weapon_1"):
			weapons.equip_by_index(0)
		if Input.is_action_just_pressed("weapon_2"):
			weapons.equip_by_index(1)
		if Input.is_action_just_pressed("weapon_3"):
			weapons.equip_by_index(2)
		
		_update_weapon_rotation()

var is_backpack_open: bool = false
var is_loot_ui_open: bool = false
var loadout_charges: Array[int] = [0, 0, 0]

func toggle_backpack():
	is_backpack_open = !is_backpack_open
	if is_backpack_open:
		print("Modo Mochila: Ativado (Inputs bloqueados)")
	else:
		print("Modo Mochila: Desativado")
	
	if hud:
		hud.set_backpack_mode(is_backpack_open)

var ability_cooldowns: Dictionary = {}

func execute_active_ability(card: CardData) -> void:
	if ability_cooldowns.get(card.id, 0.0) > 0.0:
		return

	if not card.active_scene:
		push_warning("[Player] Carta '%s' não tem active_scene configurada." % card.id)
		return

	var ability = card.active_scene.instantiate()
	if not ability is BaseActiveAbility:
		push_warning("[Player] A cena da carta '%s' não é uma BaseActiveAbility." % card.id)
		ability.queue_free()
		return

	ability.player = self
	ability.card_data = card
	ability.stack_level = weapons.get_stack_level(card.id)
	ability.configure()
	if ability.follow_player:
		add_child(ability)
	else:
		get_parent().add_child(ability)
		ability.global_position = global_position + ability.spawn_offset
	ability.execute()

	ability_cooldowns[card.id] = card.cooldown

func _try_activate_by_action(action: String) -> void:
	for card_id in weapons.unlocked_weapons:
		var card := CardDB.get_card(card_id)
		if card and card.type == "Active" and card.activation_input_action == action:
			execute_active_ability(card)
			return
	# Consumíveis no loadout
	for i in range(weapons.unlocked_weapons.size()):
		var card := CardDB.get_card(weapons.unlocked_weapons[i])
		if card and card.type == "Consumable" and card.activation_input_action == action:
			_use_consumable(i, card)
			return

func _use_consumable(slot_idx: int, card: CardData) -> void:
	if ability_cooldowns.get(card.id, 0.0) > 0.0: return
	if loadout_charges[slot_idx] <= 0: return

	if card.active_scene:
		var ability = card.active_scene.instantiate()
		if ability is BaseActiveAbility:
			ability.player = self
			ability.card_data = card
			ability.configure()
			if ability.follow_player:
				add_child(ability)
			else:
				get_parent().add_child(ability)
				ability.global_position = global_position + ability.spawn_offset
			ability.execute()
		else:
			ability.queue_free()

	loadout_charges[slot_idx] -= 1
	ability_cooldowns[card.id] = card.charge_cooldown

	if loadout_charges[slot_idx] <= 0:
		weapons.unlocked_weapons[slot_idx] = ""
		loadout_charges[slot_idx] = 0
		weapons.loadout_changed.emit()

	# Sempre atualiza HUD ao usar consumível (visual de barras muda)
	if hud: hud.refresh_all_icons()

# --- DROP DE CARTAS PARA O MUNDO ---
@onready var dropped_card_scene = preload("res://scenes/loot/pickup_card.tscn")

func drop_card_into_world(card_id: String, card_level: int = 1, charges: int = 1) -> void:
	if card_id == "": return

	var card_node = dropped_card_scene.instantiate()
	# Adiciona ao pai (fase) para não se mover com o player
	get_parent().add_child(card_node)

	# Posição inicial (centro do player)
	card_node.global_position = global_position

	# Força o ID, nível e cargas da carta no novo pickup
	if card_node.has_method("set_card_id"):
		card_node.set_card_id(card_id)
	if "card_level" in card_node:
		card_node.card_level = card_level
	if "card_charges" in card_node:
		card_node.card_charges = charges
		card_node._update_charge_bars()

	# Lança para frente baseado na escala visual do player (-1 ou 1)
	var throw_dir = 1.0 if visual.scale.x > 0 else -1.0

	card_node.velocity = Vector2(throw_dir * 100, -180)
	if "is_dynamic" in card_node:
		card_node.is_dynamic = true

	print("Player: Dropou a carta ", card_id, " lvl ", card_level, " para o mundo.")

func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_9 and event.shift_pressed:
			_debug_add_pistol()

func _debug_add_pistol() -> void:
	var slot := weapons.unlocked_weapons.find("")
	if slot == -1:
		print("[DEBUG] Loadout cheio")
		return
	weapons.unlocked_weapons[slot] = "card_pistola"
	weapons.loadout_changed.emit()
	if weapons.current_weapon_id == "":
		weapons.equip_by_index(slot)
	if hud: hud.refresh_all_icons()
	print("[DEBUG] Pistola → slot ", slot + 1)

func _process(delta: float) -> void:
	# Atualiza cooldowns
	for id in ability_cooldowns.keys():
		if ability_cooldowns[id] > 0:
			ability_cooldowns[id] -= delta
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_trigger_eye_blink()
		_blink_timer = randf_range(eye_blink_interval.x, eye_blink_interval.y)
	if _eye_blinking and not eye_sprite.is_playing():
		_eye_blinking = false
		eye_sprite.play("idle")
	_update_eye_follow()

func _update_weapon_rotation() -> void:
	if not weapon_sprite or not weapon_sprite.visible: return

	var mouse_pos = get_global_mouse_position()
	hand_pivot.look_at(mouse_pos)

	var is_looking_left = mouse_pos.x < global_position.x
	if _current_weapon_visual:
		_current_weapon_visual.set_facing(is_looking_left)
# ============================================================
# INPUT HELPERS
# ============================================================
func _get_move_input() -> float:
	return Input.get_axis("ui_left", "ui_right")


# ============================================================
# MOVEMENT
# ============================================================
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		if velocity.y > max_fall_speed:
			velocity.y = max_fall_speed


func _update_coyote(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta


func _update_jump_buffer(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta
		

func _handle_jump() -> void:
	# Reseta os pulos ao tocar o chão
	if is_on_floor():
		jumps_left = max_jumps
	
	# Pulo buffered ou pressionado agora (Ground Jump / Coyote Jump)
	if jump_buffer_timer > 0.0:
		if coyote_timer > 0.0:
			# Pulo Inicial (Chão)
			velocity.y = jump_velocity
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
			jumps_left -= 1
			_trigger_eye_blink()
		elif jumps_left > 0 and max_jumps > 1:
			# Pulo no Ar (Pulo Duplo)
			velocity.y = jump_velocity
			jump_buffer_timer = 0.0
			jumps_left -= 1
			_just_double_jumped = true
			_trigger_eye_blink()
			print("Pulo Duplo executado! Restantes: ", jumps_left)
		
	# Jump cut: soltar o botão corta a subida
	if Input.is_action_just_released("ui_accept") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier
		
		
func _handle_horizontal(delta: float, input_x: float) -> void:
	# Accel toward target speed when input exists; otherwise decel to 0.
	if input_x != 0.0:
		var accel := accel_ground if is_on_floor() else accel_air
		velocity.x = move_toward(velocity.x, input_x * current_max_speed, accel * delta)
	else:
		var decel := decel_ground if is_on_floor() else decel_air
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)


func _flip_sprite(input_x: float) -> void:
	if input_x != 0.0:
		sprite.flip_h = input_x < 0.0
		eye_sprite.flip_h = sprite.flip_h
		var flip := -1.0 if sprite.flip_h else 1.0
		var weapon_x_off := _current_weapon_visual.pivot_offset.x if _current_weapon_visual else 0.0
		hand_pivot.position.x = (_hand_pivot_base_x + weapon_x_off) * flip

func _update_animation() -> void:
	# Não interrompe animações de uma só vez (dash, etc.)
	if sprite.animation == "dash" and sprite.is_playing():
		return
	if _just_double_jumped:
		_just_double_jumped = false
		sprite.play("jump")
		return
	var target: String
	if not is_on_floor():
		target = "jump"
	elif abs(velocity.x) > 5.0:
		target = "walking"
	else:
		target = "idle"
	if sprite.animation != target:
		sprite.play(target)

func _speed_trail_loop() -> void:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	const THRESHOLD_MULT := 2.0 # acima de 2× base_max_speed ativa o trail
	const SCALE_RANGE := 8.0 # velocidade para atingir máximo de partículas
	while is_instance_valid(self ):
		await get_tree().create_timer(0.03).timeout
		if not is_instance_valid(self ): return
		var spd := absf(velocity.x)
		var threshold := base_max_speed * THRESHOLD_MULT
		if spd <= threshold: continue
		var root := get_parent()
		if not root: continue
		var t := clampf((spd - threshold) / (base_max_speed * SCALE_RANGE), 0.0, 1.0)
		var count := int(lerp(3.0, 10.0, t))
		for i in range(count):
			var p := ColorRect.new()
			p.size = Vector2(2, 2) if randf() < 0.35 else Vector2(1, 1)
			p.color = Color(0.0, 0.0, 0.0, 1.0)
			p.material = mat
			root.add_child(p)
			p.global_position = global_position + Vector2(randf_range(-4.0, 4.0), randf_range(-20.0, 8.0))
			var target_pos := p.global_position + Vector2(randf_range(-2.0, 2.0), randf_range(-5.0, -10.0))
			var dur := randf_range(1.0, 1.8)
			var tw := p.create_tween().set_parallel(true)
			tw.tween_property(p, "global_position", target_pos, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(p, "modulate:a", 0.0, dur).set_delay(dur * 0.65)
			tw.finished.connect(p.queue_free)

func _idle_sweat_loop() -> void:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var idle_time := 0.0
	while is_instance_valid(self ):
		await get_tree().create_timer(0.1).timeout
		if not is_instance_valid(self ): return
		var is_idle := is_on_floor() and absf(velocity.x) < 5.0
		if is_idle:
			idle_time += 0.1
		else:
			idle_time = 0.0
		if idle_time < 3.0: continue
		# A cada ~0.4s quando em idle, emite 1-2 gotículas
		if fmod(idle_time, 0.4) > 0.1: continue
		var root := get_parent()
		if not root: continue
		for i in range(randi_range(1, 2)):
			var p := ColorRect.new()
			p.size = Vector2(1, 1)
			var shade := randf_range(0.15, 0.30)
			p.color = Color(shade, shade, shade, 1.0)
			p.material = mat
			root.add_child(p)
			p.global_position = global_position + Vector2(randf_range(-7.0, 7.0), randf_range(-18.0, 6.0))
			var target_pos := p.global_position + Vector2(randf_range(-2.0, 2.0), randf_range(-4.0, -9.0))
			var dur := randf_range(1.8, 3.2)
			var tw := p.create_tween().set_parallel(true)
			tw.tween_property(p, "global_position", target_pos, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(p, "modulate:a", 0.0, dur).set_delay(dur * 0.55)
			tw.finished.connect(p.queue_free)
