extends Node2D
## Companion visual orbital para passivas elementais.
## Parametrize element_type, element_color e companion_texture antes de chamar set_target().

@export var element_type: String = "poison"
@export var element_color: Color = Color(0.2, 1.0, 0.1)
@export var companion_texture: Texture2D = null
@export var orbit_x: float = 30.0
@export var orbit_y: float = 8.0
@export var height: float = -28.0
@export var speed: float = 1.4
@export var follow_speed: float = 5.0

var _target: Node2D = null
var _smooth_pos: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _t_offset: float = 0.0

func _ready() -> void:
	_t_offset = randf() * TAU  # fase aleatória única por instância

func set_target(target: Node2D) -> void:
	_target = target
	_smooth_pos = target.global_position
	global_position = _smooth_pos
	_apply_element_color()
	_setup_sprite()
	_setup_aura()
	_setup_trail()

func _apply_element_color() -> void:
	if has_node("PointLight2D"):
		$PointLight2D.color = element_color

func _setup_sprite() -> void:
	if not has_node("Sprite2D"): return
	if companion_texture:
		$Sprite2D.texture = companion_texture
	else:
		$Sprite2D.visible = false

func _process(delta: float) -> void:
	if not _target or not is_instance_valid(_target):
		return
	_t += delta
	_smooth_pos = _smooth_pos.lerp(_target.global_position, follow_speed * delta)
	var ox := cos(_t * speed + _t_offset) * orbit_x \
			+ cos(_t * speed * 2.3 + _t_offset * 0.7) * orbit_x * 0.28
	var oy := height \
			+ sin(_t * speed * 1.3 + _t_offset) * orbit_y \
			+ sin(_t * speed * 0.75) * orbit_y * 0.45
	global_position = _smooth_pos + Vector2(ox, oy)

# ── Partículas temáticas ───────────────────────────────────────────────────────

func _setup_aura() -> void:
	match element_type:
		"fire":
			_make_particles(
				18, 2.0, Vector2(0, -1), 25.0, 10.0, 28.0,
				Vector2(0, -40), 0.4,
				Color(1.0, 0.55, 0.05, 1.0), Color(0.8, 0.1, 0.0, 0.0)
			)
		"poison":
			_make_particles(
				14, 5.0, Vector2(0, 0), 180.0, 1.0, 4.0,
				Vector2(0, 2), 2.0,
				Color(0.2, 0.9, 0.1, 0.7), Color(0.2, 0.9, 0.1, 0.0)
			)
		"ice":
			_make_particles(
				12, 3.0, Vector2(0, 1), 25.0, 6.0, 16.0,
				Vector2(0, 50), 0.45,
				Color(0.7, 0.95, 1.0, 1.0), Color(0.3, 0.7, 1.0, 0.0)
			)

func _setup_trail() -> void:
	match element_type:
		"fire":
			_make_particles(
				10, 4.0, Vector2(0, -1), 60.0, 3.0, 10.0,
				Vector2(0, -15), 0.9,
				Color(1.0, 0.3, 0.0, 0.8), Color(0.5, 0.05, 0.0, 0.0)
			)
		"poison":
			_make_particles(
				8, 7.0, Vector2(0, -1), 180.0, 0.5, 2.5,
				Vector2(0, -3), 2.5,
				Color(0.4, 1.0, 0.2, 0.4), Color(0.2, 0.9, 0.1, 0.0)
			)
		"ice":
			_make_particles(
				8, 5.0, Vector2(0, 1), 60.0, 2.0, 7.0,
				Vector2(0, 30), 0.8,
				Color(0.85, 0.97, 1.0, 0.7), Color(0.3, 0.7, 1.0, 0.0)
			)

func _make_particles(
		amt: int, radius: float,
		dir: Vector2, spread: float,
		vel_min: float, vel_max: float,
		grav: Vector2, lifetime: float,
		color_start: Color, color_end: Color
) -> void:
	var p := CPUParticles2D.new()
	p.emitting = true
	p.amount = amt
	p.lifetime = lifetime
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = dir
	p.spread = spread
	p.gravity = grav
	p.initial_velocity_min = vel_min
	p.initial_velocity_max = vel_max
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.6
	var grad := Gradient.new()
	grad.set_color(0, color_start)
	grad.set_color(1, color_end)
	p.color_ramp = grad
	p.color = Color(1, 1, 1, 1)
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.material = mat
	p.z_index = -1
	add_child(p)
