extends EnemyBase

## Sentinela — imóvel, olhos expressivos.
## Estados:
##   branco  → player fora de detection_range
##   amarelo → player em detection_range (base attack_range)
##   vermelho → player em attack_range atual ou full_attack ativo; ataca
## Após 1s detectado: attack_range expande para detection_range + bonus
## Atingido de fora: full_attack por 3s (ataca em qualquer distância)

@export_group("Sentinela")
@export var eye_extra_dist: float       = 3.0   # px extras de movimento dos olhos
@export var detect_expand_delay: float  = 1.0   # s em detection antes de expandir range
@export var detect_expand_bonus: float  = 50.0  # px além do detection_range ao expandir
@export var full_attack_duration: float = 3.0   # s do modo full attack após ser atingido de fora

var _base_attack_range: float = 0.0
var _detect_timer: float      = 0.0
var _full_attack_timer: float = 0.0
var _eye_wander_pos: Vector2  = Vector2.ZERO
var _eye_wander_timer: float  = 0.0
var _eye_kb_local: Vector2    = Vector2.ZERO

func _ready() -> void:
	super._ready()
	_base_attack_range = attack_range

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_tick_sentinel(delta)

func _tick_sentinel(delta: float) -> void:
	# Modo full attack — atingido de fora do detection_range
	if _full_attack_timer > 0.0:
		_full_attack_timer -= delta
		attack_range = detection_range * 4.0
		_sync_area_shapes()
		if _full_attack_timer <= 0.0:
			attack_range  = _base_attack_range
			_detect_timer = 0.0
			_sync_area_shapes()
		return

	# Player não detectado → reseta
	if not is_instance_valid(target_player):
		_detect_timer = 0.0
		attack_range  = _base_attack_range
		_sync_area_shapes()
		return

	# Player detectado — acumula timer e ajusta range
	_detect_timer += delta

	if _detect_timer >= detect_expand_delay:
		attack_range = detection_range + detect_expand_bonus
	else:
		attack_range = _base_attack_range
	_sync_area_shapes()

func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO, kb: float = 0.0, is_crit: bool = false) -> void:
	super.take_damage(amount, hit_direction, kb, is_crit)

	# Knockback visual do olho — converte direção mundial para espaço local do sprite
	if hit_direction != Vector2.ZERO and is_instance_valid(sprite):
		_eye_kb_local = sprite.global_transform.basis_xform_inv(hit_direction * 4.0)

	# Ativa full attack apenas se o player estiver FORA do detection_range
	for body in get_tree().get_nodes_in_group("player"):
		var dist := global_position.distance_to(body.global_position)
		if dist > detection_range:
			_full_attack_timer = full_attack_duration
			_sync_area_shapes()
		break

func _tick_eye(delta: float) -> void:
	if not eye_sprite: return

	if _eye_dmg_timer > 0.0:
		_eye_dmg_timer -= delta
		if _eye_dmg_timer <= 0.0:
			_eye_busy = false
			eye_sprite.play("idle")

	if not _eye_busy:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_eye_busy = true
			eye_sprite.play("blink")
			_blink_timer = randf_range(3.0, 7.0)

	# Cor do olho
	var in_attack_rng := is_instance_valid(target_player) and \
			global_position.distance_to(target_player.global_position) <= attack_range

	var target_color: Color
	if _full_attack_timer > 0.0 or in_attack_rng:
		target_color = Color(1.0, 0.2, 0.2)       # vermelho
	elif is_instance_valid(target_player):
		target_color = Color(1.0, 0.85, 0.1)       # amarelo
	else:
		target_color = Color.WHITE

	eye_sprite.modulate = eye_sprite.modulate.lerp(target_color, delta * 6.0)

	# Posição — espaço-mundo convertido para local do Sprite2D (funciona com qualquer rotação)
	# Em full_attack usa attack_target (qualquer player na cena), senão usa target_player
	var look := _EYE_LOOK_DIST + eye_extra_dist
	var move := _EYE_MOVE_DIST + eye_extra_dist

	var eye_target: Node2D = target_player
	if not is_instance_valid(eye_target) and _full_attack_timer > 0.0:
		eye_target = attack_target

	var world_offset := Vector2.ZERO
	if is_instance_valid(eye_target):
		world_offset = (eye_target.global_position - global_position).normalized() * look
	elif _full_attack_timer <= 0.0:
		# Estado branco: olho vagueia lentamente
		_eye_wander_timer -= delta
		if _eye_wander_timer <= 0.0:
			var angle := randf_range(0.0, TAU)
			var dist  := randf_range(0.3, 1.0) * look
			_eye_wander_pos   = Vector2(cos(angle), sin(angle)) * dist
			_eye_wander_timer = randf_range(1.5, 3.5)
		world_offset = _eye_wander_pos
	if velocity.length() > 5.0:
		world_offset += velocity.normalized() * move
	world_offset = world_offset.limit_length(look + move)

	var local_offset := sprite.global_transform.basis_xform_inv(world_offset)
	var lerp_speed := 1.5 if (not is_instance_valid(eye_target) and _full_attack_timer <= 0.0) else 10.0
	eye_sprite.position = eye_sprite.position.lerp(_EYE_BASE_POS + local_offset, delta * lerp_speed) + _eye_kb_local
	_eye_kb_local = _eye_kb_local.lerp(Vector2.ZERO, delta * 12.0)
