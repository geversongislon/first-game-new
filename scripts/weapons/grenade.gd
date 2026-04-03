extends RigidBody2D

@export var damage: int = 50
@export var explosion_radius: float = 30.0
@export var fuse_time: float = 3.0
@export var knockback: float = 600.0
## Dano mínimo na borda da explosão, como fração do dano total (0.3 = 30%)
@export var min_damage_ratio: float = 0.3

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var explosion_area: Area2D = $ExplosionArea
@onready var explosion_shape: CollisionShape2D = $ExplosionArea/CollisionShape2D
@onready var ambient_light: PointLight2D = $Sprite2D/AmbientLight

const _LIGHT_COLOR_START := Color(3.12, 0.92, 0.0, 1.0)
const _LIGHT_COLOR_END   := Color(3.0,  0.08, 0.0, 1.0)

var _timer: float = 0.0
var element_list: Array = []

func set_element_list(list: Array) -> void:
	var merged: Dictionary = {}
	for entry in list:
		var t: String = entry.type
		if merged.has(t):
			merged[t].dot_damage += entry.dot_damage
			merged[t].dot_ticks = maxi(merged[t].dot_ticks, entry.dot_ticks)
		else:
			merged[t] = entry.duplicate()
	element_list = merged.values()
	if element_list.size() > 0:
		sprite.modulate = element_list[0].color.lightened(0.3)

func _ready() -> void:
	explosion_area.monitoring = false
	if explosion_shape.shape is CircleShape2D:
		explosion_shape.shape.radius = explosion_radius
	
	# Garante que o sprite está no centro (reseta meus offsets anteriores)
	sprite.position = Vector2.ZERO

func setup(dir: Vector2, speed: float, _charge_ratio: float) -> void:
	# Aplica o impulso inicial usando a direção do mouse e a velocidade carregada
	# Em um platformer, 'dir' já é o vetor apontando para o mouse.
	linear_velocity = dir * speed
	
	# Dá um giro aleatório na granada para parecer natural
	apply_torque_impulse(randf_range(-200.0, 200.0))

func _physics_process(delta: float) -> void:
	_timer += delta
	if ambient_light:
		ambient_light.color = _LIGHT_COLOR_START.lerp(_LIGHT_COLOR_END, _timer / fuse_time)
	if _timer >= fuse_time:
		explode()

func explode() -> void:
	# Para a granada e a torna invisível
	freeze = true
	sprite.visible = false
	collision_shape.set_deferred("disabled", true)
	
	explosion_area.monitoring = true
	for body in explosion_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			var knockback_dir := (body.global_position - global_position).normalized()
			var dist := body.global_position.distance_to(global_position)
			var proximity: float = 1.0 - clamp(dist / explosion_radius, 0.0, 1.0)
			var dmg_scale: float = lerpf(min_damage_ratio, 1.0, proximity)
			body.take_damage(maxi(1, int(damage * dmg_scale)), knockback_dir, knockback * dmg_scale)
			for elem in element_list:
				if body.has_method("apply_element"):
					body.apply_element(elem)
	
	_spawn_explosion_fx()

	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("hit_effect"):
		cam.hit_effect(2.5, 0)  # explosão: shake grande, sem hitstop

	# Grenade pode ser liberada logo após spawnar os efeitos (partículas ficam no parent)
	await get_tree().create_timer(0.05).timeout
	queue_free()

func _spawn_explosion_fx() -> void:
	var pos := global_position
	var root := get_parent()
	if not root: return

	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	# --- Fragmentos grandes (núcleo da explosão) — poucos, rápidos, brancos/amarelos ---
	for i in range(18):
		var p := ColorRect.new()
		p.size = Vector2(4, 4) if randf() < 0.4 else Vector2(3, 3)
		var t := randf_range(0.0, 0.2)
		p.color = Color(1.0, 0.9 - t, 0.5 - t * 2.0, 1)
		p.material = mat
		root.add_child(p)
		p.global_position = pos + Vector2(randf_range(-2, 2), randf_range(-2, 2))
		var angle := randf_range(0.0, TAU)
		var dist := randf_range(30.0, 70.0)
		var target := p.global_position + Vector2(cos(angle) * dist, sin(angle) * dist + dist * 0.3)
		var dur := randf_range(0.12, 0.3)
		var tw := p.create_tween().set_parallel(true)
		tw.tween_property(p, "global_position", target, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, dur).set_delay(dur * 0.3)
		tw.finished.connect(p.queue_free)

	# --- Faíscas médias (laranja/vermelho) — massa principal ---
	for i in range(60):
		var p := ColorRect.new()
		p.size = Vector2(2, 2) if randf() < 0.5 else Vector2(1, 1)
		var warm := randf_range(0.0, 0.4)
		p.color = Color(1.0, 0.55 - warm * 0.5, 0.05, 1)
		p.material = mat
		root.add_child(p)
		p.global_position = pos + Vector2(randf_range(-5, 5), randf_range(-5, 5))
		var angle := randf_range(0.0, TAU)
		var dist := randf_range(15.0, 65.0)
		var target := p.global_position + Vector2(cos(angle) * dist, sin(angle) * dist + dist * 0.25)
		var dur := randf_range(0.2, 0.55)
		var tw := p.create_tween().set_parallel(true)
		tw.tween_property(p, "global_position", target, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, dur).set_delay(dur * 0.5)
		tw.finished.connect(p.queue_free)

	# --- Faíscas finas brancas (elétrico) — rápidas e longas ---
	for i in range(30):
		var p := ColorRect.new()
		p.size = Vector2(1, 1)
		p.color = Color(1.0, 1.0, 0.8, 1)
		p.material = mat
		root.add_child(p)
		p.global_position = pos + Vector2(randf_range(-3, 3), randf_range(-3, 3))
		var angle := randf_range(0.0, TAU)
		var dist := randf_range(40.0, 90.0)
		var target := p.global_position + Vector2(cos(angle) * dist, sin(angle) * dist + dist * 0.2)
		var dur := randf_range(0.1, 0.28)
		var tw := p.create_tween().set_parallel(true)
		tw.tween_property(p, "global_position", target, dur).set_trans(Tween.TRANS_LINEAR)
		tw.tween_property(p, "modulate:a", 0.0, dur)
		tw.finished.connect(p.queue_free)

	# --- Brasas subindo (foliagem) — sobem devagar e somem ---
	for i in range(55):
		var p := ColorRect.new()
		p.size = Vector2(1, 1)
		var heat := randf_range(0.0, 0.5)
		p.color = Color(1.0, 0.25 + heat, 0.05, 1)
		p.material = mat
		root.add_child(p)
		p.global_position = pos + Vector2(randf_range(-12, 12), randf_range(-6, 6))
		var angle := randf_range(deg_to_rad(-165), deg_to_rad(-15))
		var dist := randf_range(20.0, 85.0)
		var target := p.global_position + Vector2(cos(angle) * dist, sin(angle) * dist)
		var dur := randf_range(1.0, 2.8)
		var tw := p.create_tween().set_parallel(true)
		tw.tween_property(p, "global_position", target, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, dur).set_delay(dur * 0.35)
		tw.finished.connect(p.queue_free)
