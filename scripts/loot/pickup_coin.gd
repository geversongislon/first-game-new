extends CharacterBody2D

# Loot com física real e efeito de quique
var fall_gravity: float = 200.0
var bounce_factor: float = 0.5
var friction: float = 12.0

func _ready() -> void:
	if velocity == Vector2.ZERO:
		velocity.x = randf_range(-38.0, 38.0)
		velocity.y = randf_range(-75.0, -38.0)

func _physics_process(delta: float) -> void:
	# Aplica gravidade
	if not is_on_floor():
		velocity.y += fall_gravity * delta
	
	# Move o corpo usando a física do Godot
	move_and_slide()
	
	# Efeito de quique quando toca o chão
	if is_on_floor():
		if abs(velocity.y) < 10.0: # Se a velocidade for muito baixa, para de quicar
			velocity.y = 0
		else:
			# Inverte a velocidade Y com perca de energia (bounce)
			# Nota: is_on_floor detecta a colisão do frame anterior, 
			# mas move_and_slide reseta a velocidade ao colidir se não tratarmos.
			# Usamos get_real_velocity() ou checamos a colisão manualmente se necessário,
			# mas para um drop simples, podemos usar a velocidade acumulada.
			pass

	# Tratamento manual de quique mais preciso
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var normal = collision.get_normal()
		
		# Se colidiu com algo horizontal (chão)
		if normal.y < -0.5:
			if abs(velocity.y) > 50:
				velocity.y = - velocity.y * bounce_factor
			else:
				velocity.y = 0
			
			# Aplica atrito no X ao estar no chão
			velocity.x = lerp(velocity.x, 0.0, friction * delta)
		
		# Se colidiu com paredes
		if abs(normal.x) > 0.5:
			velocity.x = - velocity.x * bounce_factor

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		GameManager.add_run_coin(1)
		_collect_effect()

func _collect_effect() -> void:
	var parent := get_parent()
	if not parent:
		queue_free()
		return

	var base := global_position + Vector2(0.0, 5.0) # base do sprite
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var gold := Color(1.0, 0.92, 0.35, 1.0)

	for i in range(7):
		var p := ColorRect.new()
		p.size = Vector2(1, 1)
		p.color = gold.lightened(randf_range(0.0, 0.45))
		p.material = mat
		p.z_index = 10
		p.z_as_relative = false
		parent.add_child(p)
		p.global_position = base + Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 1.0))

		var angle := randf_range(deg_to_rad(-150), deg_to_rad(-30))
		var dist := randf_range(5.0, 12.0)
		var target_pos := p.global_position + Vector2(cos(angle) * dist, sin(angle) * dist)
		var duration := randf_range(0.35, 0.65)

		var tw := p.create_tween().set_parallel(true)
		tw.tween_property(p, "global_position", target_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, duration)
		tw.finished.connect(p.queue_free)

	# Luz desvanece pelo tempo da animação e depois some
	var light := get_node_or_null("PointLight2D") as PointLight2D
	if light:
		light.reparent(parent)
		var tw_light := light.create_tween()
		tw_light.tween_property(light, "energy", 0.0, 0.45)
		tw_light.tween_callback(light.queue_free)

	queue_free()
