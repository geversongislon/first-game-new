extends Control

@onready var slot1: DropSlot = $HBoxContainer/MarginCenter/CenterPanel/LoadoutSlots/DropSlot1
@onready var slot2: DropSlot = $HBoxContainer/MarginCenter/CenterPanel/LoadoutSlots/DropSlot2
@onready var slot3: DropSlot = $HBoxContainer/MarginCenter/CenterPanel/LoadoutSlots/DropSlot3
@onready var loadout_container = $HBoxContainer/MarginCenter/CenterPanel/LoadoutSlots


@onready var stats_label: Label = $StatsLabel
@onready var inventory_grid: GridContainer = $HBoxContainer/MarginRight/RightPanel/InventoryScroll/InventoryGrid
@onready var capacity_label: Label = %CapacityLabel

var card_scene = preload("res://scenes/ui/inventory/draggable_card.tscn")
var _popup_scene = preload("res://scenes/ui/inventory/card_detail_popup.tscn")

var card_popup: CardDetailPopup = null
var _popup_source_slot: DropSlot = null

func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_9 and event.shift_pressed:
			var _pts := {
				"ext_0": "Início",
				"ext_1": "Zona 01",
				"ext_2": "Zona 02",
				"ext_3": "Zona 03",
				"ext_4": "Zona 04",
				"ext_5": "Zona 05",
			}
			for _pid in _pts:
				GameManager.unlock_extraction_point(_pid, _pts[_pid])
			print("[DEBUG] Todos os pontos de extração desbloqueados! (%d)" % _pts.size())

		elif event.keycode == KEY_8 and event.shift_pressed:
			GameManager.total_coins += 10000000
			GameManager.permanent_coins_changed.emit(GameManager.total_coins)
			GameManager.save_game()
			print("[DEBUG] +10.000.000 coins permanentes")

func _ready() -> void:
	_setup_inventory()
	_setup_loadout()
	_update_stats_label()
	_create_card_popup()

	GameManager.permanent_coins_changed.connect(_on_permanent_coins_changed)
	GameManager.unlocked_cards_changed.connect(_setup_inventory)
	GameManager.card_upgraded.connect(_on_card_upgraded)

func _create_card_popup() -> void:
	card_popup = _popup_scene.instantiate()
	add_child(card_popup)
	card_popup.upgrade_requested.connect(_on_upgrade_requested)
	card_popup.sell_requested.connect(_on_sell_requested)

func _setup_inventory() -> void:
	for child in inventory_grid.get_children():
		inventory_grid.remove_child(child)
		child.queue_free()

	var max_inventory_slots := 80

	for i in range(max_inventory_slots):
		var card_id := ""
		if i < GameManager.unlocked_cards.size():
			card_id = GameManager.unlocked_cards[i]

		var slot_wrapper = ColorRect.new()
		slot_wrapper.set_script(preload("res://scripts/ui/inventory/inventory_slot_ui.gd"))
		slot_wrapper.slot_index = i
		slot_wrapper.custom_minimum_size = Vector2(16, 16)
		slot_wrapper.color = Color(0.15, 0.15, 0.15, 1)

		if card_id != "":
			var level := GameManager.get_card_level_at(i)
			var new_card = card_scene.instantiate()
			new_card.setup(card_id, level)
			new_card.inventory_index = i
			new_card.set_anchors_preset(Control.PRESET_FULL_RECT)
			new_card.card_right_clicked.connect(_on_card_right_clicked)
			var _cdata := CardDB.get_card(card_id)
			if _cdata and _cdata.type == "Consumable":
				var inv_charges := GameManager.get_card_charges_at(i)
				new_card.set_charges(inv_charges, _cdata.max_charges)
			slot_wrapper.add_child(new_card)

		inventory_grid.add_child(slot_wrapper)

	var total_cards := 0
	for id: String in GameManager.unlocked_cards:
		if id != "":
			total_cards += 1

	if capacity_label:
		capacity_label.text = str(total_cards) + "/" + str(max_inventory_slots)

