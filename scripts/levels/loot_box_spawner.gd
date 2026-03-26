@tool
extends Node
class_name LootBoxSpawner

## LootBoxSpawner: Coordenador do pool de LootBoxSpawn.
## Coleta todos os LootBoxSpawn irmãos (filhos do mesmo pai),
## embaralha e ativa apenas max_active deles por run.
##
## Uso: coloque 1 LootBoxSpawner e N LootBoxSpawn como irmãos na cena.
## Ex: 10 spawns espalhados, max_active = 2 → 2 baús aparecem por run.

## Quantos LootBoxSpawn serão ativados por run.
@export var max_active: int = 2

## Runs em que este spawner está ativo. Vazio = todas as runs.
@export var active_on_runs: Array[int] = []

func _ready() -> void:
	if Engine.is_editor_hint(): return
	if not active_on_runs.is_empty() and not (GameManager.runs_started in active_on_runs):
		return
	# Defer para garantir que todos os LootBoxSpawn irmãos já rodaram _ready()
	call_deferred("_activate_pool")

func _activate_pool() -> void:
	var candidates: Array = []
	for child in get_children():
		if child.is_in_group("loot_box_spawns"):
			candidates.append(child)
	candidates.shuffle()
	for i in mini(max_active, candidates.size()):
		candidates[i].spawn()
