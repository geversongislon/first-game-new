# Arquitetura e Padrões do Projeto

Este guia é a referência para manter o projeto organizado, legível e escalável.
A ideia é que o nome do arquivo diga **tudo o que ele faz e a qual categoria pertence**.

*Última atualização: 17/03/2026 — Seção 4 atualizada com ProjectileSniper; Seção 5 expandida com crits e WeaponVisual; nova Seção 7 sobre cenas visuais de arma*

---

## 1. Estrutura de Pastas

```
res://
├── assets/          # Arquivos brutos: sprites, sons, fontes, tilemaps
├── resources/
│   └── cards/       # CardData (.tres) — definição de cada carta do jogo
├── scenes/
│   ├── actors/      # Player, inimigos, NPCs
│   ├── weapons/
│   │   ├── archetypes/   # Templates reutilizáveis por tipo de arma
│   │   └── hitboxes/     # Areas de dano melee
│   ├── pickups/     # Itens soltos no chão (cartas, moedas)
│   ├── loot/        # Variantes de loot drop
│   ├── interactables/  # Objetos que o player interage (ExtractionZone)
│   ├── ui/
│   │   └── inventory/  # Widgets de inventário (slots, cartas arrastáveis)
│   └── levels/      # Fases completas
└── scripts/         # Espelha a estrutura de scenes/
    ├── actors/
    ├── weapons/
    │   └── archetypes/
    ├── passives/    # Scripts de buff passivo (instanciados por CardData)
    ├── actives/     # Scripts de habilidade ativa (base + implementações)
    ├── pickups/
    ├── loot/
    ├── interactables/
    ├── ui/
    │   └── inventory/
    ├── levels/
    ├── managers/    # Autoloads / Singletons
    └── resources/   # Classes de Resource (CardData)
```

---

## 2. Autoloads (Singletons)

Três singletons globais acessíveis de qualquer script:

| Singleton | Script | Responsabilidade |
|-----------|--------|-----------------|
| `GameManager` | `scripts/managers/game_manager.gd` | Estado da run, inventário permanente, save/load, progressão de zonas |
| `LoadoutManager` | `scripts/managers/loadout_manager.gd` | 3 slots equipados — sincroniza entre cenas |
| `CardDatabase` | `scripts/managers/card_database.gd` | Banco de dados de cartas (acesso estático via `CardDB.get_card(id)`) |

**Regra:** Dados que precisam persistir entre cenas vão no `GameManager` ou `LoadoutManager`. Dados somente-leitura de definição de jogo vão no `CardDB`.

---

## 3. Sistema de Cartas (CardData)

Toda carta do jogo é um arquivo `.tres` em `resources/cards/` usando a classe `CardData`.

```
card_smg.tres       → id: "card_smg",   tipo: Weapon,   arquétipo: Projectile
card_pistola.tres   → id: "card_pistola", tipo: Weapon, arquétipo: Projectile
card_bow.tres       → id: "card_bow",   tipo: Weapon,   arquétipo: Charge
card_sword.tres     → id: "card_sword", tipo: Weapon,   arquétipo: Melee
card_grenade.tres   → id: "card_grenade", tipo: Weapon, arquétipo: Throwable
card_health_up.tres → id: "card_health_up", tipo: Passive
card_speed.tres     → id: "card_speed",     tipo: Passive
card_puloduplo.tres → id: "card_puloduplo", tipo: Passive
```

**Padrão de ID:** sempre `card_` + nome descritivo em snake_case.

O `CardDB` escaneia `resources/cards/` automaticamente — **nenhum registro manual necessário**.

---

### Como criar uma nova carta — passo a passo por tipo

#### Tipo: Weapon (arma)

1. Crie `resources/cards/card_nome.tres` via Godot (Inspector → New Resource → CardData)
2. Preencha os campos obrigatórios:
   - `id` — ex: `"card_shotgun"` (único, snake_case com prefixo `card_`)
   - `display_name` — nome exibido na UI
   - `card_type` — `Weapon`
   - `weapon_archetype` — `"Projectile"`, `"Melee"`, `"Charge"` ou `"Throwable"`
   - `rarity` — `Common`, `Uncommon`, `Rare`
