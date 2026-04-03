extends Control
## Popup de reveal após fusão de cartas.
## Chamado por ui_fusion.gd via reveal.play(card) após os slots serem consumidos.

signal closed

@onready var overlay        := $Overlay as ColorRect
@onready var panel          := $CenterContainer/Panel as PanelContainer
@onready var card_icon      := $CenterContainer/Panel/VBoxContainer/MarginContainer/CardIcon as TextureRect
@onready var card_name      := $CenterContainer/Panel/VBoxContainer/CardNameMargin/CardName as Label
@onready var rarity_label   := $CenterContainer/Panel/VBoxContainer/RarityLabel as Label
@onready var progress_bg    := $CenterContainer/Panel/VBoxContainer/ProgressContainer/ProgressBg as ColorRect
@onready var progress_fill  := $CenterContainer/Panel/VBoxContainer/ProgressContainer/ProgressFill as ColorRect
@onready var loading_label  := $CenterContainer/Panel/VBoxContainer/LoadingLabel as Label
@onready var continue_btn   := $CenterContainer/Panel/VBoxContainer/MarginContainer2/ContinueBtn as Button

const BAR_WIDTH := 90.0

func play(card: CardData) -> void:
	var rc := _rarity_color(card.rarity)

	# ── Estado inicial ─────────────────────────────────────────────────────
	overlay.modulate.a      = 0.0
	panel.scale             = Vector2.ZERO
	card_icon.texture       = card.full_art if card.full_art else card.icon
	card_icon.modulate.a    = 0.0
	card_icon.scale         = Vector2.ZERO
	card_name.text          = card.display_name
	card_name.modulate.a    = 0.0
	card_name.position.y   += 6.0
	rarity_label.text       = card.rarity.to_upper()
	rarity_label.add_theme_color_override("font_color", rc)
	rarity_label.modulate.a = 0.0
	progress_fill.color     = rc
	progress_fill.size.x    = 0.0
	continue_btn.modulate.a = 0.0
	continue_btn.pressed.connect(_on_continue)

	# ── ① Overlay + painel aparecem ───────────────────────────────────────
	var t1 := create_tween().set_parallel(true)
	t1.tween_property(overlay, "modulate:a", 0.85, 0.3)
	t1.tween_property(panel, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# ── ② "FUNDINDO..." pulsa ─────────────────────────────────────────────
	var pulse := create_tween().set_loops()
	pulse.tween_property(loading_label, "modulate:a", 0.2, 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(loading_label, "modulate:a", 1.0, 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	await get_tree().create_timer(0.35).timeout

	# ── ③ Barra de carregamento ───────────────────────────────────────────
	var t2 := create_tween()
	t2.tween_property(progress_fill, "size:x", BAR_WIDTH, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t2.finished

	# ── ④ Flash branco ────────────────────────────────────────────────────
	pulse.kill()
	loading_label.visible = false

	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.8)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tf := create_tween()
	tf.tween_property(flash, "modulate:a", 0.0, 0.15)
	tf.tween_callback(flash.queue_free)

	# ── ④ Reveal da carta ─────────────────────────────────────────────────
	var card_name_base_y := card_name.position.y
	var t3 := create_tween().set_parallel(true)
	t3.tween_property(card_icon,    "modulate:a", 1.0,         0.15)
	t3.tween_property(card_icon,    "scale",      Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t3.tween_property(card_name,    "modulate:a", 1.0,         0.35).set_delay(0.1)
	t3.tween_property(card_name,    "position:y", card_name_base_y - 6.0, 0.35) \
		.set_delay(0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t3.tween_property(rarity_label, "modulate:a", 1.0,         0.3).set_delay(0.15)
	t3.tween_property(continue_btn, "modulate:a", 1.0,         0.3).set_delay(0.5)

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"Legendary": return Color(1.0, 0.8, 0.2)
		"Epic":      return Color(0.8, 0.2, 1.0)
		"Rare":      return Color(0.3, 0.6, 1.0)
		"Uncommon":  return Color(0.3, 1.0, 0.4)
	return Color(0.75, 0.75, 0.75)

func _on_continue() -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.chain().tween_callback(func(): closed.emit(); queue_free())
