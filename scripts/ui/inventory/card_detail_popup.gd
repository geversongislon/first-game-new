extends Control
class_name CardDetailPopup

signal upgrade_requested(inventory_index: int)
signal sell_requested(inventory_index: int)

@onready var card_icon: TextureRect     = $Panel/MarginContainer/VBoxContainer/Header/CardIcon
@onready var card_name_label: Label     = $Panel/MarginContainer/VBoxContainer/Header/InfoVBox/CardName
@onready var rarity_label: Label        = $Panel/MarginContainer/VBoxContainer/Header/InfoVBox/RarityLabel
@onready var level_display: HBoxContainer = $Panel/MarginContainer/VBoxContainer/Header/InfoVBox/LevelDisplay
@onready var poder_value_label: Label   = $Panel/MarginContainer/VBoxContainer/Header/PoderVBox/PoderValue
@onready var desc_label: Label          = $Panel/MarginContainer/VBoxContainer/DescLabel
@onready var stats_grid: GridContainer  = $Panel/MarginContainer/VBoxContainer/StatsGrid
@onready var upgrade_section: VBoxContainer = $Panel/MarginContainer/VBoxContainer/UpgradeSection
@onready var upgrade_cost_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/UpgradeSection/UpgradeCostLabel

const COIN_ICON := "[img=6x6]res://assets/sprites/coin.png[/img]"
@onready var upgrade_button: Button     = $Panel/MarginContainer/VBoxContainer/UpgradeSection/UpgradeButton
@onready var sell_button: Button        = $Panel/MarginContainer/VBoxContainer/SellButton

var _card_id: String = ""
var _level: int = 1
var _inventory_index: int = -1

var _preview_label: Label = null
var _action_row: HBoxContainer = null
var _cancel_button: Button = null
var _confirm_button: Button = null
var _preview_visible: bool = false

func _ready() -> void:
	_preview_label = Label.new()
	_preview_label.add_theme_font_size_override("font_size", 3)
	_preview_label.visible = false
	upgrade_section.add_child(_preview_label)

	_action_row = HBoxContainer.new()
	_action_row.visible = false
	_action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	upgrade_section.add_child(_action_row)

	_cancel_button = Button.new()
	_cancel_button.text = "CANCELAR"
	_cancel_button.add_theme_font_size_override("font_size", 3)
	_cancel_button.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_action_row.add_child(_cancel_button)

	_confirm_button = Button.new()
	_confirm_button.text = "CONFIRMAR"
	_confirm_button.add_theme_font_size_override("font_size", 3)
	_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_action_row.add_child(_confirm_button)

func open(card_id: String, level: int, inventory_index: int, read_only: bool = false) -> void:
	if card_id == "" or not CardDB.get_card(card_id):
		push_warning("CardDetailPopup.open: invalid card_id='%s'" % card_id)
		return
	_card_id = card_id
	_level = level
	_inventory_index = inventory_index
	_preview_visible = false
	_populate(card_id, level)
	if read_only:
		upgrade_section.visible = false
		sell_button.visible = false
	else:
		sell_button.visible = true
	visible = true

func refresh_level(new_level: int) -> void:
	_level = new_level
	_populate(_card_id, new_level)
	visible = true

func _populate(card_id: String, level: int) -> void:
	var card := CardDB.get_card(card_id)
	if not card:
		push_warning("CardDetailPopup: card not found in DB for id='%s'" % card_id)
		return

	card_icon.texture = card.full_art if card.full_art else card.icon

	card_name_label.text = card.display_name

	rarity_label.text = card.rarity
	rarity_label.add_theme_color_override("font_color", _rarity_color(card.rarity))

	_update_level_display(level)

	var poder := _calc_poder(card, level)
	if poder > 0.0:
		poder_value_label.text = "%.1f" % poder
		poder_value_label.get_parent().visible = true
	else:
		poder_value_label.get_parent().visible = false

	desc_label.text = card.description

	for child in stats_grid.get_children():
		stats_grid.remove_child(child)
		child.queue_free()
	_populate_stats(stats_grid, card, level)

	_update_upgrade_section(card, level)

	sell_button.text = "VENDER  %d" % card.sell_price
	if not sell_button.icon:
		sell_button.icon = load("res://assets/sprites/coin.png")
		sell_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sell_button.expand_icon = false
		sell_button.add_theme_constant_override("icon_max_width", 6)