func _on_sort_button_pressed() -> void:
	var rarity_order := {
		"Legendary": 0, "Epic": 1, "Rare": 2, "Uncommon": 3, "Common": 4
	}

	# Captura pares (carta + nível) antes de reordenar
	var pairs: Array = []
	for i in range(GameManager.unlocked_cards.size()):
		var id := GameManager.unlocked_cards[i]
		if id != "":
			pairs.append({"id": id, "level": GameManager.get_card_level_at(i)})

	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var card_a := CardDB.get_card(a["id"])
		var card_b := CardDB.get_card(b["id"])
		var ra: int = rarity_order.get(card_a.rarity, 5) if card_a else 5
		var rb: int = rarity_order.get(card_b.rarity, 5) if card_b else 5
		if ra != rb: return ra < rb
		var ta: String = card_a.type if card_a else ""
		var tb: String = card_b.type if card_b else ""
		if ta != tb: return ta > tb
		var na: String = card_a.display_name if card_a else a["id"]
		var nb: String = card_b.display_name if card_b else b["id"]
		return na < nb
	)

	GameManager.unlocked_cards.clear()
	GameManager.card_upgrade_levels.clear()
	for pair in pairs:
		GameManager.unlocked_cards.append(pair["id"])
		GameManager.card_upgrade_levels.append(pair["level"])
	GameManager.save_game()
	_setup_inventory()

func _setup_loadout() -> void:
	slot1.slot_index = 0
	slot2.slot_index = 1
	slot3.slot_index = 2
	slot1.set_initial_card(LoadoutManager.equipped_card_1_id, GameManager.equipped_card_levels[0], GameManager.equipped_card_charges[0])
	slot2.set_initial_card(LoadoutManager.equipped_card_2_id, GameManager.equipped_card_levels[1], GameManager.equipped_card_charges[1])
	slot3.set_initial_card(LoadoutManager.equipped_card_3_id, GameManager.equipped_card_levels[2], GameManager.equipped_card_charges[2])

	if not slot1.slot_changed.is_connected(_update_loadout_stack_visuals):
		slot1.slot_changed.connect(_update_loadout_stack_visuals)
		slot2.slot_changed.connect(_update_loadout_stack_visuals)
		slot3.slot_changed.connect(_update_loadout_stack_visuals)
		slot1.slot_changed.connect(_setup_inventory)
		slot2.slot_changed.connect(_setup_inventory)
		slot3.slot_changed.connect(_setup_inventory)
		slot1.card_right_clicked_in_slot.connect(_on_slot_card_right_clicked)
		slot2.card_right_clicked_in_slot.connect(_on_slot_card_right_clicked)
		slot3.card_right_clicked_in_slot.connect(_on_slot_card_right_clicked)

	_update_loadout_stack_visuals()


func _update_loadout_stack_visuals() -> void:
	var slots: Array = [slot1, slot2, slot3]
	var ids := [slot1.get_card_id(), slot2.get_card_id(), slot3.get_card_id()]

	for s in slots:
		s.clear_stack_visual()

	var counts: Dictionary = {}
	for i in range(ids.size()):
		var id: String = ids[i]
		if id == "": continue
		if not counts.has(id):
			counts[id] = []
		counts[id].append(i)

	for card_id in counts:
		var indices: Array = counts[card_id]
		if indices.size() < 2: continue
		for idx in indices:
			slots[idx].apply_stack_visual(indices.size())

	# Mantém equipped_card_levels sincronizado sempre que um slot muda
	GameManager.equipped_card_levels = [
		slot1.current_card_level,
		slot2.current_card_level,
		slot3.current_card_level,
	]
	GameManager.save_game()


func _update_stats_label() -> void:
	stats_label.text = str(GameManager.total_coins)

func _on_permanent_coins_changed(_amount: int) -> void:
	_update_stats_label()

func _on_start_run_button_pressed() -> void:
	_save_loadout()
	SceneManager.go_to("res://scenes/ui/ui_run_selection.tscn")

func _on_shop_button_pressed() -> void:
	_save_loadout()
	SceneManager.go_to("res://scenes/ui/ui_shop.tscn")

