extends CharacterBody2D
class_name EnemyBase

# ══════════════════════════════════════════════════════════════════════════════
#  Three independent state systems — they never read each other's enums:
#    LifeState  — is the enemy alive?
#    MoveMode   — what movement behaviour is active?
#    AttackPhase — where is the attack cycle?
# ══════════════════════════════════════════════════════════════════════════════
enum LifeState   { ALIVE, DEAD }
enum MoveMode    { PATROL, CHASE, STUNNED }
enum AttackPhase { READY, WINDUP, COOLDOWN }
enum MoveStyle   { PATROL, RANDOM, IDLE, STATIONARY }

# ── Inspector: Stats ──────────────────────────────────────────────────────────
@export_group("Stats")
@export var max_health: int   = 100
@export var speed: float      = 15.0
@export var gravity: float    = 225.0

# ── Inspector: Movement ───────────────────────────────────────────────────────
@export_group("Movement")
@export var movement_style: MoveStyle = MoveStyle.PATROL
@export var is_flying: bool           = false
## Marca se o inimigo persegue o player ao detectá-lo.
## Não tem nenhum efeito sobre o sistema de ataque.
@export var follow_on_detect: bool    = false
@export var detection_range: float    = 63.0
## Distância preferida ao player quando em CHASE (0 = desativado, sempre persegue).
## Útil para inimigos ranged que devem manter distância enquanto atiram.
@export var keep_distance: float      = 0.0
@export var max_fall_height: float    = 0.0   # 0 = desativado; se queda > valor, para na borda e vira
@export var ledge_wait_time: float    = 0.8   # segundos parado na borda antes de virar

# ── Inspector: Jump ───────────────────────────────────────────────────────────
@export_group("Jump")
@export var can_jump_obstacles: bool = false
@export var jump_force: float        = -80.0
@export var can_climb_walls: bool     = false
@export var max_climb_height: float   = 32.0
@export var climb_speed: float        = 25.0

# ── Inspector: Attack ─────────────────────────────────────────────────────────
@export_group("Attack")
## Selecione o comportamento de ataque (MeleeSwing, MeleePounce, RangedProjectile…).
## Após escolher um tipo, apenas os parâmetros daquele tipo aparecem no inspetor.
@export var attack_behavior: AttackBehavior
@export var attack_damage: int      = 5
@export var attack_knockback: float = 50.0
@export var attack_range: float     = 15.0

# ── Inspector: Contact Damage ─────────────────────────────────────────────────
@export_group("Contact Damage")
@export var contact_damage: int              = 0
@export var contact_knockback: float         = 38.0
@export var contact_damage_cooldown: float   = 1.0

# ── Inspector: Physics ────────────────────────────────────────────────────────
@export_group("Physics")
@export_range(0.0, 2.0, 0.05) var knockback_resistance: float = 1.0
@export var knockback_damp: float = 125.0

# ── Inspector: Loot ───────────────────────────────────────────────────────────
@export_group("Loot")
@export var card_drop_chance: float = 0.05
@export var min_gold: int           = 5
@export var max_gold: int           = 20
@export var drop_quantity: int      = 1
@export var health_drop_chance: float = 0.15
@export var min_health: int         = 1
@export var max_health_drops: int   = 2
@export_enum("Any", "Weapon", "Active", "Passive", "Consumable") var drop_card_type: String = "Any"
@export_flags("Common", "Uncommon", "Rare", "Epic", "Legendary") var drop_rarity_flags: int = 0
@export_flags("Lv1", "Lv2", "Lv3") var drop_level_flags: int = 1
var _drop_card_id: String = ""

# ── Node references ───────────────────────────────────────────────────────────
@onready var floor_ray: RayCast2D = get_node_or_null("RayCast_Floor")
@onready var wall_ray: RayCast2D  = get_node_or_null("RayCast_Wall")
@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var attack_timer: Timer  = get_node_or_null("AttackTimer")
@onready var damage_number_scene  = preload("res://scenes/ui/damage_number.tscn")
@onready var coin_scene           = preload("res://scenes/loot/pickup_coin.tscn")
@onready var card_scene           = preload("res://scenes/loot/pickup_card.tscn")
@onready var health_scene         = preload("res://scenes/loot/pickup_health.tscn")
@onready var eye_sprite: AnimatedSprite2D = $Sprite2D/eye_enemy

# ── Runtime state ─────────────────────────────────────────────────────────────
var is_dead: bool             = false
var life_state: LifeState     = LifeState.ALIVE
var move_mode: MoveMode       = MoveMode.PATROL
var attack_phase: AttackPhase = AttackPhase.READY
# Elementos ativos aplicados por projéteis do player (DoT)
# Estrutura: { type: String → { timer: float, ticks_left: int, data: Dictionary, particles: CPUParticles2D } }
var _element_timers: Dictionary = {}
var _ice_slow_stacks: int = 0
var _ice_base_speed: float = 0.0

var health: int
var direction: int       = 1
var target_player: Node2D = null   # Movement system — respects detection_range
var attack_target: Node2D = null   # Attack system  — respects attack_range only
var flash_tween: Tween
var contact_timer: float  = 0.0
var _turn_cooldown: float = 0.0
var _stun_end_ms: int     = 0   # Tempo mínimo de stun em ms (real-time, imune a time_scale)
var _no_floor_frames: int = 0   # Frames consecutivos sem chão — evita virada em emendas de tile
var _prev_x: float        = 0.0
var _stuck_frames: int    = 0   # Frames sem movimento horizontal em PATROL — detecta parede bloqueando
var _is_climbing: bool    = false
var _rapid_turns: int     = 0   # Contador de turns consecutivos rápidos — detecta inimigo preso
var _last_turn_ms: int    = 0
var _hit_streak: int      = 0   # Hits consecutivos sem pausa — escala partículas
var _last_hit_ms: int     = 0   # Timestamp do último hit (real-time)
const _STREAK_RESET_MS    = 1200
const _STREAK_MAX         = 4
var _ledge_wait: float    = 0.0  # timer de espera na borda de queda alta
var _orbit_dir: int          = 1    # 1=horário, -1=antihorário (inimigos voadores em órbita)
var _orbit_switch_timer: float = 0.0
var _fly_stuck_frames: int   = 0    # frames colidindo lateralmente (voadores)
var _fly_escape_y: float     = 0.0  # direção vertical de escape (+1 / -1)
var _fly_nav_x: float        = 0.0  # direção horizontal ao contornar plataforma (+1/-1)
var _fly_nav_timer: float    = 0.0  # segundos restantes de navegação ao redor de obstáculo
var _fly_nav_attempt: int    = 0    # número de inversões consecutivas sob plataforma
var _fly_patrol_escape: float = 0.0 # escape vertical durante cooldown de patrol loop
var _eff_keep_dist: float    = 0.0  # keep_distance efetivo adaptativo (reduz em espaços apertados)

