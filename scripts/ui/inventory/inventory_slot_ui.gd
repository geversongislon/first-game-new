extends ColorRect
class_name InventorySlotUI

var slot_index: int = -1

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.has("type") and data["type"] == "card":
		return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var dragged_id: String = data["card_id"]
	var dragged_level: int = data.get("card_level", 1)
	var source_slot = data.get("source_slot")
	var origin_inv_idx: int = data.get("inventory_index", -1)

	# Previne que arrastar a carta para o mesmo slot faça merge consigo mesma (duplicando charges)
	if origin_inv_idx == slot_index and source_slot == null:
		return

	# Garante que o GameManager tem esse index
	while GameManager.unlocked_cards.size() <= slot_index:
		GameManager.unlocked_cards.append("")

	var target_card_id: String = GameManager.unlocked_cards[slot_index]
	var target_level: int = GameManager.get_card_level_at(slot_index)

	# --- MERGE: mesma carta consumível no slot de destino ---
	# Só mergeia se nenhuma carga for perdida (total <= max_charges).
	# Se ultrapassar, cai no swap normal abaixo.
	if target_card_id == dragged_id and dragged_id != "" and source_slot == null:
		var cdata := CardDB.get_card(dragged_id)
		if cdata and cdata.type == "Consumable":
			var target_charges := GameManager.get_card_charges_at(slot_index)
			var origin_charges := GameManager.get_card_charges_at(origin_inv_idx) if origin_inv_idx >= 0 else 1
			var total := target_charges + origin_charges
			if total <= cdata.max_charges:
				GameManager.set_card_charges_at(slot_index, total)
				# Remove a carta de origem (foi absorvida)
				if origin_inv_idx >= 0:
					GameManager.replace_card_in_inventory_at(origin_inv_idx, "")
				GameManager.unlocked_cards_changed.emit()
				GameManager.save_game()
				return

	if source_slot != null:
		# Veio do loadout para este slot do baú — troca bidirecional com nível
		var src_eq_charges := 0
		if source_slot.slot_index >= 0 and source_slot.slot_index < GameManager.equipped_card_charges.size():
			src_eq_charges = GameManager.equipped_card_charges[source_slot.slot_index]
			GameManager.equipped_card_charges[source_slot.slot_index] = GameManager.get_card_charges_at(slot_index)

		source_slot.current_card_id = target_card_id
		source_slot.current_card_level = target_level
		source_slot._update_visual(target_card_id, target_level, GameManager.get_card_charges_at(slot_index))

		# Nível e charges definidos ANTES do replace para que o sinal veja o valor correto
		GameManager.set_card_level_at(slot_index, dragged_level)
		GameManager.set_card_charges_at(slot_index, src_eq_charges)
		GameManager.replace_card_in_inventory_at(slot_index, dragged_id)
		GameManager.save_game()

	elif origin_inv_idx != -1 and origin_inv_idx != slot_index:
		# Swap entre dois slots do baú — troca cartas, níveis E charges
		var origin_charges := GameManager.get_card_charges_at(origin_inv_idx)
		var target_charges := GameManager.get_card_charges_at(slot_index)

		GameManager.unlocked_cards[origin_inv_idx] = target_card_id
		GameManager.set_card_level_at(origin_inv_idx, target_level)
		GameManager.set_card_charges_at(origin_inv_idx, target_charges)
		# Nível e charges definidos ANTES do replace
		GameManager.set_card_level_at(slot_index, dragged_level)
		GameManager.set_card_charges_at(slot_index, origin_charges)
		GameManager.replace_card_in_inventory_at(slot_index, dragged_id)

