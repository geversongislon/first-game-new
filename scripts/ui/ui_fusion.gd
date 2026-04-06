extends Control

const RARITY_ORDER = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

@onready var inventory_grid: GridContainer = $HBoxContainer/MarginLeft/LeftPanel/ScrollArea/InventoryScroll/InventoryGrid
@onready var inventory_scroll: ScrollContainer = $HBoxContainer/MarginLeft/LeftPanel/ScrollArea/InventoryScroll
@onready var inventory_vscroll: VScrollBar = $HBoxContainer/MarginLeft/LeftPanel/ScrollArea/InventoryVScroll
@onready var fusion_slot1: DropSlot = $HBoxContainer/MarginRight/RightPanel/FusionSlots/FusionSlot1
@onready var fusion_slot2: DropSlot = $HBoxContainer/MarginRight/RightPanel/FusionSlots/FusionSlot2
@onready var fusion_slot3: DropSlot = $HBoxContainer/MarginRight/RightPanel/FusionSlots/FusionSlot3
@onready var result_label: Label = $HBoxContainer/MarginRight/RightPanel/ResultLabel
@onready var fuse_button: Button = $HBoxContainer/MarginRight/RightPanel/FuseButton

var _card_scene = preload("res://scenes/ui/inventory/draggable_card.tscn")

func _ready() -> void:
	_setup_inventory()
	fusion_slot1.slot_changed.connect(_on_slot_changed)
	fusion_slot2.slot_changed.connect(_on_slot_changed)
	fusion_slot3.slot_changed.connect(_on_slot_changed)
	GameManager.unlocked_cards_changed.connect(_on_inventory_changed)
	fuse_button.disabled = true

	# Sincroniza VScrollBar externo (lado esquerdo) com o ScrollContainer
	inventory_vscroll.value_changed.connect(func(v): inventory_scroll.scroll_vertical = int(v))
	inventory_scroll.get_v_scroll_bar().value_changed.connect(_on_internal_scroll_changed)
	await get_tree().process_frame
	_sync_vscroll_range()

func _on_inventory_changed() -> void:
	_setup_inventory()
	_sync_vscroll_range.call_deferred()

func _on_internal_scroll_changed(v: float) -> void:
	_sync_vscroll_range()
	inventory_vscroll.set_value_no_signal(v)

func _sync_vscroll_range() -> void:
	var bar := inventory_scroll.get_v_scroll_bar()
	inventory_vscroll.min_value = bar.min_value
	inventory_vscroll.max_value = bar.max_value
	inventory_vscroll.page = bar.page

func _setup_inventory() -> void:
	for child in inventory_grid.get_children():
		child.queue_free()

	var max_slots = 80
	for i in range(max_slots):
		var card_id = ""
		if i < GameManager.unlocked_cards.size():
			card_id = GameManager.unlocked_cards[i]

		var slot_wrapper = ColorRect.new()
		slot_wrapper.set_script(preload("res://scripts/ui/inventory/inventory_slot_ui.gd"))
		slot_wrapper.slot_index = i
		slot_wrapper.custom_minimum_size = Vector2(16, 16)
		slot_wrapper.color = Color(0.15, 0.15, 0.15, 1)

		inventory_grid.add_child(slot_wrapper)

		if card_id != "":
			var new_card = _card_scene.instantiate()
			slot_wrapper.add_child(new_card)
			var lvl := GameManager.get_card_level_at(i)
			new_card.setup(card_id, lvl)
			var cdata := CardDB.get_card(card_id)
			if cdata and cdata.type == "Consumable" and cdata.max_charges > 0:
				new_card.set_charges(GameManager.get_card_charges_at(i), cdata.max_charges)

func _on_slot_changed() -> void:
	var ids = [fusion_slot1.current_card_id, fusion_slot2.current_card_id, fusion_slot3.current_card_id]
	var all_filled: bool = ids.all(func(id): return id != "")
	var all_same: bool = all_filled and ids[0] == ids[1] and ids[1] == ids[2]

	if all_same:
		var card = CardDB.get_card(ids[0])
		if card:
			var next := _next_rarity(card.rarity)
			if next != "":
				result_label.text = "→ " + next.to_upper() + " (aleatório)"
				result_label.add_theme_color_override("font_color", _rarity_color(next))
				fuse_button.disabled = false
				return

	result_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	result_label.text = "Coloque 3 cartas iguais"
	fuse_button.disabled = true

func _on_fuse_button_pressed() -> void:
	var card_id := fusion_slot1.current_card_id
	var card := CardDB.get_card(card_id)
	if card == null:
		return
	var next_rarity := _next_rarity(card.rarity)
	if next_rarity == "":
		return

	fuse_button.disabled = true

	# ① Slots piscam branco e encolhem em sequência (stagger 0.12s entre cada)
	var slots: Array = [fusion_slot1, fusion_slot2, fusion_slot3]
	for i in range(slots.size()):
		var s: Control = slots[i]
		var tw := create_tween().set_parallel(true)
		tw.tween_property(s, "modulate", Color.WHITE, 0.08).set_delay(i * 0.12)
		tw.tween_property(s, "modulate", Color(0, 0, 0, 0), 0.15).set_delay(i * 0.12 + 0.08)
		tw.tween_property(s, "scale", Vector2.ZERO, 0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(i * 0.12 + 0.08)

	await get_tree().create_timer(slots.size() * 0.12 + 0.25).timeout

	# Limpa os slots sem devolver ao inventário — cartas já foram removidas ao dropar
	for slot: DropSlot in slots:
		slot.current_card_id = ""
		slot._update_visual("")
		slot.scale    = Vector2.ONE
		slot.modulate = Color.WHITE

	# ② Resolve carta resultado
	var rarity_filter: Array[String] = [next_rarity]
	var result := CardDB.get_random_card("", rarity_filter)
	if result == null:
		return

	# ③ Abre popup de reveal
	var reveal_scene := preload("res://scenes/ui/ui_fusion_reveal.tscn") as PackedScene
	var reveal := reveal_scene.instantiate()
	add_child(reveal)
	reveal.play(result)
	
	await reveal.closed
	GameManager.add_card_to_inventory(result.id)
	GameManager.save_game()
	_on_slot_changed()

func _on_back_button_pressed() -> void:
	# Devolve ao inventário cartas que ainda estão nos slots de fusão
	for slot: DropSlot in [fusion_slot1, fusion_slot2, fusion_slot3]:
		if slot.current_card_id != "":
			GameManager.add_card_to_inventory(slot.current_card_id)
			slot.current_card_id = ""
			slot._update_visual("")
	SceneManager.go_to("res://scenes/ui/ui_main_menu.tscn")

func _next_rarity(current: String) -> String:
	var idx := RARITY_ORDER.find(current)
	if idx == -1 or idx >= RARITY_ORDER.size() - 1:
		return ""
	return RARITY_ORDER[idx + 1]

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"Legendary": return Color(1.0, 0.8, 0.2)
		"Epic":      return Color(0.8, 0.2, 1.0)
		"Rare":      return Color(0.3, 0.6, 1.0)
		"Uncommon":  return Color(0.3, 1.0, 0.4)
	return Color(0.75, 0.75, 0.75)
