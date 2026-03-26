extends "res://scripts/actors/enemy.gd"

# ── Rat-specific defaults ────────────────────────────────────────────────────
@export_group("Rat")
@export var sniff_chance: float   = 0.30
@export var sniff_duration: float = 0.6

# ── Runtime ──────────────────────────────────────────────────────────────────
var _sniff_timer: float   = 0.0
var _is_sniffing: bool    = false
var _next_sniff_in: float = 0.0

# Shortcut to the pounce behavior (null if a different behavior is assigned)
var _pounce: MeleePounce:
	get: return attack_behavior as MeleePounce

# ── Init ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	super._ready()
	_next_sniff_in = randf_range(3.0, 8.0)


# ── Stuck check: ignora sniff e pounce ───────────────────────────────────────
func _check_patrol_stuck() -> void:
	if _is_sniffing or (_pounce != null and _pounce.is_in_pounce()):
		_stuck_frames = 0
		_prev_x = global_position.x
		return
	super._check_patrol_stuck()


# ── Patrol override: sniff espontâneo ─────────────────────────────────────────
func _move_patrol(delta: float) -> void:
	if _is_sniffing:
		_sniff_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, speed)
		if _sniff_timer <= 0.0:
			_is_sniffing = false
			update_visual()
		return
	update_visual()

	super._move_patrol(delta)

	_next_sniff_in -= delta
	if _next_sniff_in <= 0.0:
		_is_sniffing = true
		_sniff_timer = sniff_duration
		_next_sniff_in = randf_range(3.0, 8.0)


# ── Animation: sobrescreve só _get_body_animation ────────────────────────────
func _get_body_animation() -> StringName:
	if _is_climbing: return &"walking"
	if _pounce:
		match _pounce.state:
			MeleePounce.PounceState.WINDUP:
				return &"idle"
			MeleePounce.PounceState.AIRBORNE, MeleePounce.PounceState.RECOIL:
				return &"jump"
	if _is_sniffing:            return &"idle"
	if absf(velocity.x) > 1.0: return &"walking"
	return &"idle"


# ── Visual override: trata rotação de escalada + chama base ──────────────────
func update_visual() -> void:
	var spr := get_node_or_null("Sprite2D") as AnimatedSprite2D
	if spr:
		if _is_climbing:
			spr.rotation = -direction * PI / 2.0
			spr.flip_h   = direction < 0
		else:
			spr.rotation = 0.0
			# Durante pounce: usa _pounce._dir para flip; caso contrário usa direction
			if _pounce and _pounce.state != MeleePounce.PounceState.IDLE:
				spr.flip_h = _pounce._dir < 0
			else:
				spr.flip_h = direction < 0
		var anim := _get_body_animation()
		if spr.animation != anim:
			spr.play(anim)

	var eye := get_node_or_null("Sprite2D/eye_enemy") as AnimatedSprite2D
	if eye:
		eye.flip_h = direction < 0


# ── Eye override: rat usa "blink"/"damage" ────────────────────────────────────
func _tick_eye(delta: float) -> void:
	if not eye_sprite: return

	if _eye_dmg_timer > 0.0:
		_eye_dmg_timer -= delta
		if _eye_dmg_timer <= 0.0:
			_eye_busy = false
			eye_sprite.play("idle")

	# Cor: vermelho ao perseguir ou durante pounce, branco em patrulha
	var chasing := move_mode == MoveMode.CHASE or (_pounce != null and _pounce.is_in_pounce())
	var target_color := Color(1.0, 0.2, 0.2) if chasing else Color.WHITE
	eye_sprite.modulate = eye_sprite.modulate.lerp(target_color, delta * 6.0)

	if not _eye_busy:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_eye_busy = true
			eye_sprite.play("blink")
			_blink_timer = randf_range(3.0, 7.0)

func _play_eye_damage() -> void:
	if not eye_sprite: return
	_eye_dmg_timer = 0.35
	eye_sprite.play("damage")

func _on_eye_anim_finished() -> void:
	_eye_busy = false
	if eye_sprite:
		eye_sprite.play("idle")
