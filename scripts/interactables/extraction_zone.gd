extends Area2D

@export var extraction_id: String = "ext_1"
@export var extraction_name: String = "Ponto 1"

var _aura: CPUParticles2D = null

func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("extraction_zones")
		_setup_aura()

func _setup_aura() -> void:
	_aura = CPUParticles2D.new()
	add_child(_aura)

	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_aura.material = mat

	# Branco forte na base → invisível no topo
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 0.9))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	_aura.color_ramp = grad

	# Centro visual real do ColorRect com scale=1.36 aplicado a partir do left:
	# visual_left = -21, visual_right = -21 + 32*1.36 = 22.5 → centro x = 0.75
	_aura.position         = Vector2(0.75, -34.0)
	_aura.emitting         = true
	_aura.amount           = 75
	_aura.lifetime         = 2.4
	_aura.explosiveness    = 0.0   # spawn contínuo
	_aura.randomness       = 0.6

	# Emite de toda a área visual do rect
	_aura.emission_shape        = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_aura.emission_rect_extents = Vector2(29.75, 34.0)

	_aura.direction            = Vector2(0.0, -1.0)
	_aura.spread               = 12.0
	_aura.gravity              = Vector2(0.0, -6.0)
	_aura.initial_velocity_min = 2.0
	_aura.initial_velocity_max = 10.0
	_aura.scale_amount_min     = 0.2
	_aura.scale_amount_max     = 0.8

## Posição ajustada para o player spawnar aqui sem afundar no chão.
## O origin da zona fica no chão, mas o origin do player fica no centro do corpo (~23px acima dos pés).
@export var spawn_y_offset: float = -23.0

func get_spawn_position() -> Vector2:
	return global_position + Vector2(0.0, spawn_y_offset)

## Chamado quando o player entra pela extração como ponto de spawn.
## Sequência: pausa → light fade + rect shrink → queue_free.
func spawn_fade_out() -> void:
	set_process(false)
	monitoring = false

	var light: PointLight2D = $PointLight2D
	var rect: ColorRect     = $ColorRect
	var lbl: Label          = $Label

	if _aura:
		_aura.emitting = false

	await get_tree().create_timer(0.55).timeout

	var cx := (rect.offset_left + rect.offset_right) * 0.5

	var tween := create_tween().set_parallel(true)
	tween.tween_property(light, "energy",       0.0, 0.5)
	tween.tween_property(rect,  "offset_left",  cx,  0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	tween.tween_property(rect,  "offset_right", cx,  0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	tween.tween_property(lbl,   "modulate:a",   0.0, 0.3)

	await tween.finished
	queue_free()

@onready var interaction_label: Label = $InteractionLabel
@onready var progress_bar: ProgressBar = $ProgressBar

var player_in_zone: Node2D = null
var hold_time: float = 0.0
var required_time: float = 2.0

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		player_in_zone = body
		interaction_label.visible = true
		progress_bar.visible = true
		progress_bar.value = 0.0
		hold_time = 0.0

func _on_body_exited(body: Node2D) -> void:
	if body == player_in_zone:
		_set_player_flash(0.0)
		player_in_zone = null
		interaction_label.visible = false
		progress_bar.visible = false
		hold_time = 0.0

func _process(delta: float) -> void:
	if player_in_zone:
		if Input.is_key_pressed(KEY_E):
			hold_time += delta
			progress_bar.value = hold_time
			_set_player_flash(hold_time / required_time)

			if hold_time >= required_time:
				complete_extraction()
		else:
			# Reseta se soltar
			hold_time = 0.0
			progress_bar.value = 0.0
			_set_player_flash(0.0)

func _set_player_flash(amount: float) -> void:
	if not player_in_zone: return
	var sprite = player_in_zone.get_node_or_null("Visual/Sprite2D")
	if sprite and sprite.material is ShaderMaterial:
		sprite.material.set_shader_parameter("flash_amount", amount)
	var weapon_sprite = player_in_zone.weapon_sprite
	if weapon_sprite and weapon_sprite.material is ShaderMaterial:
		weapon_sprite.material.set_shader_parameter("flash_amount", amount)

func complete_extraction():
	if not player_in_zone: return
	
	set_process(false) # Evita chamadas duplas
	print("Extração Completa!")
	
	# Sincroniza o estado atual dos slots do WeaponManager → LoadoutManager
	var weapons = player_in_zone.get_node_or_null("WeaponManager")
	if weapons:
		var slots = weapons.unlocked_weapons
		for i in range(3):
			var card_id = slots[i] if i < slots.size() else ""
			LoadoutManager.equip_card(i + 1, card_id)
	
	# Salva as cargas reais dos consumíveis no loadout antes de extrair
	if "loadout_charges" in player_in_zone:
		GameManager.save_loadout_charges(player_in_zone.loadout_charges)
		print("Cargas salvas na extração: ", player_in_zone.loadout_charges)
	
	GameManager.unlock_extraction_point(extraction_id, extraction_name)
	GameManager.extract_run()
	GameManager.run_extracted = true
	SceneManager.go_to("res://scenes/ui/ui_run_end.tscn")
