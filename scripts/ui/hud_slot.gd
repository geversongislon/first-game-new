extends Panel
class_name HUDSlot

var slot_index: int = -1
var is_loadout: bool = false
var weapon_ui: CanvasLayer = null

signal right_clicked(card_id: String, card_level: int)

var border_color: Color = Color(0.3, 0.3, 0.3, 1)

func _draw() -> void:
	# 1px externo exato — fora do rect do panel
	draw_rect(Rect2(-1, -1, size.x + 2, size.y + 2), border_color, false, 1.0)

func set_border_color(c: Color) -> void:
	border_color = c
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if is_loadout and weapon_ui and weapon_ui._manager and not weapon_ui.is_backpack_active:
				weapon_ui._manager.equip_by_index(slot_index)
				get_viewport().set_input_as_handled()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var id := ""
			if is_loadout:
				if weapon_ui and weapon_ui._manager and slot_index < weapon_ui._manager.unlocked_weapons.size():
					id = weapon_ui._manager.unlocked_weapons[slot_index]
			else:
				if slot_index < GameManager.run_backpack.size():
					id = GameManager.run_backpack[slot_index]
			if id != "":
				var level := 1
				if is_loadout:
					if slot_index < GameManager.equipped_card_levels.size():
						level = GameManager.equipped_card_levels[slot_index]
				else:
					if slot_index < GameManager.run_backpack_levels.size():
						level = GameManager.run_backpack_levels[slot_index]
				right_clicked.emit(id, level)
				get_viewport().set_input_as_handled()

