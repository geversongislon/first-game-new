extends BaseWeapon
class_name ProjectileWeapon

## Incremento de dano por nível (índice 0=lvl1, 1=lvl2, 2=lvl3)
const UPGRADE_DMG_INC := [0.0, 0.25, 0.60]
## Redução do spread_max por nível de upgrade (índice 0=lvl1, 1=lvl2, 2=lvl3)
const UPGRADE_SPREAD_REDUCTION := [0.0, 0.30, 0.70]

@export var bullet_scene: PackedScene
@export var bullet_speed: float = 1200.0
@export var bullet_damage: int = 1
@export var bullet_knockback: float = 90.0
@export var bullet_gravity: float = 980.0
@export var recoil_per_shot: float = 30.0

## Se true, o player precisa ficar parado por stillness_time_required segundos antes de atirar
@export var requires_stillness: bool = false
@export var stillness_time_required: float = 1.0
## Velocidade máxima do player para ser considerado parado
const STILLNESS_THRESHOLD: float = 8.0
var _stillness_timer: float = 0.0

var _current_spread: float = 0.0
var _spread_base: float = 0.0
var _spread_max: float = 0.0
var _spread_buildup: float = 0.0
var _spread_recovery: float = 0.0

func _apply_archetype_stats() -> void:
	if not card_data: return
	bullet_speed = card_data.projectile_speed
	bullet_damage = card_data.projectile_damage
	bullet_knockback = card_data.projectile_knockback
	bullet_gravity = card_data.projectile_gravity
	recoil_per_shot = card_data.weapon_recoil
	if card_data.custom_projectile_scene:
		bullet_scene = card_data.custom_projectile_scene
	requires_stillness = card_data.requires_stillness
	stillness_time_required = card_data.stillness_time_required
	_spread_base     = card_data.spread_base_angle
	_spread_max      = card_data.spread_max_angle
	_spread_buildup  = card_data.spread_buildup_per_shot
	_spread_recovery = card_data.spread_recovery_rate
	_current_spread  = _spread_base

func _apply_archetype_bonuses(stack: int, upgrade_levels: Array) -> void:
	var stack_dmg := 1.2 if stack == 2 else (1.5 if stack == 3 else 1.0)

	var dmg_inc := 0.0
	for lvl in upgrade_levels:
		dmg_inc += UPGRADE_DMG_INC[clampi(lvl - 1, 0, 2)]

	bullet_damage = int(bullet_damage * stack_dmg * (1.0 + dmg_inc))

	# Reduz spread máximo por upgrade (usa o nível mais alto entre os slots equipados)
	if _spread_max > 0.0:
		var best_lvl := 0
		for lvl in upgrade_levels:
			best_lvl = maxi(best_lvl, lvl)
		var reduction: float = UPGRADE_SPREAD_REDUCTION[clampi(best_lvl - 1, 0, 2)]
		_spread_max *= (1.0 - reduction)

func _process(delta: float) -> void:
	super._process(delta)
	if _current_spread > _spread_base:
		_current_spread = max(_spread_base, _current_spread - _spread_recovery * delta)
	if not requires_stillness or not player: return
	var moving: bool = player.velocity.length() > STILLNESS_THRESHOLD
	if moving:
		_stillness_timer = 0.0
	else:
		_stillness_timer = min(_stillness_timer + delta, stillness_time_required)

func _is_stance_ready() -> bool:
	if not requires_stillness: return true
	return _stillness_timer >= stillness_time_required

func start_reload() -> void:
	super.start_reload()
	_current_spread = _spread_base

var _laser: Line2D = null
var _is_aiming: bool = false

func on_aim_pressed() -> void:
	if not card_data or not card_data.has_scope: return
	_is_aiming = true
	_laser = Line2D.new()
	_laser.width = 0.5
	_laser.z_index = 10
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_laser.material = mat
	if player and player.get_parent():
		player.get_parent().add_child(_laser)
	var cam: Camera2D = player.get_node_or_null("Camera2D") if player else null
	if cam and cam.has_method("set_scope_zoom"):
		cam.set_scope_zoom(true)

func on_aim_held(_delta: float) -> void:
	if not _is_aiming or not is_instance_valid(_laser): return
	var visual: WeaponVisual = player._current_weapon_visual if player else null
	var from := visual.spawn_point.global_position if visual and visual.spawn_point else player.global_position
	var dir := (player.get_global_mouse_position() - from).normalized()
	var space := player.get_world_2d().direct_space_state
	var params := PhysicsRayQueryParameters2D.create(from, from + dir * 2000.0)
	params.collision_mask = 1
	params.exclude = [player.get_rid()]
	var result := space.intersect_ray(params)
	var end: Vector2 = result.get("position", from + dir * 2000.0) if result else from + dir * 2000.0
	_laser.clear_points()
	_laser.add_point(from)
	_laser.add_point(end)
	var pulse := (sin(Time.get_ticks_msec() * 0.012) + 1.0) * 0.5
	_laser.default_color = Color(1.0, pulse * 0.2, pulse * 0.2, 0.85)

func on_aim_released() -> void:
	if not _is_aiming: return
	_is_aiming = false
	if is_instance_valid(_laser):
		_laser.queue_free()
	_laser = null
	var cam: Camera2D = player.get_node_or_null("Camera2D") if player else null
	if cam and cam.has_method("set_scope_zoom"):
		cam.set_scope_zoom(false)

func on_attack_pressed() -> void:
	if not is_automatic and can_fire() and _is_stance_ready():
		_shoot()

func on_attack_held(_delta: float) -> void:
	if is_automatic and can_fire() and _is_stance_ready():
		_shoot()

func _shoot() -> void:
	consume_ammo()
	if player and player.weapon_sprite and player.weapon_sprite.sprite_frames and player.weapon_sprite.sprite_frames.has_animation("shoot"):
		player.weapon_sprite.play("shoot")
	if player and player.has_method("muzzle_flash"):
		player.muzzle_flash()

	if bullet_scene == null: return

	var node: Node = bullet_scene.instantiate()
	var bullet: Area2D = node as Area2D
	if bullet == null: return

	var mouse_pos: Vector2 = player.get_global_mouse_position()
	var aim_origin: Vector2 = player.hand_pivot.global_position if player.hand_pivot else player.global_position
	var dir: Vector2 = (mouse_pos - aim_origin).normalized()
	if _current_spread > 0.0:
		dir = dir.rotated(randf_range(-deg_to_rad(_current_spread * 0.5), deg_to_rad(_current_spread * 0.5)))
	_current_spread = min(_spread_max, _current_spread + _spread_buildup)
	var visual: WeaponVisual = player._current_weapon_visual
	var base_pos: Vector2 = visual.spawn_point.global_position if visual and visual.spawn_point else player.global_position

	var crit := roll_crit(bullet_damage)
	bullet.damage = crit.damage
	bullet.is_crit = crit.is_crit
	bullet.knockback = bullet_knockback
	if "projectile_gravity" in bullet:
		bullet.projectile_gravity = bullet_gravity

	player.get_parent().add_child(bullet)

	bullet.global_position = base_pos
	bullet.rotation = dir.angle()

	if bullet.has_method("setup"):
		bullet.setup(dir, bullet_speed)

	player.velocity.x -= dir.x * recoil_per_shot
	player.velocity.y -= dir.y * recoil_per_shot * 0.15

	# Reseta o timer após atirar — obriga nova espera
	if requires_stillness:
		_stillness_timer = 0.0
