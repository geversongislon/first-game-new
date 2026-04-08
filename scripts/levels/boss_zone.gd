class_name BossZone
extends Area2D

@export var zoom_target: Vector2 = Vector2(0.45, 0.45)
@export var zoom_duration: float = 1.8

var _camera: Camera2D = null
var _timer: Timer = null
var _seen_enemy := false
var _zone_rect := Rect2()

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_zone_rect = _calc_rect()

func _calc_rect() -> Rect2:
	var shape := $CollisionShape2D
	if shape.shape is RectangleShape2D:
		var half: Vector2 = (shape.shape as RectangleShape2D).size / 2.0
		var center: Vector2 = global_position + shape.position
		return Rect2(center - half, half * 2.0)
	return Rect2(global_position - Vector2(200, 120), Vector2(400, 240))

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_camera = body.get_node_or_null("Camera2D")
	if _camera == null:
		return
	_camera.call("lock_to_zone", _zone_rect, zoom_target, zoom_duration)
	_seen_enemy = false
	if _timer and is_instance_valid(_timer):
		_timer.queue_free()
	_timer = Timer.new()
	_timer.wait_time = 0.5
	_timer.autostart = true
	_timer.timeout.connect(_check_cleared)
	add_child(_timer)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_unlock()

func _check_cleared() -> void:
	var living := 0
	for node in get_parent().get_children():
		if not is_instance_valid(node):
			continue
		if not ("is_dead" in node):
			continue
		if node.get("is_dead"):
			continue
		if _zone_rect.has_point((node as Node2D).global_position):
			living += 1
	if living > 0:
		_seen_enemy = true
		return
	if not _seen_enemy:
		return
	_unlock()

func _unlock() -> void:
	if _timer and is_instance_valid(_timer):
		_timer.queue_free()
		_timer = null
	_seen_enemy = false
	if is_instance_valid(_camera):
		_camera.call("unlock_zone", zoom_duration)
	_camera = null
