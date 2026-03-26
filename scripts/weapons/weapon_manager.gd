extends Node
class_name WeaponManager

# =========================
# INVENTÁRIO
# =========================

# IDs desbloqueadas
var unlocked_weapons: Array[String] = ["", "", ""]  # 3 slots fixos; "" = vazio

# Mapeamento ID -> nó da arma removido, instanciado on the fly

# Arma atual
var current_weapon_id: String = ""
var current_weapon: Node = null
var current_weapon_index: int = -1

# Passivas ativas instanciadas
var active_passives: Dictionary = {}

# Cache de munição por slot (preserva ammo ao trocar de arma)
var _ammo_cache: Dictionary = {} # slot_index (int) -> int


# =========================
# SINAIS (Para a UI)
# =========================
signal weapon_unlocked(weapon_id: String)
signal weapon_equipped(weapon_id: String, slot_index: int)
signal loadout_changed() # Novo: Avisa quando algo mudou nos 3 slots (pra recalculos)

# Templates para sistema Data-Driven
const PROJECTILE_TEMPLATE = preload("res://scenes/weapons/templates/projectile_template.tscn")
const CHARGE_TEMPLATE = preload("res://scenes/weapons/templates/charge_template.tscn")
const THROWABLE_TEMPLATE = preload("res://scenes/weapons/templates/throwable_template.tscn")

var current_card_data: CardData = null

# FUNÇÕES CORE
# =========================
func get_current_weapon() -> Node:
	return current_weapon

func _ready() -> void:
	# Sempre que o loadout mudar, atualiza passivas e recalcula stacks da arma atual
	loadout_changed.connect(_sync_passives)
	loadout_changed.connect(_refresh_current_weapon_stacks)
	
func _sync_passives() -> void:
	# Reune quais IDs de instâncias (ex: "card_health_up_0", "card_health_up_1") deveriam estar ativos
	var desired_instances = []
	for i in range(unlocked_weapons.size()):
		var card_id = unlocked_weapons[i]
		if card_id == "": continue
		var card_data = CardDB.get_card(card_id)
		if card_data and card_data.type == "Passive" and card_data.passive_scene != null:
			desired_instances.append(card_id + "_" + str(i))
			
	# Remove as passivas que não estão mais equipadas
	for active_instance_id in active_passives.keys():
		if not desired_instances.has(active_instance_id):
			var node = active_passives[active_instance_id]
			if node: node.queue_free()
			active_passives.erase(active_instance_id)
			
	# Instancia as que estão faltando
	for instance_id in desired_instances:
		if not active_passives.has(instance_id):
			var base_card_id = instance_id.substr(0, instance_id.rfind("_"))
			var data = CardDB.get_card(base_card_id)
			var node = data.passive_scene.instantiate()
			node.name = "Passive_" + instance_id
			add_child(node)
			active_passives[instance_id] = node
			
			# Opcional: Se a passiva precisar de setup (ex: conhecer o player)
			var player = get_parent() as CharacterBody2D
			if player and node.has_method("setup"):
				node.setup(player)


# =========================
# DESBLOQUEAR / ADICIONAR AO SLOT
# =========================
func unlock(card_id: String) -> bool:
	if card_id == "": return false
	
	# Procura o primeiro slot vazio ("") para preencher
	var empty_idx = unlocked_weapons.find("")
	if empty_idx != -1:
		unlocked_weapons[empty_idx] = card_id
		print("Adicionado ao slot ", empty_idx + 1, ": ", card_id)
		weapon_unlocked.emit(card_id)
		loadout_changed.emit() # Recalcula passivas
		
		# Se não tiver nada equipado, equipa essa nova
		if current_weapon_id == "":
			equip_by_index(empty_idx)
		return true
	else:
		print("Loadout cheio! Não há espaço para: ", card_id)
		return false


