extends Node
class_name GameManagerClass

# Inventário Permanente
var total_coins: int = 0
var unlocked_cards: Array[String] = []
## Nível de melhoria de cada carta — array paralelo a unlocked_cards (1–3)
var card_upgrade_levels: Array[int] = []
## Cargas dos consumíveis no inventário permanente — paralelo a unlocked_cards (0 = não-consumível)
var inventory_card_charges: Array[int] = []
## Nível das cartas equipadas nos 3 slots do loadout (indexado por slot 0–2)
var equipped_card_levels: Array[int] = [1, 1, 1]
## Cargas atuais dos consumíveis equipados nos 3 slots do loadout (0 = não-consumível ou vazio)
var equipped_card_charges: Array[int] = [0, 0, 0]

# Inventário da Run (Fase) Atual
var run_coins: int = 0
var run_cards: Array[String] = []
var run_backpack: Array[String] = ["", "", "", "", ""] # 5 slots extras
var run_backpack_levels: Array[int] = [1, 1, 1, 1, 1]
var run_backpack_charges: Array[int] = [0, 0, 0, 0, 0] # Cargas de consumíveis (paralelo a run_backpack)
var run_cards_history: Array[String] = [] # Histórico de todas as cartas coletadas na run

# Loadout Persistente (Slots 1, 2, 3)
var equipped_cards: Array = ["card_smg", "", ""] # Valor padrão inicial

# Progressão: pontos de extração desbloqueados (id → nome de exibição)
var unlocked_extraction_points: Dictionary = {"ext_0": "Início"}
var current_run_start_point: String = "ext_0"

# Contador de runs iniciadas (começa em 0, vira 1 ao iniciar a primeira run)
var runs_started: int = 0

# Baús únicos por save (once_per_save): IDs dos que já foram abertos
var opened_loot_boxes: Array[String] = []
# Inimigos únicos por save (once_per_save): IDs dos que já foram mortos
var killed_permanent_enemies: Array[String] = []

# Estatísticas da run atual (resetadas em reset_run)
var run_damage_dealt: int   = 0
var run_enemies_killed: int = 0
var run_damage_taken: int   = 0
var run_killing_enemy: String = ""
var run_elapsed: float = 0.0
var run_extracted: bool = false  # true = extração, false = morte
var _last_hit_source: String = ""  # tracking interno

# Luck (Trevo da Sorte) — resetado em reset_run()
var luck_coin_multiplier: float = 1.0   # multiplicador de moedas (base=1.0, cada trevo +bonus)
var luck_card_chance_bonus: float = 0.0  # somado ao card_drop_chance do inimigo
var luck_stack_count: int = 0            # número de Trevos equipados (controla tier de efeito)

signal run_coins_changed(new_amount: int)
signal permanent_coins_changed(new_amount: int)
signal unlocked_cards_changed()
signal run_backpack_changed()
signal card_upgraded(index: int)

func _ready() -> void:
	_register_active_ability_actions()
	load_game()

func _register_active_ability_actions() -> void:
	var bindings := {
		"active_ability_dash": KEY_SHIFT,
		"active_ability_f": KEY_F,
		"active_ability_c": KEY_C,
		"active_ability_v": KEY_V,
	}
	for action_name in bindings:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			var event := InputEventKey.new()
			event.physical_keycode = bindings[action_name]
			InputMap.action_add_event(action_name, event)

## DEBUG — pressione F5 durante o jogo para zerar o save.
## Remova este método antes de publicar o jogo.
func _process(_delta: float) -> void:
	if not OS.is_debug_build():
		return

	# Shift + R — reseta o save e volta ao menu principal
	if Input.is_key_pressed(KEY_R) and Input.is_key_pressed(KEY_SHIFT):
		if Input.is_action_just_pressed("reload"):
			reset_save()
			SceneManager.go_to("res://scenes/ui/ui_main_menu.tscn")

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# Shift + 0 — adiciona uma cópia de cada carta existente ao baú
		if event.keycode == KEY_0 and event.shift_pressed:
			var all_cards := CardDB.get_all_cards()
			for card in all_cards:
				add_card_to_inventory(card.id)
			print(">>> [DEBUG] Todas as cartas adicionadas ao baú! (%d cartas)" % all_cards.size())


func get_card_level_at(index: int) -> int:
	if index < 0 or index >= card_upgrade_levels.size():
		return 1
	return maxi(1, card_upgrade_levels[index])

func set_card_level_at(index: int, level: int) -> void:
	while card_upgrade_levels.size() <= index:
		card_upgrade_levels.append(1)
	card_upgrade_levels[index] = clampi(level, 1, 3)

func get_card_charges_at(index: int) -> int:
	if index < 0 or index >= inventory_card_charges.size():
		return 1  # Padrão: 1 carga
	var c := inventory_card_charges[index]
	return c if c > 0 else 1

