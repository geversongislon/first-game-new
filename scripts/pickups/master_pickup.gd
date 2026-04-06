@tool
extends Area2D

## MasterPickup: Script unificado para coleta de cartas e equipamentos.
## Centraliza visual, lógica de coleta e física manual leve.

# --- CONFIGURAÇÕES NO INSPETOR ---
@export_group("Setup")
@export var is_random: bool = false:
	set(v):
		is_random = v
		if is_random and Engine.is_editor_hint():
			_randomize_card()
			_update_visuals()

@export_enum("Weapon", "Active", "Passive", "Consumable", "Any") var random_type: String = "Any":
	set(v):
		random_type = v
		if is_random and Engine.is_editor_hint():
			_randomize_card()
			_update_visuals()

@export_flags("Common", "Uncommon", "Rare", "Epic", "Legendary") var random_rarity_flags: int = 0:
	set(v):
		random_rarity_flags = v
		if is_random and Engine.is_editor_hint():
			_update_visuals()

@export_flags("Lv1", "Lv2", "Lv3") var level_flags: int = 1

# A propriedade card_id é gerenciada dinamicamente pelo _get_property_list
var _card_id: String = ""

# --- VARIÁVEIS DE CONTROLE ---
var can_collect: bool = true
var is_dynamic: bool = false # Ativa física manual se detectado
var card_level: int = 1:
	set(v):
		card_level = v
		if not Engine.is_editor_hint() and is_inside_tree():
			_update_level_label()

var card_charges: int = 1  # Cargas reais do consumivel dropado

# --- FÍSICA MANUAL ---
## Runs em que este pickup aparece. Vazio = todas as runs.
## Ex: [1, 2] → aparece apenas na Run 1 e Run 2.
@export var active_on_runs: Array[int] = []

@export_group("Physics")
@export var velocity: Vector2 = Vector2.ZERO
@export var fall_gravity: float = 800.0
@export var bounce_factor: float = 0.4
@export var friction: float = 12.0

func _ready() -> void:
	if Engine.is_editor_hint():
		notify_property_list_changed()
		_update_visuals()
		return

	if not active_on_runs.is_empty() and not (GameManager.runs_started in active_on_runs):
		queue_free()
		return

	# Se nasceu com velocidade, é um item dinâmico
	if velocity != Vector2.ZERO:
		is_dynamic = true
	
	if is_random:
		_randomize_card()

	var _cd := CardDB.get_card(_card_id) if _card_id != "" else null
	card_level = _pick_level(level_flags) if (_cd and _cd.type == "Weapon") else 1

	# Conecta sinal de coleta
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	_update_visuals()

func set_card_id(id: String):
	_card_id = id
	is_random = false  # ID explícito tem prioridade sobre modo aleatório
	_update_visuals()

	# Se for um drop manual (chamado pelo Player), ativa física e atraso
	if not Engine.is_editor_hint():
		is_dynamic = true
		can_collect = false
		modulate.a = 0.5
		if is_inside_tree():
			get_tree().create_timer(1.2).timeout.connect(func():
				can_collect = true
				modulate.a = 1.0
			)
		else:
			# Nó ainda não está na árvore (add_child foi deferred) — aguarda o sinal
			tree_entered.connect(func():
				get_tree().create_timer(1.2).timeout.connect(func():
					can_collect = true
					modulate.a = 1.0
				)
			, CONNECT_ONE_SHOT)

func _randomize_card():
	var type_filter = "" if random_type == "Any" else random_type
	var rarity_arr  = _flags_to_rarity_array(random_rarity_flags)
	# Boost de raridade: 2+ Trevos da Sorte → exclui Common de drops sem filtro
	if rarity_arr.is_empty() and GameManager.luck_stack_count >= 2:
		rarity_arr.append("Uncommon")
		rarity_arr.append("Rare")
		rarity_arr.append("Epic")
		rarity_arr.append("Legendary")
	var data = CardDB.get_random_card(type_filter, rarity_arr)
	if data:
		_card_id = data.id

func _update_visuals():
	# 1. ÍCONE E REFERÊNCIA DE DADOS
	var sprite = get_node_or_null("Sprite2D")
	var light = get_node_or_null("PointLight2D")
	_update_level_label()
	var target_size = 16.0
	
	# Caso Especial: Aleatório no EDITOR
	if is_random and Engine.is_editor_hint():
		if sprite:
			var rand_tex = load("res://assets/sprites/ui/hud_icons/pickup_randon.png")
			sprite.texture = rand_tex
			if rand_tex:
				var tex_size = rand_tex.get_size()
				var scale_f = target_size / max(tex_size.x, tex_size.y)
				sprite.scale = Vector2(scale_f, scale_f)
		if light:
			var preview_rarity = _flags_to_rarity_array(random_rarity_flags)
			light.color = _rarity_color(preview_rarity[-1] if not preview_rarity.is_empty() else "")
		return

	if _card_id == "" or _card_id == null: return
	
	# Usamos a classe CardDB diretamente (Static)
	var data = CardDB.get_card(_card_id)
	
	if sprite:
		if data and data.icon:
			sprite.texture = data.icon
			var tex_size = data.icon.get_size()
			var scale_f = target_size / max(tex_size.x, tex_size.y)
			sprite.scale = Vector2(scale_f, scale_f)
			
			# Ajusta o RayCast para o fundo do sprite (32px para alvo 64px)
			var ray = get_node_or_null("FloorRay")
			if ray:
				ray.target_position.y = target_size / 2.0
		else:
			# No editor, não limpamos se data for null por delay de load
			if not Engine.is_editor_hint():
				sprite.texture = null
			
	# 2. LUZ
	if light:
		if data:
			light.color = _rarity_color(data.rarity)

	# 3. BARRAS DE CARGA (consumivel)
	_update_charge_bars()

