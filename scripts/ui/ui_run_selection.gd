extends Control

## Tela de seleção do ponto de entrada da run.
## Pontos disponíveis vêm de GameManager.unlocked_extraction_points (dict id → nome).

@onready var points_container: VBoxContainer = $MarginContainer/VBox/PointsContainer
@onready var back_button: Button             = $MarginContainer/VBox/BackButton


func _ready() -> void:
	_build_point_buttons()
	back_button.pressed.connect(_on_back_pressed)


func _build_point_buttons() -> void:
	var run_lbl := Label.new()
	run_lbl.text = "Run #%d" % (GameManager.runs_started + 1)
	run_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points_container.add_child(run_lbl)

	for point_id in GameManager.unlocked_extraction_points:
		var display_name: String = GameManager.unlocked_extraction_points[point_id]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 15)
		btn.text = "▶  " + display_name
		btn.pressed.connect(_on_point_selected.bind(point_id))
		points_container.add_child(btn)


func _on_point_selected(point_id: String) -> void:
	GameManager.current_run_start_point = point_id
	SceneManager.go_to("res://scenes/run/run.tscn")


func _on_back_pressed() -> void:
	SceneManager.go_to("res://scenes/ui/ui_main_menu.tscn")
