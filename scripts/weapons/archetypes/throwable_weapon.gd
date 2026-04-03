extends BaseWeapon
class_name ThrowableWeapon

## Incremento de dano por nível (índice 0=lvl1, 1=lvl2, 2=lvl3)
const UPGRADE_DMG_INC := [0.0, 0.25, 0.60]

const ARC_SCENE = preload("res://scenes/weapons/throw_arc.tscn")

@export var throwable_scene: PackedScene

# Velocidades (força do arremesso)
@export var max_charge: float = 1.0
@export var min_throw_speed: float = 200.0
@export var max_throw_speed: float = 800.0

func _apply_archetype_stats() -> void:
	if not card_data: return

	max_charge = card_data.max_charge_time
	min_throw_speed = card_data.charge_speed_range.x
	max_throw_speed = card_data.charge_speed_range.y

	if card_data.custom_projectile_scene:
		throwable_scene = card_data.custom_projectile_scene

func _apply_archetype_bonuses(stack: int, _upgrade_levels: Array) -> void:
	var stack_spd := 1.3 if stack == 2 else 1.8 if stack == 3 else 1.0
	min_throw_speed *= stack_spd
	max_throw_speed *= stack_spd


var is_charging: bool = false
var charge_time: float = 0.0
var _arc_node: ThrowArc = null

func on_attack_pressed() -> void:
	if can_fire():
		is_charging = true
		charge_time = 0.0
		_spawn_arc()
		_update_arc()

func on_attack_held(delta: float) -> void:
	if not is_charging: return
	charge_time = clamp(charge_time + delta, 0.0, max_charge)
	_update_arc()

func on_attack_released() -> void:
	if not is_charging: return
	_destroy_arc()

	if player and player.weapon_sprite:
		player.weapon_sprite.modulate = Color.WHITE

	var ratio: float = charge_time / max_charge
	var final_speed: float = lerp(min_throw_speed, max_throw_speed, ratio)

	_throw(final_speed, ratio)
	is_charging = false

func _throw(final_speed: float, charge_ratio: float) -> void:
	consume_ammo()
	if player and player.weapon_sprite:
		player.weapon_sprite.play("shoot")

	if throwable_scene == null:
		return

	var node: Node = throwable_scene.instantiate()
	var throwable: Node2D = node as Node2D
	if throwable == null:
		return

	var mouse_pos: Vector2 = player.get_global_mouse_position()
	var dir: Vector2 = (mouse_pos - player.global_position).normalized()

	var visual: WeaponVisual = player._current_weapon_visual
	var base_pos: Vector2 = visual.spawn_point.global_position if visual and visual.spawn_point else player.global_position

	throwable.global_position = base_pos

	player.get_parent().add_child(throwable)

	if card_data and "damage" in throwable:
		throwable.damage = card_data.charge_damage_range.x

	if card_data and "knockback" in throwable:
		throwable.knockback = card_data.charge_knockback_range.x

	if throwable.has_method("setup"):
		throwable.setup(dir, final_speed, charge_ratio)

	if player and player.active_elements.size() > 0 and throwable.has_method("set_element_list"):
		throwable.set_element_list(player.active_elements)

# -------- Arco de Trajetória --------

func _spawn_arc() -> void:
	_destroy_arc()
	if not player: return
	_arc_node = ARC_SCENE.instantiate()
	player.get_parent().add_child(_arc_node)
	_arc_node.set_exclude(player)

func _update_arc() -> void:
	if not _arc_node or not is_instance_valid(_arc_node): return
	if not player: return

	var mouse_pos := player.get_global_mouse_position()
	var dir := (mouse_pos - player.global_position).normalized()
	var ratio := charge_time / max_charge
	var speed: float = lerp(min_throw_speed, max_throw_speed, ratio)

	var visual: WeaponVisual = player._current_weapon_visual
	var spawn_pos: Vector2 = visual.spawn_point.global_position if visual and visual.spawn_point else player.global_position

	_arc_node.update_arc(spawn_pos, dir, speed)

func _destroy_arc() -> void:
	if _arc_node and is_instance_valid(_arc_node):
		_arc_node.queue_free()
	_arc_node = null

func _exit_tree() -> void:
	_destroy_arc()
