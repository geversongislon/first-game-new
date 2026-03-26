extends Node2D

func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	$Label.material = mat
	$Label.text = ""

func setup(value: int, color: Color = Color.WHITE, is_crit: bool = false):
	var label: Label = $Label
	if is_crit:
		label.text = str(value) + "!"
		label.add_theme_font_size_override("font_size", 7)
		label.modulate = color
	else:
		label.text = str(value)
		label.add_theme_font_size_override("font_size", 5)
		label.modulate = color

	var rise := 14.0 if is_crit else 10.0
	var dur  := 0.8  if is_crit else 0.6

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - rise, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, dur).set_delay(dur * 0.35)
	tween.chain().tween_callback(queue_free)
