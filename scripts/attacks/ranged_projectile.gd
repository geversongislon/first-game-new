class_name RangedProjectile
extends AttackBehavior

@export_group("Ranged Projectile")
@export var wind_up: float = 0.4
@export var cooldown: float = 1.5
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 75.0
@export var burst_count: int = 0 ## Tiros por rajada (0 = desativado)
@export var burst_pause: float = 2.0 ## Pausa após completar a rajada

func try_attack(enemy: CharacterBody2D) -> void:
	var e := enemy as EnemyBase
	if not is_instance_valid(e.attack_target): return
	if e.global_position.distance_to(e.attack_target.global_position) > e.attack_range: return
	_do_attack(e)

func _do_attack(enemy: EnemyBase) -> void:
	var shots: int = max(burst_count, 1)
	for i in shots:
		enemy.attack_phase = EnemyBase.AttackPhase.WINDUP
		_set_windup_light(enemy, true)
		await enemy.get_tree().create_timer(wind_up).timeout

		if enemy.life_state == EnemyBase.LifeState.DEAD or \
				enemy.attack_phase != EnemyBase.AttackPhase.WINDUP:
			_set_windup_light(enemy, false)
			enemy.attack_phase = EnemyBase.AttackPhase.READY
			return

		_set_windup_light(enemy, false)
		_fire(enemy)

		enemy.attack_phase = EnemyBase.AttackPhase.COOLDOWN
		await enemy.get_tree().create_timer(cooldown).timeout
		if enemy.life_state == EnemyBase.LifeState.DEAD:
			return

	if burst_count > 0:
		await enemy.get_tree().create_timer(burst_pause).timeout

	if enemy.life_state != EnemyBase.LifeState.DEAD:
		enemy.attack_phase = EnemyBase.AttackPhase.READY

func _set_windup_light(enemy: EnemyBase, active: bool) -> void:
	var light := enemy.get_node_or_null("PointLight2D") as PointLight2D
	var sprite := enemy.get_node_or_null("Sprite2D")

	if active:
		if light:
			light.color = Color(1.0, 0.1, 0.05) # vermelho
			light.energy = 0.0
			light.visible = true
			var tw := enemy.create_tween()
			tw.tween_property(light, "energy", 1.0, wind_up) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		if sprite and sprite.material is ShaderMaterial:
			sprite.material.set_shader_parameter("flash_color", Vector3(1.0, 0.1, 0.05))
			var tw := enemy.create_tween()
			tw.tween_method(
				func(v: float): sprite.material.set_shader_parameter("flash_amount", v),
				0.0, 0.3, wind_up) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	else:
		if light:
			var tw := enemy.create_tween()
			tw.tween_property(light, "energy", 0.0, 0.12)
			tw.tween_callback(func(): light.visible = false)
		if sprite and sprite.material is ShaderMaterial:
			var tw := enemy.create_tween()
			tw.tween_method(
				func(v: float): sprite.material.set_shader_parameter("flash_amount", v),
				0.3, 0.0, 0.12)
			tw.tween_callback(func(): sprite.material.set_shader_parameter("flash_color", Vector3(1.0, 1.0, 1.0)))

func _fire(enemy: EnemyBase) -> void:
	if not projectile_scene: return

	var spawn_pos: Vector2 = enemy.global_position

	var dir: Vector2 = Vector2.RIGHT * float(enemy.direction)
	if is_instance_valid(enemy.attack_target):
		dir = (enemy.attack_target.global_position - spawn_pos).normalized()
		if enemy.move_mode == EnemyBase.MoveMode.CHASE:
			enemy.direction = sign(dir.x) if dir.x != 0.0 else enemy.direction
			enemy.update_visual()

	spawn_pos += dir * 11.0

	var proj = projectile_scene.instantiate()
	var root = enemy.get_tree().current_scene if enemy.get_tree().current_scene else enemy.get_parent()
	if not root: return

	proj.position = root.to_local(spawn_pos)
	proj.z_index = 60
	if "damage" in proj: proj.damage = enemy.attack_damage
	if "knockback" in proj: proj.knockback = enemy.attack_knockback
	if "source_name" in proj: proj.source_name = enemy.name
	root.add_child(proj)
	if proj.has_method("setup"): proj.setup(dir, projectile_speed)
