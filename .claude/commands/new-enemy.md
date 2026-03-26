---
name: new-enemy
description: Guia interativo para criar um novo inimigo no projeto Godot 4. Coleta nome, arquétipo de movimento, comportamento de ataque e stats, depois gera a cena .tscn, script customizado (se necessário) e sprite placeholder.
---

Você é um assistente especializado neste projeto Godot 4. Sua tarefa é guiar a criação de um novo inimigo completo.

## Contexto do projeto

Antes de começar, leia os seguintes arquivos para entender o sistema:
- `scripts/actors/enemy.gd` — base class com todos os exports, estados e sistemas
- `scripts/attacks/ranged_projectile.gd`, `melee_swing.gd`, `melee_pounce.gd` — behaviors disponíveis
- `scenes/actors/enemy_basico.tscn` — exemplo mínimo de cena (herda enemy.tscn, só sobrescreve props)
- `scenes/actors/enemy_rat.tscn` — exemplo com script customizado e sprite próprio

**Regras fundamentais:**
- Toda cena de inimigo herda `scenes/actors/enemy.tscn`
- Script customizado só é necessário se o inimigo tiver comportamento ÚNICO (animação especial, estado extra, mecânica própria)
- Inimigos simples (walker, ranged estático, voador padrão) NÃO precisam de script novo — apenas sobrescrever props no .tscn

---

## Passo 1 — Coletar informações

Use AskUserQuestion para coletar em **2 rodadas**:

**Rodada 1 (4 perguntas simultâneas):**
1. **Nome e ID** — Ex: "Goblin" / "enemy_goblin"
2. **Arquétipo de movimento:**
   - `Walker` — patrulha no chão, segue o player
   - `Ranged Walker` — patrulha, mantém distância e atira
   - `Stationary Ranged` — imóvel, ataca à distância (tipo Sentinela)
   - `Pouncer` — patrulha no chão, pula sobre o player (tipo Rat)
   - `Flying` — voa, persegue o player em órbita ou direto
   - `Boss` — comportamento customizado, precisa de script próprio
3. **Stats** — HP, velocidade, dano de ataque, knockback, alcance de detecção
4. **Comportamento especial?** — animação única, mecânica extra, ou padrão puro?

**Rodada 2 (apenas se Ranged):**
- wind_up (s de preparação antes de atirar), cooldown entre tiros, velocidade do projétil, burst (0=desativado, N=tiros por rajada)

---

## Passo 2 — Decisão de arquivos

Com base nas respostas, determine:

### Sempre necessário:
- `scenes/actors/enemy_ID.tscn` — herda enemy.tscn, sobrescreve stats no nó raiz
- `assets/sprites/actors/enemy_ID.png` — sprite placeholder (16×16 px padrão)

### Necessário apenas se comportamento ÚNICO:
- `scripts/actors/enemy_ID.gd` — extends "res://scripts/actors/enemy.gd"

**Quando NÃO criar script:**
- Walker simples → apenas `follow_on_detect = true`, `movement_style = PATROL`
- Ranged estático → `movement_style = STATIONARY`, attach RangedProjectile
- Voador padrão → `is_flying = true`, `follow_on_detect = true`
- Pouncer sem sniff/animação especial → apenas attach MeleePounce

**Quando criar script:**
- Animação personalizada (ex: "sniff" do Rat, "wander" do Sentinela)
- Estado extra (ex: full_attack_timer do Sentinela)
- Mecânica de boss (fase 2, enrage, padrão de movimento único)

Informe ao usuário os arquivos que serão criados e peça confirmação.

---

## Passo 3 — Gerar sprite placeholder

Gere um sprite 16×16 placeholder usando Python com Pillow (ou ImageMagick como fallback).

**Cores por arquétipo:**
- Walker → vermelho escuro `(140, 30, 30)`
- Ranged → roxo `(100, 30, 140)`
- Stationary → cinza `(90, 90, 90)`
- Pouncer → laranja escuro `(160, 80, 20)`
- Flying → azul escuro `(30, 60, 140)`
- Boss → dourado `(180, 140, 20)`

```python
from PIL import Image, ImageDraw
import os

img = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)
draw.rectangle([1, 1, 14, 14], fill=COR)
# Olho simples (branco 2x2 no centro-alto)
draw.rectangle([5, 4, 6, 5], fill=(255, 255, 255, 255))
draw.rectangle([9, 4, 10, 5], fill=(255, 255, 255, 255))
os.makedirs('assets/sprites/actors', exist_ok=True)
img.save('assets/sprites/actors/enemy_ID.png')
```

Se Pillow não estiver disponível:
```bash
convert -size 16x16 xc:"rgb(R,G,B)" assets/sprites/actors/enemy_ID.png
```

---

## Passo 4 — Gerar os arquivos

### Formato da cena .tscn (herança mínima):

