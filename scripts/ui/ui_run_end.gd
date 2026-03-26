extends Control

@onready var titulo:         Label        = $Center/Panel/Titulo
@onready var run_numero:     Label        = $Center/Panel/RunNumero
@onready var dano_causado:   Label        = $Center/Panel/RowDanoCausado/Val
@onready var inimigos:       Label        = $Center/Panel/RowInimigos/Val
@onready var dano_recebido:  Label        = $Center/Panel/RowDanoRecebido/Val
@onready var duracao:        Label        = $Center/Panel/RowDuracao/Val
@onready var gold:           Label        = $Center/Panel/RowGold/Val
@onready var itens_container: HBoxContainer = $Center/Panel/ItensContainer
@onready var btn_avancar:    Button       = $Center/Panel/BtnAvancar

const _SLOT_BG := Color(0.10, 0.10, 0.12, 1.0)
const _SLOT_BD := Color(0.25, 0.25, 0.28, 1.0)

func _ready() -> void:
	_fill_data()

func _fill_data() -> void:
	# Título
	if GameManager.run_extracted:
		titulo.text = "EXTRACAO COMPLETA!"
		titulo.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3, 1.0))
	else:
		titulo.text = "FIM DA RUN"

	run_numero.text = "Run #%d" % GameManager.runs_started

	# Stats
	dano_causado.text  = str(GameManager.run_damage_dealt)
	inimigos.text      = str(GameManager.run_enemies_killed)
	dano_recebido.text = str(GameManager.run_damage_taken)

	var elapsed := GameManager.run_elapsed
	var mins: int = int(elapsed / 60.0)
	var secs: int = int(elapsed) % 60
	duracao.text = "%d:%02d" % [mins, secs]

	gold.text = str(GameManager.run_coins)

	# Loadout — X se morreu, normal se extraiu
	_add_section_label("Loadout")
	for card_id in GameManager.equipped_cards:
		if card_id != "":
			itens_container.add_child(_make_item_slot(card_id, not GameManager.run_extracted))

	# Mochila — perdida se morreu, mantida se extraiu
	var backpack_cards := GameManager.run_backpack.filter(func(s: String) -> bool: return s != "")
	if not backpack_cards.is_empty():
		_add_section_label("Mochila")
		for card_id in GameManager.run_backpack:
			if card_id != "":
				itens_container.add_child(_make_item_slot(card_id, not GameManager.run_extracted))

	btn_avancar.pressed.connect(_on_advance)

func _make_item_slot(card_id: String, lost: bool = false) -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(16, 16)

	var style := StyleBoxFlat.new()
	style.bg_color = _SLOT_BG
	style.border_color = _SLOT_BD
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)

	var data := CardDB.get_card(card_id)
	if data and data.icon:
		var tex := TextureRect.new()
		tex.texture = data.icon
		tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.offset_left = 1; tex.offset_top = 1
		tex.offset_right = -1; tex.offset_bottom = -1
		if lost:
			tex.modulate = Color(0.45, 0.45, 0.45, 1.0)
		panel.add_child(tex)

	if lost:
		var x_lbl := Label.new()
		x_lbl.text = "X"
		x_lbl.add_theme_font_size_override("font_size", 9)
		x_lbl.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1, 0.85))
		x_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		x_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		x_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(x_lbl)

	return panel

func _add_section_label(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 4)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	itens_container.add_child(lbl)

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(2, 0)
	sep.color = Color(0.25, 0.25, 0.28, 1)
	itens_container.add_child(sep)

func _on_advance() -> void:
	GameManager.reset_run()
	SceneManager.go_to("res://scenes/ui/ui_main_menu.tscn")
