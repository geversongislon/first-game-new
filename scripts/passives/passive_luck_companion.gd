extends Node2D

@export var orbit_x: float = 16.0      # amplitude horizontal da órbita
@export var orbit_y: float = 6.0       # amplitude vertical da órbita
@export var height: float = -28.0      # altura base acima do player
@export var speed: float = 1.4         # velocidade de oscilação
@export var follow_speed: float = 5.0  # quão rápido segue o player (lerp — menor = mais delay)

var _target: Node2D = null
var _smooth_pos: Vector2 = Vector2.ZERO
var _t: float = 0.0

func set_target(target: Node2D) -> void:
	_target = target
	_smooth_pos = target.global_position
	global_position = _smooth_pos
	_setup_particles()

func _process(delta: float) -> void:
	if not _target or not is_instance_valid(_target):
		return
	_t += delta
	# Suaviza a posição base — cria o delay ao mover
	_smooth_pos = _smooth_pos.lerp(_target.global_position, follow_speed * delta)
	# Órbita em elipse sobre a posição suavizada
	global_position = _smooth_pos + Vector2(
		cos(_t * speed) * orbit_x,
		height + sin(_t * speed * 1.3) * orbit_y
	)

func _setup_particles() -> void:
	var p := CPUParticles2D.new()
	p.emitting = true
	p.amount = 12
	p.lifetime = 2.5
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 3.0
	p.direction = Vector2(0, -1)
	p.spread = 55.0
	p.gravity = Vector2(0, -5)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 4.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.0
	var grad := Gradient.new()
	grad.set_color(0, Color(0.15, 1.0, 0.25, 0.8))
	grad.set_color(1, Color(0.82, 1.0, 0.86, 0.0))
	p.color_ramp = grad
	p.color = Color(1, 1, 1, 1)
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.material = mat
	add_child(p)
