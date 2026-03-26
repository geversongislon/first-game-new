extends Node2D
class_name WeaponVisual

## Nó raiz de cada cena visual de arma.
## Contém sprite + luzes + ponto de spawn posicionados visualmente no editor.
## Filhos esperados: Sprite, MuzzleLight, AmbientLight, SpawnPoint
## Armas melee podem ter um filho Hitbox (Area2D) posicionado na lâmina.

## Desloca o HandPivot (eixo de rotação) quando esta arma está equipada.
## Y negativo = mais acima (ex: sniper perto dos olhos = -4)
## Y positivo = mais abaixo (ex: shotgun na cintura = +4)
## X positivo = mais à frente no corpo / X negativo = mais atrás
@export var pivot_offset: Vector2 = Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var muzzle_light: PointLight2D = $MuzzleLight
@onready var ambient_light: PointLight2D = $AmbientLight
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var hitbox: Area2D = get_node_or_null("Hitbox")

func _ready() -> void:
	if hitbox:
		hitbox.collision_mask = 2  # layer dos inimigos
		hitbox.monitoring = true

## Chamado pelo player a cada frame de rotação da arma.
## Flipa sprite e luzes conforme a direção do mouse.
func set_facing(is_looking_left: bool) -> void:
	if sprite:
		sprite.flip_v = is_looking_left
		var off := sprite.offset
		sprite.offset = Vector2(abs(off.x), abs(off.y) if is_looking_left else -abs(off.y))
	if muzzle_light:
		muzzle_light.position.y = abs(muzzle_light.position.y) if is_looking_left else -abs(muzzle_light.position.y)
	if ambient_light:
		ambient_light.position.y = abs(ambient_light.position.y) if is_looking_left else -abs(ambient_light.position.y)
	if spawn_point:
		spawn_point.position.y = abs(spawn_point.position.y) if is_looking_left else -abs(spawn_point.position.y)