3. Configure os stats de combate (campos variam por arquétipo — ver Seção 5)
4. (Opcional) `custom_projectile_scene` — aponta para uma cena `.tscn` de projétil customizado
5. Crie `scenes/weapons/visuals/weapon_nome.tscn` com raiz `WeaponVisual` (ver Seção 7)
6. Aponte `weapon_visual_scene` no `.tres` para essa cena
7. (Opcional) Crie `scenes/pickups/pickup_nome.tscn` para o item de chão, com `card_id = "card_nome"`

#### Tipo: Passive (buff permanente na run)

1. Crie `scripts/passives/passive_nome.gd` extendendo `BasePassive`
   - Override `apply(player, card_data, stack_level)` com o efeito desejado
   - Use `player` para modificar stats direto (ex: `player.max_health += 10`)
2. Crie `scenes/passives/passive_nome.tscn` — Node raiz com o script anexado
3. Crie `resources/cards/card_nome.tres`:
   - `card_type` — `Passive`
   - `passive_scene` — aponta para `passive_nome.tscn`
   - `rarity` — define o peso de drop no `CardDatabase`

#### Tipo: Active (habilidade com cooldown)

1. Crie `scripts/actives/active_nome.gd` extendendo `BaseActiveAbility`
   - Override `execute()` — usa `player`, `card_data`, `stack_level`
   - Termine com `queue_free()`
2. Crie `scenes/actives/active_nome.tscn` — Node raiz com o script
3. Crie `resources/cards/card_nome.tres`:
   - `card_type` — `Active`
   - `active_scene` — aponta para `active_nome.tscn`
   - `cooldown` — segundos entre usos
   - `activation_input_action` — ex: `"active_ability_f"` (ver Seção 6)

---

### Campos universais do CardData (todos os tipos)

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `id` | String | Identificador único — ex: `"card_smg"` |
| `display_name` | String | Nome na UI |
| `description` | String | Texto de flavor/efeito |
| `icon` | Texture2D | Ícone exibido na carta |
| `card_type` | Enum | `Weapon`, `Passive`, `Active` |
| `rarity` | Enum | `Common`, `Uncommon`, `Rare` |
| `drop_weight` | float | Peso de drop (maior = aparece mais) |
| `max_stacks` | int | Cópias máximas do mesmo card (padrão 3) |
| `crit_chance` | float | 0.0–1.0, padrão 0.05 |
| `crit_multiplier` | float | Multiplicador de dano crit, padrão 2.0 |

---

## 4. Arquétipos de Arma e Sistema de Projéteis

O sistema é **duas camadas**:

```
CardData (.tres)
  └─ weapon_archetype → WeaponManager instancia o Template correto
       └─ Template (archetype script)
            └─ bullet_scene → Projétil/Granada instanciado a cada disparo
```

### Camada 1 — Templates (Archetypes)

Instanciados pelo `WeaponManager` com base no `weapon_archetype` do CardData:

| Arquétipo | Template | Script | Comportamento |
|-----------|----------|--------|---------------|
| `Projectile` | `templates/projectile_template.tscn` | `projectile_weapon.gd` | Tiro automático/semi — cria projétil por disparo |
| `Charge` | `templates/charge_template.tscn` | `charge_weapon.gd` | Segurar para carregar — interpola dano/velocidade |
| `Throwable` | `templates/throwable_template.tscn` | `throwable_weapon.gd` | Arremesso com física, mostra arco de trajetória |
| `Melee` | `templates/melee_template.tscn` | `melee_weapon.gd` | Hitbox Area2D em arco, detecta overlap |

### Camada 2 — Projéteis

Cenas que representam a "bala". Todas reutilizam `projectile.gd` exceto grenadas e sniper:

