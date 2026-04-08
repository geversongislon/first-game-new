class_name CameraFollow
extends Camera2D

## Offset horizontal em pixels de jogo (viewport 320px → 320/6 ≈ 53)
@export var thirds_offset: float = 53.0
## Velocidade de transição do offset (lerp speed)
@export var transition_speed: float = 1.0

var _target_offset_x: float = 0.0
var _walk_timer: float = 0.0
## Segundos andando antes de mudar o offset
@export var walk_commit_time: float = 0.12

## Offset vertical ao olhar para baixo (S)
@export var look_down_offset: float = 60.0
## Segundos segurando S antes de iniciar o movimento da câmera
@export var look_down_delay: float = 0.4

var _target_offset_y: float = 0.0
var _look_down_timer: float = 0.0

var _shake_intensity: float = 0.0
var _shake_duration: float  = 0.0

var _hitstop_end_ms: int = 0  # wall-clock, imune ao time_scale

## Zoom out da mira (sniper). Valores < 1 = mais afastado
@export var scope_zoom_out: Vector2 = Vector2(0.6, 0.6)
@export var scope_zoom_duration: float = 0.18

var _base_zoom: Vector2 = Vector2.ONE
var _scope_tween: Tween = null
var _zone_locked: bool = false

func _ready() -> void:
	_base_zoom = zoom

func set_scope_zoom(aiming: bool) -> void:
	if _scope_tween:
		_scope_tween.kill()
	_scope_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	var target := scope_zoom_out if aiming else _base_zoom
	_scope_tween.tween_property(self, "zoom", target, scope_zoom_duration)

func shake(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_duration  = duration

## Chama hitstop + shake de uma vez. Usado pelos projéteis ao acertar inimigos.
func hit_effect(shake_intensity: float, hitstop_ms: int) -> void:
	shake(shake_intensity, 0.10)
	if hitstop_ms > 0:
		Engine.time_scale = 0.05
		_hitstop_end_ms = Time.get_ticks_msec() + hitstop_ms

## Slow-motion. Escala configurável (padrão 0.2), duração em ms reais.
func slow_motion(real_duration_ms: int, slow_scale: float = 0.2) -> void:
	Engine.time_scale = slow_scale
	_hitstop_end_ms = Time.get_ticks_msec() + real_duration_ms

func _process(delta: float) -> void:
	var player := get_parent() as CharacterBody2D
	if not player:
		return

	if not _zone_locked:
		var input_x := Input.get_axis("ui_left", "ui_right")
		if abs(input_x) > 0.1 and abs(player.velocity.x) > 10.0:
			_walk_timer += delta
			if _walk_timer >= walk_commit_time:
				_target_offset_x = thirds_offset if input_x > 0.0 else -thirds_offset
		else:
			_walk_timer = 0.0

		offset.x = lerpf(offset.x, _target_offset_x, transition_speed * delta)

		# Look down — câmera desce após segurar S por look_down_delay segundos
		if Input.is_action_pressed("move_down"):
			_look_down_timer += delta
			if _look_down_timer >= look_down_delay:
				_target_offset_y = look_down_offset
		else:
			_look_down_timer = 0.0
			_target_offset_y = 0.0
		offset.y = lerpf(offset.y, _target_offset_y, transition_speed * delta)

	# Hitstop — restaura time_scale quando o tempo real passar
	if _hitstop_end_ms > 0 and Time.get_ticks_msec() >= _hitstop_end_ms:
		_hitstop_end_ms = 0
		Engine.time_scale = 1.0

	# Safety: nunca deixar time_scale travado sem hitstop ativo
	if Engine.time_scale < 1.0 and _hitstop_end_ms == 0:
		Engine.time_scale = 1.0

	if _shake_duration > 0.0:
		_shake_duration -= delta
		offset += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_intensity

func lock_to_zone(rect: Rect2, target_zoom: Vector2, duration: float) -> void:
	_zone_locked = true
	offset = Vector2.ZERO
	_target_offset_x = 0.0
	_target_offset_y = 0.0
	limit_smoothed = true
	limit_left   = int(rect.position.x)
	limit_top    = int(rect.position.y)
	limit_right  = int(rect.position.x + rect.size.x)
	limit_bottom = int(rect.position.y + rect.size.y)
	_base_zoom = target_zoom
	if _scope_tween:
		_scope_tween.kill()
	_scope_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_scope_tween.tween_property(self, "zoom", target_zoom, duration)

func unlock_zone(duration: float) -> void:
	_zone_locked = false
	limit_smoothed = false
	limit_left   = -10000000
	limit_top    = -10000000
	limit_right  =  10000000
	limit_bottom =  10000000
	var restore_zoom := Vector2(0.68, 0.68)
	_base_zoom = restore_zoom
	if _scope_tween:
		_scope_tween.kill()
	_scope_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_scope_tween.tween_property(self, "zoom", restore_zoom, duration)
