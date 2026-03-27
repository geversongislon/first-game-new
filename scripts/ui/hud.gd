extends CanvasLayer

@onready var container = $LoadoutBar
@onready var life_bar: ProgressBar = $LifeBar
@onready var life_label: Label = $LifeBar/LifeLabel
@onready var gold_label: Label = $GoldDisplay/GoldLabel
@onready var run_label: Label = $RunLabel
@onready var _flashlight_panel: Panel = $FlashlightPanel

# Mapeamento de action → tecla exibida no HUD
const ACTION_LABELS: Dictionary = {
	"active_ability_dash": "SHIFT",
	"active_ability_f": "F",
	"active_ability_c": "C",
	"active_ability_v": "V",
}

# O mapeamento de ícones agora é feito via CardDatabase

var _manager: WeaponManager = null

# Barra de dificuldade (fill cresce de 0 a 100% verde → vermelho)
var _diff_bar: Control = null
var _diff_bar_fill: ColorRect = null

# Label flutuante acima do player em world-space
var _world_ammo_label: Label = null
# Indicador de stance (requer imobilidade) — ponto colorido ao lado do ammo label
var _stance_dot: Node2D = null
const _STANCE_INDICATOR_SCRIPT = preload("res://scripts/weapons/stance_indicator.gd")

# Array de painéis (slots 0, 1 e 2)
var slot_panels = []

# Referência para os novos slots da mochila
var backpack_panels = []

var _card_popup: CardDetailPopup = null
var _popup_scene = preload("res://scenes/ui/inventory/card_detail_popup.tscn")

# Nós visuais criados para indicar stacking (bordas, conectores, badges)
var _stack_overlays: Array = []
# Tweens de pulso ativos para stacking
var _stack_tweens: Array = []
# Overlay para conectores de stack (fora do HBoxContainer para não empurrar slots)
var _connector_overlay: Control = null
# Lista de conectores com metadados dos painéis que conectam
var _connector_nodes: Array = []

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_clear_all_slots()
	_create_ui_structure()
	_create_world_ammo_label()
	_create_difficulty_bar()
	run_label.text = "Run #%d" % GameManager.runs_started
	GameManager.run_backpack_changed.connect(update_backpack)
	_setup_card_popup()

func _setup_card_popup() -> void:
	_card_popup = _popup_scene.instantiate()
	add_child(_card_popup)
	for slot in slot_panels + backpack_panels:
		slot.right_clicked.connect(_on_hud_slot_right_clicked)

func _on_hud_slot_right_clicked(card_id: String, card_level: int) -> void:
	if _card_popup:
		_card_popup.open(card_id, card_level, -1, true)


func _create_difficulty_bar() -> void:
	_diff_bar = Control.new()
	_diff_bar.name = "DifficultyBar"
	_diff_bar.anchor_left = 0.5
	_diff_bar.anchor_right = 0.5
	_diff_bar.anchor_top = 0.0
	_diff_bar.anchor_bottom = 0.0
	_diff_bar.offset_left = -20.0 # 40px total, centrado
	_diff_bar.offset_right = 20.0
	_diff_bar.offset_top = 13.0
	_diff_bar.offset_bottom = 16.0
	_diff_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_diff_bar)

	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.15, 0.15, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_diff_bar.add_child(bg)

	_diff_bar_fill = ColorRect.new()
	_diff_bar_fill.name = "Fill"
	_diff_bar_fill.color = Color(0.146, 0.56, 0.146, 1.0)
	_diff_bar_fill.size = Vector2(0.0, 3.0)
	_diff_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_diff_bar_fill.material = mat
	_diff_bar.add_child(_diff_bar_fill)

func set_difficulty(t: float) -> void:
	if not is_instance_valid(_diff_bar_fill): return
	var bar_w := _diff_bar.size.x
	_diff_bar_fill.size.x = bar_w * t
	_diff_bar_fill.color = Color(minf(t * 2.0, 1.0), minf((1.0 - t) * 2.0, 1.0), 0.0, 1.0)