func set_card_charges_at(index: int, charges: int) -> void:
	while inventory_card_charges.size() <= index:
		inventory_card_charges.append(0)
	inventory_card_charges[index] = maxi(0, charges)

func upgrade_card_at(index: int) -> bool:
	if index < 0 or index >= unlocked_cards.size(): return false
	var card_id := unlocked_cards[index]
	if card_id == "": return false

	var current_level := get_card_level_at(index)
	if current_level >= 3: return false

	var card := CardDB.get_card(card_id)
	var cost := (card.upgrade_cost if card else 100) * (2 if current_level == 2 else 1)
	if total_coins < cost: return false

	total_coins -= cost
	set_card_level_at(index, current_level + 1)

	permanent_coins_changed.emit(total_coins)
	card_upgraded.emit(index)
	save_game()
	return true

func add_card_to_inventory(card_id: String) -> void:
	if card_id == "": return

	var initial_level := 1
	var initial_charges := 0
	var card := CardDB.get_card(card_id)
	if card:
		initial_level = card.card_level
		if card.type == "Consumable":
			initial_charges = 1  # Padrão: 1 carga

	var empty_idx := unlocked_cards.find("")
	if empty_idx != -1:
		unlocked_cards[empty_idx] = card_id
		set_card_level_at(empty_idx, initial_level)
		set_card_charges_at(empty_idx, initial_charges)
	else:
		unlocked_cards.append(card_id)
		card_upgrade_levels.append(initial_level)
		inventory_card_charges.append(initial_charges)

	unlocked_cards_changed.emit()
	save_game()

func add_card_to_inventory_with_level(card_id: String, level: int, charges: int = -1) -> int:
	if card_id == "": return -1
	var card := CardDB.get_card(card_id)
	var resolved_charges := charges
	if resolved_charges < 0:
		resolved_charges = 1 if (card and card.type == "Consumable") else 0
	var idx := unlocked_cards.find("")
	if idx != -1:
		unlocked_cards[idx] = card_id
		set_card_level_at(idx, level)
		set_card_charges_at(idx, resolved_charges)
	else:
		unlocked_cards.append(card_id)
		card_upgrade_levels.append(clampi(level, 1, 3))
		inventory_card_charges.append(resolved_charges)
		idx = unlocked_cards.size() - 1
	unlocked_cards_changed.emit()
	save_game()
	return idx

func remove_card_from_inventory(card_id: String) -> void:
	var idx := unlocked_cards.find(card_id)
	if idx != -1:
		unlocked_cards[idx] = ""
		set_card_level_at(idx, 1)
		set_card_charges_at(idx, 0)
		unlocked_cards_changed.emit()
		save_game()

func replace_card_in_inventory_at(index: int, new_card_id: String, charges: int = -1) -> void:
	if index >= 0 and index < unlocked_cards.size():
		unlocked_cards[index] = new_card_id
		if new_card_id == "":
			set_card_charges_at(index, 0)
		elif charges >= 0:
			set_card_charges_at(index, charges)
		unlocked_cards_changed.emit()
		save_game()

# --- LÓGICA DA RUN ---
func add_run_coin(amount: int = 1) -> void:
	run_coins += amount
	run_coins_changed.emit(run_coins)
	
func reset_run() -> void:
	"""Limpa o inventário temporário ao morrer ou iniciar nova run."""
	run_coins = 0
	run_cards.clear()
	run_cards_history.clear()
	run_backpack = ["", "", "", "", ""]
	run_backpack_levels = [1, 1, 1, 1, 1]
	run_backpack_charges = [0, 0, 0, 0, 0]
	run_damage_dealt   = 0
	run_enemies_killed = 0
	run_damage_taken   = 0
	run_killing_enemy  = ""
	run_elapsed        = 0.0
	run_extracted      = false
	_last_hit_source   = ""
	luck_coin_multiplier  = 1.0
	luck_card_chance_bonus = 0.0
	luck_stack_count      = 0
	run_coins_changed.emit(run_coins)

func extract_run() -> void:
	"""Transfere o loot temporário para o inventário permanente."""
	total_coins += run_coins
	
	# As cartas do LOADOUT (slots 1, 2, 3) ficam equipadas no LoadoutManager
	# e serão mostradas como equipadas no menu inicial.
	# NÃO as adicionamos ao baú aqui.
	
	# Extrai apenas as cartas que estão na MOCHILA (slots extras da run)
	for i in range(run_backpack.size()):
		var card_id = run_backpack[i]
		if card_id != "":
			var level = run_backpack_levels[i] if i < run_backpack_levels.size() else 1
			var charges = run_backpack_charges[i] if i < run_backpack_charges.size() else 1
			var empty_idx = unlocked_cards.find("")
			if empty_idx != -1:
				unlocked_cards[empty_idx] = card_id
				set_card_level_at(empty_idx, level)
				set_card_charges_at(empty_idx, charges)
			else:
				unlocked_cards.append(card_id)
				card_upgrade_levels.append(clampi(level, 1, 3))
				inventory_card_charges.append(maxi(1, charges))

	
	permanent_coins_changed.emit(total_coins)
	unlocked_cards_changed.emit()
	
	# Garante que o LoadoutManager reflita no save (embora ele já deva estar sincronizado)
	equipped_cards = LoadoutManager.get_equipped_cards()
	
	save_game()

