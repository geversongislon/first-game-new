extends BaseWeapon
class_name ChargeWeapon

## Incremento de dano por nível (índice 0=lvl1, 1=lvl2, 2=lvl3)
const UPGRADE_DMG_INC := [0.0, 0.25, 0.60]

@export var projectile_scene: PackedScene

@export var max_charge: float = 1.5
@export var min_projectile_speed: float = 500.0
@export var max_projectile_speed: float = 1400.0

@export var min_damage: int = 5
@export var max_damage: int = 20

@export var min_knockback: float = 120.0
@export var max_knockback: float = 520.0

@export var min_recoil: float = 100.0
@export var max_recoil: float = 980.0

func _apply_archetype_stats() -> void:
	if not card_data: return
	
	max_charge = card_data.max_charge_time
	min_damage = card_data.charge_damage_range.x
	max_damage = card_data.charge_damage_range.y
	min_projectile_speed = card_data.charge_speed_range.x
	max_projectile_speed = card_data.charge_speed_range.y
	min_knockback = card_data.charge_knockback_range.x
	max_knockback = card_data.charge_knockback_range.y
	min_recoil = card_data.charge_recoil_range.x
	max_recoil = card_data.charge_recoil_range.y
	
	if card_data.custom_projectile_scene:
		projectile_scene = card_data.custom_projectile_scene

func _apply_archetype_bonuses(stack: int, upgrade_levels: Array) -> void:
	var stack_dmg   := 1.5  if stack == 2 else 2.5  if stack == 3 else 1.0
	var charge_mult := 0.80 if stack == 2 else 0.10 if stack == 3 else 1.0

	var dmg_inc := 0.0
	for lvl in upgrade_levels:
		dmg_inc += UPGRADE_DMG_INC[clampi(lvl - 1, 0, 2)]

	min_damage = int(min_damage * stack_dmg * (1.0 + dmg_inc))
	max_damage = int(max_damage * stack_dmg * (1.0 + dmg_inc))
	max_charge *= charge_mult


var is_charging: bool = false
var charge_time: float = 0.0
var _base_light_energy: float = -1.0

func on_attack_pressed() -> void:
	if can_fire():
		is_charging = true
		charge_time = 0.0
		var visual: WeaponVisual = player._current_weapon_visual if player else null
		if visual and visual.ambient_light:
			_base_light_energy = visual.ambient_light.energy

func on_attack_held(delta: float) -> void:
	if not is_charging: return
	
	charge_time = clamp(charge_time + delta, 0.0, max_charge)
	
	if player and player.weapon_sprite:
		var ratio := charge_time / max_charge
		var sprite: AnimatedSprite2D = player.weapon_sprite
		if sprite.animation != "charge":
			sprite.play("charge")
			sprite.pause()
		var frame_count: int = sprite.sprite_frames.get_frame_count("charge")
		sprite.frame = int(ratio * (frame_count - 1))
		var visual: WeaponVisual = player._current_weapon_visual
		if ratio >= 1.0:
			var pulse := (sin(Time.get_ticks_msec() * 0.015) + 1.0) * 0.5
			sprite.modulate = Color.WHITE.lerp(Color(1.5, 1.5, 0.0), pulse)
			if visual and visual.ambient_light:
				visual.ambient_light.color = Color.WHITE.lerp(Color(1.0, 0.85, 0.2), pulse)
				visual.ambient_light.energy = lerp(visual.ambient_light.energy, 2.8, pulse)
		else:
			sprite.modulate = Color.WHITE

func on_attack_released() -> void:
	if not is_charging: return

	var visual: WeaponVisual = player._current_weapon_visual if player else null
	if player and player.weapon_sprite:
		player.weapon_sprite.modulate = Color.WHITE
	if visual and visual.ambient_light and _base_light_energy >= 0.0:
		visual.ambient_light.color = Color.WHITE
		var tw := visual.create_tween()
		tw.tween_property(visual.ambient_light, "energy", _base_light_energy, 0.15)

	_shoot()
	is_charging = false
	consume_ammo()

func _shoot() -> void:
	if player and player.weapon_sprite:
		player.weapon_sprite.play("shoot")

	if projectile_scene == null: return

	var arrow_node: Node = projectile_scene.instantiate()
	var arrow: Area2D = arrow_node as Area2D
	if arrow == null: return

	var mouse_pos: Vector2 = player.get_global_mouse_position()
	var dir: Vector2 = (mouse_pos - player.global_position).normalized()
	var visual: WeaponVisual = player._current_weapon_visual
	var base_pos: Vector2 = visual.spawn_point.global_position if visual and visual.spawn_point else player.global_position

	arrow.global_position = base_pos
	arrow.rotation = dir.angle()

	var ratio: float = charge_time / max_charge
	var final_speed: float = lerp(min_projectile_speed, max_projectile_speed, ratio)

	var base_dmg := int(round(lerp(float(min_damage), float(max_damage), ratio)))
	var crit := roll_crit(base_dmg)
	arrow.damage = crit.damage
	arrow.is_crit = crit.is_crit
	
	player.get_parent().add_child(arrow)
	
	if arrow.has_method("setup"):
		arrow.setup(dir, final_speed)
	
	var t: float = pow(ratio, 2.0)
	arrow.knockback = lerp(min_knockback, max_knockback, t)

	var recoil: float = lerp(min_recoil, max_recoil, ratio)
	player.velocity.x -= dir.x * recoil
	player.velocity.y -= dir.y * recoil * 0.15
