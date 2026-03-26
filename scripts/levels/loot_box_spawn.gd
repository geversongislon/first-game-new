@tool
extends Marker2D
class_name LootBoxSpawn

## LootBoxSpawn: Ponto candidato para spawnar um LootBox no mapa.
## Não spawna sozinho — precisa ser chamado pelo LootBoxSpawner pai.
## No editor: aparece como um ícone de baú dourado.

@export var loot_box_scene: PackedScene
@export var spawn_y_offset: float = 0.0

@export_group("Once Per Save")
@export var once_per_save: bool = false
## ID único para este baú. Obrigatório quando once_per_save = true.
@export var chest_id: String = ""

@export_group("Loot Config")
@export_enum("Any", "Weapon", "Active", "Passive") var card_type: String = "Any"
@export_flags("Common", "Uncommon", "Rare", "Epic", "Legendary") var rarity_flags: int = 0
@export_flags("Lv1", "Lv2", "Lv3") var level_flags: int = 1

var _did_spawn: bool = false

func _ready() -> void:
	if Engine.is_editor_hint(): return
	if once_per_save:
		call_deferred("spawn")  # sempre spawna, independente do LootBoxSpawner
	else:
		add_to_group("loot_box_spawns")

func spawn() -> void:
	if _did_spawn: return
	_did_spawn = true
	if not loot_box_scene: return
	var container := owner if is_instance_valid(owner) else get_parent()
	var box = loot_box_scene.instantiate()
	box.position = container.to_local(global_position) + Vector2(0, spawn_y_offset)
	if "card_type" in box:
		box.card_type = card_type
	if "rarity_flags" in box:
		box.rarity_flags = rarity_flags
	if "level_flags" in box:
		box.level_flags = level_flags
	if "once_per_save" in box:
		box.once_per_save = once_per_save
	if "chest_id" in box:
		box.chest_id = chest_id
	container.add_child(box)

func _draw() -> void:
	if not Engine.is_editor_hint(): return
	# Ícone de baú: dourado = candidato disponível
	var col_ring := Color(0.9, 0.7, 0.1, 0.9)
	var col_fill := Color(0.9, 0.7, 0.1, 0.18)

	# Círculo base
	draw_circle(Vector2.ZERO, 9.0, col_fill)
	draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 32, col_ring, 1.5)

	# Silhueta de baú (corpo + tampa)
	var body := Rect2(-6, -2, 12, 7)
	var lid  := Rect2(-6, -7, 12, 5)
	draw_rect(Rect2(body.position + Vector2.ONE * -0.5, body.size), Color(col_ring.r, col_ring.g, col_ring.b, 0.14))
	draw_rect(body, col_ring, false, 1.2)
	draw_rect(Rect2(lid.position + Vector2.ONE * -0.5, lid.size), Color(col_ring.r, col_ring.g, col_ring.b, 0.14))
	draw_rect(lid, col_ring, false, 1.2)

	# Traço horizontal separando tampa do corpo
	draw_line(Vector2(-6, -2), Vector2(6, -2), col_ring, 1.0)

	# Fechadura (pequeno quadrado central)
	draw_rect(Rect2(-1.5, -2.5, 3, 3), col_ring.darkened(0.2))
	draw_rect(Rect2(-1.5, -2.5, 3, 3), col_ring, false, 0.8)