func _update_level_display(level: int) -> void:
	for child in level_display.get_children():
		level_display.remove_child(child)
		child.queue_free()
	if level <= 1: return
	var pip_color := Color(0.4, 0.7, 1.0) if level == 2 else Color(1.0, 0.85, 0.2)
	var border_color := pip_color.darkened(0.45)
	for i in range(level):
		var pip := Panel.new()
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.custom_minimum_size = Vector2(4, 4)
		var style := StyleBoxFlat.new()
		style.bg_color = pip_color
		style.border_color = border_color
		style.set_border_width_all(1)
		pip.add_theme_stylebox_override("panel", style)
		level_display.add_child(pip)

func _update_upgrade_section(card: CardData, level: int) -> void:
	if card.type != "Weapon" or level >= 3:
		upgrade_section.visible = false
		return
	upgrade_section.visible = true
	var cost := card.upgrade_cost * (2 if level == 2 else 1)
	var has_gold := GameManager.total_coins >= cost
	var cost_color_hex := "ffda33" if has_gold else "cc4d4d"
	upgrade_cost_label.bbcode_text = "[center][color=#%s]Nível %d → %d:  %d%s[/color][/center]" % [cost_color_hex, level, level + 1, cost, COIN_ICON]

	if _preview_visible:
		upgrade_button.visible = false
		_show_upgrade_preview()
		var preview_color := Color(0.6, 0.9, 0.6) if has_gold else Color(0.5, 0.5, 0.5)
		_preview_label.add_theme_color_override("font_color", preview_color)
		_preview_label.visible = true
		_action_row.visible = true
		_confirm_button.disabled = not has_gold
		var confirm_color := Color(0.3, 1.0, 0.4) if has_gold else Color(0.5, 0.5, 0.5)
		_confirm_button.add_theme_color_override("font_color", confirm_color)
	else:
		upgrade_button.visible = true
		upgrade_button.text = "MELHORAR"
		upgrade_button.remove_theme_color_override("font_color")
		upgrade_button.disabled = false
		_preview_label.visible = false
		_action_row.visible = false

func _calc_poder(card: CardData, level: int) -> float:
	var i          := clampi(level - 1, 0, 2)
	var rate_mult  : float = 1.0 + BaseWeapon.UPGRADE_RATE_INC[i]
	var ammo_mult  : float = 1.0 + BaseWeapon.UPGRADE_AMMO_INC[i]
	var reload_mult: float = 1.0 + BaseWeapon.UPGRADE_RELOAD_INC[i]
	var dmg_mult   : float = 1.0 + ProjectileWeapon.UPGRADE_DMG_INC[i]
	var crit       : float = card.crit_chance + BaseWeapon.UPGRADE_CRIT_INC[i]
	var fire_rate  : float = card.fire_rate * rate_mult
	var max_ammo   : int   = int(card.max_ammo * ammo_mult)
	var reload     : float = card.reload_time * reload_mult
	var crit_mult  : float = card.crit_multiplier
	match card.weapon_archetype:
		"Projectile":
			var dmg     : float = card.projectile_damage * dmg_mult
			var eff_dmg : float = dmg * (1.0 + crit * (crit_mult - 1.0))
			var cycle   : float = max_ammo / fire_rate + reload
			return eff_dmg * max_ammo / cycle
		"Charge":
			var avg_dmg : float = lerp(float(card.charge_damage_range.x), float(card.charge_damage_range.y), 0.75) * dmg_mult
			var eff_dmg : float = avg_dmg * (1.0 + crit * (crit_mult - 1.0))
			var cycle   : float = max_ammo * (card.max_charge_time * 0.75) + reload
			return eff_dmg * max_ammo / cycle
		"Throwable":
			var dmg   : float = float(card.charge_damage_range.x) * dmg_mult
			var cycle : float = max_ammo * (card.max_charge_time * 0.50) + reload
			return dmg * max_ammo / cycle
	return 0.0

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"Legendary": return Color(1.0, 0.8, 0.2)
		"Epic":      return Color(0.8, 0.2, 1.0)
		"Rare":      return Color(0.3, 0.6, 1.0)
		"Uncommon":  return Color(0.3, 1.0, 0.4)
	return Color(0.75, 0.75, 0.75)

