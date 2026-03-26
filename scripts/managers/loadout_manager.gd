extends Node
class_name LoadoutManagerClass

# IDs das cartas equipadas atualmente
var equipped_card_1_id: String = ""
var equipped_card_2_id: String = ""
var equipped_card_3_id: String = ""

# Se houver um Resource de 'CardData' para a carta baseada no ID:
# (Isso será útil depois para instanciar a carta no jogador)
var equipped_card_1: Resource = null
var equipped_card_2: Resource = null
var equipped_card_3: Resource = null

func _ready() -> void:
	# O estado inicial agora é controlado pelo GameManager.load_game()
	pass

func get_equipped_cards() -> Array[String]:
	return [equipped_card_1_id, equipped_card_2_id, equipped_card_3_id]

func sync_from_game_manager(cards_array: Array) -> void:
	var validated = ["", "", ""]
	for i in range(min(cards_array.size(), 3)):
		var id = cards_array[i]
		var data = CardDB.get_card(id)
		if data:
			validated[i] = id
			
	equipped_card_1_id = validated[0]
	equipped_card_2_id = validated[1]
	equipped_card_3_id = validated[2]
	print("LoadoutManager: Sincronizado e validado: ", validated)

func equip_card(slot: int, card_id: String, card_resource: Resource = null) -> void:
	if slot == 1:
		equipped_card_1_id = card_id
		equipped_card_1 = card_resource
	elif slot == 2:
		equipped_card_2_id = card_id
		equipped_card_2 = card_resource
	elif slot == 3:
		equipped_card_3_id = card_id
		equipped_card_3 = card_resource
	
	# Salva a cada mudança no loadout para garantir persistência
	if GameManager:
		GameManager.equipped_cards = get_equipped_cards()
		GameManager.save_game()
