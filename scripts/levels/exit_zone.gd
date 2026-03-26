extends Area2D
class_name ExitZone

## Cena da próxima área a carregar.
@export var next_area: PackedScene

## ID do ponto de entrada na próxima área (deve bater com AreaBase.entry_points).
@export var entry_point: String = "south"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not next_area:
		push_warning("ExitZone: next_area não configurado em " + name)
		return
	var run := _find_run()
	if not run:
		push_warning("ExitZone: não encontrou nó Run na árvore.")
		return
	run.load_area(next_area, entry_point)

func _find_run() -> Node:
	# Sobe pela árvore até encontrar o nó com método load_area (Run)
	var node := get_parent()
	while node:
		if node.has_method("load_area") and node.has_method("get_world_container"):
			return node
		node = node.get_parent()
	return null