func _create_world_ammo_label() -> void:
	var player = get_parent()
	if not player: return
	_world_ammo_label = Label.new()
	_world_ammo_label.name = "WorldAmmoLabel"
	_world_ammo_label.position = Vector2(0, -15)
	_world_ammo_label.add_theme_font_size_override("font_size", 3)
	_world_ammo_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_world_ammo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_world_ammo_label.add_theme_constant_override("outline_size", 1)
	_world_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_world_ammo_label.visible = false
	var lbl_mat := CanvasItemMaterial.new()
	lbl_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_world_ammo_label.material = lbl_mat
	player.call_deferred("add_child", _world_ammo_label)

	_stance_dot = Node2D.new()
	_stance_dot.set_script(_STANCE_INDICATOR_SCRIPT)
	_stance_dot.visible = false
	player.call_deferred("add_child", _stance_dot)

func _clear_all_slots():
	for child in container.get_children():
		child.queue_free()
	if is_instance_valid(_world_ammo_label):
		_world_ammo_label.queue_free()
		_world_ammo_label = null
	if is_instance_valid(_stance_dot):
		_stance_dot.queue_free()
		_stance_dot = null

func _create_ui_structure():
	# Criamos dois grupos: Loadout (3) e Mochila (5)
	slot_panels.clear()
	backpack_panels.clear()
	
	# --- LOADOUT (1, 2, 3) ---
	var loadout_label = Label.new()
	loadout_label.text = "Slots:"
	loadout_label.add_theme_font_size_override("font_size", 4)
	loadout_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	container.add_child(loadout_label)

	for i in range(3):
		var panel = _create_slot_panel(i, Color(0.2, 0.2, 0.2, 1), true)
		slot_panels.append(panel)
		container.add_child(panel)

	# Espaçador
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(3, 0)
	container.add_child(spacer)

	# --- MOCHILA (Backpack) ---
	var backpack_label = Label.new()
	backpack_label.text = "Bag:"
	backpack_label.add_theme_font_size_override("font_size", 4)
	backpack_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	container.add_child(backpack_label)
	
	for i in range(5):
		var panel = _create_slot_panel(i, Color(0.15, 0.2, 0.3, 1), false)
		backpack_panels.append(panel)
		container.add_child(panel)
	
	# Overlay para conectores de stack (irmão do container, fora do layout)
	_connector_overlay = Control.new()
	_connector_overlay.name = "ConnectorOverlay"
	_connector_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_connector_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_connector_overlay)

	_create_background_drop_zone()

func _create_background_drop_zone():
	# Criamos um Control invisível que cobre toda a tela por baixo dos outros
	var bg = Control.new()
	bg.name = "BackgroundDropZone"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Garante que ele fique atrás da barra e dos slots
	bg.show_behind_parent = true
	add_child(bg)
	move_child(bg, 0)
	
	# Usamos um script básico de drop
	bg.set_script(load("res://scripts/ui/world_drop_zone.gd"))
	bg.set("weapon_ui", self )

