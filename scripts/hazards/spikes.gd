extends Area2D

@export var damage: int = 35
@export var knockback_force: float = 450.0

# Cooldown por corpo (RID → msec) — evita double-hit quando múltiplos spikes
# estão lado a lado e disparam body_entered no mesmo frame.
static var _hit_times: Dictionary = {}
const HIT_COOLDOWN_MS: int = 500

func _ready() -> void:
	collision_layer = 32  # layer 6 — detectável pelo wall_ray do inimigo
	collision_mask = 6    # detecta player (layer 3=4) + inimigos (layer 2=2)
	monitorable = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") and not body.is_in_group("enemies"):
		return
	var rid: RID = body.get_rid()
	var now := Time.get_ticks_msec()
	if now - _hit_times.get(rid, -999999) < HIT_COOLDOWN_MS:
		return
	_hit_times[rid] = now
	var direction := (body.global_position - global_position).normalized()
	body.take_damage(damage, direction, knockback_force, false)
