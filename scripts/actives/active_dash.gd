extends BaseActiveAbility
## Habilidade Ativa: Dash
##
## Stack x1 — Dash rápido na direção do movimento (ou para frente se parado)
## Stack x2 — Dash mais longo (boost_speed)
## Stack x3 — Dash + invulnerabilidade durante a duração
##
## Configuração no Inspector da cena:
##   base_speed              → velocidade do dash x1
##   boost_speed             → velocidade do dash x2+
##   invulnerability_duration → tempo de invulnerabilidade no x3


## Velocidade do dash no stack x1.
@export var base_speed: float = 1050.0

## Velocidade do dash no stack x2 e acima.
@export var boost_speed: float = 2000.0

## Duração da invulnerabilidade no stack x3 (segundos).
@export var invulnerability_duration: float = 0.3


func execute() -> void:
	var dash_speed := boost_speed if stack_level >= 2 else base_speed

	# Direção: sempre segue para onde o sprite está virado
	var move_dir: float = -1.0 if player.sprite.flip_h else 1.0

	player.velocity.x = move_dir * dash_speed
	player.sprite.play("dash")

	if stack_level >= 3:
		player.is_invulnerable = true
		player.flash_white()

		# Blink: alterna transparência rapidamente para sinalizar invulnerabilidade
		var tween := player.create_tween().set_loops()
		tween.tween_property(player, "modulate:a", 0.15, 0.07)
		tween.tween_property(player, "modulate:a", 1.0,  0.07)

		# Captura referência local antes de queue_free() para que a lambda
		# não dependa de 'self' (que será liberado antes do timer disparar)
		var p := player
		get_tree().create_timer(invulnerability_duration).timeout.connect(
			func() -> void:
				p.is_invulnerable = false
				tween.kill()
				p.modulate.a = 1.0
		)

	queue_free()