| Cena | Script | Diferencial |
|------|--------|-------------|
| `projectile_smg.tscn` | `projectile.gd` | `projectile_gravity = 50.0` (leve) |
| `projectile_pistola.tscn` | `projectile.gd` | `projectile_gravity = 50.0`, `damage = 20` |
| `projectile_bow.tscn` | `projectile.gd` | `stick_on_hit = true` (flecha crava) |
| `projectile_sniper.tscn` | `projectile_sniper.gd` | Script próprio — penetra inimigos, dano escala com distância, raycast anti-tunneling |
| `projectile_grenade.tscn` | `grenade.gd` | `RigidBody2D` com física real, explode por timer em área |

**`projectile.gd` — @export disponíveis:**
```gdscript
@export var damage: int = 1
@export var knockback: float = 0.0
@export var stick_on_hit: bool = false
@export var projectile_gravity: float = 980.0
```

**`projectile_sniper.gd` — vars (atribuídas pelo archetype ao instanciar):**
```gdscript
var damage: int          # base — escala com distância até MAX_DAMAGE_MULTIPLIER (3×)
var is_crit: bool
@export var impact_color: Color  # cor das partículas de impacto na parede (inspetor)
```
Usa `_sweep_hits()` (raycast por frame) em vez de `_on_body_entered` para evitar tunneling em alta velocidade. Penetra inimigos (não para no primeiro hit).

**`grenade.gd` — @export adicionais:**
```gdscript
@export var explosion_radius: float = 200.0
@export var fuse_time: float = 3.0
```

### Como o CardData controla o projétil

Por padrão cada template usa o projétil definido nele. Para trocar:
- Preencha `custom_projectile_scene` no CardData → substitui o projétil padrão do template
- `damage` e `knockback` são sempre sobrescritos pelo CardData via `initialize_from_card()`

### Como adicionar uma nova arma

**Caso 1 — Nova arma reutilizando projétil existente (mais comum):**
1. Crie `resources/cards/card_nome.tres` com `weapon_archetype`, stats de dano/knockback/ammo
2. Deixe `custom_projectile_scene` vazio → usa o projétil padrão do template
3. Pronto — nenhum script novo necessário

**Caso 2 — Nova arma com projétil visual diferente:**
1. Crie `resources/cards/card_nome.tres`
2. Crie `scenes/weapons/projectile_nome.tscn` com `projectile.gd` como script
3. Ajuste os @export no inspetor (gravity, stick_on_hit)
4. Aponte `custom_projectile_scene` no CardData para a nova cena

**Caso 3 — Nova arma Melee:**
1. Crie `resources/cards/card_nome.tres` com `weapon_archetype = "Melee"`
2. Opcional: crie `scenes/weapons/hitboxes/hitbox_nome.tscn` para hitbox customizada
3. Aponte `melee_hitbox_scene` no CardData se necessário

**Caso 4 — Novo tipo de projétil com comportamento único (ex: ricochete, explosão):**
1. Crie `scripts/weapons/projectile_nome.gd` extendendo `Area2D` ou `RigidBody2D`
2. Implemente `setup(direction, speed)` e `_on_body_entered()`
3. Crie a cena em `scenes/weapons/projectile_nome.tscn`
4. Aponte `custom_projectile_scene` no CardData

---

## 5. Sistema de Dano das Armas

### Fluxo completo: disparo → projétil → hit → dano

```
CardData (.tres)
  └─ initialize_from_card()   → injeta stats na instância da arma
       └─ apply_stack_bonus() → multiplica dano/knockback pelo nível do stack

[Projectile]  _shoot()        → roll_crit() → instancia projétil com damage + is_crit
[Melee]       _perform_attack()→ roll_crit() → ativa hitbox Area2D, detecta overlap
[Charge]      on_attack_released() → interpola dano min→max, roll_crit()
[Throwable]   on_attack_released() → lança granada com velocidade escalada

Projétil colide com enemy
  └─ body.take_damage(damage, direction, knockback, is_crit)
       ├─ health -= damage
       ├─ Flash branco (shader)
       ├─ Exibe DamageNumber (laranja + "!" se is_crit, branco caso contrário)
       ├─ velocity.x = sign(dir.x) * knockback * knockback_resistance
       └─ move_mode = STUNNED (decai via knockback_damp até parar)
```

