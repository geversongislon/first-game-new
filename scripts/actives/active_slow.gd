extends BaseActiveAbility
## Consumível: Slow Mo
## Dilata o tempo: inimigos, projéteis e partículas ficam lentos.
## O movimento do player não é afetado (PROCESS_MODE_ALWAYS).

const SLOW_SCALE  := 0.25
const DURATION_MS := 4000  # duração em ms reais (imune ao time_scale)

var _start_ms: int = 0
var _saved_gpu: Dictionary = {}
var _saved_cpu: Dictionary = {}

func configure() -> void:
	follow_player = false
	spawn_offset  = Vector2(0, -20)

func _ready() -> void:
	set_process(false)

func execute() -> void:
	if not player:
		queue_free()
		return

	# Usa o mecanismo da câmera — evita o safety-reset de time_scale
	var cam := player.get_viewport().get_camera_2d()
	if cam and cam.has_method("slow_motion"):
		cam.slow_motion(DURATION_MS, SLOW_SCALE)
	else:
		Engine.time_scale = SLOW_SCALE  # fallback sem câmera

	player.set("slow_mo_compensation", true)
	_set_player_anim_speed(1.0 / SLOW_SCALE)
	_slow_particles()

	_start_ms = Time.get_ticks_msec()
	set_process(true)

	_spawn_activation_fx()

func _process(_delta: float) -> void:
	_update_weapon_compensation(1.0 / SLOW_SCALE)
	if Time.get_ticks_msec() - _start_ms >= DURATION_MS:
		_end_effect()

# ── Visual de ativação ───────────────────────────────────────────────────────

func _spawn_activation_fx() -> void:
	var pos: Vector2 = player.global_position + spawn_offset
	var root := get_tree().current_scene if get_tree() else null
	if not root: return

	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	# Flash central branco — núcleo do burst
	for i in range(12):
		var p := ColorRect.new()
		p.size = Vector2(randi_range(2, 4), randi_range(2, 4))
		p.color = Color(1.0, 1.0, 1.0, 1.0)
		p.material = mat
		root.add_child(p)
		p.global_position = pos + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
		var angle := randf_range(0.0, TAU)
		var dist  := randf_range(20.0, 55.0)
		var target := p.global_position + Vector2(cos(angle) * dist, sin(angle) * dist * 0.8)
		var dur   := randf_range(0.10, 0.25)
		var tw := p.create_tween().set_parallel(true)
		tw.tween_property(p, "global_position", target, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, dur).set_delay(dur * 0.2)
		tw.finished.connect(p.queue_free)

	# Faíscas azuis — burst principal (massa de partículas)
	for i in range(55):
		var p := ColorRect.new()
		p.size = Vector2(2, 2) if randf() < 0.5 else Vector2(1, 1)
		var t := randf_range(0.0, 0.3)
		p.color = Color(0.2 + t, 0.5 + t * 0.5, 1.0, 1.0)
		p.material = mat
		root.add_child(p)
		p.global_position = pos + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
		var angle := randf_range(0.0, TAU)
		var dist  := randf_range(15.0, 70.0)
		var target := p.global_position + Vector2(cos(angle) * dist, sin(angle) * dist * 0.9)
		var dur   := randf_range(0.15, 0.40)
		var tw := p.create_tween().set_parallel(true)
		tw.tween_property(p, "global_position", target, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, dur).set_delay(dur * 0.4)
		tw.finished.connect(p.queue_free)

	# Faíscas brancas longas — alcance estendido
	for i in range(25):
		var p := ColorRect.new()
		p.size = Vector2(1, 1)
		p.color = Color(0.8, 0.95, 1.0, 1.0)
		p.material = mat
		root.add_child(p)
		p.global_position = pos + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
		var angle := randf_range(0.0, TAU)
		var dist  := randf_range(45.0, 100.0)
		var target := p.global_position + Vector2(cos(angle) * dist, sin(angle) * dist * 0.85)
		var dur   := randf_range(0.10, 0.22)
		var tw := p.create_tween().set_parallel(true)
		tw.tween_property(p, "global_position", target, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, dur)
		tw.finished.connect(p.queue_free)

# ── Arma atual ───────────────────────────────────────────────────────────────

func _update_weapon_compensation(comp: float) -> void:
	var wm := player.get_node_or_null("WeaponManager")
	if not wm: return
	var weapon: Node = wm.get("current_weapon") as Node
	if weapon and "time_compensation" in weapon:
		weapon.time_compensation = comp

# ── Animações do player ───────────────────────────────────────────────────────

func _set_player_anim_speed(spd: float) -> void:
	for path in ["Visual/Sprite2D", "Visual/Sprite2D/Sprite2D"]:
		var node := player.get_node_or_null(path) as AnimatedSprite2D
		if node:
			node.speed_scale = spd
	var weapon_sprite := player.get("weapon_sprite") as AnimatedSprite2D
	if is_instance_valid(weapon_sprite):
		weapon_sprite.speed_scale = spd

# ── Partículas ────────────────────────────────────────────────────────────────

func _slow_particles() -> void:
	var root := get_tree().current_scene if get_tree() else null
	if not root:
		return
	_saved_gpu.clear()
	_saved_cpu.clear()
	for node in root.find_children("*", "GPUParticles2D", true, false):
		var p := node as GPUParticles2D
		_saved_gpu[p] = p.speed_scale
		p.speed_scale *= SLOW_SCALE
	for node in root.find_children("*", "CPUParticles2D", true, false):
		var p := node as CPUParticles2D
		_saved_cpu[p] = p.speed_scale
		p.speed_scale *= SLOW_SCALE

func _restore_particles() -> void:
	for key in _saved_gpu.keys():
		if is_instance_valid(key):
			(key as GPUParticles2D).speed_scale = _saved_gpu[key]
	for key in _saved_cpu.keys():
		if is_instance_valid(key):
			(key as CPUParticles2D).speed_scale = _saved_cpu[key]
	_saved_gpu.clear()
	_saved_cpu.clear()

# ── Fim do efeito ─────────────────────────────────────────────────────────────

func _end_effect() -> void:
	set_process(false)
	_restore_particles()
	if is_instance_valid(player):
		player.set("slow_mo_compensation", false)
		_set_player_anim_speed(1.0)
		_update_weapon_compensation(1.0)
	queue_free()
