extends BaseActiveAbility
## Efeito consumível: Kit Médico
## Restaura vida imediatamente ao ser usado.
## O efeito visual fica no lugar — não segue o player.

func configure() -> void:
	follow_player = true
	spawn_offset = Vector2(0, -24)

func execute() -> void:
	if player and player.has_method("heal"):
		player.heal(15)
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		sprite.play("life")
		sprite.animation_finished.connect(queue_free, CONNECT_ONE_SHOT)
	else:
		queue_free()