### Sistema de Critical Hit

`roll_crit()` é um helper em `base_weapon.gd` herdado por todos os archetypes:

```gdscript
func roll_crit(base_damage: int) -> Dictionary:
    var is_crit := randf() < crit_chance
    return {"damage": int(base_damage * crit_multiplier) if is_crit else base_damage, "is_crit": is_crit}
```

Configurado por carta no `CardData`:
```gdscript
@export_range(0.0, 1.0, 0.01) var crit_chance: float = 0.05
@export var crit_multiplier: float = 2.0
```

Stacks **não** aumentam crit chance — apenas dano, velocidade e fire_rate (ver tabela abaixo).

### Stack bonus por arquétipo

| Stack | Projectile | Melee | Charge | Throwable |
|-------|-----------|-------|--------|-----------|
| 2x   | 2.0× dano, 1.15× velocidade | 1.5× dano, 1.3× KB | 1.5× dano, 0.80× carga | 1.3× vel. lançamento |
| 3x   | 3.5× dano, 1.35× velocidade | 2.5× dano, 1.8× KB | 2.5× dano, 0.10× carga | 1.8× vel. lançamento |

Universal (todos): 2x → 1.3× fire_rate, 1.5× ammo, 0.85× reload | 3x → 1.7×, 2.0×, 0.70×

### Knockback

```
velocity.x = sign(hit_direction.x) * knockback_force * knockback_resistance
```

- `knockback_resistance` — export por inimigo, range `0.0` (imune) → `2.0` (ultra-leve)
- `knockback_damp` — taxa de freagem (padrão 500.0); maior = para mais rápido

### Granada — caso especial

Dano em área ao expirar o `fuse_time`:
```
Timer → explode()
  └─ ExplosionArea detecta todos os bodies em explosion_radius
       └─ take_damage(damage, radial_direction, knockback)
```

### Campos do CardData por arquétipo

| Campo | Arquétipo | Efeito |
|-------|-----------|--------|
| `projectile_damage` | Projectile / Charge | Dano do projétil |
| `melee_damage` | Melee | Dano direto por swing |
| `charge_damage_range` | Charge | `Vector2(min, max)` interpolado pelo % de carga |
| `projectile_knockback` | Projectile | Força de knockback |
| `melee_knockback` | Melee | Força de knockback |
| `charge_knockback_range` | Charge | `Vector2(min, max)` escalado com carga² |
| `custom_projectile_scene` | Todos | Substitui o projétil/grenade padrão |

### Arquivos-chave

| Arquivo | Papel |
|---------|-------|
| `scripts/weapons/base_weapon.gd` | Stack bonus, ammo, reload, `roll_crit()` |
| `scripts/weapons/archetypes/*.gd` | Lógica de disparo por arquétipo |
| `scripts/weapons/projectile.gd` | Física de voo e colisão |
| `scripts/weapons/projectile_sniper.gd` | Projétil penetrante com raycast e escala de dano por distância |
| `scripts/weapons/grenade.gd` | Explosão em área |
| `scripts/actors/enemy.gd` | `take_damage()`, knockback, morte, `_show_damage_number()` |
| `scripts/actors/player.gd` | `take_damage()`, `heal()`, instanciação de `WeaponVisual` |
| `scripts/ui/damage_number.gd` | Número de dano flutuante (UNSHADED, laranja em crit) |

---

## 7. Cenas Visuais de Arma (WeaponVisual)

O visual de cada arma (sprite + luzes + ponto de disparo) é uma **cena independente**, editável visualmente no editor Godot. O player instancia dinamicamente ao equipar.

### Estrutura de cada cena visual

```
WeaponVisual (Node2D, weapon_visual.gd)
├── Sprite (AnimatedSprite2D)    ← light_mask=17
├── MuzzleLight (PointLight2D)   ← flash de tiro
├── AmbientLight (PointLight2D)  ← range_item_cull_mask=16
└── SpawnPoint (Marker2D)        ← origem dos projéteis e da stance indicator
```

