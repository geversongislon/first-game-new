extends StaticBody2D

var _broken: bool = false


func _on_hit_detector_area_entered(area: Area2D) -> void:
	_hit()

func take_damage(_amount: int = 0, _dir: Vector2 = Vector2.ZERO, _kb: float = 0.0) -> void:
	print("[LightPost] take_damage chamado")
	_hit()

func _hit() -> void:
	if _broken:
		return
	_broken = true

	# Apaga a luz primeiro
	var light := get_node_or_null("PointLight2D")
	if light:
		light.enabled = false

	# Faísca: origem no centro da collision da lampada
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	var spark_origin: Vector2 = col.position if col else (light.position if light else Vector2.ZERO)
	var spark_mat := CanvasItemMaterial.new()
	spark_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for i in range(14):
		var spark := ColorRect.new()
		spark.size = Vector2(2, 2)
		spark.color = Color(1.0, randf_range(0.0, 0.7), 0.0, 1.0)
		spark.position = spark_origin
		spark.material = spark_mat
		add_child(spark)
		var angle := randf_range(deg_to_rad(20), deg_to_rad(160))
		var dist := randf_range(8.0, 20.0)
		var fall := randf_range(18.0, 38.0)
		var target := spark_origin + Vector2(cos(angle) * dist, sin(angle) * dist + fall)
		var duration := randf_range(1.2, 2.0)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(spark, "position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(spark, "modulate:a", 0.0, duration * 1.2)
		tw.finished.connect(spark.queue_free)