# ── Difficulty scaling base values ────────────────────────────────────────────
var _base_speed: float   = 0.0
var _base_damage: int    = 0
var _base_contact: int   = 0

# ── Eye state ──────────────────────────────────────────────────────────────────
const _EYE_BASE_POS  := Vector2(-1.0, 0.0)
const _EYE_LOOK_DIST := 2.5   # pixels toward player
const _EYE_MOVE_DIST := 1.5   # pixels from velocity
var _blink_timer: float  = 0.0
var _eye_busy: bool      = false
var _eye_dmg_timer: float = 0.0

# ── Setup ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("enemies")
	health = max_health

	# Duplicate attack behavior so each instance has its own state
	if attack_behavior:
		attack_behavior = attack_behavior.duplicate(true)

	# Duplicate shared resources so instances don't share data
	for path in ["DetectionArea/CollisionShape2D", "AttackArea/CollisionShape2D"]:
		if has_node(path):
			var col = get_node(path)
			if col.shape:
				col.shape = col.shape.duplicate()
	if sprite and sprite.material:
		sprite.material = sprite.material.duplicate()

	if has_node("ProgressBar"):
		$ProgressBar.max_value = max_health
		$ProgressBar.value = health

	if not is_flying and movement_style != MoveStyle.STATIONARY:
		collision_mask |= 16  # colide com one-way platforms (layer 5)

	_sync_area_shapes()
	update_visual()
	_setup_signals()
	_check_initial_overlap()

	if eye_sprite:
		_blink_timer = randf_range(2.0, 5.0)
		eye_sprite.animation_finished.connect(_on_eye_anim_finished)

	if wall_ray:
		wall_ray.add_exception(self)
		wall_ray.collide_with_areas = true
		wall_ray.collision_mask |= 32  # detecta spike areas (layer 6)
	if not is_flying:
		if floor_ray:
			# Sincroniza só o floor_ray — wall_ray usa a máscara padrão da cena
			floor_ray.collision_mask = collision_mask
			floor_ray.add_exception(self)
	# Ignore the player so rays don't mistake it for a wall
	for p in get_tree().get_nodes_in_group("player"):
		if wall_ray:  wall_ray.add_exception(p)
		if not is_flying:
			if floor_ray: floor_ray.add_exception(p)
	update_rays()

	_base_speed   = speed
	_base_damage  = attack_damage
	_base_contact = contact_damage

	_orbit_dir          = 1 if randf() < 0.5 else -1
	_orbit_switch_timer = randf_range(1.0, 3.0)

func apply_difficulty(t: float) -> void:
	speed          = _base_speed   * lerp(1.0, 2.0, t)
	attack_damage  = int(_base_damage  * lerp(1.0, 3.0, t))
	contact_damage = int(_base_contact * lerp(1.0, 3.0, t))

func _sync_area_shapes() -> void:
	# Keep Area2D radii in sync with exported values
	if has_node("DetectionArea/CollisionShape2D"):
		var col = $DetectionArea/CollisionShape2D
		if not (col.shape is CircleShape2D): col.shape = CircleShape2D.new()
		col.shape.radius = detection_range
	if has_node("AttackArea/CollisionShape2D"):
		var col = $AttackArea/CollisionShape2D
		if not (col.shape is CircleShape2D): col.shape = CircleShape2D.new()
		col.shape.radius = attack_range

func _check_initial_overlap() -> void:
	if has_node("AttackArea"):
		for body in $AttackArea.get_overlapping_bodies():
			if body.is_in_group("player"):
				target_player = body
				break

func _setup_signals() -> void:
	if has_node("DetectionArea"):
		$DetectionArea.collision_mask = 4
	if has_node("AttackArea"):
		var area = $AttackArea
		area.collision_mask = 4
		if not area.body_entered.is_connected(_on_attack_area_body_entered):
			area.body_entered.connect(_on_attack_area_body_entered)
		if not area.body_exited.is_connected(_on_attack_area_body_exited):
			area.body_exited.connect(_on_attack_area_body_exited)
	if attack_timer and not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
		attack_timer.timeout.connect(_on_attack_timer_timeout)

# ── Main loop ─────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if life_state == LifeState.DEAD:
		return

	contact_timer = maxf(contact_timer - delta, 0.0)
	_turn_cooldown = maxf(_turn_cooldown - delta, 0.0)

	# 1. Track player — the ONLY place follow_on_detect is read
	_update_player_tracking()

	# 2. Gravity
	if not is_flying and not is_on_floor() and movement_style != MoveStyle.STATIONARY:
		velocity.y += gravity * delta

	# 3. Attack behavior tick (state machines like pounce run before move_and_slide)
	if attack_behavior:
		attack_behavior.tick(self, delta)

	# 4. Attack trigger — independent from movement
	_tick_attack()

	# 5. Movement system — completely independent from attack
	_tick_movement(delta)

	if movement_style != MoveStyle.STATIONARY:
		move_and_slide()
	_check_patrol_stuck()
	_check_contact_damage()
	_tick_eye(delta)