func _populate_stats(grid: GridContainer, card: CardData, level: int = 1) -> void:
	var pairs: Array = []
	var C_VAL := Color(0.95, 0.95, 1.00)
	var C_DMG := Color(1.00, 0.45, 0.35)
	var C_GRN := Color(0.45, 1.00, 0.55)
	var C_YLW := Color(1.00, 0.85, 0.25)
	var C_BLU := Color(0.40, 0.75, 1.00)

	# Multiplicadores de nível — lidos diretamente das constantes dos arquivos de arma
	var i := clampi(level - 1, 0, 2)
	var rate_mult:   float = 1.0 + BaseWeapon.UPGRADE_RATE_INC[i]
	var ammo_mult:   float = 1.0 + BaseWeapon.UPGRADE_AMMO_INC[i]
	var reload_mult: float = 1.0 + BaseWeapon.UPGRADE_RELOAD_INC[i]
	var dmg_mult:    float = 1.0 + ProjectileWeapon.UPGRADE_DMG_INC[i]
	var crit_chance: float = card.crit_chance + BaseWeapon.UPGRADE_CRIT_INC[i]

	match card.type:
		"Weapon":
			match card.weapon_archetype:
				"Projectile":
					pairs = [
						["Dano",     str(int(card.projectile_damage * dmg_mult)),              C_DMG],
						["Munição",  str(int(card.max_ammo * ammo_mult)),                      C_GRN],
						["Cadência", "%.1f/s" % (card.fire_rate * rate_mult),                  C_VAL],
						["Recarga",  "%.1fs" % (card.reload_time * reload_mult),               C_GRN],
						["Vel.",     "%d" % int(card.projectile_speed),                        C_YLW],
						["Knockback",str(int(card.projectile_knockback)),                       C_BLU],
					]
					if card.requires_stillness:
						pairs.append(["Parado", "%.1fs" % card.stillness_time_required, C_GRN])
				"Charge":
					pairs = [
						["Dano",    "%d–%d" % [int(card.charge_damage_range.x * dmg_mult), int(card.charge_damage_range.y * dmg_mult)], C_DMG],
						["Munição", str(int(card.max_ammo * ammo_mult)),                                                                  C_GRN],
						["Recarga", "%.1fs" % (card.reload_time * reload_mult),                                                           C_GRN],
						["Carga",   "%.1fs" % card.max_charge_time,                                                                       C_VAL],
					]
				"Throwable":
					pairs = [
						["Dano",    "%d" % int(card.charge_damage_range.x * dmg_mult), C_DMG],
						["Munição", str(int(card.max_ammo * ammo_mult)),                C_GRN],
						["Recarga", "%.1fs" % (card.reload_time * reload_mult),         C_GRN],
					]
				"Melee":
					pairs = [
						["Dano",  str(int(card.melee_damage * dmg_mult)), C_DMG],
						["KB",    str(int(card.melee_knockback)),          C_BLU],
					]
		"Active":
			pairs = [["Cooldown", "%.1fs" % card.cooldown, C_GRN]]
		"Passive":
			if card.flat_health_bonus > 0:
				pairs.append(["HP Bônus", "+%d" % card.flat_health_bonus, C_DMG])
			if card.speed_multiplier != 1.0:
				pairs.append(["Velocidade", "x%.1f" % card.speed_multiplier, C_YLW])
		"Consumable":
			pairs = [
				["Cargas", "%d máx" % card.max_charges, C_GRN],
				["Cooldown", "%.1fs" % card.charge_cooldown, C_GRN],
			]

	if card.type == "Weapon":
		pairs.append(["Crítico", "%d%%" % int(crit_chance * 100.0), C_YLW])

	var C_NAME := Color(0.55, 0.55, 0.60)
	for pair in pairs:
		var name_lbl := Label.new()
		name_lbl.text = pair[0]
		name_lbl.add_theme_font_size_override("font_size", 3)
		name_lbl.add_theme_color_override("font_color", C_NAME)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_lbl)

		var val_lbl := Label.new()
		val_lbl.text = pair[1]
		val_lbl.add_theme_font_size_override("font_size", 3)
		val_lbl.add_theme_color_override("font_color", pair[2])
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(val_lbl)

func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		visible = false

func _on_close_pressed() -> void:
	visible = false

func _on_upgrade_pressed() -> void:
	_preview_visible = true
	var card := CardDB.get_card(_card_id)
	if not card: return
	_update_upgrade_section(card, _level)

