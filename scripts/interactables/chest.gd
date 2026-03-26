extends Node2D
class_name Chest

@export var coins_min: int = 5
@export var coins_max: int = 15
@export var health_chance: float = 0.5
@export var card_chance: float = 0.3
@export var opened: bool = false

@onready var coin_scene: PackedScene = preload("res://scenes/loot/pickup_coin.tscn")
@onready var health_scene: PackedScene = preload("res://scenes/loot/pickup_health.tscn")
@onready var card_scene: PackedScene = preload("res://scenes/loot/pickup_card.tscn")
@onready var interact_area: Area2D = $InteractArea
@onready var sprite: Sprite2D = $Sprite2D
@onready var interact_label: Label = $InteractLabel
@onready var point_light: PointLight2D = $PointLight2D

var _player_nearby: Node2D = null

func _ready() -> void:
	if not interact_area.body_entered.is_connected(_on_body_entered):
		interact_area.body_entered.connect(_on_body_entered)
	if not interact_area.body_exited.is_connected(_on_body_exited):
		interact_area.body_exited.connect(_on_body_exited)
	interact_label.visible = false

func _process(_delta: float) -> void:
	if _player_nearby and not opened and Input.is_key_pressed(KEY_E):
		open()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		_player_nearby = body
		if not opened:
			interact_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body == _player_nearby:
		_player_nearby = null
		interact_label.visible = false

func open() -> void:
	if opened: return
	opened = true
	interact_label.visible = false
	sprite.modulate = Color(0.5, 0.5, 0.5, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(point_light, "energy", 0.0, 5.0)
	_spawn_loot()

func _spawn_loot() -> void:
	var coins = randi_range(coins_min, coins_max)
	for _i in coins:
		_spawn_item(coin_scene)
	if randf() < health_chance:
		_spawn_item(health_scene)
	if randf() < card_chance:
		_spawn_item(card_scene)

func _spawn_item(scene: PackedScene) -> void:
	if not scene: return
	var item = scene.instantiate()
	item.global_position = global_position + Vector2(0.0, -65.0)
	get_parent().add_child(item)
	if "velocity" in item:
		item.velocity = Vector2(randf_range(-55.0, 55.0), randf_range(-120.0, -80.0))
