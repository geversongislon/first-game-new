extends Control

## Tela de seleção do ponto de entrada da run.
## Dots clicáveis representam pontos de extração. Clicar seleciona e habilita o botão de entrada.

var _card_selected_point: Array[String] = ["", "", ""]

const AREAS := [
	{
		"name": "ÁREA 01",
		"color": Color(0.408, 0.68, 0.413, 1.0),
		"points": [
			{"id": "ext_0", "name": "ENTRADA"},
			{"id": "ext_1", "name": "ZONA 01"},
			{"id": "ext_2", "name": "ZONA 02"},
			{"id": "ext_3", "name": "ZONA 03"},
			{"id": "ext_4", "name": "ZONA 04"},
		],
		"has_boss": false,
	},
	{
		"name": "ÁREA 02",
		"color": Color(0.168, 0.346, 0.73, 1.0),
		"points": [],
		"has_boss": true,
	},
	{
		"name": "ÁREA 03",
		"color": Color(0.76, 0.292, 0.258, 1.0),
		"points": [],
		"has_boss": true,
	},
]


func _ready() -> void:
	_setup_cards()
	%BackButton.pressed.connect(_on_back_pressed)
	_style_button(%BackButton, Color(0.22, 0.22, 0.22))
	%BackButton.add_theme_font_size_override("font_size", 7)


func _setup_cards() -> void:
	for i in AREAS.size():
		var area_data: Dictionary = AREAS[i]
		var card := get_node("%%AreaCard_%d" % i) as Panel
		if not card:
			continue

		var title_lbl  := card.find_child("AreaTitle") as Label
		var dots_grid  := card.find_child("DotsGrid") as GridContainer
		var boss_row   := card.find_child("BossRow") as HBoxContainer
		var sel_label  := card.find_child("SelectedPointLabel") as Label
		var enter_btn  := card.find_child("EnterButton") as Button
		var overlay    := card.find_child("LockOverlay_%d" % i) as ColorRect
		var unlocked   := _is_area_unlocked(i)

		# Borda colorida ou cinza
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.07, 0.07, 0.07)
		style.border_color = area_data.color if unlocked else Color(0.22, 0.22, 0.22)
		style.set_border_width_all(1)
		card.add_theme_stylebox_override("panel", style)

		# Título
		if title_lbl:
			title_lbl.text = area_data.name
			title_lbl.add_theme_color_override("font_color",
				area_data.color if unlocked else Color(0.35, 0.35, 0.35))

		# Boss row
		if boss_row:
			boss_row.visible = area_data.has_boss and unlocked

		# Estado inicial do botão de entrada
		if sel_label:
			sel_label.text = "—"
			sel_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
		if enter_btn:
			enter_btn.disabled = true
			enter_btn.custom_minimum_size = Vector2(0, 14)
			enter_btn.add_theme_font_size_override("font_size", 6)
			_style_button(enter_btn, area_data.color.darkened(0.5))
			enter_btn.pressed.connect(_enter_area.bind(i))

		# Overlay de bloqueio
		if overlay:
			overlay.visible = not unlocked

		if not unlocked or not dots_grid:
			continue

		# Dots com números
		var pt_index := 0
		for pt in area_data.points:
			var pt_unlocked := GameManager.is_unlocked(pt.id)
			var dot := Button.new()
			dot.custom_minimum_size = Vector2(16, 16)
			dot.text = str(pt_index + 1)
			dot.add_theme_font_size_override("font_size", 6)
			dot.disabled = not pt_unlocked
			dot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if pt_unlocked else Control.CURSOR_ARROW
			dot.set_meta("pt_id", pt.id)
			_style_dot(dot, area_data.color, pt_unlocked, false)

			if pt_unlocked:
				var cap_id   : String = pt.id
				var cap_name : String = pt.name
				var cap_color : Color = area_data.color
				dot.pressed.connect(func():
					_card_selected_point[i] = cap_id
					if sel_label:
						sel_label.text = cap_name
						sel_label.add_theme_color_override("font_color", cap_color)
					if enter_btn:
						enter_btn.disabled = false
					_update_dots_style(i, dots_grid, cap_color)
				)

			dots_grid.add_child(dot)
			pt_index += 1


func _update_dots_style(card_index: int, dots_grid: GridContainer, area_color: Color) -> void:
	for dot in dots_grid.get_children():
		if dot is Button and dot.has_meta("pt_id"):
			var pt_id = dot.get_meta("pt_id")
			var is_selected = (_card_selected_point[card_index] == pt_id)
			_style_dot(dot, area_color, GameManager.is_unlocked(pt_id), is_selected)


func _style_dot(btn: Button, area_color: Color, pt_unlocked: bool, is_selected: bool = false) -> void:
	var c_norm = area_color.lightened(0.25) if is_selected else area_color.darkened(0.58)
	var c_hov  = area_color.lightened(0.4) if is_selected else area_color.darkened(0.35)
	var c_pres = area_color.lightened(0.5) if is_selected else area_color.darkened(0.15)
	var c_foc  = area_color.lightened(0.2) if is_selected else area_color.darkened(0.55)

	var states := {
		"normal":   c_norm if pt_unlocked else Color(0.06, 0.06, 0.06),
		"hover":    c_hov if pt_unlocked else Color(0.06, 0.06, 0.06),
		"pressed":  c_pres if pt_unlocked else Color(0.06, 0.06, 0.06),
		"disabled": Color(0.06, 0.06, 0.06),
		"focus":    c_foc if pt_unlocked else Color(0.06, 0.06, 0.06),
	}
	var border := area_color.lightened(0.5) if (pt_unlocked and is_selected) else (area_color if pt_unlocked else Color(0.18, 0.18, 0.18))
	var border_disabled := Color(0.14, 0.14, 0.14)
	for state in states:
		var sty := StyleBoxFlat.new()
		sty.bg_color = states[state]
		sty.border_color = border_disabled if state == "disabled" else border
		sty.set_border_width_all(1)
		btn.add_theme_stylebox_override(state, sty)


func _enter_area(card_index: int) -> void:
	var pt_id := _card_selected_point[card_index]
	if pt_id != "":
		_on_point_selected(pt_id)


func _is_area_unlocked(area_index: int) -> bool:
	for pt in AREAS[area_index].points:
		if GameManager.is_unlocked(pt.id):
			return true
	return false


func _style_button(btn: Button, base_color: Color) -> void:
	for sd in [["normal", base_color], ["hover", base_color.lightened(0.18)], ["pressed", base_color.darkened(0.15)]]:
		var sty := StyleBoxFlat.new()
		sty.bg_color = sd[1]
		btn.add_theme_stylebox_override(sd[0], sty)


func _on_point_selected(point_id: String) -> void:
	GameManager.current_run_start_point = point_id
	SceneManager.go_to("res://scenes/run/run.tscn")


func _on_back_pressed() -> void:
	SceneManager.go_to("res://scenes/ui/ui_main_menu.tscn")
