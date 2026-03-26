extends ColorRect
class_name DropSlot

var current_card_id: String = ""
var current_card_level: int = 1
var slot_index: int = -1  # 0-2 quando usado no main menu loadout

signal slot_changed
signal card_right_clicked_in_slot(card_id: String, card_level: int)

# Estado do efeito visual de stack
var _stack_border: Panel = null

# --------- DRAG & DROP NATIVO ---------

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.has("type") and data["type"] == "card":
		return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	print("Carta Dropada no Slot! ID: ", data["card_id"])

	if data.has("source_slot") and data["source_slot"] == self:
		return # Soltou a carta no seu próprio slot, ignora para não duplicar cargas

	var incoming_card_id: String = data["card_id"]
	var incoming_level: int = data.get("card_level", 1)
	var previous_card_id: String = current_card_id
	var previous_level: int = current_card_level

	if data.has("source_slot") and data["source_slot"] != null and data["source_slot"] != self:
		# Veio de OUTRO slot de loadout (Swap entre slots) — troca cartas E níveis
		var source = data["source_slot"]

		# Troca as charges salvas junto com as cartas
		var my_saved_charges := GameManager.equipped_card_charges[slot_index] if slot_index >= 0 and slot_index < GameManager.equipped_card_charges.size() else 0
		var src_saved_charges := GameManager.equipped_card_charges[source.slot_index] if source.slot_index >= 0 and source.slot_index < GameManager.equipped_card_charges.size() else 0

		current_card_id = incoming_card_id
		current_card_level = incoming_level
		if slot_index >= 0 and slot_index < GameManager.equipped_card_charges.size():
			GameManager.equipped_card_charges[slot_index] = src_saved_charges
		_update_visual(current_card_id, current_card_level, src_saved_charges)

		if "current_card_id" in source:
			source.current_card_id = previous_card_id
			source.current_card_level = previous_level
			if source.slot_index >= 0 and source.slot_index < GameManager.equipped_card_charges.size():
				GameManager.equipped_card_charges[source.slot_index] = my_saved_charges
			source._update_visual(previous_card_id, previous_level, my_saved_charges)

	else:
		# Veio do INVENTÁRIO (baú)
		var inv_idx: int = data.get("inventory_index", -1)
		var incoming_inv_charges := GameManager.get_card_charges_at(inv_idx) if inv_idx >= 0 else 1

		# --- MERGE: mesma carta consumível já no slot → soma cargas ---
		# Só mergeia se nenhuma carga for perdida (total <= max_charges).
		# Se ultrapassar, cai no equip normal (swap) abaixo.
		var incoming_cdata := CardDB.get_card(incoming_card_id)
		if incoming_cdata and incoming_cdata.type == "Consumable" and previous_card_id == incoming_card_id:
			var slot_charges := GameManager.equipped_card_charges[slot_index] if slot_index >= 0 and slot_index < GameManager.equipped_card_charges.size() else 0
			var total := slot_charges + incoming_inv_charges
			if total <= incoming_cdata.max_charges:
				# Atualiza charges no slot
				if slot_index >= 0 and slot_index < GameManager.equipped_card_charges.size():
					GameManager.equipped_card_charges[slot_index] = total
				GameManager.save_game()
				# Remove a carta do inventário (foi consumida no merge)
				if inv_idx >= 0:
					GameManager.replace_card_in_inventory_at(inv_idx, "")
				else:
					GameManager.remove_card_from_inventory(incoming_card_id)
				# Atualiza visual com charges somadas
				_update_visual(current_card_id, current_card_level, total)
				return

		# --- EQUIP NORMAL: carta diferente ou slot vazio ---
		# Determina as charges a serem preservadas da carta anterior (se for consumível)
		var prev_eq_charges := 0
		if slot_index >= 0 and slot_index < GameManager.equipped_card_charges.size():
			prev_eq_charges = GameManager.equipped_card_charges[slot_index]

		if previous_card_id != "" and inv_idx != -1:
			# Devolve carta anterior para o exato slot do baú (preservando charges)
			GameManager.replace_card_in_inventory_at(inv_idx, previous_card_id, prev_eq_charges if prev_eq_charges > 0 else -1)
			GameManager.set_card_level_at(inv_idx, previous_level)
		else:
			if previous_card_id != "":
				GameManager.add_card_to_inventory_with_level(previous_card_id, previous_level, prev_eq_charges if prev_eq_charges > 0 else -1)
			if inv_idx != -1:
				GameManager.replace_card_in_inventory_at(inv_idx, "")
				GameManager.set_card_level_at(inv_idx, 1)
			else:
				GameManager.remove_card_from_inventory(incoming_card_id)

		current_card_id = incoming_card_id
		current_card_level = incoming_level
		# Aplica as charges do inventário ao slot de loadout e salva
		if slot_index >= 0 and slot_index < GameManager.equipped_card_charges.size():
			GameManager.equipped_card_charges[slot_index] = incoming_inv_charges if (incoming_cdata and incoming_cdata.type == "Consumable") else 0
		GameManager.save_game()
		_update_visual(current_card_id, current_card_level, incoming_inv_charges if (incoming_cdata and incoming_cdata.type == "Consumable") else -1)

# --------- VISUAL ---------

func set_initial_card(id: String, level: int = 1, charges: int = -1) -> void:
	if id == "" and current_card_id != "":
		# Preserva charges ao devolver ao inventário
		var prev_charges := 0
		if slot_index >= 0 and slot_index < GameManager.equipped_card_charges.size():
			prev_charges = GameManager.equipped_card_charges[slot_index]
			GameManager.equipped_card_charges[slot_index] = 0
		GameManager.add_card_to_inventory_with_level(current_card_id, current_card_level, prev_charges if prev_charges > 0 else -1)

	current_card_id = id
	current_card_level = level
	_update_visual(id, level, charges)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			set_initial_card("")

func _update_visual(id: String, level: int = 1, charges: int = -1) -> void:
	for child in $CardContainer.get_children():
		$CardContainer.remove_child(child)
		child.queue_free()

	if id == "":
		slot_changed.emit()
		return

	var card_scene = preload("res://scenes/ui/inventory/draggable_card.tscn")
	var new_card = card_scene.instantiate()
	new_card.setup(id, level)
	var _cdata := CardDB.get_card(id)
	if _cdata and _cdata.type == "Consumable":
		var display_charges := charges if charges >= 0 else _cdata.max_charges
		new_card.set_charges(display_charges, _cdata.max_charges)
	new_card.card_right_clicked.connect(
		func(card): card_right_clicked_in_slot.emit(card.card_id, card.card_level)
	)
	new_card.custom_minimum_size = Vector2(
		custom_minimum_size.x - 2,
		custom_minimum_size.y - 2
	)
	$CardContainer.add_child(new_card)
	slot_changed.emit()


# --------- EFEITO VISUAL DE STACK ---------

func apply_stack_visual(level: int) -> void:
	clear_stack_visual()

	var stack_color := Color(0.66, 0.592, 0.251, 1.0) if level == 2 else Color(0.77, 0.346, 0.664, 1.0)

	_stack_border = Panel.new()
	_stack_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stack_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = stack_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	_stack_border.add_theme_stylebox_override("panel", style)
	add_child(_stack_border)

func clear_stack_visual() -> void:
	if _stack_border and is_instance_valid(_stack_border):
		_stack_border.queue_free()
	_stack_border = null

# --------- API ---------
func get_card_id() -> String:
	return current_card_id
