class_name MeleeSwing
extends AttackBehavior

@export_group("Melee Swing")
@export var wind_up: float  = 0.4
@export var cooldown: float = 1.5

func try_attack(enemy: CharacterBody2D) -> void:
	var e := enemy as EnemyBase
	if not is_instance_valid(e.attack_target): return
	if e.global_position.distance_to(e.attack_target.global_position) > e.attack_range: return
	_do_attack(e)

func _do_attack(enemy: EnemyBase) -> void:
	enemy.attack_phase = EnemyBase.AttackPhase.WINDUP

	await enemy.get_tree().create_timer(wind_up).timeout

	if enemy.life_state == EnemyBase.LifeState.DEAD or enemy.attack_phase != EnemyBase.AttackPhase.WINDUP:
		enemy.attack_phase = EnemyBase.AttackPhase.READY
		return

	# Deal damage
	if is_instance_valid(enemy.attack_target):
		var dist: float = enemy.global_position.distance_to(enemy.attack_target.global_position)
		if dist <= enemy.attack_range + 20.0 and enemy.attack_target.has_method("take_damage"):
			var dir: Vector2 = (enemy.attack_target.global_position - enemy.global_position).normalized()
			GameManager._last_hit_source = enemy.name
			enemy.attack_target.take_damage(enemy.attack_damage, dir, enemy.attack_knockback)

	enemy.attack_phase = EnemyBase.AttackPhase.COOLDOWN
	await enemy.get_tree().create_timer(cooldown).timeout
	if enemy.life_state != EnemyBase.LifeState.DEAD:
		enemy.attack_phase = EnemyBase.AttackPhase.READY