# ── Player tracking ───────────────────────────────────────────────────────────
# follow_on_detect lives HERE and NOWHERE ELSE.
func _update_player_tracking() -> void:
	if not is_instance_valid(target_player):
		target_player = null
		for body in get_tree().get_nodes_in_group("player"):
			target_player = body
			# Add ray exceptions the first time we find the player
			if not is_flying:
				if floor_ray: floor_ray.add_exception(target_player)
				if wall_ray:  wall_ray.add_exception(target_player)
			break

	if target_player == null:
		if move_mode == MoveMode.CHASE:
			move_mode = MoveMode.PATROL
		return

	if global_position.distance_to(target_player.global_position) > detection_range:
		target_player = null
		if move_mode == MoveMode.CHASE:
			move_mode = MoveMode.PATROL
		return

	# follow_on_detect: sole control over PATROL ↔ CHASE transition
	if follow_on_detect:
		if move_mode == MoveMode.PATROL:
			move_mode = MoveMode.CHASE
	else:
		if move_mode == MoveMode.CHASE:
			move_mode = MoveMode.PATROL

# ══════════════════════════════════════════════════════════════════════════════
#  ATTACK SYSTEM
#  Delegates entirely to attack_behavior resource.
#  attack_behavior.tick() runs every frame (step 3 in _physics_process).
#  _tick_attack() only triggers try_attack() when READY and player in range.
#  Does NOT read move_mode or follow_on_detect.
# ══════════════════════════════════════════════════════════════════════════════
func _tick_attack() -> void:
	if not attack_behavior:               return
	if attack_phase != AttackPhase.READY: return

	# Set attack_target to the nearest player (behaviors may use their own range checks)
	attack_target = null
	for body in get_tree().get_nodes_in_group("player"):
		attack_target = body
		break

	# Delegate entirely to the behavior — it decides whether the range is acceptable
	attack_behavior.try_attack(self)

func _on_attack_timer_timeout() -> void:
	attack_phase = AttackPhase.READY

# ══════════════════════════════════════════════════════════════════════════════
#  MOVEMENT SYSTEM
#  Reads only move_mode, movement_style, is_flying.
#  Does NOT read attack_phase or follow_on_detect.
# ══════════════════════════════════════════════════════════════════════════════
func _tick_movement(delta: float) -> void:
	# Behavior congelando movimento (ex: pounce windup/airborne/recoil)
	if attack_behavior and attack_behavior.blocks_movement():
		return
	# Escalada tem prioridade sobre qualquer outro movimento
	if _is_climbing:
		_do_climb()
		update_visual()
		return
	match move_mode:
		MoveMode.STUNNED:
			velocity.x = move_toward(velocity.x, 0.0, knockback_damp * delta)
			if Time.get_ticks_msec() >= _stun_end_ms and absf(velocity.x) < 5.0:
				move_mode = MoveMode.PATROL
				_turn_cooldown = 0.0
				# Se há parede na direção atual (onde foi arremessado), vira imediatamente
				if test_move(global_transform, Vector2(direction * 2.0, 0.0)):
					turn()
		MoveMode.PATROL:
			_move_patrol(delta)
		MoveMode.CHASE:
			_move_chase()

func _move_patrol(delta: float) -> void:
	# Espera na borda de queda alta
	if _ledge_wait > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		_ledge_wait -= delta
		if _ledge_wait <= 0.0:
			turn()
		return
	match movement_style:
		MoveStyle.STATIONARY:
			velocity = Vector2.ZERO

		MoveStyle.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, speed)
			if is_flying:
				velocity.y = move_toward(velocity.y, 0.0, speed)

		MoveStyle.PATROL:
			velocity.x = direction * speed
			if not is_flying and _turn_cooldown <= 0.0 and _has_floor_spike_ahead():
				turn()
				return
			if is_flying:
				if _fly_patrol_escape != 0.0:
					velocity.y = _fly_patrol_escape * speed
					if _turn_cooldown <= 0.0:
						_fly_patrol_escape = 0.0
				elif is_on_ceiling():
					velocity.y = speed * 0.9
				elif is_on_floor():
					velocity.y = -speed * 0.9
				else:
					velocity.y = 0.0
				if _turn_cooldown <= 0.0 and (_is_real_wall() or (wall_ray and wall_ray.is_colliding())):
					turn()
			else:
				# Jump takes priority over turning
			# Contador reativo: só incrementa quando já está no ar sem chão
				if floor_ray and not floor_ray.is_colliding() and not is_on_floor():
					_no_floor_frames += 1
				else:
					_no_floor_frames = 0

				var dl := _drop_limit()
				# Buffer de overshoot: compensa o inimigo ficar brevemente acima da
				# plataforma ao terminar de escalar (v²/2g + 2px de margem).
				var check_dl := dl + (climb_speed * climb_speed) / (2.0 * gravity) + 2.0 if dl > 0.0 else 0.0

				# Detecção PROATIVA: floor_ray não vê chão à frente e body ainda no chão.
				# Suprimida se há parede à frente (a parede cuidará da virada).
				# Suprimida nos primeiros frames após virar (_turn_cooldown) para evitar
				# falso-positivo enquanto o floor_ray se atualiza na nova direção.
				var wall_ahead_now := (wall_ray and wall_ray.is_colliding()) or _is_real_wall()
				var proactive_drop := floor_ray and not floor_ray.is_colliding() \
						and is_on_floor() and check_dl > 0.0 and _turn_cooldown <= 0.0 \
						and not wall_ahead_now and _is_big_drop_of(check_dl)
				# Detecção REATIVA: já caiu e não há chão suficiente abaixo
				var reactive_drop := _no_floor_frames >= 2 and check_dl > 0.0 and _is_big_drop_of(check_dl)

				if proactive_drop or reactive_drop:
					_ledge_wait = ledge_wait_time
				elif not _try_jump() and _turn_cooldown <= 0.0:
					# Escalada: usa wall_ray (antecipa paredes antes do impacto físico)
					# Virada: usa _is_real_wall() para evitar falso-positivo em props/decoração
					var ray_wall := wall_ray and wall_ray.is_colliding()
					if (ray_wall or _is_real_wall()) and _try_climb():
						pass  # escalada iniciada — não vira
					elif _is_real_wall() and velocity.y >= -10.0:
						turn()

		MoveStyle.RANDOM:
			velocity.x = direction * speed