func _create_slot_panel(index: int, bg_color: Color, is_loadout: bool) -> Panel:
	var panel = Panel.new()
	panel.set_script(load("res://scripts/ui/hud_slot.gd"))
	panel.slot_index = index
	panel.is_loadout = is_loadout
	panel.weapon_ui = self
	
	# Loadout e Mochila: 16×16
	var slot_size := 16
	panel.custom_minimum_size = Vector2(slot_size, slot_size)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	panel.add_theme_stylebox_override("panel", style)
	
	# Slot Label (apenas loadout tem 1, 2, 3)
	if is_loadout:
		var label = Label.new()
		label.text = str(index + 1)
		label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		label.position = Vector2(2, 2)
		label.add_theme_font_size_override("font_size", 5)
		panel.add_child(label)
	
	# Ícone
	var icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
	icon.name = "Icon"
	panel.add_child(icon)
	
	# Adicionamos metadados para o drop_slot (simulado aqui ou via script se preferir)
	# Para o HUD in-game, vamos lidar com o drag-drop aqui no WeaponUI mesmo ou em sub-scripts
	# Por simplicidade, vamos usar o sistema de DropSlot se ele for compatível
	
	# Cooldown Overlay (Novo)
	var cooldown_overlay = ColorRect.new()
	cooldown_overlay.name = "CooldownOverlay"
	cooldown_overlay.color = Color(0, 0, 0, 0.6)
	cooldown_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	cooldown_overlay.visible = false
	panel.add_child(cooldown_overlay)
	
	var cooldown_label = Label.new()
	cooldown_label.name = "CooldownLabel"
	cooldown_label.set_anchors_preset(Control.PRESET_CENTER)
	cooldown_label.add_theme_font_size_override("font_size", 4)
	cooldown_label.position = Vector2(-7, -15)
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown_overlay.add_child(cooldown_label)

	# Ammo label — só nos slots de loadout
	if is_loadout:
		var ammo_lbl := Label.new()
		ammo_lbl.name = "AmmoLabel"
		ammo_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
		ammo_lbl.position = Vector2(0, -6)
		ammo_lbl.add_theme_font_size_override("font_size", 4)
		ammo_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		ammo_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		ammo_lbl.add_theme_constant_override("outline_size", 1)
		ammo_lbl.visible = false
		panel.add_child(ammo_lbl)

		# LevelPips criado dinamicamente em refresh_all_icons

	panel.modulate = Color(1, 1, 1, 0.4)
	return panel

func _process(_delta: float) -> void:
	_update_cooldown_visuals()
	_update_health_visuals()
	_update_gold_visuals()
	_update_ammo_slots()
	_update_world_ammo_label()
	_update_connector_positions()

func _update_connector_positions() -> void:
	for connector in _connector_nodes:
		if not is_instance_valid(connector): continue
		var lp: Panel = connector.get_meta("left_panel")
		var rp: Panel = connector.get_meta("right_panel")
		if not is_instance_valid(lp) or not is_instance_valid(rp): continue
		var lr := lp.get_global_rect()
		var rr := rp.get_global_rect()
		var gap := rr.position.x - lr.end.x
		connector.size = Vector2(max(gap, 2), 8)
		connector.position = Vector2(lr.end.x, lr.position.y + (lr.size.y - 8) * 0.5)

func _update_ammo_slots() -> void:
	if not _manager: return

	for i in range(slot_panels.size()):
		var panel: Panel = slot_panels[i]
		var ammo_lbl := panel.get_node_or_null("AmmoLabel") as Label
		if not ammo_lbl: continue

		var card_id: String = _manager.unlocked_weapons[i] if i < _manager.unlocked_weapons.size() else ""
		var card_data := CardDB.get_card(card_id) if card_id != "" else null

		if not card_data or card_data.type != "Weapon" or card_data.weapon_archetype == "Melee" or i != _manager.current_weapon_index:
			ammo_lbl.visible = false
			continue

		var weapon := _manager.get_current_weapon()
		if not weapon or not ("current_ammo" in weapon):
			ammo_lbl.visible = false
			continue

		ammo_lbl.visible = true
		ammo_lbl.add_theme_font_size_override("font_size", 4)
		if weapon.is_reloading:
			ammo_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
			ammo_lbl.text = "%.1fs" % weapon.reload_timer
		else:
			var pct: float = float(weapon.current_ammo) / float(max(weapon.max_ammo, 1))
			ammo_lbl.add_theme_color_override("font_color", Color(1.0, pct, pct * 0.3, 1.0))
			ammo_lbl.text = str(weapon.current_ammo) + "/" + str(weapon.max_ammo)

