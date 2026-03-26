extends Area2D

@export var damage: int = 35
@export var knockback_force: float = 450.0

# Cooldown compartilhado entre todas as instâncias — evita double-hit quando
# dois espinhos estão lado a lado e disparam body_entered no mesmo frame.
static var _last_hit_msec: int = -999999
const HIT_COOLDOWN_MS: int = 500

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var now := Time.get_ticks_msec()
	if now - _last_hit_msec < HIT_COOLDOWN_MS:
		return
	_last_hit_msec = now
	var direction := (body.global_position - global_position).normalized()
	body.take_damage(damage, direction, knockback_force, false)