# =========================
# EQUIPAR / SELECIONAR SLOT
# =========================
func equip_by_id(card_id: String) -> void:
	if card_id == "":
		current_weapon_id = ""
		if current_weapon:
			current_weapon.queue_free()
		current_weapon = null
		current_weapon_index = -1
		current_card_data = null
		print("Slot desequipado")
		weapon_equipped.emit("", -1)
		return

	if not unlocked_weapons.has(card_id):
		print("Card não está nos slots:", card_id)
		return

	# Se a mesma carta já está equipada e a instância é válida, apenas reaplica bônus (não reinstancia)
	if current_card_data != null and current_card_data.id == card_id and is_instance_valid(current_weapon):
		# Corrige o índice se o slot atual não tem mais esta carta (ex: chamada direta via equip_by_id)
		if current_weapon_index < 0 or current_weapon_index >= unlocked_weapons.size() or unlocked_weapons[current_weapon_index] != card_id:
			var new_idx := unlocked_weapons.find(card_id)
			if new_idx != -1:
				current_weapon_index = new_idx
		# Salva ammo antes de apply_all_bonuses (que reseta current_ammo = max_ammo)
		var saved_ammo: int = current_weapon.get("current_ammo") if "current_ammo" in current_weapon else -1
		# Reaplica bônus com o menor nível entre todas as cópias no loadout
		if current_weapon.has_method("apply_all_bonuses"):
			current_weapon.apply_all_bonuses(get_stack_level(card_id), get_stack_upgrade_levels(card_id))
		# Restaura ammo (via cache de slot se disponível, senão valor salvo)
		if saved_ammo >= 0 and "current_ammo" in current_weapon:
			if _ammo_cache.has(current_weapon_index):
				current_weapon.current_ammo = mini(_ammo_cache[current_weapon_index], current_weapon.max_ammo)
			else:
				current_weapon.current_ammo = mini(saved_ammo, current_weapon.max_ammo)
		# Sempre emite o sinal para garantir atualização visual (inclui troca entre slots stacked)
		weapon_equipped.emit(current_weapon_id, current_weapon_index)
		return

	# Pega os dados da carta
	current_card_data = CardDB.get_card(card_id)
	
	# Determina se é uma arma real ou outra coisa (ativa/passiva)
	var weapon_id = ""
	if current_card_data and current_card_data.type == "Weapon":
		weapon_id = current_card_data.weapon_id
	
	current_weapon_id = weapon_id
	
	# Remove a arma antiga da cena de jogo
	if current_weapon:
		current_weapon.queue_free()
		current_weapon = null
		
	# Instancia a arma nova (Prioridade: Sistema Data-Driven)
	if current_card_data:
		if current_card_data.weapon_archetype != "None":
			match current_card_data.weapon_archetype:
				"Projectile": current_weapon = PROJECTILE_TEMPLATE.instantiate()
				"Charge": current_weapon = CHARGE_TEMPLATE.instantiate()
				"Throwable": current_weapon = THROWABLE_TEMPLATE.instantiate()

		if current_weapon:
			add_child(current_weapon)
			# Injeta os dados da carta na arma
			if current_weapon.has_method("initialize_from_card"):
				current_weapon.initialize_from_card(current_card_data)

		# Faz o setup injetando o Player nela (chama _apply_card_stats internamente)
		var player = get_parent() as CharacterBody2D
		if player and current_weapon and current_weapon.has_method("setup"):
			current_weapon.setup(player)

		# Aplica stack + upgrade em uma única chamada (DEPOIS do setup)
		if current_weapon and current_weapon.has_method("apply_all_bonuses"):
			current_weapon.apply_all_bonuses(get_stack_level(card_id), get_stack_upgrade_levels(card_id))

	
	# Atualiza o índice
	if current_weapon_index < 0 or \
	   current_weapon_index >= unlocked_weapons.size() or \
	   unlocked_weapons[current_weapon_index] != card_id:
		current_weapon_index = unlocked_weapons.find(card_id)

	# Restaura munição cacheada para este slot (clamp garante que não excede o max)
	if current_weapon and _ammo_cache.has(current_weapon_index):
		if "current_ammo" in current_weapon and "max_ammo" in current_weapon:
			current_weapon.current_ammo = min(_ammo_cache[current_weapon_index], current_weapon.max_ammo)
	
	print("Selecionado slot ", current_weapon_index, " com card: ", card_id)
	weapon_equipped.emit(weapon_id, current_weapon_index)

