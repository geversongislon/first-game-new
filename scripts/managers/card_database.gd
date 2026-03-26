extends Node
class_name CardDB
## CardDatabase — Singleton de cartas. Acesso estático via CardDB.get_card(id)

# Dicionário principal estático para acesso global via classe
static var cards: Dictionary = {}

func _ready() -> void:
	# No jogo, carrega normalmente
	if cards.is_empty():
		_load_all_cards_static()
	print("CardDatabase: ", cards.size(), " cartas carregadas no Singleton.")

## Versão estática do carregamento para ser usada no editor ou jogo
static func _load_all_cards_static() -> void:
	var path = "res://resources/cards/"
	var dir = DirAccess.open(path)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var full_path = path + file_name
			var data = load(full_path)
			if data is CardData and data.id != "":
				cards[data.id] = data
		file_name = dir.get_next()
	dir.list_dir_end()

# ─── API pública (Estática) ──────────────────────────────────────────────

static func get_card(id: String) -> CardData:
	if cards.is_empty():
		_load_all_cards_static()
	return cards.get(id, null)

static func get_all_cards() -> Array:
	if cards.is_empty():
		_load_all_cards_static()
	return cards.values()

static func get_random_card(type_filter: String = "", rarity_filters: Array[String] = []) -> CardData:
	if cards.is_empty():
		_load_all_cards_static()

	var pool = cards.values()
	if type_filter != "":
		pool = pool.filter(func(c): return c.type == type_filter)
	if not rarity_filters.is_empty():
		pool = pool.filter(func(c): return c.rarity in rarity_filters)
	if pool.is_empty():
		return null

	var total_weight: float = 0.0
	for card in pool:
		total_weight += card.drop_weight

	var roll: float = randf() * total_weight
	for card in pool:
		roll -= card.drop_weight
		if roll <= 0.0:
			return card
	return pool[-1]

## Retorna o weapon_id a partir de um card_id (ex: "card_smg" → "smg")
static func get_weapon_id(card_id: String) -> String:
	var data: CardData = get_card(card_id)
	if data and data.type == "Weapon":
		return data.weapon_id
	return ""

## Retorna o card_id a partir de um weapon_id (ex: "smg" → "card_smg")
static func get_card_id_from_weapon(weapon_id: String) -> String:
	if weapon_id == "": return ""
	
	if cards.is_empty():
		_load_all_cards_static()
		
	for card in cards.values():
		if card.weapon_id == weapon_id:
			return card.id
	return ""
