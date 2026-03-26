extends Control

@onready var coins_label: Label = $VBoxContainer/TopBar/CoinsLabel
@onready var grid: GridContainer = $VBoxContainer/ScrollContainer/Grid
@onready var back_button: Button = $VBoxContainer/TopBar/BackButton

var _purchased_this_session: Array[String] = []

func _ready() -> void:
	GameManager.permanent_coins_changed.connect(_update_coins_label)
	_update_coins_label(GameManager.total_coins)
	_build_shop()
	back_button.pressed.connect(_on_back_pressed)

func _update_coins_label(_amount: int = 0) -> void:
	coins_label.text = "Moedas: " + str(GameManager.total_coins)

func _get_price(card: CardData) -> int:
	match card.rarity:
		"Common":    return 50
		"Uncommon":  return 100
		"Rare":      return 200
		"Epic":      return 350
		"Legendary": return 500
	return 50

func _build_shop() -> void:
	for child in grid.get_children():
		child.queue_free()
	var cards = CardDB.get_all_cards()
	for card in cards:
		_add_card_entry(card)

func _add_card_entry(card: CardData) -> void:
	var price := _get_price(card)

	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(30, 30)
	container.add_theme_constant_override("separation", 1)

	# Ícone
	if card.icon:
		var tex := TextureRect.new()
		tex.texture = card.icon
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(16, 16)
		tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		container.add_child(tex)
	else:
		var rect := ColorRect.new()
		rect.custom_minimum_size = Vector2(16, 16)
		rect.color = _get_type_color(card.type)
		rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		container.add_child(rect)

	# Nome
	var name_lbl := Label.new()
	name_lbl.text = card.display_name
	name_lbl.add_theme_font_size_override("font_size", 3)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(name_lbl)

	# Preço
	var price_lbl := Label.new()
	price_lbl.text = str(price) + " moedas"
	price_lbl.add_theme_font_size_override("font_size", 3)
	price_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(price_lbl)

	# Botão comprar
	var btn := Button.new()
	var already_bought := card.id in _purchased_this_session
	btn.text = "COMPRADO" if already_bought else "COMPRAR"
	btn.disabled = already_bought or GameManager.total_coins < price
	btn.add_theme_font_size_override("font_size", 3)
	btn.pressed.connect(_on_buy_pressed.bind(card.id, price, btn))
	container.add_child(btn)

	grid.add_child(container)

func _on_buy_pressed(card_id: String, price: int, btn: Button) -> void:
	if GameManager.total_coins < price:
		return
	GameManager.total_coins -= price
	GameManager.permanent_coins_changed.emit(GameManager.total_coins)
	GameManager.add_card_to_inventory(card_id)
	_purchased_this_session.append(card_id)
	btn.text = "COMPRADO"
	btn.disabled = true

func _get_type_color(type: String) -> Color:
	match type:
		"Weapon":     return Color(0.757, 0.0, 0.188, 1.0)
		"Active":     return Color(0.935, 0.71, 0.0, 1.0)
		"Passive":    return Color(0.213, 0.512, 0.345, 1.0)
		"Consumable": return Color(0.2, 0.6, 0.8, 1.0)
	return Color(0.3, 0.3, 0.3)

func _on_back_pressed() -> void:
	SceneManager.go_to("res://scenes/ui/ui_main_menu.tscn")