func _update_world_ammo_label() -> void:
	if not _world_ammo_label or not is_instance_valid(_world_ammo_label): return
	if not _manager:
		_world_ammo_label.visible = false
		return

	var weapon := _manager.get_current_weapon()
	var card_data := _manager.current_card_data

	if not weapon or not card_data or card_data.type != "Weapon" \
	   or card_data.weapon_archetype == "Melee" \
	   or not ("current_ammo" in weapon):
		_world_ammo_label.visible = false
		if is_instance_valid(_stance_dot): _stance_dot.visible = false
		return

	# Segue a posição do sprite da arma sem herdar a rotação
	var player = get_parent()
	if player:
		var weapon_sprite = player.weapon_sprite
		if weapon_sprite:
			var local_pos: Vector2 = player.to_local(weapon_sprite.global_position)
			_world_ammo_label.position = local_pos + Vector2(0, -9)
			if is_instance_valid(_stance_dot):
				var visual = player._current_weapon_visual
				if visual and visual.spawn_point:
					_stance_dot.position = player.to_local(visual.spawn_point.global_position) + Vector2(-3, -4)
				else:
					_stance_dot.position = local_pos + Vector2(28, -6)

	# Atualiza indicador de stance
	if is_instance_valid(_stance_dot):
		var needs_stillness: bool = card_data.get("requires_stillness") == true
		_stance_dot.visible = needs_stillness
		if needs_stillness and "requires_stillness" in weapon:
			var timer: float = weapon.get("_stillness_timer") if "_stillness_timer" in weapon else 0.0
			var req: float = weapon.get("stillness_time_required") if "stillness_time_required" in weapon else 1.0
			_stance_dot.set("progress", timer / max(req, 0.001))

	if weapon.is_reloading:
		_world_ammo_label.visible = true
		_world_ammo_label.add_theme_font_size_override("font_size", 3)
		_world_ammo_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		_world_ammo_label.text = "%.1fs" % weapon.reload_timer
	else:
		_world_ammo_label.visible = false

func _update_gold_visuals() -> void:
	if gold_label:
		gold_label.text = str(GameManager.run_coins)

func _update_health_visuals() -> void:
	if not _manager or not _manager.get_parent() or not life_bar: return
	var player = _manager.get_parent()
	if not "current_health" in player: return
	
	life_bar.max_value = player.max_health
	life_bar.value = player.current_health
	
	if life_label:
		life_label.text = str(player.current_health) + " / " + str(player.max_health)
		
	# Atualiza a cor dos slots caso possuam cartas "travadas" (ex: passiva de vida)
	if player.has_method("can_unequip_card"):
		for i in range(slot_panels.size()):
			var panel = slot_panels[i]
			if i >= _manager.unlocked_weapons.size(): continue
			var card_id = _manager.unlocked_weapons[i]
			if card_id != "" and not player.can_unequip_card(card_id, i):
				# Tint vermelho claro para indicar que está trancada
				panel.self_modulate = Color(1, 0.5, 0.5, 1)
			else:
				panel.self_modulate = Color(1, 1, 1, 1)

func _update_cooldown_visuals() -> void:
	if not _manager or not _manager.get_parent(): return
	var player = _manager.get_parent()
	if not "ability_cooldowns" in player: return
	
	var cooldowns = player.ability_cooldowns
	
	# Atualiza apenas os slots do Loadout (1, 2, 3)
	for i in range(slot_panels.size()):
		var panel = slot_panels[i]
		if i >= _manager.unlocked_weapons.size():
			panel.get_node("CooldownOverlay").visible = false
			continue
		var card_id = _manager.unlocked_weapons[i]
		var overlay = panel.get_node("CooldownOverlay")
		var label = overlay.get_node("CooldownLabel")

		if card_id != "" and cooldowns.get(card_id, 0.0) > 0.0:
			overlay.visible = true
			label.text = "%.1f" % cooldowns[card_id]
		else:
			overlay.visible = false

