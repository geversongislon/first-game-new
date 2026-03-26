extends Node
class_name BaseWeapon

@export var is_automatic: bool = false

## Incrementos de upgrade por nível (índice 0=lvl1, 1=lvl2, 2=lvl3)
## Altere aqui — o popup de detalhes lê automaticamente esses valores
const UPGRADE_RATE_INC := [0.0, 0.15, 0.30]
const UPGRADE_AMMO_INC := [0.0, 0.15, 0.30]
const UPGRADE_RELOAD_INC := [0.0, -0.10, -0.20]
const UPGRADE_CRIT_INC := [0.0, 0.05, 0.10] # incremento absoluto na chance de crítico


# Atributos padronizados de munição e tempo
@export var max_ammo: int = 30
@export var reload_time: float = 1.5
@export var fire_rate: float = 5.0 # tiros por segundo

var current_ammo: int
var is_reloading: bool = false
var reload_timer: float = 0.0
var cooldown: float = 0.0
## Multiplicador de delta — setado pelo Slow Mo para manter fire rate/reload normais
var time_compensation: float = 1.0

# Nível de stacking (1 = normal, 2 = dois iguais, 3 = três iguais)
var stack_level: int = 1

var crit_chance: float = 0.05
var crit_multiplier: float = 2.0

# Referência para o Player que está segurando a arma
var player: CharacterBody2D = null
var card_data: CardData = null

func setup(p: CharacterBody2D) -> void:
	player = p
	# Se a arma já tiver card_data (injetado pelo Manager), inicializa atributos
	if card_data:
		_apply_card_stats()
	else:
		current_ammo = max_ammo # Fallback para armas manuais old-school

func initialize_from_card(data: CardData) -> void:
	card_data = data
	# Se o player já estiver setado, aplica agora, senão o setup fará isso
	if player:
		_apply_card_stats()

func _apply_card_stats() -> void:
	if not card_data: return

	is_automatic = card_data.is_automatic

	max_ammo = card_data.max_ammo
	current_ammo = max_ammo
	reload_time = card_data.reload_time
	fire_rate = card_data.fire_rate
	crit_chance = card_data.crit_chance
	crit_multiplier = card_data.crit_multiplier

	# Função para os filhos estenderem com stats específicos (dano, etc)
	_apply_archetype_stats()

## Rola o dado de crítico. Retorna {damage: int, is_crit: bool}
func roll_crit(base_damage: int) -> Dictionary:
	var is_crit := randf() < crit_chance
	return {
		"damage": int(base_damage * crit_multiplier) if is_crit else base_damage,
		"is_crit": is_crit
	}

func _apply_archetype_stats() -> void:
	pass # Virtual

# Ponto de entrada único. Reseta para o CardData base e aplica stack + upgrade em ordem.
# stack: quantas cópias da carta estão no loadout (1–3)
# upgrade_levels: Array com o nível de cada cópia (ex: [3, 2, 1])
func apply_all_bonuses(stack: int, upgrade_levels: Array) -> void:
	stack_level = stack
	_apply_card_stats() # reseta para valores base do CardData

	if stack > 1:
		var rate_mult := 1.2 if stack == 2 else 1.4
		var ammo_mult := 1.2 if stack == 2 else 1.4
		var reload_mult := 0.8 if stack == 2 else 0.6
		fire_rate *= rate_mult
		max_ammo = int(max_ammo * ammo_mult)
		reload_time *= reload_mult

	# Soma os incrementos de upgrade de cada cópia independentemente
	var rate_inc := 0.0
	var ammo_inc := 0.0
	var reload_inc := 0.0
	var crit_inc := 0.0
	for lvl in upgrade_levels:
		var i := clampi(lvl - 1, 0, 2)
		rate_inc += UPGRADE_RATE_INC[i]
		ammo_inc += UPGRADE_AMMO_INC[i]
		reload_inc += UPGRADE_RELOAD_INC[i]
		crit_inc += UPGRADE_CRIT_INC[i]

	if rate_inc > 0.0:
		fire_rate *= (1.0 + rate_inc)
	if ammo_inc > 0.0:
		max_ammo = int(max_ammo * (1.0 + ammo_inc))
	if reload_inc < 0.0:
		reload_time *= maxf(0.1, 1.0 + reload_inc)
	if crit_inc > 0.0:
		crit_chance = minf(crit_chance + crit_inc, 0.95)

	current_ammo = max_ammo
	_apply_archetype_bonuses(stack, upgrade_levels)

func _apply_archetype_bonuses(_stack: int, _upgrade_levels: Array) -> void:
	pass # Virtual — cada archetype sobrescreve com seus bônus específicos

func _process(delta: float) -> void:
	var eff := delta * time_compensation
	# Gerencia o temporizador entre os tiros (Cooldown)
	if cooldown > 0.0:
		cooldown -= eff

	# Gerencia o temporizador de recarga (Reload)
	if is_reloading:
		reload_timer -= eff
		if reload_timer <= 0.0:
			# Terminou de recarregar
			current_ammo = max_ammo
			is_reloading = false
			print("Reload completed! Ammo: ", current_ammo, "/", max_ammo)

func can_fire() -> bool:
	if is_reloading:
		return false
	if current_ammo <= 0:
		return false
	if cooldown > 0.0:
		return false
	return true

func consume_ammo() -> void:
	current_ammo -= 1
	cooldown = 1.0 / fire_rate
	print("Bang! Ammo: ", current_ammo, "/", max_ammo)
	
	if current_ammo <= 0:
		# Auto-reload opcional quando acaba a bala
		start_reload()

func start_reload() -> void:
	if is_reloading or current_ammo == max_ammo:
		return
	
	is_reloading = true
	reload_timer = reload_time
	print("Reloading...")

# Funções virtuais que os filhos (SMG, Bow) vão substituir
func on_attack_pressed() -> void:
	pass

func on_attack_held(_delta: float) -> void:
	pass

func on_attack_released() -> void:
	pass

func on_aim_pressed() -> void:
	pass

func on_aim_held(_delta: float) -> void:
	pass

func on_aim_released() -> void:
	pass

# Deprecated: use as novas funções acima
func handle_input(_delta: float) -> void:
	pass
