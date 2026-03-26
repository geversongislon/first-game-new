@tool
extends Marker2D
class_name SpawnPoint

@export var enemy_scene: PackedScene = null:
	set(v):
		enemy_scene = v
		if is_node_ready(): queue_redraw()

## Intervalo base de spawn em segundos.
@export var spawn_interval: float = 10.0

## Quantos inimigos spawnar de uma vez.
@export var spawn_count: int = 1:
	set(v):
		spawn_count = v
		if is_node_ready(): queue_redraw()

## Se ativado, spawna mesmo que inimigos anteriores ainda estejam vivos.
## Se desativado, só spawna quando todos os inimigos deste ponto morrerem.
@export var continuous_spawn: bool = true:
	set(v):
		continuous_spawn = v
		if is_node_ready(): queue_redraw()

## Runs em que este spawn está ativo. Vazio = todas as runs.
## Ex: [1, 2] → aparece apenas na Run 1 e Run 2.
@export var active_on_runs: Array[int] = []

## Probabilidade de spawnar a cada ciclo (0.0 = nunca, 1.0 = sempre).
@export_range(0.0, 1.0, 0.05) var spawn_chance: float = 1.0

@export_group("Once Per Save")
## Se true, o inimigo não respawna após morrer neste save (ideal para chefes).
@export var once_per_save: bool = false
## ID único deste spawn. Obrigatório quando once_per_save = true.
@export var enemy_id: String = ""

@export_group("Loot Override")
## Sobrescreve raridade do loot (checkboxes). Nenhum marcado = usa padrão do inimigo.
@export_flags("Common", "Uncommon", "Rare", "Epic", "Legendary") var loot_rarity_flags: int = 0
## Sobrescreve nível da carta (checkboxes). Nenhum marcado = usa padrão do inimigo.
@export_flags("Lv1", "Lv2", "Lv3") var loot_level_flags: int = 0

var _timer: float = 0.0
var _spawned_enemies: Array = []

func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("spawn_points")
		# Spawn chance é avaliado UMA vez por run — se falhar, desativa o spawn point
		if spawn_chance < 1.0 and randf() > spawn_chance:
			set_process(false)

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	_timer -= delta
	if _timer <= 0.0:
		_timer = spawn_interval
		_try_spawn()

func _try_spawn() -> void:
	if not enemy_scene: return
	if _is_on_screen(): return
	if not continuous_spawn and has_living_enemies(): return
	if not active_on_runs.is_empty() and not (GameManager.runs_started in active_on_runs): return
	if once_per_save and enemy_id != "" and enemy_id in GameManager.killed_permanent_enemies:
		set_process(false)
		return
	var container := owner if is_instance_valid(owner) else get_parent()
	for i in spawn_count:
		var enemy := enemy_scene.instantiate()
		enemy.position = container.to_local(global_position)
		enemy.rotation = global_rotation - container.global_rotation
		container.add_child(enemy)
		_spawned_enemies.append(enemy)
		if once_per_save and enemy_id != "":
			enemy.tree_exiting.connect(_on_permanent_enemy_exiting.bind(enemy))
		if loot_rarity_flags > 0 and "drop_rarity_flags" in enemy:
			enemy.drop_rarity_flags = loot_rarity_flags
		if loot_level_flags > 0 and "drop_level_flags" in enemy:
			enemy.drop_level_flags = loot_level_flags

func _on_permanent_enemy_exiting(enemy: Node) -> void:
	if not enemy.get("is_dead"): return
	if enemy_id in GameManager.killed_permanent_enemies: return
	GameManager.killed_permanent_enemies.append(enemy_id)
	GameManager.save_game()
	set_process(false)

func has_living_enemies() -> bool:
	_spawned_enemies = _spawned_enemies.filter(
		func(e): return is_instance_valid(e) and not e.get("is_dead")
	)
	return not _spawned_enemies.is_empty()

func _is_on_screen() -> bool:
	var vp := get_viewport()
	if not vp: return false
	var screen_pos := vp.get_canvas_transform() * global_position
	return vp.get_visible_rect().has_point(screen_pos)

func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	# Ciano se filtrado por run, laranja se normal
	var is_conditional := not active_on_runs.is_empty()
	var col_fill  := Color(0.0, 0.8, 1.0, 0.22) if is_conditional else Color(1.0, 0.55, 0.0, 0.22)
	var col_ring  := Color(0.0, 0.8, 1.0, 0.95) if is_conditional else Color(1.0, 0.55, 0.0, 0.95)
	var col_wait  := Color(1.0, 0.25, 0.25, 0.85)

	draw_circle(Vector2.ZERO, 7.0, col_fill)
	draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 32, col_ring, 1.5)
	draw_line(Vector2(-3.5, 0), Vector2(3.5, 0), col_ring, 1.0)
	draw_line(Vector2(0, -3.5), Vector2(0, 3.5), col_ring, 1.0)

	# corpo do enemy: base no origin, altura para cima (-Y local)
	var body_h := 28.0
	var body_w := 10.0
	var body_rect := Rect2(-body_w * 0.5, -body_h, body_w, body_h)
	draw_rect(body_rect, Color(col_ring.r, col_ring.g, col_ring.b, 0.12))
	draw_rect(body_rect, col_ring, false, 1.2)
	# cabeça
	draw_circle(Vector2(0, -body_h - 5), 5.0, Color(col_ring.r, col_ring.g, col_ring.b, 0.18))
	draw_arc(Vector2(0, -body_h - 5), 5.0, 0.0, TAU, 16, col_ring, 1.2)

	var count := mini(spawn_count, 8)
	if count > 1:
		for i in count:
			var angle := (TAU / count) * i - PI * 0.5
			draw_circle(Vector2(cos(angle), sin(angle)) * 13.0, 2.5, col_ring)

	if not continuous_spawn:
		draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 32, col_wait, 1.5)
		draw_line(Vector2(7, -13), Vector2(13, -7), col_wait, 1.5)
		draw_line(Vector2(13, -13), Vector2(7, -7), col_wait, 1.5)