Arquivo: `scenes/weapons/visuals/weapon_nome.tscn`

### Como o player usa o visual

```
_on_weapon_equipped()
  → card_data.weapon_visual_scene.instantiate() as WeaponVisual
  → hand_pivot.add_child(visual)
  → weapon_sprite   = visual.sprite
  → muzzle_light    = visual.muzzle_light
  → weapon_ambient_light = visual.ambient_light
```

`set_facing(is_looking_left)` é chamado a cada frame para flipar sprite e luzes conforme direção do mouse.

### Para criar o visual de uma nova arma

1. Crie `scenes/weapons/visuals/weapon_nome.tscn` com nó raiz `WeaponVisual` e script `weapon_visual.gd`
2. Adicione `Sprite` (AnimatedSprite2D), `MuzzleLight`, `AmbientLight`, `SpawnPoint`
3. Posicione tudo visualmente no editor
4. Aponte `weapon_visual_scene` no `.tres` da carta para essa cena

### Cenas visuais existentes

| Cena | Arma |
|------|------|
| `weapon_pistola.tscn` | Pistola |
| `weapon_smg.tscn` | SMG |
| `weapon_sniper.tscn` | Sniper |
| `weapon_bow.tscn` | Arco |
| `weapon_grenade.tscn` | Granada |
| `weapon_sword.tscn` | Espada |

---

## 6. Sistema de Habilidades Ativas

Segue o mesmo padrão das passivas: cada habilidade é uma **cena independente** com um script próprio. O player é genérico — não conhece os detalhes de nenhuma habilidade.

### Fluxo de execução
```
Player detecta input (SHIFT/F/C/V)
  → _try_activate_by_action(action)
    → localiza CardData com activation_input_action == action
      → execute_active_ability(card)
        → instancia card.active_scene
        → injeta: ability.player, ability.card_data, ability.stack_level
        → add_child(ability) + ability.execute()
          → habilidade faz seu efeito
          → queue_free() ao terminar
        → inicia cooldown
```

### Estrutura de arquivos
```
scripts/actives/
  base_active_ability.gd   ← classe base (class_name BaseActiveAbility)
  active_dash.gd           ← dash (extends BaseActiveAbility)

scenes/actives/
  active_dash.tscn         ← Node + active_dash.gd (@export vars tweakáveis)
```

### Para criar uma nova habilidade ativa
1. Crie `scripts/actives/active_nome.gd` extendendo `BaseActiveAbility`
2. Override `execute()` — use `player`, `card_data` e `stack_level`
3. Termine com `queue_free()`
4. Crie `scenes/actives/active_nome.tscn` — Node raiz com o script anexado
5. No `.tres` da carta: aponte `active_scene` para a cena; defina `activation_input_action` e `cooldown`

### Campos relevantes no CardData (tipo Active)
| Campo | Exemplo | Uso |
|-------|---------|-----|
| `active_ability_id` | `"dash"` | Identificador/debug (não executa mais via match) |
| `cooldown` | `5.0` | Segundos de espera após uso |
| `activation_input_action` | `"active_ability_dash"` | Hotkey mapeada no InputMap |
| `active_scene` | `active_dash.tscn` | Cena instanciada para executar o efeito |

### Hotkeys disponíveis
| Action | Tecla | Uso sugerido |
|--------|-------|-------------|
| `active_ability_dash` | SHIFT | Mobilidade |
| `active_ability_f` | F | Utilidade |
| `active_ability_c` | C | Utilidade |
| `active_ability_v` | V | Utilidade |

---

## 6. Padrões de Nomenclatura

Usamos `snake_case` para todos os arquivos.

### Prefixos obrigatórios por categoria