func save_loadout_charges(charges: Array[int]) -> void:
	"""Salva as cargas dos consumíveis do loadout (chamado na extração e na run)."""
	for i in range(3):
		equipped_card_charges[i] = charges[i] if i < charges.size() else 0

func unlock_extraction_point(point_id: String, display_name: String = "") -> void:
	if point_id != "" and not unlocked_extraction_points.has(point_id):
		unlocked_extraction_points[point_id] = display_name if display_name != "" else point_id
		save_game()

func is_unlocked(point_id: String) -> bool:
	return unlocked_extraction_points.has(point_id)

func expand_backpack(extra: int) -> void:
	for i in extra:
		run_backpack.append("")
		run_backpack_levels.append(1)
		run_backpack_charges.append(0)
	run_backpack_changed.emit()

func add_to_run_backpack(card_id: String, level: int = 1, charges: int = 0) -> bool:
	"""Adiciona uma carta ao primeiro slot vazio da mochila.
	Para consumíveis: empilha cargas em slots existentes antes de abrir novo slot."""
	var card = CardDB.get_card(card_id)
	if card and card.type == "Consumable":
		# Tenta empilhar em slot existente com cargas disponíveis
		for i in range(run_backpack.size()):
			if run_backpack[i] == card_id:
				while run_backpack_charges.size() <= i:
					run_backpack_charges.append(0)
				var slot_charges: int = run_backpack_charges[i]
				var space_left: int = card.max_charges - slot_charges
				if space_left > 0:
					run_backpack_charges[i] += mini(charges, space_left)
					run_backpack_changed.emit()
					return true
		# Sem slot com espaço: abre slot novo
		var nested_bpk_idx = run_backpack.find("")
		if nested_bpk_idx != -1:
			run_backpack[nested_bpk_idx] = card_id
			while run_backpack_levels.size() <= nested_bpk_idx:
				run_backpack_levels.append(1)
			while run_backpack_charges.size() <= nested_bpk_idx:
				run_backpack_charges.append(0)
			run_backpack_levels[nested_bpk_idx] = clampi(level, 1, 3)
			run_backpack_charges[nested_bpk_idx] = charges if charges > 0 else 1
			run_backpack_changed.emit()
			return true
		return false

	# Não-consumível: comportamento original
	var bpk_idx = run_backpack.find("")
	if bpk_idx != -1:
		run_backpack[bpk_idx] = card_id
		while run_backpack_levels.size() <= bpk_idx:
			run_backpack_levels.append(1)
		while run_backpack_charges.size() <= bpk_idx:
			run_backpack_charges.append(0)
		run_backpack_levels[bpk_idx] = clampi(level, 1, 3)
		run_backpack_charges[bpk_idx] = 0
		run_backpack_changed.emit()
		return true
	return false

# --- SAVE / LOAD BÁSICO ---
# Para um MVP simples, usaremos ConfigFile ou JSON. Aqui vamos de ConfigFile.
const SAVE_PATH = "user://savegame.cfg"

func save_game() -> void:
	var config = ConfigFile.new()
	config.set_value("Inventory", "total_coins", total_coins)
	config.set_value("Inventory", "unlocked_cards", unlocked_cards)
	config.set_value("Inventory", "card_upgrade_levels", card_upgrade_levels)
	config.set_value("Inventory", "inventory_card_charges", inventory_card_charges)
	config.set_value("Inventory", "equipped_cards", equipped_cards)
	config.set_value("Inventory", "equipped_card_levels", equipped_card_levels)
	config.set_value("Inventory", "equipped_card_charges", equipped_card_charges)
	config.set_value("Progression", "unlocked_extraction_points", unlocked_extraction_points)
	config.set_value("Progression", "runs_started", runs_started)
	config.set_value("Events", "opened_loot_boxes", opened_loot_boxes)
	config.set_value("Events", "killed_permanent_enemies", killed_permanent_enemies)
	config.save(SAVE_PATH)