func _update_charge_bars() -> void:
	if Engine.is_editor_hint(): return
	# Remove barras antigas
	for child in get_children():
		if child.name.begins_with("_Chg"):
			remove_child(child)
			child.queue_free()
	var data := CardDB.get_card(_card_id)
	if not data or data.type != "Consumable": return
	var max_c := data.max_charges
	for i in range(max_c):
		var bar := Panel.new()
		bar.name = "_Chg%d" % i
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.size = Vector2(2, 2)
		bar.position = Vector2(6, 4 - i * 3)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.55, 0.1, 1.0) if i < card_charges else Color(0.2, 0.2, 0.2, 0.8)
		bar.add_theme_stylebox_override("panel", style)
		add_child(bar)

func _update_level_label() -> void:
	if Engine.is_editor_hint(): return
	var existing = get_node_or_null("LevelLabel")
	if existing:
		remove_child(existing)
		existing.queue_free()
	for i in range(3):
		var old := get_node_or_null("_LvPip%d" % i)
		if old:
			remove_child(old)
			old.queue_free()
	if card_level <= 1: return
	var pip_color := Color(0.4, 0.7, 1.0) if card_level == 2 else Color(1.0, 0.85, 0.2)
	var border_color := pip_color.darkened(0.45)
	for i in range(card_level):
		var pip := Panel.new()
		pip.name = "_LvPip%d" % i
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.size = Vector2(6, 6)
		pip.position = Vector2(-11, 3 - i * 7)
		var style := StyleBoxFlat.new()
		style.bg_color = pip_color
		style.border_color = border_color
		style.set_border_width_all(1)
		pip.add_theme_stylebox_override("panel", style)
		add_child(pip)

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"Legendary": return Color(1.0, 0.8, 0.2)
		"Epic":      return Color(1.0, 0.2, 1.0)
		"Rare":      return Color(0.2, 0.4, 1.0)
		"Uncommon":  return Color(0.2, 1.0, 0.2)
		"Common":    return Color(1.0, 1.0, 1.0)
		_:           return Color(0.6, 0.2, 1.0) # Any = roxo

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_dynamic: return
	
	# Gravidade
	velocity.y += fall_gravity * delta
	
	# Movimento Manual com detecção simples
	var next_pos = position + velocity * delta
	
	# Detecção de Chão (RayCast opcional ou check de colisão)
	# Para manter simples e sem RayCast, vamos apenas verificar se a v.y > 0
	# Se voce quiser algo mais preciso, adicione um RayCast2D chamado "FloorRay" na cena
	if has_node("FloorRay"):
		var ray = $FloorRay as RayCast2D
		ray.force_raycast_update()
		if ray.is_colliding() and velocity.y > 0:
			# Ajusta para a colisão global tirando a distância do raio
			# Isso evita que o pivô (centro) vá para o ponto de impacto
			global_position.y = ray.get_collision_point().y - abs(ray.target_position.y)
			velocity.y = -velocity.y * bounce_factor
			if abs(velocity.y) < 40: 
				velocity.y = 0
				is_dynamic = false 
			velocity.x = lerp(velocity.x, 0.0, friction * delta)
			return

	position = next_pos

func _on_body_entered(body: Node2D) -> void:
	if not can_collect: return

	if body.has_method("collect_card"):
		if body.collect_card(_card_id, card_level, card_charges):
			_collect_effect()

func _collect_effect() -> void:
	can_collect = false

	# Esconde o sprite e os pips de nível imediatamente
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.visible = false
	for i in range(3):
		var pip := get_node_or_null("_LvPip%d" % i)
		if pip:
			pip.visible = false

	# Pega a cor da luz antes de apagar
	var light = get_node_or_null("PointLight2D") as PointLight2D
	var flame_color := Color(1.0, 1.0, 1.0)
	if light:
		flame_color = light.color

	# Spawna partículas de chama no pai
	var parent = get_parent()
	var origin := global_position
	var spark_mat := CanvasItemMaterial.new()
	spark_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	for i in range(12):
		var p := ColorRect.new()
		p.size = Vector2(2, 2)
		# Varia a cor entre a base e um tom mais claro
		p.color = flame_color.lightened(randf_range(0.0, 0.4))
		p.material = spark_mat
		parent.add_child(p)
		p.global_position = origin + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 0.0))

		var angle := randf_range(deg_to_rad(-150), deg_to_rad(-30))  # arco subindo
		var dist  := randf_range(6.0, 18.0)
		var target_pos := p.global_position + Vector2(cos(angle) * dist, sin(angle) * dist)
		var duration   := randf_range(0.5, 1.0)

		var tw := p.create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "global_position", target_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, duration)
		tw.finished.connect(p.queue_free)

	# Apaga a luz gradualmente em 1s, depois libera o nó
	if light:
		var tw_light := create_tween()
		tw_light.tween_property(light, "energy", 0.0, 1.0)
		tw_light.tween_callback(queue_free)
	else:
		queue_free()

# --- EDITOR DROPDOWN ---

func _get_property_list():
	var properties = []
	var cards_list = ""
	var dir = DirAccess.open("res://resources/cards/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var d = load("res://resources/cards/" + file_name)
				if d and d is CardData:
					cards_list += d.id + ","
			file_name = dir.get_next()
		dir.list_dir_end()
	
	properties.append({
		"name": "card_id",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": cards_list,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	return properties

func _set(property, value):
	if property == "card_id":
		_card_id = value
		_update_visuals()
		return true
	return false

func _get(property):
	if property == "card_id":
		return _card_id
	return null

# --- HELPERS DE FLAGS ---
const _RARITIES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

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
