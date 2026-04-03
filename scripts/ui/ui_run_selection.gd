extends Control

## Tela de seleção do ponto de entrada da run.
## Pontos disponíveis vêm de GameManager.unlocked_extraction_points (dict id → nome).

@onready var points_container: VBoxContainer = $MarginContainer/VBox/ScrollContainer/PointsContainer
@onready var back_button: Button             = $MarginContainer/VBox/BackButton


func _ready() -> void:
	_build_point_buttons()
	back_button.pressed.connect(_on_back_pressed)
	# Botão voltar sempre com tom cinza, opaco mas saturado (saturação 0, então só luminance importa)
	_style_button(back_button, Color.from_hsv(0.0, 0.0, 0.35))
	back_button.add_theme_font_size_override("font_size", 8)
	back_button.custom_minimum_size = Vector2(0, 20)


func _build_point_buttons() -> void:
	var run_lbl := Label.new()
	run_lbl.text = "Run #%d" % (GameManager.runs_started + 1)
	run_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	run_lbl.add_theme_font_size_override("font_size", 8)
	points_container.add_child(run_lbl)

	var num_points := GameManager.unlocked_extraction_points.size()
	var current_index := 0

	var sorted_ids := GameManager.unlocked_extraction_points.keys()
	sorted_ids.sort()

	for point_id in sorted_ids:
		var display_name: String = GameManager.unlocked_extraction_points[point_id]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 16)
		btn.text = "▶  " + display_name.to_upper()
		btn.add_theme_font_size_override("font_size", 8)
		btn.pressed.connect(_on_point_selected.bind(point_id))
		
		var t := 0.0
		if num_points > 1:
			t = float(current_index) / float(num_points - 1)
		
		# Hue map: 0.33 (Verde) -> 0.0 (Vermelho).
		var hue := lerpf(0.33, 0.0, t)
		# Cor opaca e menos saturada (Saturação 0.45, Value 0.6)
		var btn_color := Color.from_hsv(hue, 0.45, 0.6)
		
		_style_button(btn, btn_color)
		
		points_container.add_child(btn)
		current_index += 1


func _style_button(btn: Button, base_color: Color) -> void:
	for state in [["normal", base_color], ["hover", base_color.lightened(0.15)], ["pressed", base_color.darkened(0.15)]]:
		var sty := StyleBoxFlat.new()
		sty.bg_color = state[1]
		btn.add_theme_stylebox_override(state[0], sty)


func _on_point_selected(point_id: String) -> void:
	GameManager.current_run_start_point = point_id
	SceneManager.go_to("res://scenes/run/run.tscn")


func _on_back_pressed() -> void:
	SceneManager.go_to("res://scenes/ui/ui_main_menu.tscn")