**Walker simples (sem script):**
```
[gd_scene format=3 uid="uid://PLACEHOLDER"]

[ext_resource type="PackedScene" uid="uid://di8qg0ho8kb82" path="res://scenes/actors/enemy.tscn" id="1_base"]
[ext_resource type="Script" uid="uid://SWING_UID" path="res://scripts/attacks/melee_swing.gd" id="2_swing"]

[sub_resource type="Resource" id="Resource_swing"]
script = ExtResource("2_swing")
wind_up = 0.3
cooldown = 1.2
metadata/_custom_type_script = "uid://SWING_UID"

[node name="Enemy_ID" instance=ExtResource("1_base")]
max_health = HP
speed = SPEED
movement_style = 0
follow_on_detect = true
detection_range = DETECTION
attack_behavior = SubResource("Resource_swing")
attack_damage = DAMAGE
attack_knockback = KNOCKBACK
attack_range = RANGE
contact_damage = CONTACT_DMG
card_drop_chance = 0.05
min_gold = 3
max_gold = 10
```

**Ranged Walker:**
```
[gd_scene format=3 uid="uid://PLACEHOLDER"]

[ext_resource type="PackedScene" uid="uid://di8qg0ho8kb82" path="res://scenes/actors/enemy.tscn" id="1_base"]
[ext_resource type="PackedScene" uid="uid://dajq6eejldnxi" path="res://scenes/weapons/enemy_projectile.tscn" id="2_proj"]
[ext_resource type="Script" uid="uid://c43w7npygftgi" path="res://scripts/attacks/ranged_projectile.gd" id="3_ranged"]

[sub_resource type="Resource" id="Resource_ranged"]
script = ExtResource("3_ranged")
wind_up = WIND_UP
cooldown = COOLDOWN
projectile_scene = ExtResource("2_proj")
projectile_speed = PROJ_SPEED
metadata/_custom_type_script = "uid://c43w7npygftgi"

[node name="Enemy_ID" instance=ExtResource("1_base")]
max_health = HP
speed = SPEED
follow_on_detect = true
detection_range = DETECTION
keep_distance = KEEP_DIST
attack_behavior = SubResource("Resource_ranged")
attack_damage = DAMAGE
attack_knockback = KNOCKBACK
attack_range = ATTACK_RANGE
card_drop_chance = 0.05
min_gold = 3
max_gold = 10
```

**Flying:**
```
[node name="Enemy_ID" instance=ExtResource("1_base")]
max_health = HP
speed = SPEED
is_flying = true
follow_on_detect = true
detection_range = DETECTION
keep_distance = KEEP_DIST
# ... resto do ataque igual ao Ranged ou Melee
```

**Stationary Ranged (sem follow):**
```
[node name="Enemy_ID" instance=ExtResource("1_base")]
max_health = HP
speed = 0.0
movement_style = 3
follow_on_detect = false
detection_range = DETECTION
# ... attach RangedProjectile igual ao Ranged Walker
```

### Formato do script customizado (apenas se necessário):

```gdscript
extends "res://scripts/actors/enemy.gd"

## Enemy_ID — descrição do comportamento único

@export_group("Enemy_ID")
@export var PARAM_ESPECIFICO: float = VALOR

# Estado extra (se necessário)
var _estado: bool = false

func _ready() -> void:
    super._ready()
    # inicialização específica

# Sobrescrever APENAS os métodos que precisam de comportamento diferente:
# - _get_body_animation() → animação personalizada
# - _move_patrol() → patrulha customizada
# - _tick_eye() → cor/posição do olho
# - take_damage() → reação especial ao dano
# NÃO copiar métodos da base — apenas sobrescrever o que for diferente
```

**Exports disponíveis no EnemyBase (não redeclarar):**
- Stats: `max_health`, `speed`, `gravity`
- Movimento: `movement_style`, `is_flying`, `follow_on_detect`, `detection_range`, `keep_distance`, `max_fall_height`
- Jump: `can_jump_obstacles`, `jump_force`, `can_climb_walls`, `max_climb_height`
- Ataque: `attack_behavior`, `attack_damage`, `attack_knockback`, `attack_range`
- Contato: `contact_damage`, `contact_knockback`, `contact_damage_cooldown`
- Loot: `card_drop_chance`, `min_gold`, `max_gold`, `health_drop_chance`

---

## Passo 5 — Resumo final

Após criar os arquivos, exibir:

```
✓ Inimigo criado: NOME (enemy_ID)

  Arquivos gerados:
  - scenes/actors/enemy_ID.tscn
  - scripts/actors/enemy_ID.gd    (se comportamento customizado)
  - assets/sprites/actors/enemy_ID.png  (placeholder 16×16)

  Para usar em áreas:
  1. Abrir um SpawnPoint na área desejada
  2. Setar enemy_scene = scenes/actors/enemy_ID.tscn
  3. Ajustar spawn_chance e spawn_interval no inspetor

  Próximos passos:
  - Substituir o sprite placeholder pelo sprite final
  - Configurar animações no Sprite2D/SpriteFrames (idle, walking, jump)
  - Ajustar collision shape no inspetor se o corpo for diferente do padrão
  - Para boss: considerar adicionar can_respawn = false no SpawnPoint
```
