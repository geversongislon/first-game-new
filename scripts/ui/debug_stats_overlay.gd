extends CanvasLayer
class_name DebugStatsOverlay

## Overlay de debug: mostra stats do player e cartas equipadas.
## Toggle com F3. Visível apenas durante a run.

const UPDATE_INTERVAL: float = 0.1

var _player: Node = null
var _panel: PanelContainer = null
var _label: RichTextLabel = null
var _hint: Label = null
var _timer: float = 0.0
var _visible: bool = false

func _ready() -> void:
	layer = 10
	_build_ui()
	_build_hint()
	_find_player()

func _build_ui() -> void:
	_panel = PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.82)
	style.border_color = Color(0.25, 0.55, 1.0, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left   = 3
	style.content_margin_right  = 3
	style.content_margin_top    = 2
	style.content_margin_bottom = 2
	_panel.add_theme_stylebox_override("panel", style)

	_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_panel.position = Vector2(3, -3)
	_panel.grow_vertical   = Control.GROW_DIRECTION_BEGIN
	_panel.grow_horizontal = Control.GROW_DIRECTION_END
	_panel.custom_minimum_size = Vector2(55, 0)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.custom_minimum_size = Vector2(52, 0)
	_label.add_theme_font_size_override("normal_font_size", 3)
	_label.add_theme_font_size_override("bold_font_size", 3)
	_label.scroll_active = false

	_panel.add_child(_label)
	add_child(_panel)

func _build_hint() -> void:
	_hint = Label.new()
	_hint.text = "[F3]"
	_hint.add_theme_font_size_override("font_size", 3)
	_hint.modulate = Color(0.35, 0.55, 1.0, 0.5)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.position = Vector2(3, -3)
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_hint)
	_panel.visible = false

func _find_player() -> void:
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]
		# Atualiza imediatamente quando o loadout muda (troca de carta, equip, etc.)
		var mgr: WeaponManager = _player.get_node_or_null("WeaponManager")
		if mgr and not mgr.loadout_changed.is_connected(_refresh):
			mgr.loadout_changed.connect(_refresh)
		if mgr and not mgr.weapon_equipped.is_connected(_on_weapon_equipped):
			mgr.weapon_equipped.connect(_on_weapon_equipped)

func _on_weapon_equipped(_id: String, _slot: int) -> void:
	_refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		_visible = !_visible
		_panel.visible = _visible
		_hint.visible = !_visible

func _process(delta: float) -> void:
	if not _visible: return
	if not is_instance_valid(_player):
		_find_player()
		return
	_timer -= delta
	if _timer > 0.0: return
	_timer = UPDATE_INTERVAL
	_refresh()

