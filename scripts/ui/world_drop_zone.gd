extends Control

var weapon_ui = null

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Só aceita se a mochila estiver ativa para evitar drops acidentais
	if not weapon_ui or not weapon_ui.is_backpack_active:
		return false
	return typeof(data) == TYPE_DICTIONARY and data.get("type") == "run_card"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var card_id = data["card_id"]
	var card_level: int = data.get("card_level", 1)
	var card_charges: int = data.get("card_charges", 1)
	var origin_slot = data["origin_slot"]
	var origin_is_loadout = data["origin_is_loadout"]
	
	# 1. Remove da origem
	if origin_is_loadout:
		if weapon_ui._manager:
			weapon_ui._manager.unlocked_weapons[origin_slot] = ""
			if origin_slot < GameManager.equipped_card_levels.size():
				GameManager.equipped_card_levels[origin_slot] = 1
			if origin_slot < GameManager.equipped_card_charges.size():
				GameManager.equipped_card_charges[origin_slot] = 0
			# Se soltou a arma ativa, desequipa
			if weapon_ui._manager.current_weapon_index == origin_slot:
				weapon_ui._manager.equip_by_id("")
			weapon_ui._manager.loadout_changed.emit()
	else:
		GameManager.run_backpack[origin_slot] = ""
		if origin_slot < GameManager.run_backpack_levels.size():
			GameManager.run_backpack_levels[origin_slot] = 1
		if origin_slot < GameManager.run_backpack_charges.size():
			GameManager.run_backpack_charges[origin_slot] = 0
		GameManager.run_backpack_changed.emit()
	
	# 2. Faz o Player dropar no mapa com impulso e charges corretas
	var player = get_tree().get_first_node_in_group("player")
	if not player: player = weapon_ui.get_parent() # Fallback
	
	if player and player.has_method("drop_card_into_world"):
		player.drop_card_into_world(card_id, card_level, card_charges)
		
	# 3. Refresh UI
	weapon_ui.refresh_all_icons()