func equip_by_index(index: int) -> void:
	if index >= 0 and index < unlocked_weapons.size():
		# Salva munição do slot atual ANTES de trocar o índice
		if current_weapon and is_instance_valid(current_weapon) and current_weapon_index >= 0:
			if "current_ammo" in current_weapon:
				_ammo_cache[current_weapon_index] = current_weapon.current_ammo
		current_weapon_index = index
		equip_by_id(unlocked_weapons[index])

# =========================
# INPUT
# =========================
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("switch_weapon"):
		_switch_to_next_weapon()

func _switch_to_next_weapon() -> void:
	if unlocked_weapons.size() <= 1:
		return
		
	var next_idx = (current_weapon_index + 1) % unlocked_weapons.size()
	equip_by_index(next_idx)

func handle_attack_pressed() -> void:
	if current_weapon == null:
		return
	if current_weapon.has_method("on_attack_pressed"):
		current_weapon.on_attack_pressed()

func handle_attack_held(delta: float) -> void:
	if current_weapon == null:
		return
	if current_weapon.has_method("on_attack_held"):
		current_weapon.on_attack_held(delta)

func handle_attack_released() -> void:
	if current_weapon == null:
		return
	if current_weapon.has_method("on_attack_released"):
		current_weapon.on_attack_released()

func handle_aim_pressed() -> void:
	if current_weapon and current_weapon.has_method("on_aim_pressed"):
		current_weapon.on_aim_pressed()

func handle_aim_held(delta: float) -> void:
	if current_weapon and current_weapon.has_method("on_aim_held"):
		current_weapon.on_aim_held(delta)

func handle_aim_released() -> void:
	if current_weapon and current_weapon.has_method("on_aim_released"):
		current_weapon.on_aim_released()

# Deprecated
func handle_attack_input(delta: float) -> void:
	handle_attack_held(delta)


# =========================
# SISTEMA DE STACKING
# =========================

# Retorna quantas vezes card_id aparece nos slots do loadout (1, 2 ou 3)
func get_stack_level(card_id: String) -> int:
	var count := 0
	for id in unlocked_weapons:
		if id == card_id:
			count += 1
	return max(count, 1)

# Retorna um Array com o nível de cada cópia de card_id no loadout
func get_stack_upgrade_levels(card_id: String) -> Array:
	var levels := []
	for i in range(unlocked_weapons.size()):
		if unlocked_weapons[i] == card_id:
			var lvl := GameManager.equipped_card_levels[i] if i < GameManager.equipped_card_levels.size() else 1
			levels.append(lvl)
	if levels.is_empty():
		levels.append(1)
	return levels

# Recalcula os stats da arma atualmente equipada quando o loadout muda
# (ex: ao arrastar um segundo card igual para o loadout)
func _refresh_current_weapon_stacks() -> void:
	if current_weapon_index < 0 or current_weapon == null: return
	if current_weapon_index >= unlocked_weapons.size(): return
	var card_id := unlocked_weapons[current_weapon_index]
	if card_id == "" or current_card_data == null: return

	# Salva ammo antes do re-init (initialize_from_card e apply_all_bonuses resetam current_ammo)
	var saved_ammo: int = current_weapon.get("current_ammo") if "current_ammo" in current_weapon else -1
	# Reinicia os stats base do CardData antes de reaplicar multiplicadores
	if current_weapon.has_method("initialize_from_card"):
		current_weapon.initialize_from_card(current_card_data)
	if current_weapon.has_method("apply_all_bonuses"):
		current_weapon.apply_all_bonuses(get_stack_level(card_id), get_stack_upgrade_levels(card_id))
	# Restaura ammo respeitando o novo max_ammo após bônus
	if saved_ammo >= 0 and "current_ammo" in current_weapon:
		current_weapon.current_ammo = mini(saved_ammo, current_weapon.max_ammo)