| Prefixo | Categoria | Exemplo |
|---------|-----------|---------|
| `card_` | Recursos de carta (`.tres`) | `card_smg.tres`, `card_bow.tres` |
| `pickup_` | Itens interativos no chão | `pickup_coin.tscn`, `pickup_card.tscn` |
| `projectile_` | Munições e tiros | `projectile_smg.tscn`, `projectile_bow.tscn` |
| `ui_` | Telas e menus | `ui_main_menu.tscn`, `ui_run_selection.tscn` |
| `passive_` | Scripts de buff passivo | `passive_health.gd`, `passive_speed.gd` |
| `active_` | Scripts de habilidade ativa | `active_dash.gd`, `active_shield.gd` |
| `ext_` | IDs de zonas de extração | `ext_0`, `ext_1`, `ext_2` |

### Sufixos por função

| Sufixo | Função | Exemplo |
|--------|--------|---------|
| `_weapon` | Arma equipada (lógica de ataque) | `base_weapon.gd` |
| `_manager` | Singleton/Autoload | `game_manager.gd` |
| `_ui` | Componente de HUD/interface | `weapon_ui.tscn` |
| `_zone` | Área interativa do mapa | `extraction_zone.gd` |

---

## 8. Zonas de Extração

IDs seguem o padrão `ext_N` onde N começa em 0:

- `ext_0` — sempre desbloqueado (ponto de início padrão)
- `ext_1`, `ext_2`, ... — desbloqueados ao extrair por essa zona

**Para adicionar uma nova zona:**
1. Crie uma `ExtractionZone` na cena com `extraction_id = "ext_N"` no inspetor
2. Adicione um `Marker2D` na cena com o **nome exato** `ext_N` (spawn point)
3. Registre no array `EXTRACTION_POINTS` de `ui_run_selection.gd`

O sistema é **não-sequencial** — qualquer zona alcançada e extraída fica disponível, independente da ordem.

---

## 9. Scripts Genéricos — Regra de Ouro

Se dois objetos fazem a mesma coisa, **não crie scripts separados**. Crie um script genérico e configure via `@export` no inspetor.

**Exemplo: Projéteis**
- `projectile_bow.tscn` e `projectile_smg.tscn` usam o mesmo `projectile.gd`
- O que muda são os valores exportados (`damage`, `speed`, `gravity`, `stick_on_hit`)

**Exemplo: Inimigos**
- Todos os inimigos usam `enemy.gd` como base
- Comportamento configurado via `@export`: `attack_type`, `move_mode`, `follow_on_detect`, `is_flying`, etc.

---

## 11. Ciclo de Vida — Exemplos Completos

### Exemplo A: Bazuca (projétil customizado, sem novo script)

1. **`scenes/weapons/projectile_bazuca.tscn`** — Node: `Area2D`, script: `projectile.gd`
   - Inspetor: `projectile_gravity = 0`, `stick_on_hit = false`
   - Adicione sprite e CollisionShape adequados
2. **`resources/cards/card_bazuca.tres`**
   - `weapon_archetype = "Projectile"`, `projectile_damage = 500`, `fire_rate = 0.5`
   - `custom_projectile_scene = [projectile_bazuca.tscn]`
3. *(opcional)* `scenes/pickups/pickup_bazuca.tscn` com `card_id = "card_bazuca"` para o item de chão

**Resultado:** `WeaponManager` instancia `projectile_template` → `_apply_card_stats()` injeta 500 de dano → cada tiro instancia `projectile_bazuca.tscn`.

---

### Exemplo B: Lança-foguetes (explosão em área)

1. **`scripts/weapons/projectile_rocket.gd`** — extends `RigidBody2D`, baseado em `grenade.gd`
   - Override `explode()` para lógica de splash
2. **`scenes/weapons/projectile_rocket.tscn`** — Node: `RigidBody2D`, script: `projectile_rocket.gd`
3. **`resources/cards/card_rocket.tres`** — `weapon_archetype = "Projectile"`, `custom_projectile_scene = [projectile_rocket.tscn]`

---

### Exemplo C: Arma Melee nova (Machado)

1. **`resources/cards/card_axe.tres`** — `weapon_archetype = "Melee"`, `melee_damage = 45`, `melee_knockback = 200`
2. *(sem código novo)* — usa `melee_template.tscn` com hitbox padrão

Nenhum script novo necessário nos casos A e C — só assets e configuração.
