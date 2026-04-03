extends TileMapLayer

@export_range(0.0, 1.0, 0.01, "suffix:%") var flicker_chance: float = 0.15
@export var flicker_interval_min: float = 2.0   # segundos entre episódios
@export var flicker_interval_max: float = 8.0
@export var flicker_pulses_min: int    = 2      # pulsadas rápidas por episódio
@export var flicker_pulses_max: int    = 6

func _ready() -> void:
	await get_tree().process_frame  # aguarda scene tiles instanciarem
	var lights: Array[PointLight2D] = []
	_collect_lights(self, lights)
	for light in lights:
		if randf() < flicker_chance:
			var parent := light.get_parent()
			if parent and "is_flickering" in parent:
				parent.is_flickering = true
			_schedule_flicker(light)

func _collect_lights(node: Node, result: Array[PointLight2D]) -> void:
	for child in node.get_children():
		if child is PointLight2D:
			result.append(child)
		elif child.get_child_count() > 0:
			_collect_lights(child, result)

func _schedule_flicker(light: PointLight2D) -> void:
	await get_tree().create_timer(randf_range(flicker_interval_min, flicker_interval_max)).timeout
	if not is_instance_valid(light): return
	await _do_flicker(light)
	_schedule_flicker(light)  # loop contínuo com intervalo aleatório

func _do_flicker(light: PointLight2D) -> void:
	var base := light.energy
	for i in randi_range(flicker_pulses_min, flicker_pulses_max):
		light.energy = 0.0
		await get_tree().create_timer(randf_range(0.03, 0.12)).timeout
		if not is_instance_valid(light): return
		light.energy = base
		await get_tree().create_timer(randf_range(0.02, 0.08)).timeout
		if not is_instance_valid(light): return