func _on_cancel_pressed() -> void:
	_preview_visible = false
	var card := CardDB.get_card(_card_id)
	if card:
		_update_upgrade_section(card, _level)

func _on_confirm_pressed() -> void:
	upgrade_requested.emit(_inventory_index)

func _show_upgrade_preview() -> void:
	var card := CardDB.get_card(_card_id)
	if not card: return
	var next := _level + 1
	if next > 3: return

	var lines: Array[String] = []

	var poder_cur := _calc_poder(card, _level)
	var poder_nxt := _calc_poder(card, next)
	if poder_cur > 0.0:
		lines.append("Poder: %.1f → %.1f" % [poder_cur, poder_nxt])

	var ci := clampi(_level - 1, 0, 2)
	var ni := clampi(next - 1, 0, 2)
	var cur_rate_mult:  float = 1.0 + BaseWeapon.UPGRADE_RATE_INC[ci]
	var cur_ammo_mult:  float = 1.0 + BaseWeapon.UPGRADE_AMMO_INC[ci]
	var cur_rel_mult:   float = 1.0 + BaseWeapon.UPGRADE_RELOAD_INC[ci]
	var nxt_rate_mult:  float = 1.0 + BaseWeapon.UPGRADE_RATE_INC[ni]
	var nxt_ammo_mult:  float = 1.0 + BaseWeapon.UPGRADE_AMMO_INC[ni]
	var nxt_rel_mult:   float = 1.0 + BaseWeapon.UPGRADE_RELOAD_INC[ni]

	if card.type == "Weapon":
		var cur_fire: float = card.fire_rate * cur_rate_mult
		var nxt_fire: float = card.fire_rate * nxt_rate_mult
		var cur_ammo: int   = int(card.max_ammo * cur_ammo_mult)
		var nxt_ammo: int   = int(card.max_ammo * nxt_ammo_mult)
		var cur_rel: float  = card.reload_time * cur_rel_mult
		var nxt_rel: float  = card.reload_time * nxt_rel_mult
		lines.append("Cadência: %.1f → %.1f/s" % [cur_fire, nxt_fire])
		lines.append("Munição: %d → %d" % [cur_ammo, nxt_ammo])
		lines.append("Recarga: %.1fs → %.1fs" % [cur_rel, nxt_rel])

	var cur_dmg_mult: float = 1.0 + ProjectileWeapon.UPGRADE_DMG_INC[ci]
	var nxt_dmg_mult: float = 1.0 + ProjectileWeapon.UPGRADE_DMG_INC[ni]

	match card.weapon_archetype:
		"Projectile":
			var cur_dmg: int = int(card.projectile_damage * cur_dmg_mult)
			var nxt_dmg: int = int(card.projectile_damage * nxt_dmg_mult)
			lines.append("Dano: %d → %d" % [cur_dmg, nxt_dmg])
		"Charge":
			var cur_min: int = int(card.charge_damage_range.x * cur_dmg_mult)
			var cur_max: int = int(card.charge_damage_range.y * cur_dmg_mult)
			var nxt_min: int = int(card.charge_damage_range.x * nxt_dmg_mult)
			var nxt_max: int = int(card.charge_damage_range.y * nxt_dmg_mult)
			lines.append("Dano: %d–%d → %d–%d" % [cur_min, cur_max, nxt_min, nxt_max])
		"Throwable":
			var cur_dmg: int = int(card.charge_damage_range.x * cur_dmg_mult)
			var nxt_dmg: int = int(card.charge_damage_range.x * nxt_dmg_mult)
			lines.append("Dano: %d → %d" % [cur_dmg, nxt_dmg])
		"Melee":
			var cur_dmg: int = int(card.melee_damage * cur_dmg_mult)
			var nxt_dmg: int = int(card.melee_damage * nxt_dmg_mult)
			lines.append("Dano: %d → %d" % [cur_dmg, nxt_dmg])

	var cur_crit: float = card.crit_chance + BaseWeapon.UPGRADE_CRIT_INC[ci]
	var nxt_crit: float = card.crit_chance + BaseWeapon.UPGRADE_CRIT_INC[ni]
	lines.append("Crítico: %d%% → %d%%" % [int(cur_crit * 100.0), int(nxt_crit * 100.0)])

	_preview_label.text = "\n".join(lines)

func _on_sell_pressed() -> void:
	sell_requested.emit(_inventory_index)