func connect_to_weapon_manager(manager: WeaponManager):
	_manager = manager
	_manager.weapon_equipped.connect(_on_weapon_equipped)
	_manager.weapon_unlocked.connect(_on_weapon_unlocked)
	_manager.loadout_changed.connect(refresh_all_icons)

	refresh_all_icons()

	if _manager.current_weapon_id != "":
		_on_weapon_equipped(_manager.current_weapon_id, _manager.current_weapon_index)

func _draw_level_pips(panel: Panel, level: int, pip_sz: int = 3) -> void:
	# Remove pips antigos imediatamente da árvore (queue_free sozinho não basta — nó fica visível na mesma frame)
	for i in range(3):
		var old := panel.get_node_or_null("_Pip%d" % i)
		if old:
			panel.remove_child(old)
			old.queue_free()

	if level <= 1: return

	var colors := [Color(0.4, 0.7, 1.0), Color(1.0, 0.85, 0.2)]
	var pip_color: Color = colors[clampi(level - 2, 0, 1)]
	var border_color := pip_color.darkened(0.45)
	var gap := pip_sz + 1

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
		pip.offset_right = 1 + pip_sz
		pip.offset_bottom = - (i * gap) - 1
		pip.offset_top = pip.offset_bottom - pip_sz
		panel.add_child(pip)

func _draw_charge_bars(panel: Panel, charges: int, max_charges: int) -> void:
	# Remove todas as barras anteriores independente do max anterior
	for child in panel.get_children():
		if child.name.begins_with("_Charge"):
			panel.remove_child(child)
			child.queue_free()
	if max_charges <= 0: return

	# Barras fixas: 2×2px, 1px de gap — ancoragem PRESET_BOTTOM_RIGHT (imune a size=0)
	for i in range(max_charges):
		var bar := Panel.new()
		bar.name = "_Charge%d" % i
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.55, 0.1, 1.0) if i < charges else Color(0.2, 0.2, 0.2, 1.0)
		bar.add_theme_stylebox_override("panel", style)
		bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		bar.offset_right = -1
		bar.offset_left = bar.offset_right - 2
		bar.offset_bottom = - (i * 3) - 1
		bar.offset_top = bar.offset_bottom - 2
		panel.add_child(bar)

func refresh_all_icons():
	# Popula Loadout
	var player = _manager.get_parent() if _manager else null
	for i in range(slot_panels.size()):
		if i < _manager.unlocked_weapons.size():
			_update_slot_icon(slot_panels[i], _manager.unlocked_weapons[i], i)
		var card_id: String = _manager.unlocked_weapons[i] if i < _manager.unlocked_weapons.size() else ""
		var level: int = GameManager.equipped_card_levels[i] if i < GameManager.equipped_card_levels.size() else 1
		_draw_level_pips(slot_panels[i], level if card_id != "" else 0)
		var card := CardDB.get_card(card_id)
		if card and card.type == "Consumable":
			var ch: int = player.loadout_charges[i] if player and "loadout_charges" in player and i < player.loadout_charges.size() else 0
			_draw_charge_bars(slot_panels[i], ch, card.max_charges)
		else:
			_draw_charge_bars(slot_panels[i], 0, 0)

	# Popula Mochila
	for i in range(backpack_panels.size()):
		_update_slot_icon(backpack_panels[i], GameManager.run_backpack[i])
		var bp_id: String = GameManager.run_backpack[i]
		var bp_level: int = GameManager.run_backpack_levels[i] if i < GameManager.run_backpack_levels.size() else 1
		_draw_level_pips(backpack_panels[i], bp_level if bp_id != "" else 0, 3)
		var bp_card := CardDB.get_card(bp_id)
		if bp_card and bp_card.type == "Consumable":
			var ch: int = GameManager.run_backpack_charges[i] if i < GameManager.run_backpack_charges.size() else 0
			_draw_charge_bars(backpack_panels[i], ch, bp_card.max_charges)
		else:
			_draw_charge_bars(backpack_panels[i], 0, 0)

	_update_stack_visuals()

