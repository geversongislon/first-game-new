extends Node2D
class_name AreaBase

## Dicionário de pontos de entrada. Preencha no editor via código ou arraste Marker2Ds.
## Chave: String (ex: "south", "north"). Valor: preenchido via _ready a partir dos filhos.
@export var entry_points: Dictionary = {}

func _ready() -> void:
	# Auto-registra Marker2Ds filhos do nó EntryPoints (se existir)
	var ep_node := get_node_or_null("EntryPoints")
	if ep_node:
		for child in ep_node.get_children():
			entry_points[child.name.to_lower()] = child.global_position

## Retorna a posição global do ponto de entrada pelo id.
## Prioridade: 1) EntryPoints Marker2D, 2) ExtractionZone com id matching (e a remove).
func get_entry_position(id: String) -> Vector2:
	var key := id.to_lower()

	# 1. EntryPoints fixos (Marker2Ds — para ext_0 e pontos sem extraction zone)
	if entry_points.has(key):
		var val = entry_points[key]
		if val is Vector2:
			return val
		if val is Node2D:
			return (val as Node2D).global_position

	# 2. Busca ExtractionZone com id matching nesta área — remove ao usar como entrada
	for node in get_tree().get_nodes_in_group("extraction_zones"):
		if node.get("extraction_id") == key and is_ancestor_of(node):
			var pos: Vector2 = node.get_spawn_position() if node.has_method("get_spawn_position") else node.global_position
			if node.has_method("spawn_fade_out"):
				node.spawn_fade_out()
			else:
				node.queue_free()
			return pos

	push_warning("AreaBase.get_entry_position: entry '%s' não encontrado." % id)
	return global_position

## Retorna o container de inimigos desta área.
## Convenção: nó chamado "Enemys" filho direto da área.
func get_enemy_container() -> Node:
	return get_node_or_null("Enemys")
