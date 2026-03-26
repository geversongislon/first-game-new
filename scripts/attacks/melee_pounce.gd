class_name MeleePounce
extends AttackBehavior

@export_group("Melee Pounce")
@export var pounce_range: float    = 50.0   # distância que ativa o pounce
@export var pounce_windup: float   = 0.40   # segundos de preparação antes de saltar
@export var pounce_h_speed: float  = 90.0   # velocidade horizontal do salto
@export var pounce_v_speed: float  = 110.0  # velocidade vertical do salto
@export var pounce_recoil_h: float = 60.0   # velocidade horizontal do recuo
@export var pounce_recoil_v: float = 85.0   # velocidade vertical do recuo
@export var cooldown: float        = 1.5

enum PounceState { IDLE, WINDUP, AIRBORNE, RECOIL }

var state: PounceState = PounceState.IDLE
var _timer: float      = 0.0
var _dir: int          = 1
var _hit: bool         = false

func is_in_pounce() -> bool:
	return state != PounceState.IDLE

func blocks_movement() -> bool:
	return state != PounceState.IDLE

func reset() -> void:
	state  = PounceState.IDLE
	_timer = 0.0
	_hit   = false

# ── Per-frame tick — runs before move_and_slide ────────────────────────────
func tick(enemy: CharacterBody2D, delta: float) -> void:
	_tick_state(enemy as EnemyBase, delta)

func _tick_state(enemy: EnemyBase, delta: float) -> void:
	match state:
		PounceState.WINDUP:
			_timer -= delta
			if _timer <= 0.0:
				state           = PounceState.AIRBORNE
				_hit            = false
				enemy.velocity.x = _dir * pounce_h_speed
				enemy.velocity.y = -pounce_v_speed
				enemy.direction  = _dir
				enemy.update_visual()

		PounceState.AIRBORNE:
			if not _hit:
				for body in enemy.get_tree().get_nodes_in_group("player"):
					if enemy.global_position.distance_to(body.global_position) <= enemy.attack_range + 8.0:
						_hit = true
						var hit_dir: Vector2 = (body.global_position - enemy.global_position).normalized()
						GameManager._last_hit_source = enemy.name
						body.take_damage(enemy.attack_damage, hit_dir, enemy.attack_knockback)
						# Recua imediatamente ao acertar — não espera pousar
						state            = PounceState.RECOIL
						enemy.velocity.x = -_dir * pounce_recoil_h
						enemy.velocity.y = -pounce_recoil_v
						enemy.update_visual()
						break
			# Errou e pousou
			if state == PounceState.AIRBORNE and enemy.is_on_floor() and enemy.velocity.y >= 0.0:
				_end_pounce(enemy)

		PounceState.RECOIL:
			if enemy.is_on_floor() and enemy.velocity.y >= 0.0:
				_end_pounce(enemy)

# ── Iniciar pounce (chamado por try_attack) ────────────────────────────────
func try_attack(enemy: CharacterBody2D) -> void:
	var e := enemy as EnemyBase
	if state != PounceState.IDLE:               return
	if e.attack_phase != EnemyBase.AttackPhase.READY: return
	if not e.is_on_floor():                     return

	# Encontra player no alcance do pounce
	var player: Node2D = null
	for body in e.get_tree().get_nodes_in_group("player"):
		if e.global_position.distance_to(body.global_position) <= pounce_range:
			player = body
			break
	if not player: return

	# Não pula se player estiver muito acima
	var dy: float = player.global_position.y - e.global_position.y
	if dy < -20.0: return

	# Inicia windup
	state           = PounceState.WINDUP
	_timer          = pounce_windup
	_hit            = false
	_dir            = sign(player.global_position.x - e.global_position.x) as int
	if _dir == 0: _dir = e.direction
	e.attack_phase  = EnemyBase.AttackPhase.WINDUP
	e.direction     = _dir
	e.update_visual()
	e.update_rays()

func _end_pounce(enemy: EnemyBase) -> void:
	state          = PounceState.IDLE
	enemy.attack_phase = EnemyBase.AttackPhase.COOLDOWN
	_cooldown_async(enemy)

func _cooldown_async(enemy: EnemyBase) -> void:
	await enemy.get_tree().create_timer(cooldown).timeout
	if enemy.life_state != EnemyBase.LifeState.DEAD:
		enemy.attack_phase = EnemyBase.AttackPhase.READY
