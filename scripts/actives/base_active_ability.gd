extends Node
class_name BaseActiveAbility
## Classe base para todas as habilidades ativas do jogo.
##
## Fluxo de vida:
##   1. Player instancia a cena via card_data.active_scene.instantiate()
##   2. Player injeta: player, card_data, stack_level
##   3. Player chama add_child(ability) e em seguida ability.execute()
##   4. A habilidade se auto-destrói com queue_free() ao terminar
##
## Para criar uma nova habilidade ativa:
##   1. Crie o script em scripts/actives/ extendendo BaseActiveAbility
##   2. Override execute() com a lógica da habilidade
##   3. Crie a cena em scenes/actives/ com Node raiz + script anexado
##   4. No CardData da carta, aponte active_scene para essa cena


## Referência ao CharacterBody2D do player.
## Injetada automaticamente pelo player antes de execute().
var player: CharacterBody2D = null

## Dados da carta que originou esta habilidade (para ler stats se necessário).
var card_data: CardData = null

## Quantas vezes esta carta está equipada no loadout (1, 2 ou 3).
## Usado para aplicar efeitos de stacking.
var stack_level: int = 1

## Se false, o nó é adicionado como filho do pai do player (fica no lugar).
## Se true (padrão), fica como filho do player e acompanha o movimento.
var follow_player: bool = true

## Offset aplicado à posição inicial quando follow_player = false.
var spawn_offset: Vector2 = Vector2.ZERO


## Chamado antes de add_child() — override para ajustar follow_player e spawn_offset.
func configure() -> void:
	pass

## Executa a habilidade. Override obrigatório nos filhos.
## Ao terminar, chame queue_free() para liberar o nó.
func execute() -> void:
	queue_free()
