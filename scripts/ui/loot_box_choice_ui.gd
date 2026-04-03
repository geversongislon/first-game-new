extends CanvasLayer
class_name LootBoxChoiceUI

## Popup de escolha de cartas após abrir um LootBox.
## UI construída via código. O jogo continua rodando durante a escolha.

var _loot_box: Node = null
var _cards: Array = [] # [{card_id, card_level}, ...]
var _reveal_index: int = 0
var _reveal_timer: float = 0.0
var _reveal_interval: float = 0.8 # segundos entre revelações

var _slots: Array = [] # [{icon_wrapper, placeholder, icon, loading_bar, name_lbl, rarity_lbl, btn}]
var _full_label: Label = null

func setup(cards: Array, loot_box: Node) -> void:
	_cards = cards
	_loot_box = loot_box
	var player = get_tree().get_first_node_in_group("player")
	if player and "is_loot_ui_open" in player:
		player.is_loot_ui_open = true

func _ready() -> void:
	layer = 10
	_build_ui()

func _build_ui() -> void:
	# Container full-screen para centralizar o painel
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	var title := Label.new()
	title.text = "LOOT BOX"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 4)
	title_row.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(12, 12)
	close_btn.pressed.connect(_close)
	title_row.add_child(close_btn)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 5)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	for i in 3:
		var slot_vbox := VBoxContainer.new()
		slot_vbox.custom_minimum_size = Vector2(20, 0)
		slot_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		slot_vbox.add_theme_constant_override("separation", 2)
		hbox.add_child(slot_vbox)

		var icon_wrapper := Control.new()
		icon_wrapper.custom_minimum_size = Vector2(16, 16)
		icon_wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot_vbox.add_child(icon_wrapper)

		# Placeholder: quadrado cinza arredondado com "?"
		var placeholder := Panel.new()
		placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ph_style := StyleBoxFlat.new()
		ph_style.bg_color = Color(0.22, 0.22, 0.25, 1.0)
		ph_style.border_color = Color(0.5, 0.5, 0.55, 1.0)
		ph_style.border_width_left = 1
		ph_style.border_width_top = 1
		ph_style.border_width_right = 1
		ph_style.border_width_bottom = 1
		ph_style.expand_margin_left = -2
		ph_style.expand_margin_top = -2
		ph_style.expand_margin_right = -2
		ph_style.expand_margin_bottom = -2
		placeholder.add_theme_stylebox_override("panel", ph_style)
		icon_wrapper.add_child(placeholder)

		var q_lbl := Label.new()
		q_lbl.text = "?"
		q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		q_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		q_lbl.add_theme_font_size_override("font_size", 5)
		placeholder.add_child(q_lbl)

		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		icon_wrapper.add_child(icon)

		var loading_bar := ProgressBar.new()
		loading_bar.custom_minimum_size = Vector2(0, 3)
		loading_bar.max_value = 1.0
		loading_bar.value = 0.0
		loading_bar.show_percentage = false
		slot_vbox.add_child(loading_bar)

		var name_lbl := Label.new()
		name_lbl.text = "???"
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_lbl.clip_text = true
		name_lbl.custom_minimum_size = Vector2(52, 0)
		name_lbl.add_theme_font_size_override("font_size", 4)
		slot_vbox.add_child(name_lbl)

		var rarity_lbl := Label.new()
		rarity_lbl.text = ""
		rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rarity_lbl.add_theme_font_size_override("font_size", 4)
		slot_vbox.add_child(rarity_lbl)

		var btn := Button.new()
		btn.text = "Pegar"
		btn.disabled = true
		btn.add_theme_font_size_override("font_size", 5)
		var capture_i := i
		btn.pressed.connect(func(): _on_pick(capture_i))
		slot_vbox.add_child(btn)

		_slots.append({"icon_wrapper": icon_wrapper, "placeholder": placeholder, "icon": icon, "loading_bar": loading_bar, "name_lbl": name_lbl, "rarity_lbl": rarity_lbl, "btn": btn})

	_full_label = Label.new()
	_full_label.text = "Mochila cheia!"
	_full_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_full_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_full_label.visible = false
	vbox.add_child(_full_label)

func _process(delta: float) -> void:
	if _reveal_index >= _cards.size():
		return
	_reveal_timer += delta
	if _reveal_index < _slots.size():
		_slots[_reveal_index]["loading_bar"].value = _reveal_timer / _reveal_interval
	if _reveal_timer >= _reveal_interval:
		_reveal_timer = 0.0
		_reveal_card(_reveal_index)
		_reveal_index += 1

func _reveal_card(i: int) -> void:
	if i >= _slots.size() or i >= _cards.size():
		return
	var entry = _cards[i]
	var data = CardDB.get_card(entry["card_id"])
	if not data:
		return

	var slot = _slots[i]
	slot["loading_bar"].visible = false
	var art_tex = data.icon
	if art_tex:
		slot["icon"].texture = art_tex
		slot["icon"].texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	slot["name_lbl"].text = data.display_name
	slot["rarity_lbl"].text = data.rarity
	slot["rarity_lbl"].add_theme_color_override("font_color", _rarity_color(data.rarity))
	slot["btn"].disabled = false

	slot["placeholder"].visible = false
	slot["icon"].visible = true
	_add_level_pips(slot["icon_wrapper"], entry["card_level"])

	# Animação de revelação: escala 0 → 1 no wrapper (icon + pips juntos)
	var wrapper_node: Control = slot["icon_wrapper"]
	wrapper_node.scale = Vector2.ZERO
	var tw: Tween = create_tween()
	tw.tween_property(wrapper_node, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_pick(i: int) -> void:
	if i >= _cards.size():
		return
	var entry = _cards[i]
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	if player.collect_card(entry["card_id"], entry["card_level"]):
		_close()
	else:
		_full_label.visible = true
		get_tree().create_timer(1.5).timeout.connect(func():
			if is_instance_valid(_full_label):
				_full_label.visible = false
		)

func _add_level_pips(wrapper: Control, level: int) -> void:
	if level <= 1:
		return
	var colors := [Color(0.4, 0.7, 1.0), Color(1.0, 0.85, 0.2)]
	var pip_color: Color = colors[clampi(level - 2, 0, 1)]
	var border_color := pip_color.darkened(0.45)
	for i in range(level):
		var pip := Panel.new()
		pip.name = "_Pip%d" % i
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = pip_color
		style.border_color = border_color
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		pip.add_theme_stylebox_override("panel", style)
		pip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		pip.offset_left = 1
		pip.offset_right = 5
		pip.offset_bottom = - (i * 5) - 1
		pip.offset_top = pip.offset_bottom - 4
		wrapper.add_child(pip)

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"Legendary": return Color(1.0, 0.8, 0.2)
		"Epic": return Color(1.0, 0.2, 1.0)
		"Rare": return Color(0.2, 0.4, 1.0)
		"Uncommon": return Color(0.2, 1.0, 0.2)
		_: return Color(1.0, 1.0, 1.0)

func _close() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and "is_loot_ui_open" in player:
		player.is_loot_ui_open = false
	if _loot_box and is_instance_valid(_loot_box):
		if _loot_box.has_method("deactivate"):
			_loot_box.deactivate()
	queue_free()
