extends ColorRect
class_name DraggableCard

var card_id: String = ""
var card_data: CardData = null
var card_level: int = 1
var card_charges: int = 0
var inventory_index: int = -1
var _charge_bars: Array = []

signal card_clicked(card: DraggableCard)
signal card_right_clicked(card: DraggableCard)

func setup(id: String, level: int = 1) -> void:
	card_id = id
	card_level = level
	card_data = CardDB.get_card(id)

	# Failsafe: se o save estava sujo com "bow" em vez de "card_bow"
	if not card_data:
		var converted = CardDB.get_card_id_from_weapon(id)
		if converted != "":
			card_id = converted
			card_data = CardDB.get_card(card_id)

	if card_data:
		if card_data.icon:
			$WeaponArt.texture = card_data.icon

		self.mouse_filter = Control.MOUSE_FILTER_PASS
	else:
		push_warning("DraggableCard: Dados não encontrados no CardDatabase para " + id)

	_update_level_visual(level)

func set_charges(charges: int, max_charges: int) -> void:
	card_charges = charges
	_update_charge_visual(charges, max_charges)

func _update_charge_visual(charges: int, max_charges: int) -> void:
	for bar in _charge_bars:
		if is_instance_valid(bar):
			bar.queue_free()
	_charge_bars.clear()
	if max_charges <= 0: return

	# Barras fixas: 2×2px, 1px de gap — ancoragem PRESET_BOTTOM_RIGHT (imune a size=0)
	for i in range(max_charges):
		var bar := Panel.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.55, 0.1, 1.0) if i < charges else Color(0.25, 0.25, 0.25, 1.0)
		bar.add_theme_stylebox_override("panel", style)
		bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		bar.offset_right  = -1
		bar.offset_left   = bar.offset_right - 2
		bar.offset_bottom = -(i * 3) - 1
		bar.offset_top    = bar.offset_bottom - 2
		add_child(bar)
		_charge_bars.append(bar)

func _update_level_visual(level: int) -> void:
	# Remove pips antigos imediatamente da árvore
	for i in range(3):
		var old := get_node_or_null("_Pip%d" % i)
		if old:
			remove_child(old)
			old.queue_free()

	if level <= 1: return  # Nível 1 não exibe indicador

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
		# Ancora no canto inferior esquerdo, pips empilhados para cima
		pip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		pip.offset_left   = 1
		pip.offset_right  = 5     # 4px de largura
		pip.offset_bottom = -(i * 5) - 1   # 1px margem inferior, +5 por pip
		pip.offset_top    = pip.offset_bottom - 4  # 4px de altura
		add_child(pip)

# ----------- DRAG & DROP NATIVO DO GODOT -----------

func _get_drag_data(_at_position: Vector2):
	var source = null
	var inv_idx := -1

	if get_parent() and get_parent().name == "CardContainer":
		source = get_parent().get_parent()
	elif get_parent() and "slot_index" in get_parent():
		inv_idx = get_parent().slot_index

	var data = {
		"type": "card",
		"card_id": card_id,
		"card_level": card_level,
		"source_slot": source,
		"inventory_index": inv_idx
	}

	var preview = Control.new()
	var icon_node := TextureRect.new()
	icon_node.texture = $WeaponArt.texture
	icon_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_node.modulate.a = 0.85
	icon_node.size = size
	icon_node.position = -0.5 * size
	preview.add_child(icon_node)
	set_drag_preview(preview)

	return data

# ----------- CLIQUE -----------
var _drag_started: bool = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_started = false
			elif not _drag_started:
				if not (get_parent() and get_parent().name == "CardContainer"):
					card_clicked.emit(self)
					get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			card_right_clicked.emit(self)
			get_viewport().set_input_as_handled()
