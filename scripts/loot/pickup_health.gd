extends CharacterBody2D

@export var heal_amount: int = 25

var fall_gravity: float = 200.0
var bounce_factor: float = 0.4
var friction: float = 12.0

var _floating: bool = false
var _float_time: float = 0.0
const FLOAT_AMPLITUDE: float = 2.5
const FLOAT_SPEED: float = 2.8
const FLOAT_HEIGHT: float = -8.0
const FLOAT_RISE_SPEED: float = 7.0

@onready var _visual: ColorRect = $ColorRect

func _ready() -> void:
	if velocity == Vector2.ZERO:
		velocity.x = randf_range(-30.0, 30.0)
		velocity.y = randf_range(-75.0, -38.0)
	_float_time = randf_range(0.0, TAU)

func _physics_process(delta: float) -> void:
	if _floating:
		# Sobe gradualmente até FLOAT_HEIGHT, depois oscila
		var target_y := FLOAT_HEIGHT + sin(_float_time) * FLOAT_AMPLITUDE
		_visual.position.y = move_toward(_visual.position.y, target_y, FLOAT_RISE_SPEED * delta)
		if abs(_visual.position.y - FLOAT_HEIGHT) < FLOAT_AMPLITUDE + 1.0:
			_float_time += delta * FLOAT_SPEED
		return

	if not is_on_floor():
		velocity.y += fall_gravity * delta
	move_and_slide()

	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var normal = col.get_normal()
		if normal.y < -0.5:
			if abs(velocity.y) > 50:
				velocity.y = -velocity.y * bounce_factor
			else:
				velocity.y = 0
			velocity.x = lerp(velocity.x, 0.0, friction * delta)
		if abs(normal.x) > 0.5:
			velocity.x = -velocity.x * bounce_factor

	# Quando praticamente parado no chão, passa para modo flutuante
	if is_on_floor() and abs(velocity.x) < 5.0 and abs(velocity.y) < 5.0:
		velocity = Vector2.ZERO
		_floating = true

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		if body.has_method("heal"):
			body.heal(heal_amount)
		_collect_effect()

func _collect_effect() -> void:
	var parent := get_parent()
	if not parent:
		queue_free()
		return

	var base := global_position + Vector2(0.0, 5.0)
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var red := Color(1.0, 0.25, 0.25, 1.0)

	for i in range(7):
		var p := ColorRect.new()
		p.size = Vector2(1, 1)
		p.color = red.lightened(randf_range(0.0, 0.45))
		p.material = mat
		p.z_index = 10
		p.z_as_relative = false
		parent.add_child(p)
		p.global_position = base + Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 1.0))

		var angle := randf_range(deg_to_rad(-150), deg_to_rad(-30))
		var dist  := randf_range(5.0, 12.0)
		var target_pos := p.global_position + Vector2(cos(angle) * dist, sin(angle) * dist)
		var duration   := randf_range(0.35, 0.65)

		var tw := p.create_tween().set_parallel(true)
		tw.tween_property(p, "global_position", target_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, duration)
		tw.finished.connect(p.queue_free)

	var light := get_node_or_null("PointLight2D") as PointLight2D
	if light:
		light.reparent(parent)
		var tw_light := light.create_tween()
		tw_light.tween_property(light, "energy", 0.0, 0.45)
		tw_light.tween_callback(light.queue_free)

	queue_free()