func _get_drag_data(_at_position: Vector2):
	if not weapon_ui or not weapon_ui.is_backpack_active:
		return null
		
	var id = ""
	if is_loadout:
		if weapon_ui._manager and slot_index < weapon_ui._manager.unlocked_weapons.size():
			id = weapon_ui._manager.unlocked_weapons[slot_index]
	else:
		id = GameManager.run_backpack[slot_index]
	
	if id == "": return null

	# Verifica se é seguro desequipar esta carta do loadout
	if is_loadout and weapon_ui and weapon_ui._manager:
		var player = weapon_ui._manager.get_parent()
		if player and player.has_method("can_unequip_card"):
			if not player.can_unequip_card(id, slot_index):
				return null # Aborta o drag & drop, carta travada

	var level: int = 1
	if is_loadout:
		level = GameManager.equipped_card_levels[slot_index] if slot_index < GameManager.equipped_card_levels.size() else 1
	else:
		level = GameManager.run_backpack_levels[slot_index] if slot_index < GameManager.run_backpack_levels.size() else 1

	var charges: int = 0
	if is_loadout:
		var player = weapon_ui._manager.get_parent() if weapon_ui._manager else null
		if player and "loadout_charges" in player and slot_index < player.loadout_charges.size():
			charges = player.loadout_charges[slot_index]
	else:
		if slot_index < GameManager.run_backpack_charges.size():
			charges = GameManager.run_backpack_charges[slot_index]

	# Payload
	var data = {
		"type": "run_card",
		"card_id": id,
		"card_level": level,
		"card_charges": charges,
		"origin_slot": slot_index,
		"origin_is_loadout": is_loadout
	}
	
	# Preview
	var preview = Control.new()
	var icon_copy = $Icon.duplicate()
	icon_copy.set_anchors_preset(Control.PRESET_TOP_LEFT)
	icon_copy.size = size
	icon_copy.position = -0.5 * size
	preview.add_child(icon_copy)
	set_drag_preview(preview)
	
	return data

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not weapon_ui or not weapon_ui.is_backpack_active:
		return false
		
	if typeof(data) != TYPE_DICTIONARY or data.get("type") != "run_card":
		return false
		
	# Precisamos verificar se a carta alvo (que vai ser substituída e mandada pro lugar da origem)
	# pode ser removida com segurança do loadout.

	
	# Se O MEU SLOT (destino) for um slot de loadout, a carta que está nele vai ser enviada pra origem.
	if is_loadout and weapon_ui and weapon_ui._manager:
		var target_id = ""
		if slot_index < weapon_ui._manager.unlocked_weapons.size():
			target_id = weapon_ui._manager.unlocked_weapons[slot_index]
			
		if target_id != "":
			var player = weapon_ui._manager.get_parent()
			if player and player.has_method("can_unequip_card"):
				if not player.can_unequip_card(target_id, slot_index):
					return false # Aborta, não posso tirar a carta que está aqui
	
	return true

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var target_id = "" # O que está aqui agora (pra trocar)
	var dragged_id = data["card_id"]
	var dragged_level: int = data.get("card_level", 1)
	var dragged_charges: int = data.get("card_charges", 0)
	var origin_slot = data["origin_slot"]
	var origin_is_loadout = data["origin_is_loadout"]

	if is_loadout == origin_is_loadout and slot_index == origin_slot:
		return # Previne duplicar charges ao arrastar o item para si mesmo

	# 1. Pega o que está no slot de destino (ID e nível)
	if is_loadout:
		target_id = weapon_ui._manager.unlocked_weapons[slot_index]
	else:
		target_id = GameManager.run_backpack[slot_index]

	# Merge de consumíveis: mesma carta, empilha cargas
	if target_id == dragged_id and dragged_id != "":
		var card := CardDB.get_card(dragged_id)
		if card and card.type == "Consumable":
			var target_charges: int = 0
			var player = weapon_ui._manager.get_parent() if weapon_ui and weapon_ui._manager else null
			if is_loadout and player and "loadout_charges" in player:
				target_charges = player.loadout_charges[slot_index]
			elif not is_loadout and slot_index < GameManager.run_backpack_charges.size():
				target_charges = GameManager.run_backpack_charges[slot_index]

			var total := target_charges + dragged_charges
			var merged := mini(total, card.max_charges)
			var overflow := total - merged

			if is_loadout and player and "loadout_charges" in player:
				player.loadout_charges[slot_index] = merged
			elif not is_loadout and slot_index < GameManager.run_backpack_charges.size():
				GameManager.run_backpack_charges[slot_index] = merged

			if overflow > 0:
				if origin_is_loadout and player and "loadout_charges" in player:
					player.loadout_charges[origin_slot] = overflow
				elif not origin_is_loadout and origin_slot < GameManager.run_backpack_charges.size():
					GameManager.run_backpack_charges[origin_slot] = overflow
			else:
				if origin_is_loadout:
					weapon_ui._manager.unlocked_weapons[origin_slot] = ""
					if player and "loadout_charges" in player:
						player.loadout_charges[origin_slot] = 0
				else:
					GameManager.run_backpack[origin_slot] = ""
					if origin_slot < GameManager.run_backpack_charges.size():
						GameManager.run_backpack_charges[origin_slot] = 0

			if origin_is_loadout or is_loadout:
				weapon_ui._manager.loadout_changed.emit()
			weapon_ui.refresh_all_icons()
			return

	var target_level: int = 1
	if is_loadout:
		target_level = GameManager.equipped_card_levels[slot_index] if slot_index < GameManager.equipped_card_levels.size() else 1
	else:
		target_level = GameManager.run_backpack_levels[slot_index] if slot_index < GameManager.run_backpack_levels.size() else 1

	# Lê cargas do destino ANTES do swap (para troca bidirecional)
	var _player = weapon_ui._manager.get_parent() if weapon_ui and weapon_ui._manager else null
	var target_charges: int = 0
	if is_loadout and _player and "loadout_charges" in _player and slot_index < _player.loadout_charges.size():
		target_charges = _player.loadout_charges[slot_index]
	elif not is_loadout and slot_index < GameManager.run_backpack_charges.size():
		target_charges = GameManager.run_backpack_charges[slot_index]

	# 2. Atualiza o DESTINO com a carta arrastada
	if is_loadout:
		weapon_ui._manager.unlocked_weapons[slot_index] = dragged_id
		GameManager.equipped_card_levels[slot_index] = dragged_level
		# Se o destino está selecionado, equipa a nova arma
		if weapon_ui._manager.current_weapon_index == slot_index or weapon_ui._manager.current_weapon_id == "":
			weapon_ui._manager.equip_by_index(slot_index)
	else:
		GameManager.run_backpack[slot_index] = dragged_id
		if slot_index < GameManager.run_backpack_levels.size():
			GameManager.run_backpack_levels[slot_index] = dragged_level

	# 3. Atualiza a ORIGEM com o que estava no destino (Troca)
	if origin_is_loadout:
		weapon_ui._manager.unlocked_weapons[origin_slot] = target_id
		GameManager.equipped_card_levels[origin_slot] = target_level

		# Se a carta saiu do slot ativo, desequipa ou equipa o que entrou na troca
		if weapon_ui._manager.current_weapon_index == origin_slot:
			if target_id != "":
				weapon_ui._manager.equip_by_index(origin_slot) # Troca
			else:
				weapon_ui._manager.equip_by_id("") # Desequipa
	else:
		GameManager.run_backpack[origin_slot] = target_id
		if origin_slot < GameManager.run_backpack_levels.size():
			GameManager.run_backpack_levels[origin_slot] = target_level

	# Transfere cargas de consumíveis (swap bidirecional)
	var _p = weapon_ui._manager.get_parent() if weapon_ui and weapon_ui._manager else null
	if is_loadout and _p and "loadout_charges" in _p:
		_p.loadout_charges[slot_index] = dragged_charges
	elif not is_loadout and slot_index < GameManager.run_backpack_charges.size():
		GameManager.run_backpack_charges[slot_index] = dragged_charges
	if origin_is_loadout and _p and "loadout_charges" in _p:
		_p.loadout_charges[origin_slot] = target_charges
	elif not origin_is_loadout and origin_slot < GameManager.run_backpack_charges.size():
		GameManager.run_backpack_charges[origin_slot] = target_charges

	# Aviso para o Player recalcular os Status (Passivas)
	if origin_is_loadout or is_loadout:
		weapon_ui._manager.loadout_changed.emit()

	# 4. Refresh Geral da UI
	weapon_ui.refresh_all_icons()