func _refresh() -> void:
	var p := _player
	var mgr: WeaponManager = p.get_node_or_null("WeaponManager")

	var t := ""

	# ── PLAYER ──────────────────────────────────────────────
	t += "[b][color=#5599ff]▸ PLAYER[/color][/b]\n"
	t += _row("HP",     "%d / %d" % [p.current_health, p.max_health], _hp_color(p.current_health, p.max_health))
	t += _row("Speed",  "%.0f" % p.current_max_speed,  "#aaddff")
	t += _row("Jumps",  "%d / %d" % [p.jumps_left, p.max_jumps], "#aaddff")
	t += _row("Grav",   "%.0f" % p.gravity, "#778899")
	t += "\n"

	if not mgr: _label.text = t; return

	# ── ARMA EQUIPADA ───────────────────────────────────────
	var w := mgr.get_current_weapon()
	if w:
		var cd: CardData = w.card_data
		var archetype: String = cd.weapon_archetype if cd else "?"
		var cur_idx := mgr.current_weapon_index
		var upg_lvl := GameManager.equipped_card_levels[cur_idx] if cur_idx >= 0 and cur_idx < GameManager.equipped_card_levels.size() else 1
		var stk_lvl := mgr.get_stack_level(mgr.current_weapon_id) if mgr.current_weapon_id != "" else 1
		var lvl_str: String = ["", "^", "^^", "^^^"][clampi(upg_lvl, 0, 3)]
		var stk_str := (" ×%d" % stk_lvl) if stk_lvl > 1 else ""
		t += "[b][color=#ffcc44]▸ ARMA  [color=#666688](%s · %s)[/color]  [color=#88bbff]%s[/color][color=#ffcc44]%s[/color][/color][/b]\n" % [
			cd.display_name if cd else "?", archetype, lvl_str, stk_str
		]

		# Ammo + Reload (todos exceto Melee)
		if "current_ammo" in w:
			t += _row("Ammo",   "%d / %d" % [w.current_ammo, w.max_ammo], _ammo_color(w.current_ammo, w.max_ammo))
		if "reload_time" in w:
			var reload_str := ("%.1fs [color=#ff8800]⟳[/color]" % w.reload_timer) if w.is_reloading else ("%.1fs" % w.reload_time)
			t += _row("Reload", reload_str, "#aaaaaa")
		if "fire_rate" in w:
			t += _row("Rate",   "%.1f/s" % w.fire_rate, "#aaddff")

		match archetype:
			"Projectile":
				if "bullet_damage"    in w: t += _row("DMG",    str(w.bullet_damage),         "#ff6666")
				if "bullet_knockback" in w: t += _row("KB",     "%.0f" % w.bullet_knockback,  "#ffaa55")
				if "bullet_speed"     in w: t += _row("Speed",  "%.0f" % w.bullet_speed,      "#88ccff")
			"Charge":
				if "min_damage"           in w: t += _row("DMG",   "%d–%d" % [w.min_damage, w.max_damage],                      "#ff6666")
				if "min_knockback"        in w: t += _row("KB",    "%.0f–%.0f" % [w.min_knockback, w.max_knockback],             "#ffaa55")
				if "min_projectile_speed" in w: t += _row("Speed", "%.0f–%.0f" % [w.min_projectile_speed, w.max_projectile_speed], "#88ccff")
				if "max_charge"           in w: t += _row("Charge","%.1fs" % w.max_charge,                                      "#cc88ff")
				if "is_charging"          in w and w.is_charging:
					t += _row("↑Pwr",  "%.0f%%" % (w.charge_time / w.max_charge * 100.0), "#ffee88")
			"Throwable":
				if "min_throw_speed" in w: t += _row("Speed", "%.0f–%.0f" % [w.min_throw_speed, w.max_throw_speed], "#88ccff")
				if "max_charge"      in w: t += _row("Charge","%.1fs" % w.max_charge,                               "#cc88ff")
				if "is_charging"     in w and w.is_charging:
					t += _row("↑Pwr", "%.0f%%" % (w.charge_time / w.max_charge * 100.0), "#ffee88")
			"Melee":
				if "_damage"    in w: t += _row("DMG",   str(w._damage),          "#ff6666")
				if "_knockback" in w: t += _row("KB",    "%.0f" % w._knockback,   "#ffaa55")
				if "_hit_stun"  in w: t += _row("Stun",  "%.2fs" % w._hit_stun,   "#88ffcc")
		var _poder: float = 0.0
		if w is ProjectileWeapon:
			var _eff   : float = float(w.bullet_damage) * (1.0 + float(w.crit_chance) * (float(w.crit_multiplier) - 1.0))
			var _cycle : float = float(w.max_ammo) / float(w.fire_rate) + float(w.reload_time)
			_poder = _eff * float(w.max_ammo) / _cycle
		elif w is ChargeWeapon:
			var _avg   : float = lerp(float(w.min_damage), float(w.max_damage), 0.75)
			var _eff   : float = _avg * (1.0 + float(w.crit_chance) * (float(w.crit_multiplier) - 1.0))
			var _cycle : float = float(w.max_ammo) * (float(w.max_charge) * 0.75) + float(w.reload_time)
			_poder = _eff * float(w.max_ammo) / _cycle
		elif w is ThrowableWeapon:
			if w.card_data:
				var _dmg   : float = float(w.card_data.charge_damage_range.x)
				var _cycle : float = float(w.max_ammo) * (float(w.max_charge) * 0.5) + float(w.reload_time)
				_poder = _dmg * float(w.max_ammo) / _cycle
		if _poder > 0.0:
			t += _row("Poder", "%.1f" % _poder, "#ffcc44")
		t += "\n"

	# ── LOADOUT COMPLETO ─────────────────────────────────────
	t += "[b][color=#88ff99]▸ LOADOUT[/color][/b]\n"
	for i in mgr.unlocked_weapons.size():
		var cid: String = mgr.unlocked_weapons[i]
		var active_marker: String = "[color=#ffcc44]►[/color] " if i == mgr.current_weapon_index else "  "
		if cid == "":
			t += "%s[color=#334455]— empty —[/color]\n" % active_marker
			continue
		var card: CardData = CardDB.get_card(cid)
		if not card:
			t += "%s[color=#334455]— ? —[/color]\n" % active_marker
			continue
		var rarity_color: String = _rarity_color(card.rarity)
		var type_color: String = match_type_color(card.type)
		t += "%s[color=%s]%s[/color]  [color=%s]%s[/color]\n" % [
			active_marker, rarity_color, card.display_name, type_color, card.type
		]

	t += "\n[color=#334455][F3] toggle[/color]"
	_label.text = t

# ── Helpers ─────────────────────────────────────────────────

func _row(label: String, value: String, color: String) -> String:
	return "  [color=#556677]%-7s[/color] [color=%s]%s[/color]\n" % [label, color, value]

func _hp_color(cur: int, mx: int) -> String:
	var pct := float(cur) / float(max(mx, 1))
	if pct > 0.6: return "#44ff88"
	if pct > 0.3: return "#ffcc44"
	return "#ff4444"

func _ammo_color(cur: int, mx: int) -> String:
	var pct := float(cur) / float(max(mx, 1))
	if pct > 0.5: return "#ffffff"
	if pct > 0.2: return "#ffaa44"
	return "#ff4444"

func match_type_color(type: String) -> String:
	match type:
		"Weapon":     return "#ffcc44"
		"Passive":    return "#aa77dd"
		"Active":     return "#dd9944"
		"Consumable": return "#44aacc"
	return "#778899"

func _rarity_color(rarity: String) -> String:
	match rarity:
		"Common":    return "#aaaaaa"
		"Uncommon":  return "#44dd66"
		"Rare":      return "#4488ff"
		"Epic":      return "#cc44ff"
		"Legendary": return "#ffaa00"
	return "#ffffff"
