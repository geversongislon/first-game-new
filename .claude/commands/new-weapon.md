---
name: new-weapon
description: Guia interativo para criar uma nova arma no projeto Godot 4. Faz perguntas sobre nome, arquétipo e stats, depois gera os arquivos necessários (.tres, cena do projétil, sprite placeholder).
---

Você é um assistente especializado neste projeto Godot 4. Sua tarefa é guiar a criação de uma nova arma completa.

## Contexto do projeto
- Leia o ARCHITECTURE.md para entender o sistema antes de começar
- Armas são data-driven: stats no CardData (.tres), lógica nos arquétipos
- Templates prontos: Projectile, Charge, Throwable, Melee
- Projéteis reutilizam projectile.gd (ou grenade.gd para explosão)

## Passo 1 — Perguntas básicas

Use o AskUserQuestion para coletar as seguintes informações em até 2 rodadas:

**Rodada 1 (4 perguntas simultâneas):**
1. Nome da arma e ID (ex: "Shotgun" / "card_shotgun")
2. Arquétipo: Projectile / Charge / Throwable / Melee
3. Stats básicos: dano, knockback, fire_rate, ammo_max, reload_time
4. Projétil especial? (visual novo, explosão em área, ricochete, ou usar padrão)

**Rodada 2 (se arquétipo for Charge ou Throwable):**
- Valores min/max de dano e velocidade de carga

## Passo 2 — Análise e decisão de arquivos

Com base nas respostas, determine:

### Sempre necessário:
- `resources/cards/card_ID.tres` — CardData completo

### Necessário apenas se projétil visual diferente:
- `scenes/weapons/projectile_ID.tscn` — cena do projétil (reutiliza projectile.gd)

### Necessário apenas se comportamento novo (ricochete, explosão custom, etc.):
- `scripts/weapons/projectile_ID.gd` — novo script de projétil
- `scenes/weapons/projectile_ID.tscn` — cena usando o novo script

### Necessário apenas se Melee com hitbox customizada:
- `scenes/weapons/hitboxes/hitbox_ID.tscn`

Informe o usuário quais arquivos serão criados e peça confirmação antes de gerar.

## Passo 3 — Gerar sprite provisório

Gere um sprite placeholder usando Python com Pillow (ou ImageMagick se Pillow não estiver disponível).

O sprite deve ser:
- Tamanho: 32x16 pixels para projéteis, 48x48 para armas melee/throwable
- Cor baseada no tipo: Projectile=amarelo, Charge=azul, Melee=cinza, Throwable=laranja
- Salvar em: `assets/sprites/weapons/projectile_ID.png` (ou `weapon_ID.png` para melee)
- Nome seguindo o padrão do projeto

Script Python para gerar o sprite:
```python
from PIL import Image, ImageDraw
import os

# Adapte cor e tamanho conforme o tipo
img = Image.new('RGBA', (LARGURA, ALTURA), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)
draw.rectangle([0, 0, LARGURA-1, ALTURA-1], fill=COR)
os.makedirs('assets/sprites/weapons', exist_ok=True)
img.save('assets/sprites/weapons/NOME.png')
```

Se Pillow não estiver disponível, use ImageMagick:
```bash
convert -size LARGURAxALTURA xc:"COR" assets/sprites/weapons/NOME.png
```

## Passo 4 — Gerar os arquivos

### Formato do CardData (.tres):
```
[gd_resource type="Resource" script_class="CardData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/card_data.gd" id="1_carddata"]

[resource]
script = ExtResource("1_carddata")
id = "card_ID"
card_name = "NOME"
type = "Weapon"
weapon_archetype = "ARQUÉTIPO"
projectile_damage = DANO
projectile_knockback = KNOCKBACK
fire_rate = FIRE_RATE
max_ammo = AMMO
reload_time = RELOAD
projectile_speed = VELOCIDADE
```

Adapte os campos conforme o arquétipo (use melee_damage para Melee, charge_damage_range para Charge, etc. conforme a Seção 5 do ARCHITECTURE.md).

### Formato de cena de projétil (.tscn) — apenas se necessário:
Baseie-se na estrutura de `scenes/weapons/projectile_smg.tscn` existente, ajustando:
- Script: `res://scripts/weapons/projectile.gd` (ou novo script se comportamento customizado)
- @export: `projectile_gravity`, `stick_on_hit` conforme o tipo
- CollisionShape2D: CapsuleShape2D para projéteis, CircleShape2D para granadas

## Passo 5 — Resumo final

Após criar os arquivos, exiba:
```
✓ Arma criada: NOME (card_ID)
  Arquivos gerados:
  - resources/cards/card_ID.tres
  - scenes/weapons/projectile_ID.tscn  (se aplicável)
  - assets/sprites/weapons/NOME.png    (placeholder)

  Próximos passos:
  1. Substituir o sprite placeholder em assets/sprites/weapons/
  2. Ajustar stats no inspetor do .tres se necessário
  3. Para testar: adicionar card_ID ao loadout no GameManager
```
