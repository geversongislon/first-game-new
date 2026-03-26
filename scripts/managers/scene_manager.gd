extends Node

## Gerencia transições de cena com fade e troca de áreas durante a run.

var _fade_canvas: CanvasLayer = null
var _fade_rect: ColorRect = null
var _is_transitioning: bool = false

func _ready() -> void:
	_build_fade_overlay()

func _build_fade_overlay() -> void:
	_fade_canvas = CanvasLayer.new()
	_fade_canvas.layer = 200
	add_child(_fade_canvas)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.modulate.a = 0.0
	_fade_canvas.add_child(_fade_rect)

## Transição completa para outra cena (menu → hub → run).
func go_to(path: String) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	await _fade_out()
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_in()
	_is_transitioning = false

## Troca a área dentro da run com fade completo (chamado pelo ExitZone).
func load_area(run: Node, area_scene: PackedScene, entry_id: String) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	await _fade_out()
	await _swap_area(run, area_scene, entry_id)
	await _fade_in()
	_is_transitioning = false

## Troca a área SEM fade — use no _ready() da run enquanto go_to já gerencia o fade.
## O go_to já fez o fade_out antes de trocar a cena, e fará fade_in depois.
func swap_area_now(run: Node, area_scene: PackedScene, entry_id: String) -> void:
	await _swap_area(run, area_scene, entry_id)

func _swap_area(run: Node, area_scene: PackedScene, entry_id: String) -> void:
	var container: Node = run.get_node_or_null("WorldContainer")
	if not container:
		push_error("SceneManager._swap_area: Run não tem WorldContainer")
		return

	# Remove área atual
	for child in container.get_children():
		child.queue_free()
	await get_tree().process_frame

	# Instancia nova área
	var area: Node = area_scene.instantiate()
	container.add_child(area)
	await get_tree().process_frame

	# Posiciona o player no entry point
	var player: Node = run.get_node_or_null("Player")
	if player and area.has_method("get_entry_position"):
		var entry_pos: Vector2 = area.get_entry_position(entry_id)
		player.global_position = entry_pos
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera:
			camera.position_smoothing_enabled = false
		await get_tree().process_frame
		await get_tree().process_frame
		if camera:
			camera.position_smoothing_enabled = true

func _fade_out(duration: float = 0.3) -> void:
	await _tween_alpha(0.0, 1.0, duration)

func _fade_in(duration: float = 0.3) -> void:
	await _tween_alpha(1.0, 0.0, duration)

func _tween_alpha(from: float, to: float, duration: float) -> void:
	_fade_rect.modulate.a = from
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", to, duration)
	await tween.finished