func _move_chase() -> void:
	if not is_instance_valid(target_player):
		move_mode = MoveMode.PATROL
		return

	var dist  := global_position.distance_to(target_player.global_position)
	var dir2d := (target_player.global_position - global_position).normalized()

	# Facing sempre voltado para o player (mesmo quando recuando)
	var new_dir: int = sign(dir2d.x) if dir2d.x != 0.0 else direction
	if new_dir != direction:
		direction = new_dir
		update_visual()
		update_rays()

	# keep_distance adaptativo: reduz quando espremido contra obstáculo ou player acima
	if keep_distance > 0.0:
		var target_kd := keep_distance
		if is_on_ceiling() or is_on_floor():
			target_kd = keep_distance * 0.35   # muito apertado: quase cola no player
		elif target_player.global_position.y < global_position.y - 15.0:
			target_kd = keep_distance * 0.6    # player acima: reduz para não ser empurrado
		_eff_keep_dist = lerpf(_eff_keep_dist, target_kd, 0.06)
	else:
		_eff_keep_dist = 0.0

	# Direção de movimento: keep_distance=0 → sempre avança
	var move_dir := dir2d
	if _eff_keep_dist > 0.0:
		if dist < _eff_keep_dist - 5.0:
			move_dir = -dir2d          # muito perto: recua
		elif dist <= _eff_keep_dist + 5.0:
			if is_flying:
				# Órbita: movimento perpendicular ao vetor player-enemy
				var dt := get_physics_process_delta_time()
				_orbit_switch_timer = maxf(_orbit_switch_timer - dt, 0.0)
				if _orbit_switch_timer <= 0.0:
					_orbit_switch_timer = randf_range(2.5, 5.0)
					if randf() < 0.4:
						_orbit_dir *= -1
				var perp := Vector2(-dir2d.y, dir2d.x) * _orbit_dir
				# Parede lateral → inverte sentido + sobe/desce para escapar
				if _is_real_wall():
					_orbit_dir *= -1
					_orbit_switch_timer = randf_range(2.5, 5.0)
					perp = Vector2(-dir2d.y, dir2d.x) * _orbit_dir
					perp.y += -0.6 * _orbit_dir
					perp = perp.normalized()
				# Viés vertical: puxa o enemy para ficar acima do player
				# Deadzone: ignora correções menores que 25% de _eff_keep_dist (evita tremor)
				var ideal_y  := target_player.global_position.y - _eff_keep_dist
				var dy_err   := global_position.y - ideal_y
				var dy_ratio := 0.0
				if _eff_keep_dist > 0.0 and absf(dy_err) > _eff_keep_dist * 0.25:
					dy_ratio = clampf(dy_err / _eff_keep_dist, -0.6, 0.6)
				move_dir = (perp + Vector2(0.0, -dy_ratio * 0.35)).normalized()
			else:
				move_dir = Vector2.ZERO    # na zona ideal: para

	if is_flying:
		var dt := get_physics_process_delta_time()
		_fly_nav_timer = maxf(_fly_nav_timer - dt, 0.0)

		# Calcula velocidade alvo e suaviza com aceleração (movimentos fluidos)
		var target_vel := move_dir * speed
		if is_on_ceiling() or is_on_floor():
			# Obstáculo vertical: inicia/renova timer de navegação lateral
			_fly_stuck_frames = 0
			if _fly_nav_timer <= 0.0 and _fly_nav_x == 0.0:
				# Primeira colisão (sem nav ativa): escolhe direção em direção ao X do player
				var dx := target_player.global_position.x - global_position.x if is_instance_valid(target_player) else 0.0
				_fly_nav_x = sign(dx) if absf(dx) > 5.0 else (1.0 if randf() < 0.5 else -1.0)
				_fly_nav_attempt = 0
				_fly_nav_timer = 1.2
			elif _fly_nav_timer < 0.1:
				# Timer expirou ou prestes a expirar com nav ativa → inverte com distância crescente
				_fly_nav_x *= -1
				_fly_nav_attempt += 1
				_fly_nav_timer = minf(1.2 + 0.8 * _fly_nav_attempt, 4.0)
			target_vel = Vector2(_fly_nav_x * speed, speed * 0.35 if is_on_ceiling() else -speed * 0.25)
		elif _fly_nav_timer > 0.0:
			# Contato quebrou mas timer ainda ativo: mantém direção de navegação
			target_vel = Vector2(_fly_nav_x * speed, move_dir.y * speed)
		elif _is_real_wall():
			# Parede lateral → escape vertical; inverte direção se ainda preso
			_fly_stuck_frames += 1
			if _fly_stuck_frames == 1:
				_fly_escape_y = 1.0 if randf() < 0.5 else -1.0
			elif _fly_stuck_frames > 20:
				_fly_escape_y *= -1
				_fly_stuck_frames = 0
			target_vel.y += _fly_escape_y * speed * 0.7
			target_vel = target_vel.limit_length(speed * 1.3)
		else:
			# Voo livre, sem obstáculo: reseta sentinela de nav para próxima colisão
			_fly_stuck_frames = maxi(_fly_stuck_frames - 1, 0)
			_fly_nav_x = 0.0
			_fly_nav_attempt = 0
		velocity = velocity.move_toward(target_vel, speed * 4.0 * dt)
	else:
		if move_dir == Vector2.ZERO:
			velocity.x = move_toward(velocity.x, 0.0, speed)
		else:
			velocity.x = sign(move_dir.x) * speed
			if _has_floor_spike_ahead():
				velocity.x = 0.0
			else:
				_try_jump()