func load_game() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		# 1. Carrega Moedas e Bú
		total_coins = config.get_value("Inventory", "total_coins", 0)
		var loaded_cards = config.get_value("Inventory", "unlocked_cards", [])
		
		# 2. Carrega Loadout e LIMPA dados "envenenados" de bugs anteriores
		var raw_equipped = config.get_value("Inventory", "equipped_cards", ["card_smg", "", ""])
		equipped_cards = ["", "", ""] # Reset temporário para limpeza
		
		for i in range(min(raw_equipped.size(), 3)):
			var id = raw_equipped[i]
			if id == "": continue
			
			var data = CardDB.get_card(id)
			if data:
				# Aceita qualquer um dos 3 tipos nos slots de loadout
				equipped_cards[i] = id
		
		# 3. Limpeza do Baú: mantem espaços vazios e IDs válidos + carrega níveis
		var loaded_levels = config.get_value("Inventory", "card_upgrade_levels", [])
		var loaded_charges_inv = config.get_value("Inventory", "inventory_card_charges", [])
		unlocked_cards.clear()
		card_upgrade_levels.clear()
		inventory_card_charges.clear()
		for i in range(loaded_cards.size()):
			var card_id = loaded_cards[i]
			if card_id == "" or CardDB.get_card(card_id) != null:
				unlocked_cards.append(card_id)
				var lvl = loaded_levels[i] if i < loaded_levels.size() else 1
				card_upgrade_levels.append(clampi(lvl, 1, 3))
				# Cargas do inventário — migra saves antigos: consumivel default 1
				var ch: int = loaded_charges_inv[i] if i < loaded_charges_inv.size() else -1
				if ch < 0:
					var cdata := CardDB.get_card(card_id)
					ch = 1 if (cdata and cdata.type == "Consumable") else 0
				inventory_card_charges.append(maxi(0, ch))

		# Carrega níveis do loadout equipado
		var loaded_eq_levels = config.get_value("Inventory", "equipped_card_levels", [1, 1, 1])
		equipped_card_levels = [1, 1, 1]
		for i in range(mini(3, loaded_eq_levels.size())):
			equipped_card_levels[i] = clampi(loaded_eq_levels[i], 1, 3)

		# Carrega cargas dos consumíveis equipados
		var loaded_eq_charges = config.get_value("Inventory", "equipped_card_charges", [0, 0, 0])
		equipped_card_charges = [0, 0, 0]
		for i in range(mini(3, loaded_eq_charges.size())):
			equipped_card_charges[i] = maxi(0, loaded_eq_charges[i])
		
		# 4. Carrega progressão de extração
		var saved_points = config.get_value("Progression", "unlocked_extraction_points", {"ext_0": "Início"})
		if saved_points is Dictionary:
			unlocked_extraction_points = saved_points
		else:
			# Compatibilidade com save antigo (Array)
			unlocked_extraction_points = {"ext_0": "Início"}
			for p in saved_points:
				if p is String and p != "" and p != "ext_0":
					unlocked_extraction_points[p] = p
		if unlocked_extraction_points.is_empty():
			unlocked_extraction_points = {"ext_0": "Início"}

		# 5. Contador de runs
		runs_started = config.get_value("Progression", "runs_started", 0)

		# 6. Eventos únicos por save
		var raw_boxes = config.get_value("Events", "opened_loot_boxes", [])
		opened_loot_boxes.assign(raw_boxes)
		var raw_killed = config.get_value("Events", "killed_permanent_enemies", [])
		killed_permanent_enemies.assign(raw_killed)

		# 7. Sincroniza o LoadoutManager com os dados limpos
		LoadoutManager.sync_from_game_manager(equipped_cards)

		permanent_coins_changed.emit(total_coins)
	else:
		# Se não houver save (primeira vez), começa apenas com a SMG no baú
		unlocked_cards = ["card_smg"]
		card_upgrade_levels = [1]
		save_game()

## DEBUG: Zera o save completamente. Use pelo console do Godot em tempo de execução.
## Exemplo: GameManager.reset_save()
func reset_save() -> void:
	total_coins = 0
	unlocked_cards = []
	card_upgrade_levels = []
	equipped_cards = ["", "", ""]
	equipped_card_levels = [1, 1, 1]
	inventory_card_charges.clear()
	equipped_card_charges = [0, 0, 0]
	run_coins = 0
	run_cards.clear()
	run_backpack = ["", "", "", "", ""]
	run_backpack_levels = [1, 1, 1, 1, 1]
	run_backpack_charges = [0, 0, 0, 0, 0]
	unlocked_extraction_points = {"ext_0": "Início"}
	current_run_start_point = "ext_0"
	runs_started = 0
	opened_loot_boxes.clear()
	killed_permanent_enemies.clear()
	LoadoutManager.sync_from_game_manager(equipped_cards)
	permanent_coins_changed.emit(total_coins)
	unlocked_cards_changed.emit()
	save_game()
	print(">>> [GameManager] Save zerado com sucesso!")