func _on_fusion_button_pressed() -> void:
	_save_loadout()
	SceneManager.go_to("res://scenes/ui/ui_fusion.tscn")

func _save_loadout() -> void:
	var id1 := slot1.get_card_id()
	var id2 := slot2.get_card_id()
	var id3 := slot3.get_card_id()

	LoadoutManager.equip_card(1, id1)
	LoadoutManager.equip_card(2, id2)
	LoadoutManager.equip_card(3, id3)

	GameManager.equipped_card_levels = [
		slot1.current_card_level,
		slot2.current_card_level,
		slot3.current_card_level
	]
	GameManager.save_game()

# --------- POPUP DE DETALHES / MELHORIA / VENDA ---------

func _on_card_right_clicked(card: DraggableCard) -> void:
	if card_popup:
		card_popup.open(card.card_id, card.card_level, card.inventory_index)

func _on_slot_card_right_clicked(card_id: String, card_level: int) -> void:
	if not card_popup: return
	_popup_source_slot = null
	for slot in [slot1, slot2, slot3]:
		if slot.current_card_id == card_id:
			_popup_source_slot = slot
			break
	var idx := GameManager.unlocked_cards.find(card_id)
	card_popup.open(card_id, card_level, idx)

func _on_card_upgraded(index: int) -> void:
	_update_stats_label()
	if card_popup and card_popup.visible:
		card_popup.refresh_level(GameManager.get_card_level_at(index))
	_setup_inventory()

func _on_upgrade_requested(inventory_index: int) -> void:
	if _popup_source_slot != null:
		# Upgrade de carta no slot do loadout — afeta equipped_card_levels, não o inventário
		var slot := _popup_source_slot
		var card_id := slot.current_card_id
		var current_level := slot.current_card_level
		if current_level >= 3 or card_id == "": return
		var card := CardDB.get_card(card_id)
		if not card: return
		var cost := card.upgrade_cost * (2 if current_level == 2 else 1)
		if GameManager.total_coins < cost: return
		GameManager.total_coins -= cost
		GameManager.permanent_coins_changed.emit(GameManager.total_coins)
		var new_level := current_level + 1
		GameManager.equipped_card_levels[slot.slot_index] = new_level
		var charges := GameManager.equipped_card_charges[slot.slot_index] if slot.slot_index < GameManager.equipped_card_charges.size() else -1
		slot.set_initial_card(card_id, new_level, charges)
		GameManager.save_game()
		if card_popup and card_popup.visible:
			card_popup.refresh_level(new_level)
		_update_stats_label()
	else:
		GameManager.upgrade_card_at(inventory_index)

func _on_sell_requested(inventory_index: int) -> void:
	var source_slot := _popup_source_slot
	_popup_source_slot = null

	var card_id: String = ""
	if inventory_index >= 0 and inventory_index < GameManager.unlocked_cards.size():
		card_id = GameManager.unlocked_cards[inventory_index]
	elif source_slot != null:
		card_id = source_slot.current_card_id
	if card_id == "": return

	var card := CardDB.get_card(card_id)
	GameManager.total_coins += card.sell_price if card else 20
	GameManager.permanent_coins_changed.emit(GameManager.total_coins)

	if inventory_index >= 0:
		GameManager.replace_card_in_inventory_at(inventory_index, "")
		GameManager.set_card_level_at(inventory_index, 1)

	# Limpa o slot do loadout se a carta estiver equipada
	var slot_to_clear: DropSlot = source_slot
	if slot_to_clear == null or slot_to_clear.current_card_id != card_id:
		for s in [slot1, slot2, slot3]:
			if s.current_card_id == card_id:
				slot_to_clear = s
				break
	if slot_to_clear != null and slot_to_clear.current_card_id == card_id:
		slot_to_clear.clear_sold()
		LoadoutManager.equip_card(slot_to_clear.slot_index + 1, "")

	GameManager.save_game()
	if card_popup:
		card_popup.visible = false
	_setup_inventory()