func _check_patrol_stuck() -> void:
	## Se o enemy está em PATROL mas não se move horizontalmente por 3+ frames,
	## há uma parede bloqueando. Vira independente de ray ou is_on_wall().
	if move_mode != MoveMode.PATROL or is_flying or _turn_cooldown > 0.0 or _is_climbing or _ledge_wait > 0.0:
		_stuck_frames = 0
		_prev_x = global_position.x
		return
	# Threshold = metade do movimento esperado por frame — só aciona se realmente parado
	# Ex: speed=15 → 0.25px/frame → threshold 0.125px; speed=70 → 0.58px → threshold 0.29px
	var _stuck_threshold := speed * get_physics_process_delta_time() * 0.5
	if absf(global_position.x - _prev_x) < _stuck_threshold:
		_stuck_frames += 1
		if _stuck_frames >= 3:
			# Se pode escalar e há parede à frente (não borda), deixa _try_climb() agir
			var wall_here := _is_real_wall()
			if can_climb_walls and wall_here and _no_floor_frames < 2:
				pass  # não vira — _move_patrol() vai chamar _try_climb()
			else:
				turn()
			_stuck_frames = 0
	else:
		_stuck_frames = 0
	_prev_x = global_position.x

func _is_real_wall() -> bool:
	## is_on_wall() but ignores collisions with the player body.
	if not is_on_wall(): return false
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider and collider.is_in_group("player"): continue
		if absf(col.get_normal().x) > 0.5: return true
	return false

func _do_climb() -> void:
	## Executa a escalada frame a frame.
	velocity.x = direction * speed       # empurra contra a parede
	velocity.y = -climb_speed            # sobe (override da gravidade)
	# Chegou no topo: parede sumiu à frente
	if (not wall_ray or not wall_ray.is_colliding()) and not _is_real_wall():
		_is_climbing = false
		_turn_cooldown = 0.4


func _drop_limit() -> float:
	## Limite de queda aceitável.
	## max_fall_height > 0 → usa esse valor explícito (tem prioridade).
	## Caso contrário usa max_climb_height (inimigos com can_climb_walls param na borda
	## de quedas maiores que a altura que conseguem escalar, mas descem o que subiram).
	if max_fall_height > 0.0: return max_fall_height
	if max_climb_height > 0.0: return max_climb_height
	return 0.0


func _is_big_drop_of(limit: float) -> bool:
	## Raio vertical à frente: retorna true se não há chão dentro de `limit` pixels.
	## Parte dos PÉS do inimigo (floor_ray.global_position.y) para medir corretamente.
	var space := get_world_2d().direct_space_state
	var origin_x := global_position.x + direction * (absf(floor_ray.position.x if floor_ray else 0.0) + 2.0)
	var origin_y := floor_ray.global_position.y if floor_ray else global_position.y
	var from := Vector2(origin_x, origin_y)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, limit))
	query.exclude = [self]
	return space.intersect_ray(query).is_empty()


func _is_big_drop() -> bool:
	return _is_big_drop_of(_drop_limit())


func _try_climb() -> bool:
	## Raio horizontal a max_climb_height acima: se a parede ainda está lá, é alta demais.
	if not can_climb_walls or is_flying or _is_climbing: return false
	if not is_on_floor():                                return false
	if Time.get_ticks_msec() < _stun_end_ms + 400:      return false

	var space := get_world_2d().direct_space_state
	# Raio horizontal na altura máxima de escalada.
	# Se a parede bloquear o raio → alta demais para subir.
	# Se o raio passar livre → parede curta o suficiente → sobe.
	var from := global_position + Vector2(0.0, -max_climb_height)
	var reach := (absf(wall_ray.position.x) + absf(wall_ray.target_position.x)) if wall_ray else 16.0
	var to   := from + Vector2(direction * reach, 0.0)
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.exclude = [self]
	if space.intersect_ray(query):
		return false  # parede mais alta que max_climb_height — não sobe

	_is_climbing = true
	return true


func _try_jump() -> bool:
	## Unified jump logic for both patrol and chase.
	## Returns true if a jump was triggered (so caller skips the turn check).
	if not can_jump_obstacles:               return false
	if not is_on_floor():                    return false
	if velocity.y < -10.0:                   return false  # Already ascending
	# Após stun: prefere virar em vez de pular para não re-entrar na parede do knockback
	if Time.get_ticks_msec() < _stun_end_ms + 400:        return false
	if not is_instance_valid(target_player): return false

	if _is_real_wall() or (wall_ray and wall_ray.is_colliding()):
		velocity.y = jump_force
		return true
	return false

# ══════════════════════════════════════════════════════════════════════════════
#  DAMAGE, KNOCKBACK & DEATH
# ══════════════════════════════════════════════════════════════════════════════
func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO, kb: float = 0.0, is_crit: bool = false) -> void:
	if life_state == LifeState.DEAD: return

	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_hit_ms > _STREAK_RESET_MS:
		_hit_streak = 0
	_hit_streak = mini(_hit_streak + 1, _STREAK_MAX)
	_last_hit_ms = now_ms

	flash_white(0.5 + _hit_streak * 0.1)
	_play_eye_damage()
	_spawn_hit_fx(hit_direction, amount, _hit_streak)
	_show_damage_number(amount, is_crit)

	if hit_direction != Vector2.ZERO and kb > 0.0 and movement_style != MoveStyle.STATIONARY:
		move_mode = MoveMode.STUNNED
		_stun_end_ms = Time.get_ticks_msec() + 350
		_is_climbing = false
		velocity.x = sign(hit_direction.x) * kb * knockback_resistance
		velocity.y = -kb * knockback_resistance * 0.35  # arremesso leve para cima

	GameManager.run_damage_dealt += amount
	health -= amount
	if has_node("ProgressBar"):
		$ProgressBar.value = health

	if health <= 0:
		die()

