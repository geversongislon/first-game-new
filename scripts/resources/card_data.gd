extends Resource
class_name CardData

# === Configurações de Identidade ===
@export var id: String = ""
@export var display_name: String = ""
@export_enum("Weapon", "Active", "Passive", "Consumable") var type: String = "Weapon"
@export_enum("Common", "Uncommon", "Rare", "Epic", "Legendary") var rarity: String = "Common"
@export_multiline var description: String = ""

@export_group("Visuals")
@export var full_art: Texture2D = null # Para Menu/Inventário (Alta resolução)
@export var icon: Texture2D = null     # Para Gameplay/HUD (Ícone simples)

# === Configurações de Arma (Data-Driven) ===
@export_group("Weapon Archetype")
@export_enum("None", "Projectile", "Charge", "Throwable", "Melee") var weapon_archetype: String = "None"
@export var is_automatic: bool = false

@export_group("Base Stats")
@export var fire_rate: float = 5.0 # Tiros por segundo
@export var max_ammo: int = 30
@export var reload_time: float = 1.5

@export_group("Combat Stats (Direct Fire)")
@export var projectile_damage: int = 1
@export_range(0.0, 1.0, 0.01) var crit_chance: float = 0.05
@export var crit_multiplier: float = 2.0
@export var projectile_speed: float = 1200.0
@export var projectile_knockback: float = 90.0
@export var projectile_gravity: float = 980.0
@export var weapon_recoil: float = 30.0

@export_group("Charge Stats (Bow/Grenade)")
@export var max_charge_time: float = 1.0
@export var charge_damage_range: Vector2i = Vector2i(5, 20)
@export var charge_speed_range: Vector2 = Vector2(400, 1400)
@export var charge_knockback_range: Vector2 = Vector2(100, 500)
@export var charge_recoil_range: Vector2 = Vector2(100, 800)

@export_group("Melee Stats")
@export var melee_damage: int = 15
@export var melee_knockback: float = 200.0
@export var melee_hit_stun: float = 0.15    ## Tempo (segundos) que o inimigo fica imóvel

@export_group("Custom Assets")
@export var weapon_visual_scene: PackedScene = null  # Cena visual da arma (sprite + luzes)
@export var custom_projectile_scene: PackedScene = null # Ex: Granada que quica
@export var weapon_id: String = "" # ID interno legado (opcional)

@export_group("Mechanics")
@export var requires_stillness: bool = false          # Player precisa estar parado para atirar
@export var stillness_time_required: float = 1.0      # Segundos parado necessários
@export var has_scope: bool = false                   # Botão direito: laser + zoom out (Sniper)

@export_group("Spread")
@export var spread_base_angle: float = 0.0        # Ângulo mínimo de imprecisão em graus (0 = perfeito)
@export var spread_max_angle: float = 0.0         # Ângulo máximo após buildup
@export var spread_buildup_per_shot: float = 0.0  # Graus adicionados por disparo
@export var spread_recovery_rate: float = 0.0     # Graus/segundo de recuperação ao parar

# === Configurações de Passivas ===
@export_group("Passive Bonuses")
@export var passive_scene: PackedScene = null
@export var flat_health_bonus: int = 0
@export var speed_multiplier: float = 1.0

@export_group("Passive Element")
## Dano por tick do DoT elemental (0 = não é uma passiva elemental)
@export var dot_damage: int = 0
## Intervalo em segundos entre ticks de dano
@export var dot_tick_interval: float = 0.0
## Número de ticks antes de expirar
@export var dot_ticks: int = 0
## Se verdadeiro, exibe linha de slow no popup
@export var element_has_slow: bool = false

# === Configurações de Consumíveis ===
@export_group("Consumable")
## Quantidade máxima de cargas que um slot pode acumular
@export var max_charges: int = 1
## Tempo de cooldown entre usos de carga
@export var charge_cooldown: float = 0.5

# === Configurações de Ativas ===
@export_group("Active Abilities")
## Identificador interno da habilidade (ex: "dash", "shield"). Apenas para referência/debug.
@export var active_ability_id: String = ""
@export var cooldown: float = 5.0
## Action do InputMap que aciona esta habilidade.
## Mapeamentos: active_ability_dash=SHIFT  active_ability_f=F  active_ability_c=C  active_ability_v=V
@export var activation_input_action: String = ""
## Cena da habilidade ativa. Deve ter um nó raiz que estende BaseActiveAbility.
## O Player instancia esta cena, injeta player/card_data/stack_level e chama execute().
@export var active_scene: PackedScene = null

# === Economia e Drop ===
@export_group("Economy")
@export var sell_price: int = 20
@export var drop_weight: float = 10.0

@export_group("Upgrade")
## Nível inicial desta carta quando obtida (1 = padrão)
@export_range(1, 3) var card_level: int = 1
## Custo em gold para subir de nível: L1→L2 = upgrade_cost; L2→L3 = upgrade_cost × 2
@export var upgrade_cost: int = 100
