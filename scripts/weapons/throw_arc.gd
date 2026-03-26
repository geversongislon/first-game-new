extends Node2D
class_name ThrowArc

const STEPS: int        = 60
const STEP_DT: float    = 0.05
const DOT_RADIUS: float = 1.5
const DOT_COLOR: Color  = Color(1, 1, 1, 0.5)
const HIT_COLOR: Color  = Color(1, 0.45, 0.15, 0.85)  # laranja para impacto

# Máscara de colisão igual à da grenade (layers 1 e 2)
var collision_mask: int = 3

var gravity: float = 980.0

# Pontos calculados via raycast (em coordenadas de mundo)
var _arc_points: PackedVector2Array = []
var _hit_point: Vector2 = Vector2.INF

var _spawn_pos:     Vector2 = Vector2.ZERO
var _dir:           Vector2 = Vector2.RIGHT
var _speed:         float   = 0.0
var _exclude_rids:  Array[RID] = []

func _ready() -> void:
	gravity = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
	# Node fica sempre na origem — desenha em coordenadas de mundo
	global_position = Vector2.ZERO
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat

func set_exclude(body: CollisionObject2D) -> void:
	_exclude_rids = [body.get_rid()]

func update_arc(spawn_world_pos: Vector2, direction: Vector2, speed: float) -> void:
	_spawn_pos = spawn_world_pos
	_dir       = direction
	_speed     = speed
	_recalculate_arc()
	queue_redraw()

func _recalculate_arc() -> void:
	_arc_points.clear()
	_hit_point = Vector2.INF

	if not is_inside_tree(): return

	var space := get_world_2d().direct_space_state
	var vx := _dir.x * _speed
	var vy := _dir.y * _speed
	var prev := _spawn_pos
	_arc_points.append(prev)

	for i in range(1, STEPS + 1):
		var t    := float(i) * STEP_DT
		var curr := Vector2(
			_spawn_pos.x + vx * t,
			_spawn_pos.y + vy * t + 0.5 * gravity * t * t
		)

		var params := PhysicsRayQueryParameters2D.create(prev, curr)
		params.collision_mask = collision_mask
		params.exclude = _exclude_rids
		var result := space.intersect_ray(params)

		if result:
			_arc_points.append(result["position"])
			_hit_point = result["position"]
			break

		_arc_points.append(curr)
		prev = curr

func _draw() -> void:
	var total := _arc_points.size()
	if total < 1: return

	for i in range(total):
		var pct    := 1.0 - float(i) / float(max(total, 1))
		var col    := DOT_COLOR
		col.a     *= pct
		var radius := DOT_RADIUS * (0.4 + 0.6 * pct)
		draw_circle(_arc_points[i], radius, col)

	# Marcador de impacto na parede/chão
	if _hit_point != Vector2.INF:
		draw_circle(_hit_point, DOT_RADIUS * 3.0, HIT_COLOR)