func apply_hit_stun(duration: float) -> void:
	if duration <= 0.0 or life_state == LifeState.DEAD: return
	move_mode = MoveMode.STUNNED
	velocity.x = 0.0
	await get_tree().create_timer(duration).timeout
	if life_state != LifeState.DEAD and move_mode == MoveMode.STUNNED:
		move_mode = MoveMode.CHASE

func die() -> void:
	is_dead = true
	life_state = LifeState.DEAD
	_hit_streak = 0
	GameManager.run_enemies_killed += 1
	if attack_behavior: attack_behavior.reset()
	set_physics_process(false)
	collision_layer = 0
	collision_mask  = 0
	_drop_loot()
	_spawn_death_fx()
	queue_free()

func _spawn_hit_fx(hit_dir: Vector2, damage: int = 5, streak: int = 0) -> void:
	var root := get_parent()
	if not root: return

	# sqrt comprime a curva: dano 5→t≈0.53, dano 10→t≈0.82, dano 15→t=1.0
	var dmg_t    := clampf(sqrt((damage - 1.0) / 14.0), 0.0, 1.0)
	var streak_t := float(streak) / float(_STREAK_MAX)
	var t        := clampf(dmg_t * 0.5 + streak_t * 0.7, 0.0, 1.0)

	var count    := roundi(lerpf(6.0, 42.0, t))
	var spread   := lerpf(deg_to_rad(65), deg_to_rad(110), t)
	var dist_max := lerpf(10.0, 22.0, t)
	var dur_max  := lerpf(0.45, 0.85, t)        # longa = efeito vapor
	var br_max   := lerpf(0.12, 0.28, t)        # mais escuro, predominantemente preto
	var big_chance := t * 0.15                  # máx 15% de partículas com 2px

	# Ponto de impacto: borda do sprite na direção de onde veio o golpe
	var impact := global_position + (-hit_dir if hit_dir != Vector2.ZERO else Vector2.ZERO) * 8.0

	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	var base_angle := hit_dir.angle() if hit_dir != Vector2.ZERO else 0.0

	for i in range(count):
		var p := ColorRect.new()
		var sz := 2.0 if randf() < big_chance else 1.0
		p.size = Vector2(sz, sz)
		var shade := pow(randf(), 2.0) * br_max  # bias para preto
		p.color = Color(shade, shade, shade, 1.0)
		p.material = mat
		root.add_child(p)
		p.global_position = impact + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))

		# 60% seguem a direção do impacto, 40% derivam para cima (vapor)
		var angle: float
		if randf() < 0.6:
			angle = base_angle + randf_range(-spread, spread)
		else:
			angle = -PI * 0.5 + randf_range(-spread * 0.5, spread * 0.5)

		var dist  := randf_range(3.0, dist_max)
		var target := p.global_position + Vector2(cos(angle) * dist, sin(angle) * dist)
		var dur   := randf_range(0.25, dur_max)

		var tw := p.create_tween().set_parallel(true)
		tw.tween_property(p, "global_position", target, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, dur)
		tw.finished.connect(p.queue_free)

func _spawn_death_fx() -> void:
	var pos := global_position
	var root := get_parent()
	if not root: return

	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	for i in range(22):
		var p := ColorRect.new()
		p.size = Vector2(2, 2) if randf() < 0.4 else Vector2(1, 1)
		var shade := randf_range(0.0, 0.35)
		p.color = Color(shade, shade, shade, 1.0)
		p.material = mat
		root.add_child(p)
		p.global_position = pos + Vector2(randf_range(-6.0, 6.0), randf_range(-8.0, 2.0))

		var angle := randf_range(deg_to_rad(-165), deg_to_rad(-15))
		var dist  := randf_range(14.0, 38.0)
		var target := p.global_position + Vector2(cos(angle) * dist, sin(angle) * dist)
		var dur   := randf_range(0.8, 1.8)

		var tw := p.create_tween().set_parallel(true)
		tw.tween_property(p, "global_position", target, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, dur).set_delay(dur * 0.4)
		tw.finished.connect(p.queue_free)

func _drop_loot() -> void:
	if randf() < card_drop_chance + GameManager.luck_card_chance_bonus:
		var card_node = card_scene.instantiate()
		card_node.global_position = global_position
		card_node.velocity = Vector2(randf_range(-38.0, 38.0), randf_range(-88.0, -50.0))
		if _drop_card_id != "":
			var _cdata := CardDB.get_card(_drop_card_id)
			card_node.card_level = _pick_level(drop_level_flags) if (_cdata and _cdata.type == "Weapon") else 1
			card_node.set_card_id(_drop_card_id)
		else:
			card_node.is_random = true
			card_node.random_type = drop_card_type
			card_node.random_rarity_flags = drop_rarity_flags
			card_node.level_flags = drop_level_flags
		get_parent().call_deferred("add_child", card_node)
	var effective_health_chance: float = health_drop_chance
	if is_instance_valid(target_player) and "current_health" in target_player and "max_health" in target_player:
		var hp_pct: float = float(target_player.current_health) / float(max(target_player.max_health, 1))
		# Quanto menos vida, maior o multiplicador: 1x com HP cheio, até 3x com HP crítico
		var low_hp_mult: float = lerp(3.0, 1.0, hp_pct)
		effective_health_chance = clamp(health_drop_chance * low_hp_mult, 0.0, 1.0)
	if randf() < effective_health_chance:
		var health_count = randi_range(min_health, max_health_drops)
		for _i in health_count:
			_spawn_loot_item(health_scene)
	var gold = int(randi_range(min_gold, max_gold) * drop_quantity * GameManager.luck_coin_multiplier)
	for _i in gold:
		_spawn_loot_item(coin_scene)