func _update_slot_icon(panel: Panel, id: String, slot_index: int = -1):
	var icon_rect = panel.get_node_or_null("Icon") as TextureRect
	if not icon_rect: return

	# Limpa badges antes de recriar (remove_child garante remoção imediata da árvore)
	var old_key = panel.get_node_or_null("KeyBadge")
	var old_pass = panel.get_node_or_null("PassiveBadge")
	if old_key: panel.remove_child(old_key); old_key.queue_free()
	if old_pass: panel.remove_child(old_pass); old_pass.queue_free()

	if id == "":
		icon_rect.texture = null
		return

	# Tenta pegar a carta (pode vir como 'card_smg' ou só 'smg')
	var card_data = CardDB.get_card(id)
	if not card_data:
		var card_id = CardDB.get_card_id_from_weapon(id)
		card_data = CardDB.get_card(card_id)

	if card_data and card_data.icon:
		icon_rect.texture = card_data.icon
	else:
		icon_rect.texture = null

	if not card_data: return

	# Badge de tecla para cartas ATIVAS e CONSUMÍVEIS
	var _active_action: String = card_data.activation_input_action
	if _active_action == "" and slot_index in _auto_action_map:
		_active_action = _auto_action_map[slot_index]
	if card_data.type in ["Active", "Consumable"] and _active_action != "":
		var key_text: String = ACTION_LABELS.get(_active_action, "?")
		var badge := Label.new()
		badge.name = "KeyBadge"
		badge.text = key_text
		badge.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		badge.position = Vector2(1, -4)
		badge.add_theme_font_size_override("font_size", 3)
		badge.add_theme_color_override("font_color", Color(1, 0.9, 0, 1))
		panel.add_child(badge)

	# Badge "P" para cartas PASSIVAS
	elif card_data.type == "Passive":
		var badge := Label.new()
		badge.name = "PassiveBadge"
		badge.text = "P"
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.position = Vector2(-4, 2)
		badge.add_theme_font_size_override("font_size", 4)
		badge.add_theme_color_override("font_color", Color(0, 1, 1, 1))
		badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		badge.add_theme_constant_override("outline_size", 1)
		panel.add_child(badge)

func _on_weapon_unlocked(_weapon_id: String) -> void:
	refresh_all_icons()

func _on_weapon_equipped(_weapon_id: String, slot_index: int) -> void:
	_on_weapon_equipped_by_index(slot_index)

func _on_weapon_equipped_by_index(index: int) -> void:
	for panel in slot_panels:
		panel.modulate = Color(1, 1, 1, 0.4)

	if index >= 0 and index < slot_panels.size():
		slot_panels[index].modulate = Color(1, 1, 1, 1.0)
		var tween = create_tween()
		tween.tween_property(slot_panels[index], "scale", Vector2(1.1, 1.1), 0.1)
		tween.tween_property(slot_panels[index], "scale", Vector2(1.0, 1.0), 0.1)

	_update_stack_visuals()

# --- SISTEMA DE DRAG & DROP IN-GAME (Simulado nos Panels) ---
# Em vez de criar scripts separados, vamos injetar o comportamento se possível
# Ou melhor, criar um script herdado para os slots do HUD.
# Mas para o MVP, vamos atualizar os ícones da mochila quando o GameManager mudar.

func update_backpack() -> void:
	while backpack_panels.size() < GameManager.run_backpack.size():
		var panel = _create_slot_panel(backpack_panels.size(), Color(0.15, 0.2, 0.3, 1), false)
		container.add_child(panel)
		backpack_panels.append(panel)
	refresh_all_icons()

var is_backpack_active: bool = false

var _auto_action_map: Dictionary = {}

func set_auto_action_map(map: Dictionary) -> void:
	_auto_action_map = map
	refresh_all_icons()

