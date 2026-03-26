# 📖 Manual de Inclusão de Cartas — Geometrics Cards

Este manual descreve **o passo a passo completo** para criar uma nova carta no jogo,
de zero até funcionar no gameplay. Nenhum código existente precisa ser alterado.
Todo o sistema é **Data-Driven**: os dados ficam nos `.tres`, a lógica já está pronta.

---

## Índice

1. [Conceitos Fundamentais](#1-conceitos-fundamentais)
2. [Tipos de Carta](#2-tipos-de-carta)
3. [Passo a Passo: Criando uma Carta de Arma (Weapon)](#3-passo-a-passo-criando-uma-carta-de-arma-weapon)
4. [Passo a Passo: Criando uma Carta Passiva (Passive)](#4-passo-a-passo-criando-uma-carta-passiva-passive)
5. [Passo a Passo: Criando uma Carta Ativa (Active)](#5-passo-a-passo-criando-uma-carta-ativa-active)
6. [Referência Completa de Campos](#6-referência-completa-de-campos)
7. [Archetypes de Arma Disponíveis](#7-archetypes-de-arma-disponíveis)
8. [Checklist Final](#8-checklist-final)

---

## 1. Conceitos Fundamentais

### Como o sistema funciona

```
CardData (.tres)  →  CardDatabase (Autoload)  →  WeaponManager / Player
     ↑                      ↑                            ↑
  Você edita         Carrega tudo auto               Lê e aplica
  aqui               maticamente                     os dados
```

- **`CardData`** (`scripts/resources/card_data.gd`): O "formulário" de toda carta. Define
  todos os atributos via `@export`, visíveis no Inspetor.
- **`CardDatabase`** (`scripts/managers/card_database.gd`): Singleton que escaneia
  `res://resources/cards/` e carrega todos os `.tres` automaticamente ao iniciar o jogo.
- **`WeaponManager`** (`scripts/weapons/weapon_manager.gd`): Lê os dados da carta e
  instancia o arquétipo correto baseado no campo `weapon_archetype`.
- **`GameManager`** (`scripts/managers/game_manager.gd`): Guarda o inventário do jogador
  e persiste os dados em `user://savegame.cfg`.

> **Regra de ouro:** você **nunca** precisa editar código para adicionar uma nova carta.
> Apenas crie um arquivo `.tres` e preencha o Inspetor.

---

## 2. Tipos de Carta

| Tipo | Valor no Campo `type` | O que faz |
|---|---|---|
| **Arma** | `"Weapon"` | Equipa uma arma no jogador. Controla disparo, munição, recuo. |
| **Passiva** | `"Passive"` | Bônus permanente enquanto estiver no loadout (HP, velocidade, etc.). |
| **Ativa** | `"Active"` | Habilidade com cooldown ativada por tecla (não implementado ainda). |

---

## 3. Passo a Passo: Criando uma Carta de Arma (Weapon)

### 3.1. Prepare os Assets Visuais

Antes de criar o `.tres`, reúna:

| Asset | Onde guardar | Formato recomendado |
|---|---|---|
| Ícone da arma (HUD) | `assets/sprites/ui/hud_icons/` | `.webp` ou `.png`, ~64×64px |
| Spritesheet animada | `assets/sprites/weapons/<nome>/` | `.png` ou `.webp` |
| SpriteFrames animado | `assets/sprites/weapons/<nome>/<nome>_frames.tres` | `.tres` do Godot |

**Animações obrigatórias no `SpriteFrames`** (nomes exatos):

| Animação | Usado por | Regra |
|---|---|---|
| `idle` | Todos os archetypes | Loop contínuo enquanto equipado |
| `shoot` | Todos | Toca uma vez ao disparar |
| `charge_0` | `Charge` | Início da carga (0–33%) |
| `charge_1` | `Charge` | Meio da carga (33–66%) |
| `charge_2` | `Charge` | Carga máxima (66–100%), com efeito de pulso amarelo |

> Se a arma não tiver animações de `charge_*`, ela ainda funciona (ignora silenciosamente),
> mas o feedback visual ficará faltando.

---

### 3.2. Crie o Arquivo `.tres`

No Godot Editor:

1. No FileSystem, vá até `res://resources/cards/`.
2. Clique com o botão direito → **Novo Recurso**.
3. Na caixa de busca, procure por `CardData` e selecione.
4. Salve com o nome: `card_<nome_da_arma>.tres`  
   Exemplo: `card_shotgun.tres`, `card_laser.tres`.

> **Conveção de nomenclatura:** sempre `card_` como prefixo, em `snake_case`.

---

### 3.3. Preencha o Inspetor

Com o `.tres` aberto, preencha os campos:

#### 🔑 Identidade (obrigatórios)

| Campo | Tipo | Exemplo | Regra |
|---|---|---|---|
| `id` | String | `"card_shotgun"` | **Único no jogo, igual ao nome do arquivo** |
| `display_name` | String | `"Shotgun"` | Nome exibido na UI |
| `type` | Enum | `"Weapon"` | Selecione `Weapon` |
| `rarity` | Enum | `"Uncommon"` | Common / Uncommon / Rare / Epic / Legendary |
| `description` | String | `"Disparo em espingarda..."` | Texto para o tooltip |

#### 🎨 Visuals

| Campo | Tipo | Exemplo |
|---|---|---|
| `full_art` | Texture2D | Ícone importado de `hud_icons/` |
| `icon` | Texture2D | Mesmo ícone (ou arte separada no futuro) |

#### ⚙️ Weapon Archetype (determina o comportamento de tiro)

| Campo | Tipo | O que preencher |
|---|---|---|
| `weapon_archetype` | Enum | Veja a **Seção 7** para escolher o certo |
| `weapon_animations` | SpriteFrames | O `.tres` de animações que você criou |
| `spawn_offset` | Vector2 | Posição do projétil relativa ao jogador. Ex: `Vector2(70, -20)` |
| `is_automatic` | bool | `true` = mantém pressionado; `false` = clique por clique |

#### 📊 Base Stats

| Campo | Padrão | Descrição |
|---|---|---|
| `fire_rate` | `5.0` | Tiros por segundo. `12.0` = metralhadora, `1.0` = sniper. |
| `max_ammo` | `30` | Quantidade máxima de munição. |
| `reload_time` | `1.5` | Segundos para recarregar. |

#### 💥 Combat Stats — Para `Projectile` e `Throwable`

| Campo | Padrão | Descrição |
|---|---|---|
| `projectile_damage` | `1` | Dano por projétil. |
| `projectile_speed` | `1200.0` | Velocidade do projétil em px/s. |
| `projectile_knockback` | `90.0` | Força de empurrão no inimigo. |
| `weapon_recoil` | `30.0` | Empurrão no próprio jogador ao atirar. |

#### 🎯 Charge Stats — Para `Charge` (Arco, etc.)

| Campo | Padrão | Descrição |
|---|---|---|
| `max_charge_time` | `1.0` | Segundos para carga máxima. |
| `charge_damage_range` | `Vector2i(5, 20)` | Dano mín/máx (0% carga → 100% carga). |
| `charge_speed_range` | `Vector2(400, 1400)` | Velocidade min/max do projétil. |
| `charge_knockback_range` | `Vector2(100, 500)` | Knockback min/max. |
| `charge_recoil_range` | `Vector2(100, 800)` | Recuo no jogador min/max. |

#### 🎁 Assets Customizados

| Campo | Quando usar |
|---|---|
| `custom_projectile_scene` | Se precisar de um projétil especial (ex: granada que quica). Deixe vazio para usar o projétil padrão do template. |
| `weapon_id` | Legado. Se a carta representa uma arma, coloque aqui o nome da arma sem prefixo (ex: `"shotgun"`). Necessário para `get_weapon_id()`. |

#### 💰 Economia

| Campo | Padrão | Descrição |
|---|---|---|
| `sell_price` | `20` | Moedas recebidas ao vender. |
| `drop_weight` | `10.0` | Peso de drop. **Maior = mais comum.** Legendary = ~1.0, Common = ~15.0. |

---

### 3.4. Guia de Drop Weight por Raridade

> Estes valores são sugestões. Ajuste conforme o balanceamento do jogo.

| Raridade | `drop_weight` sugerido |
|---|:---:|
| Common | 15.0 |
| Uncommon | 10.0 |
| Rare | 5.0 |
| Epic | 2.0 |
| Legendary | 0.5 |

---

### 3.5. Teste no Jogo

1. Rode o projeto no Godot.
2. No console, verifique a linha:
   ```
   CardDatabase: X cartas carregadas: [card_smg, card_bow, card_shotgun, ...]
   ```
   O `id` da sua nova carta deve aparecer na lista.
3. Se não aparecer, verifique:
   - O campo `id` não está vazio.
   - O script do `.tres` é `CardData` (`card_data.gd`).
   - O arquivo está na pasta `res://resources/cards/`.

---

## 4. Passo a Passo: Criando uma Carta Passiva (Passive)

Cartas passivas aplicam bônus contínuos enquanto estão no loadout do jogador.
O sistema lê os campos do `CardData` diretamente.

### 4.1. Crie o `.tres`

Igual ao processo da Seção 3.2, mas salve como `card_<nome>.tres`.  
Exemplo: `card_armor.tres`, `card_bersk.tres`.

### 4.2. Campos relevantes

| Campo | Valor |
|---|---|
| `type` | `"Passive"` |
| `weapon_archetype` | `"None"` (deixe como está) |
| `flat_health_bonus` | `+X` de HP permanente (ex: `25`) |
| `speed_multiplier` | Multiplicador de velocidade (ex: `1.2` = +20% de velocidade) |
| `passive_scene` | Opcional: cena com lógica complexa de passiva (para passivas futuras) |

> **Bônus atuais implementados:** `flat_health_bonus` e `speed_multiplier`.
> Para criar passivas com efeitos customizados, consulte a seção de Player e implemente
> um nó de passiva dedicado apontado pelo campo `passive_scene`.

---

## 5. Passo a Passo: Criando uma Carta Ativa (Active)

> ⚠️ O sistema de cartas Ativas **ainda não está implementado** no gameplay.
> A estrutura de dados já existe no `CardData`, mas a lógica de ativação por tecla
> e cooldown precisará ser desenvolvida no Player/HUD.

Quando for implementado, o fluxo será:

| Campo | Valor |
|---|---|
| `type` | `"Active"` |
| `active_ability_id` | String identificando a habilidade (ex: `"dash"`, `"heal"`) |
| `cooldown` | Segundos de cooldown após uso |

---

## 6. Referência Completa de Campos

```
CardData
│
├── Identidade
│   ├── id                  : String     → ID único. Ex: "card_shotgun"
│   ├── display_name        : String     → Nome na UI
│   ├── type                : Enum       → "Weapon" | "Active" | "Passive"
│   ├── rarity              : Enum       → "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"
│   └── description         : String     → Texto multiline do tooltip
│
├── Visuals
│   ├── full_art            : Texture2D  → Arte do inventário
│   └── icon                : Texture2D  → Ícone do HUD
│
├── Weapon Archetype
│   ├── weapon_archetype    : Enum       → "None" | "Projectile" | "Charge" | "Throwable"
│   ├── weapon_animations   : SpriteFrames → Animações da arma equipada
│   ├── spawn_offset        : Vector2    → Offset do projétil
│   └── is_automatic        : bool       → Tiro contínuo ao segurar?
│
├── Base Stats
│   ├── fire_rate           : float      → Tiros/segundo
│   ├── max_ammo            : int        → Capacidade máxima
│   └── reload_time         : float      → Segundos para recarregar
│
├── Combat Stats (Projectile)
│   ├── projectile_damage   : int
│   ├── projectile_speed    : float
│   ├── projectile_knockback: float
│   └── weapon_recoil       : float
│
├── Charge Stats (Charge/Throwable)
│   ├── max_charge_time     : float
│   ├── charge_damage_range : Vector2i   → (min_dano, max_dano)
│   ├── charge_speed_range  : Vector2    → (min_vel, max_vel)
│   ├── charge_knockback_range: Vector2
│   └── charge_recoil_range : Vector2
│
├── Melee Stats
│   ├── melee_damage        : int          → Dano por acerto
│   ├── melee_range         : float        → Documentação do alcance (o shape real é a hitbox scene)
│   ├── melee_arc           : float        → Documentação do arco (o shape real é a hitbox scene)
│   ├── melee_knockback     : float        → Empurrão aplicado nos inimigos atingidos
│   ├── melee_hit_stun      : float        → Segundos que o inimigo fica parado (0 = nenhum)
│   └── melee_hitbox_scene  : PackedScene  → Cena com Area2D ajustável no editor por arma ⭐
│
├── Custom Assets
│   ├── melee_hitbox_scene  : PackedScene  → **Obrigatório** para armas Melee (Area2D)
│   ├── custom_projectile_scene: PackedScene → Projétil customizado
│   └── weapon_id           : String       → ID legado da arma
│
├── Passive Bonuses
│   ├── passive_scene       : PackedScene
│   ├── flat_health_bonus   : int
│   └── speed_multiplier    : float      → 1.0 = neutro, 1.2 = +20%
│
├── Active Abilities
│   ├── active_ability_id   : String
│   └── cooldown            : float
│
└── Economy
    ├── sell_price          : int        → Moedas ao vender
    └── drop_weight         : float      → Peso de drop (maior = mais comum)
```

---

## 7. Archetypes de Arma Disponíveis

O campo `weapon_archetype` determina qual script de comportamento será usado.

| `weapon_archetype` | Script usado | Comportamento | Exemplos |
|---|---|---|---|
| `"Projectile"` | `projectile_weapon.gd` | Dispara um projétil em direção ao mouse. Suporta tiro único e automático. | SMG, Pistola |
| `"Charge"` | `charge_weapon.gd` | Segura para carregar. Solta para disparar. Dano/velocidade escalam com a carga. Tem 3 estados visuais de carga. | Arco |
| `"Throwable"` | `throwable_weapon.gd` | Segura para aumentar o alcance do arremesso. Usa a cena do projétil com método `setup(dir, speed, charge_ratio)`. | Granada |
| `"Melee"` | `melee_weapon.gd` | Ataque corpo a corpo. Usa uma cena `Area2D` (`melee_hitbox_scene`) que você abre no editor e ajusta o `CollisionShape2D` livremente por arma. Sem projétil. | Espada, Faca, Machado |
| `"None"` | — | Nenhum comportamento de tiro. Usar apenas para cartas Passivas ou Ativas. | — |

---

## 8. Checklist Final

Antes de considerar uma carta pronta, verifique:

### Assets
- [ ] Ícone/sprite importado no projeto e sem erros no FileSystem
- [ ] `SpriteFrames` criado com as animações `idle`, `shoot` (e `charge_*` se for `Charge`)

### Arquivo `.tres`
- [ ] Salvo em `res://resources/cards/card_<nome>.tres`
- [ ] Campo `id` preenchido e **único** (mesmo nome do arquivo sem extensão)
- [ ] Campo `type` correto: `Weapon`, `Passive` ou `Active`
- [ ] Campo `rarity` definido
- [ ] Campo `display_name` e `description` preenchidos
- [ ] `full_art` e `icon` apontando para uma textura válida (não null)
- [ ] `weapon_archetype` correto para o tipo de arma
- [ ] `weapon_animations` apontando para o `SpriteFrames` correto
- [ ] `drop_weight` definido (não zero)
- [ ] `sell_price` definido

### Testes no jogo
- [ ] Nome da carta aparece no `print` do `CardDatabase` no console
- [ ] Carta aparece no inventário (via `GameManager.add_card_to_inventory("card_<nome>")` no debugger)
- [ ] A arma dispara corretamente após ser equipada no loadout
- [ ] O ícone aparece no HUD slot ao equipar
- [ ] A carta aparece na tela de inventário com arte e stats corretos