func _spawn_loot_item(scene: PackedScene) -> void:
	if not scene: return
	var item = scene.instantiate()
	item.global_position = global_position
	if "velocity" in item:
		item.velocity = Vector2(randf_range(-38.0, 38.0), randf_range(-88.0, -50.0))
	get_parent().call_deferred("add_child", item)

# ── Contact damage ────────────────────────────────────────────────────────────
func _check_contact_damage() -> void:
	if contact_damage <= 0 or contact_timer > 0.0: return

	var player: Node2D = null

	# Path 1: enemy's slide collisions — works when enemy is moving
	for i in get_slide_collision_count():
		var col = get_slide_collision(i).get_collider()
		if col and col.is_in_group("player"):
			player = col
			break

	# Path 2: player's own slide collisions — catches player standing on top
	if not player and is_instance_valid(target_player):
		if target_player.has_method("get_slide_collision_count"):
			for i in target_player.get_slide_collision_count():
				if target_player.get_slide_collision(i).get_collider() == self:
					player = target_player
					break

	# Path 3: shape query fallback — catches remaining edge cases
	if not player:
		var col_node := get_node_or_null("CollisionShape2D")
		if col_node and col_node.shape:
			var params := PhysicsShapeQueryParameters2D.new()
			params.shape          = col_node.shape
			params.transform      = col_node.global_transform
			params.exclude        = [get_rid()]
			params.collision_mask = 4  # Player layer only
			for r in get_world_2d().direct_space_state.intersect_shape(params, 4):
				if r.collider and r.collider.is_in_group("player"):
					player = r.collider
					break

	if not player or not player.has_method("take_damage"): return

	# Garantir componente horizontal no knockback mesmo quando o player está em cima
	var dir := (player.global_position - global_position).normalized()
	if absf(dir.x) < 0.2:
		dir = Vector2(float(direction), dir.y).normalized()

	GameManager._last_hit_source = name
	player.take_damage(contact_damage, dir, contact_knockback)
	contact_timer = contact_damage_cooldown

# ── Eye behaviour ─────────────────────────────────────────────────────────────
func _tick_eye(delta: float) -> void:
	if not eye_sprite: return

	# Damage timer: exibe "damage" por um curto período
	if _eye_dmg_timer > 0.0:
		_eye_dmg_timer -= delta
		if _eye_dmg_timer <= 0.0:
			_eye_busy = false
			eye_sprite.play("idle")

	# Blink: espera timer aleatório e toca "blink"
	if not _eye_busy:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_eye_busy = true
			eye_sprite.play("blink")
			_blink_timer = randf_range(3.0, 7.0)

	# Cor do olho — STATIONARY tem escala amarelo→vermelho; demais usam branco/vermelho
	var target_color: Color
	if movement_style == MoveStyle.STATIONARY:
		var in_attack_range := is_instance_valid(target_player) and \
				global_position.distance_to(target_player.global_position) <= attack_range
		if in_attack_range:
			target_color = Color(1.0, 0.2, 0.2)        # vermelho: na área de ataque
		elif is_instance_valid(target_player):
			target_color = Color(1.0, 0.85, 0.1)       # amarelo: detectado mas fora do alcance
		else:
			target_color = Color.WHITE
	else:
		var player_detected := is_instance_valid(target_player)
		target_color = Color(1.0, 0.2, 0.2) if (move_mode == MoveMode.CHASE or player_detected) else Color.WHITE
	eye_sprite.modulate = eye_sprite.modulate.lerp(target_color, delta * 6.0)

	# Posição: calcula direção em espaço-mundo e converte para local do Sprite2D.
	# Isso funciona corretamente com qualquer rotação do sprite (inclusive de cabeça para baixo).
	var world_offset := Vector2.ZERO
	if is_instance_valid(target_player):
		var dir_to_player := (target_player.global_position - global_position).normalized()
		world_offset = dir_to_player * _EYE_LOOK_DIST
	if velocity.length() > 5.0:
		world_offset += velocity.normalized() * _EYE_MOVE_DIST
	world_offset = world_offset.limit_length(_EYE_LOOK_DIST + _EYE_MOVE_DIST)
	# Converte para espaço local do Sprite2D (considera rotação — flip_h não afeta o transform)
	var local_offset := sprite.global_transform.basis_xform_inv(world_offset)
	eye_sprite.position = eye_sprite.position.lerp(_EYE_BASE_POS + local_offset, delta * 10.0)

func _play_eye_damage() -> void:
	if not eye_sprite: return
	_eye_busy = true
	_eye_dmg_timer = 0.35
	eye_sprite.play("damage")

func _on_eye_anim_finished() -> void:
	# Só "blink" é não-looping — retorna ao idle após o blink
	_eye_busy = false
	if eye_sprite:
		eye_sprite.play("idle")

# ── Visuals & utils ───────────────────────────────────────────────────────────
func update_visual() -> void:
	if sprite:
		sprite.flip_h = direction < 0
		var anim := _get_body_animation()
		if sprite.animation != anim:
			sprite.play(anim)
	if eye_sprite:
		eye_sprite.flip_h = direction < 0

## Virtual — subclasses sobrescrevem só isso para customizar animação do corpo
func _get_body_animation() -> StringName:
	if _is_climbing:             return &"walking"
	if not is_on_floor():        return &"jump"
	if absf(velocity.x) > 1.0:  return &"walking"
	return &"idle"

func _has_floor_spike_ahead() -> bool:
	if is_flying or movement_style == MoveStyle.STATIONARY:
		return false
	var space := get_world_2d().direct_space_state
	# Raio diagonal: parte ligeiramente acima dos pés e desce, garantindo
	# que passe pela shape do spike (que fica ~3px abaixo do topo do tile).
	var from := global_position + Vector2(direction * 2.0, 10.0)
	var to   := global_position + Vector2(direction * 22.0, 22.0)
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.collide_with_areas = true
	params.collision_mask = 32
	params.exclude = [get_rid()]
	return not space.intersect_ray(params).is_empty()

