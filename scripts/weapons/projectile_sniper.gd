extends Area2D
class_name ProjectileSniper

## Projétil do Sniper:
## - Penetra inimigos (não destrói no primeiro hit)
## - Sem gravidade (linha reta)
## - Dano escala com a distância percorrida
## - Rastro visual com Line2D
## - Raycast manual para evitar tunneling em altas velocidades

var speed: float = 1500.0
var damage: int = 80
var knockback: float = 250.0
var direction: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var is_crit: bool = false

@export var impact_color: Color = Color(0.85, 0.95, 1.0, 1.0)

const DISTANCE_SCALE_PER_100PX: float = 0.20
const MAX_DAMAGE_MULTIPLIER: float = 3.0
const LIFETIME: float = 3.0
const TRAIL_POINTS: int = 28

## Máscara: layer 1 = mundo/paredes, layer 2 = inimigos (ajuste conforme projeto)
const ENEMY_MASK: int = 2
const WALL_MASK: int = 1

var _spawn_position: Vector2 = Vector2.ZERO
var _hit_enemies: Array[RID] = []
var _trail: Line2D = null
var _exclude_rids: Array[RID] = []
var time_compensation: float = 1.0

func setup(dir: Vector2, spd: float) -> void:
	direction = dir
	speed = spd
	velocity = direction * speed
	call_deferred("_record_spawn")

func _record_spawn() -> void:
	_spawn_position = global_position

func set_exclude(body: CollisionObject2D) -> void:
	_exclude_rids = [body.get_rid()]

func _ready() -> void:
	_spawn_trail()
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
	# Projéteis do player mantêm velocidade normal durante slow-mo
	if Engine.time_scale > 0.0 and Engine.time_scale < 1.0:
		var p := get_tree().get_first_node_in_group("player")
		if p and p.get("slow_mo_compensation"):
			time_compensation = 1.0 / Engine.time_scale

func _spawn_trail() -> void:
	_trail = Line2D.new()
	_trail.width = 1
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND

	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	gradient.set_color(1, Color(0.85, 0.96, 1.0, 0.75))
	_trail.gradient = gradient

	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_trail.material = mat

	call_deferred("_add_trail_to_parent")

func _add_trail_to_parent() -> void:
	if is_instance_valid(get_parent()):
		get_parent().add_child(_trail)

func _physics_process(delta: float) -> void:
	var prev_pos: Vector2 = global_position
	var eff := delta * time_compensation
	position += velocity * eff
	rotation = velocity.angle()

	_sweep_hits(prev_pos, global_position)

	if is_instance_valid(_trail):
		_trail.add_point(global_position)
		while _trail.get_point_count() > TRAIL_POINTS:
			_trail.remove_point(0)

## Raycast da posição anterior até a atual — detecta hits mesmo com alta velocidade
func _sweep_hits(from: Vector2, to: Vector2) -> void:
	if not is_inside_tree(): return
	var space := get_world_2d().direct_space_state

	# 1) Checa inimigos
	var enemy_params := PhysicsRayQueryParameters2D.create(from, to)
	enemy_params.collision_mask = ENEMY_MASK
	enemy_params.exclude = _exclude_rids

	var result := space.intersect_ray(enemy_params)
	if result:
		var body: Object = result.get("collider")
		if body and body is CollisionObject2D:
			var rid: RID = (body as CollisionObject2D).get_rid()
			if rid not in _hit_enemies and body.has_method("take_damage"):
				_hit_enemies.append(rid)
				var dist: float = global_position.distance_to(_spawn_position)
				var multiplier: float = clamp(
					1.0 + (dist / 100.0) * DISTANCE_SCALE_PER_100PX,
					1.0, MAX_DAMAGE_MULTIPLIER
				)
				var final_damage: int = int(float(damage) * multiplier)
				body.take_damage(final_damage, velocity.normalized(), knockback, is_crit)

	# 2) Checa paredes
	var wall_params := PhysicsRayQueryParameters2D.create(from, to)
	wall_params.collision_mask = WALL_MASK
	wall_params.exclude = _exclude_rids
	var wall_result := space.intersect_ray(wall_params)
	if wall_result:
		_spawn_impact_fx(wall_result.get("position", global_position))
		queue_free()

func _spawn_impact_fx(pos: Vector2) -> void:
	var root := get_parent()
	if not root: return
	var hit_dir := velocity.normalized()
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for i in range(6):
		var p := ColorRect.new()
		p.size = Vector2(1, 1)
		p.color = impact_color
		p.material = mat
		root.add_child(p)
		p.global_position = pos + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
		var base_angle := (hit_dir * -1.0).angle()
		var angle := base_angle + randf_range(deg_to_rad(-55), deg_to_rad(55))
		var dist := randf_range(3.0, 10.0)
		var target := p.global_position + Vector2(cos(angle) * dist, sin(angle) * dist)
		var dur := randf_range(0.1, 0.25)
		var tw := p.create_tween().set_parallel(true)
		tw.tween_property(p, "global_position", target, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, dur)
		tw.finished.connect(p.queue_free)

func _exit_tree() -> void:
	if is_instance_valid(_trail):
		_trail.queue_free()