func set_flashlight_active(active: bool) -> void:
	_flashlight_panel.modulate = Color.WHITE if active else Color(0.4, 0.4, 0.4, 1.0)

func set_backpack_mode(active: bool):
	is_backpack_active = active
	var tween = create_tween().set_parallel(true)
	
	# Se estiver ativando, destaca TUDO para edição
	if active:
		for p in slot_panels:
			tween.tween_property(p, "modulate:a", 1.0, 0.2)
		for p in backpack_panels:
			tween.tween_property(p, "modulate:a", 1.0, 0.2)
		tween.tween_property(container, "scale", Vector2(1.05, 1.05), 0.2)
	else:
		# Se estiver desativando, restaura o destaque apenas da arma ATUAL
		var current_idx = -1
		if _manager:
			current_idx = _manager.current_weapon_index
			
		for i in range(slot_panels.size()):
			var target_a = 1.0 if i == current_idx else 0.4
			tween.tween_property(slot_panels[i], "modulate:a", target_a, 0.2)
			
		# Mochila volta a ficar apagada (0.4)
		for p in backpack_panels:
			tween.tween_property(p, "modulate:a", 0.4, 0.2)
			
		tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.2)

func _convert_to_weapon_id(id: String) -> String:
	return CardDB.get_weapon_id(id)


# =========================
# SISTEMA DE STACKING VISUAL
# =========================

func _update_stack_visuals() -> void:
	if not _manager: return

	# Para todos os tweens de pulso anteriores
	for t in _stack_tweens:
		if t and is_instance_valid(t):
			t.kill()
	_stack_tweens.clear()

	# Remove nós visuais antigos (conectores e badges)
	for node in _stack_overlays:
		if node and is_instance_valid(node):
			node.queue_free()
	_stack_overlays.clear()
	_connector_nodes.clear()

	# Conta quantas vezes cada card_id aparece no loadout
	var counts: Dictionary = {}
	for i in range(slot_panels.size()):
		var id = _manager.unlocked_weapons[i] if i < _manager.unlocked_weapons.size() else ""
		if id == "": continue
		if not counts.has(id):
			counts[id] = []
		counts[id].append(i)

	# Estilo base (sem stack) — restaura todos os slots primeiro
	var default_color := Color(0.2, 0.2, 0.2, 1)
	var default_border := Color(0.3, 0.3, 0.3, 1)
	for i in range(slot_panels.size()):
		var panel: Panel = slot_panels[i]
		var style = StyleBoxFlat.new()
		style.bg_color = default_color
		panel.add_theme_stylebox_override("panel", style)
		panel.call("set_border_color", default_border)
		# Reseta cor do pulso (RGB) sem tocar no alpha de ativo/inativo
		panel.modulate = Color(1.0, 1.0, 1.0, panel.modulate.a)
		# Remove badge antigo se existir
		var old_badge = panel.get_node_or_null("StackBadge")
		if old_badge:
			old_badge.queue_free()

	# Aplica visual para cada grupo com stack >= 2
	for card_id in counts:
		var indices: Array = counts[card_id]
		if indices.size() < 2: continue

		var level := indices.size()
		var stack_color := Color(0.65, 0.55, 0.2, 0.85) if level == 2 else Color(0.55, 0.15, 0.55, 0.85)

		for idx in indices:
			var panel: Panel = slot_panels[idx]

			panel.call("set_border_color", stack_color)

			var is_active: bool = (_manager.current_weapon_index == idx)
			if not is_active:
				var pulse_max: float = 0.7 if level == 2 else 1.0
				panel.modulate = Color(1.0, 1.0, 1.0, pulse_max * 0.7)
				var tween := create_tween().set_loops()
				tween.tween_property(panel, "modulate:a", pulse_max, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
				tween.tween_property(panel, "modulate:a", 0.45, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
				_stack_tweens.append(tween)

			