func update_rays() -> void:
	# Posições e alcances são configurados visualmente no editor.
	# O código só garante que os rays apontem para o lado correto ao virar.
	if wall_ray:
		wall_ray.position.x        = absf(wall_ray.position.x) * direction
		wall_ray.target_position.x = absf(wall_ray.target_position.x) * direction
	if is_flying or not floor_ray: return
	floor_ray.position.x        = absf(floor_ray.position.x) * direction
	floor_ray.target_position.x = absf(floor_ray.target_position.x) * direction

func turn() -> void:
	if movement_style == MoveStyle.STATIONARY: return
	direction *= -1
	var now := Time.get_ticks_msec()
	if now - _last_turn_ms < 600:
		_rapid_turns += 1
		# 3 turns rápidos = inimigo preso — pausa longa para "desistir" e tentar sair
		_turn_cooldown = 1.5 if _rapid_turns >= 3 else 0.2
		if _rapid_turns >= 3:
			_rapid_turns = 0
			if is_flying:
				_fly_patrol_escape = 1.0 if randf() < 0.5 else -1.0
	else:
		_rapid_turns = 0
		_turn_cooldown = 0.2
	_last_turn_ms = now
	update_visual()
	update_rays()

func flash_white(intensity: float = 0.5) -> void:
	if not sprite or not sprite.material: return
	var mat := sprite.material as ShaderMaterial
	if mat == null: return
	if flash_tween and flash_tween.is_running(): flash_tween.kill()
	mat.set_shader_parameter("flash_amount", intensity)
	flash_tween = create_tween()
	flash_tween.tween_property(mat, "shader_parameter/flash_amount", 0.0, 0.12)

func apply_element(data: Dictionary) -> void:
	if life_state == LifeState.DEAD: return
	var type: String = data.type
	if _element_timers.has(type):
		# Refresca os ticks — o efeito foi reaplicado antes de expirar
		_element_timers[type].ticks_left = data.dot_ticks
		if type == "ice":
			_apply_ice_slow()
		return
	var particles := _spawn_element_particles(data.color)
	_element_timers[type] = {
		timer      = data.tick_interval,
		ticks_left = data.dot_ticks,
		data       = data,
		particles  = particles
	}
	if type == "ice":
		_apply_ice_slow()

func _apply_ice_slow() -> void:
	if _ice_base_speed == 0.0:
		_ice_base_speed = speed
	_ice_slow_stacks += 1
	speed = _ice_base_speed * maxf(1.0 - _ice_slow_stacks * 0.15, 0.25)

func _process(delta: float) -> void:
	if _element_timers.is_empty(): return
	for type in _element_timers.keys():
		var entry: Dictionary = _element_timers[type]
		entry.timer -= delta
		if entry.timer <= 0.0:
			entry.timer = entry.data.tick_interval
			if life_state != LifeState.DEAD:
				# Aplica dano direto sem passar por take_damage() para evitar número branco duplicado
				flash_white()
				_play_eye_damage()
				GameManager.run_damage_dealt += entry.data.dot_damage
				health -= entry.data.dot_damage
				if has_node("ProgressBar"):
					$ProgressBar.value = health
				_show_damage_number(entry.data.dot_damage, false, entry.data.color)
				if health <= 0:
					die()
					break  # enemy destruído — para de processar outros elementos
			entry.ticks_left -= 1
			if entry.ticks_left <= 0:
				if is_instance_valid(entry.particles):
					entry.particles.queue_free()
				if type == "ice" and _ice_base_speed > 0.0:
					speed = _ice_base_speed
					_ice_base_speed = 0.0
					_ice_slow_stacks = 0
				_element_timers.erase(type)
				break  # erase durante iteração — reinicia no próximo frame

func _spawn_element_particles(color: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = true
	p.amount = 24
	p.lifetime = 1.2
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 7.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, -25)
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 22.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	var grad := Gradient.new()
	grad.set_color(0, Color(color.r, color.g, color.b, 1.0))
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = grad
	p.color = Color(1, 1, 1, 1)
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.material = mat
	p.z_index = 2
	add_child(p)
	return p

func _show_damage_number(amount: int, is_crit: bool = false, override_color: Color = Color.WHITE) -> void:
	if not damage_number_scene: return
	var dn = damage_number_scene.instantiate()
	var pos := global_position
	if has_node("DamageNumberPosition"):
		pos = $DamageNumberPosition.global_position
	var world_pos := pos + Vector2(randf_range(-15.0, 15.0), randf_range(-10.0, 10.0))
	var par := get_parent()
	dn.position = par.to_local(world_pos)
	par.add_child(dn)
	if is_crit:
		dn.setup(amount, Color(1.0, 0.65, 0.0), true)
	elif override_color != Color.WHITE:
		dn.setup(amount, override_color)
	else:
		dn.setup(amount)

# ── Signals ───────────────────────────────────────────────────────────────────
# AttackArea signals no longer manage target_player — attack system is independent.
# target_player is owned exclusively by _update_player_tracking().
func _on_attack_area_body_entered(_body: Node2D) -> void:
	pass  # _tick_attack() scans independently each frame

func _on_attack_area_body_exited(_body: Node2D) -> void:
	pass  # _tick_attack() scans independently each frame

# ── Loot helpers ──────────────────────────────────────────────────────────────
func _pick_level(flags: int) -> int:
	var pool := []
	if flags & 1: pool.append(1)
	if flags & 2: pool.append(2)
	if flags & 4: pool.append(3)
	return pool[randi() % pool.size()] if not pool.is_empty() else 1

# ── Loot: drop_card_id como dropdown no Inspector ─────────────────────────────
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
		"name": "drop_card_id",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": cards_list,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	return properties

func _set(property, value):
	if property == "drop_card_id":
		_drop_card_id = value
		return true
	return false

func _get(property):
	if property == "drop_card_id":
		return _drop_card_id
	return null
