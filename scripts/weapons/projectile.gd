extends Area2D

@export var projectile_gravity: float = 980.0
var speed: float = 800.0 # Alterado de export para var comum, quem dita isso é o arco
@export var damage: int = 1
@export var knockback: float = 0.0
@export var stick_on_hit: bool = false
@export var impact_color: Color = Color(1.0, 0.9, 0.7, 1.0)

var direction: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var is_stuck: bool = false
var is_crit: bool = false
var source_name: String = "" # nome do inimigo que disparou (vazio = projétil do player)
var time_compensation: float = 1.0
var element_list: Array = []

func set_element_list(list: Array) -> void:
	# Agrega entradas do mesmo tipo (ex: 2x Poison → 1 entry com dano somado)
	var merged: Dictionary = {}
	for entry in list:
		var t: String = entry.type
		if merged.has(t):
			merged[t].dot_damage += entry.dot_damage
			merged[t].dot_ticks = maxi(merged[t].dot_ticks, entry.dot_ticks)
		else:
			merged[t] = entry.duplicate()
	element_list = merged.values()

	if element_list.is_empty(): return
	var first: Dictionary = element_list[0]
	for child in get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			child.modulate = first.color.lightened(0.3)
			break
	if has_node("PointLight2D"):
		$PointLight2D.color = first.color
	_setup_tip_particles(first)

func _setup_tip_particles(elem: Dictionary) -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(10, 0)
	p.emitting = true
	p.amount = 8
	p.lifetime = 0.4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.5
	p.direction = Vector2(-1, 0)
	p.spread = 35.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 22.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.4
	var grad := Gradient.new()
	grad.set_color(0, elem.color.lightened(0.2))
	grad.set_color(1, Color(elem.color.r, elem.color.g, elem.color.b, 0.0))
	p.color_ramp = grad
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.material = mat
	p.z_index = -1
	add_child(p)

func _ready() -> void:
	# Projéteis do player mantêm velocidade normal durante slow-mo
	if source_name == "" and Engine.time_scale > 0.0 and Engine.time_scale < 1.0:
		var p := get_tree().get_first_node_in_group("player")
		if p and p.get("slow_mo_compensation"):
			time_compensation = 1.0 / Engine.time_scale

func setup(dir: Vector2, spd: float) -> void:
	direction = dir
	speed = spd
	
	# Calcula a velocidade inicial APÓS o Godot ter carregado a projectile_gravity do Inspector
	velocity = direction * speed

func _physics_process(delta: float) -> void:
	if is_stuck:
		return
	var eff := delta * time_compensation
	velocity.y += projectile_gravity * eff
	position += velocity * eff
	rotation = velocity.angle()

func _on_body_entered(body: Node) -> void:
	if is_stuck:
		return

	if source_name != "" and (body.is_in_group("Player") or body.name == "Player"):
		GameManager._last_hit_source = source_name
	if body.has_method("take_damage"):
		body.take_damage(damage, velocity.normalized(), knockback, is_crit)
		for elem in element_list:
			if body.has_method("apply_element"):
				body.apply_element(elem)
	else:
		_spawn_impact_fx()

	if stick_on_hit:
		_stick_to_target(body)
	else:
		queue_free()

func _spawn_impact_fx() -> void:
	var root := get_parent()
	if not root: return
	var pos := global_position
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
		# Espalha num cone oposto à direção de impacto
		var base_angle := (hit_dir * -1.0).angle()
		var angle := base_angle + randf_range(deg_to_rad(-60), deg_to_rad(60))
		var dist := randf_range(3.0, 10.0)
		var target := p.global_position + Vector2(cos(angle) * dist, sin(angle) * dist)
		var dur := randf_range(0.1, 0.25)
		var tw := p.create_tween().set_parallel(true)
		tw.tween_property(p, "global_position", target, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, dur)
		tw.finished.connect(p.queue_free)

func _stick_to_target(target: Node) -> void:
	is_stuck = true
	velocity = Vector2.ZERO
	
	# Desliga o radar de colisão pro jogo não ficar processando infinitamente
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Se acertou um corpo que se mexe (KinematicBody/CharacterBody), 
	# a flecha vira "filha" dele para acompanhá-lo no movimento.
	if target is CharacterBody2D or target is RigidBody2D:
		call_deferred("_reparent_to_target", target)
		
	# Inicia o "Lixeiro" para ela sumir suavemente depois de 10 segundos
	await get_tree().create_timer(10.0).timeout
	
	var tween = create_tween()
	tween.tween_property(self , "modulate:a", 0.0, 1.0) # Fica invisível em 1 segundo
	await tween.finished
	queue_free()

func _reparent_to_target(target: Node) -> void:
	if not is_instance_valid(target) or not is_instance_valid(get_parent()):
		return
		
	var global_pos = global_position
	var global_rot = global_rotation
	get_parent().remove_child(self )
	target.add_child(self )
	global_position = global_pos
	global_rotation = global_rot
