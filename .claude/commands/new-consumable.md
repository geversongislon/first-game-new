---
name: new-consumable
description: Guia interativo para criar uma nova carta Consumível no projeto Godot 4. Coleta nome, ID, cargas, tecla de ativação e efeito, depois gera script, cena (baseada no Kit Médico) e CardData .tres com ícone placeholder.
---

Você é um assistente especializado neste projeto Godot 4. Sua tarefa é guiar a criação de uma nova carta Consumível completa.

## Contexto do sistema de consumíveis

- Consumíveis têm cargas (`max_charges`) — ao usar esgota 1 carga; ao zerar, some do loadout
- Efeito executado via `BaseActiveAbility` → `execute()` → `queue_free()`
- `configure()` define `follow_player` e `spawn_offset` ANTES de `add_child`
- `CardDB` auto-carrega qualquer `.tres` em `resources/cards/` — sem registro manual
- Teclas disponíveis: `active_ability_f` (F) ou `active_ability_q` (Q)
- Animação padrão: reutilizar sprite/frames de `scenes/actives/active_health_regen.tscn`

## Passo 1 — Coletar informações

Use AskUserQuestion com estas perguntas (todas de uma vez):

1. **Nome e ID** — ex: "Bomba de Fumaça" / "card_smoke_bomb"
2. **Efeito** — o que acontece ao usar? (cura, escudo, buff de velocidade, etc.)
3. **Cargas máximas** — padrão é 3. Outro valor?
4. **Tecla de ativação** — F (`active_ability_f`) ou Q (`active_ability_q`)?
5. **Visual acompanha o player?** — `true` = segue (aura/buff), `false` = fica no lugar (efeito de ponto)
6. **Raridade** — Common / Uncommon / Rare / Epic

## Passo 2 — Confirmar arquivos que serão criados

Informe ao usuário:
```
Arquivos a criar:
- scripts/actives/active_ID.gd          ← lógica do efeito
- scenes/actives/active_ID.tscn         ← cena com sprite placeholder (baseado no Kit Médico)
- assets/sprites/ui/hud_icons/icon_ID.png  ← ícone 16x16 placeholder
- resources/cards/card_ID.tres          ← dados da carta (auto-registrado)
```

Peça confirmação antes de gerar.

## Passo 3 — Gerar ícone placeholder 16x16

Use Python para gerar um ícone colorido baseado na raridade:
- Common = `(180, 180, 180)` cinza
- Uncommon = `(100, 200, 100)` verde
- Rare = `(80, 130, 220)` azul
- Epic = `(180, 80, 220)` roxo

```python
from PIL import Image, ImageDraw
import os

cor = (R, G, B)  # baseado na raridade
img = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)
draw.rectangle([1, 1, 14, 14], fill=(*cor, 255))
draw.rectangle([1, 1, 14, 14], outline=(255, 255, 255, 180))
os.makedirs('assets/sprites/ui/hud_icons', exist_ok=True)
img.save('assets/sprites/ui/hud_icons/icon_ID.png')
print("Ícone criado")
```

Se Pillow não disponível:
```bash
convert -size 16x16 xc:"rgb(R,G,B)" -fill none -stroke white -draw "rectangle 1,1 14,14" assets/sprites/ui/hud_icons/icon_ID.png
```

## Passo 4 — Gerar o script do efeito

`scripts/actives/active_ID.gd`:
```gdscript
extends BaseActiveAbility
## Consumível: NOME
## DESCRIÇÃO DO EFEITO

func configure() -> void:
	follow_player = FOLLOW_PLAYER  # true ou false
	spawn_offset = Vector2(0, -24) # relevante só se follow_player = false

func execute() -> void:
	if player:
		# TODO: implementar efeito
		# Exemplos:
		# player.heal(20)
		# player.add_shield(15)
		# player.apply_speed_buff(1.5, 3.0)
		pass
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		sprite.play("life")
		sprite.animation_finished.connect(func(_n: StringName) -> void: queue_free(), CONNECT_ONE_SHOT)
	else:
		queue_free()
```

## Passo 5 — Gerar a cena .tscn

Copiar estrutura de `active_health_regen.tscn`, substituindo apenas o nome do nó raiz e o script.

`scenes/actives/active_ID.tscn`:
```
[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/actives/active_ID.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/sprites/regenvida.png" id="2_tex"]
[ext_resource type="Texture2D" path="res://assets/sprites/ui/luz.png" id="3_light"]

[sub_resource type="AtlasTexture" id="AtlasTexture_0"]
atlas = ExtResource("2_tex")
region = Rect2(0, 0, 48, 64)

[sub_resource type="AtlasTexture" id="AtlasTexture_1"]
atlas = ExtResource("2_tex")
region = Rect2(48, 0, 48, 64)

[sub_resource type="AtlasTexture" id="AtlasTexture_2"]
atlas = ExtResource("2_tex")
region = Rect2(96, 0, 48, 64)

[sub_resource type="AtlasTexture" id="AtlasTexture_3"]
atlas = ExtResource("2_tex")
region = Rect2(144, 0, 48, 64)

[sub_resource type="AtlasTexture" id="AtlasTexture_4"]
atlas = ExtResource("2_tex")
region = Rect2(192, 0, 48, 64)

[sub_resource type="AtlasTexture" id="AtlasTexture_5"]
atlas = ExtResource("2_tex")
region = Rect2(240, 0, 48, 64)

[sub_resource type="AtlasTexture" id="AtlasTexture_6"]
atlas = ExtResource("2_tex")
region = Rect2(288, 0, 48, 64)

[sub_resource type="SpriteFrames" id="SpriteFrames_0"]
animations = [{
"frames": [
{"duration": 1.0, "texture": SubResource("AtlasTexture_0")},
{"duration": 1.0, "texture": SubResource("AtlasTexture_1")},
{"duration": 1.0, "texture": SubResource("AtlasTexture_2")},
{"duration": 1.0, "texture": SubResource("AtlasTexture_3")},
{"duration": 1.0, "texture": SubResource("AtlasTexture_4")},
{"duration": 1.0, "texture": SubResource("AtlasTexture_5")},
{"duration": 1.0, "texture": SubResource("AtlasTexture_6")}
],
"loop": false,
"name": &"life",
"speed": 8.0
}]

[node name="ActiveNOME_SEM_ESPACOS" type="Node2D"]
script = ExtResource("1_script")

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
position = Vector2(0, -5)
sprite_frames = SubResource("SpriteFrames_0")
animation = &"life"

[node name="PointLight2D" type="PointLight2D" parent="AnimatedSprite2D"]
position = Vector2(0, -4)
scale = Vector2(0.143, 0.143)
color = Color(1, 0.1, 0.16, 1)
texture = ExtResource("3_light")
```

> Nota para o usuário: substitua o sprite em `AnimatedSprite2D` pelo asset final no editor do Godot.

## Passo 6 — Gerar o CardData .tres

`resources/cards/card_ID.tres`:
```
[gd_resource type="Resource" script_class="CardData" format=3]

[ext_resource type="Script" path="res://scripts/resources/card_data.gd" id="1_data"]
[ext_resource type="Texture2D" path="res://assets/sprites/ui/hud_icons/icon_ID.png" id="2_icon"]
[ext_resource type="PackedScene" path="res://scenes/actives/active_ID.tscn" id="3_scene"]

[resource]
script = ExtResource("1_data")
id = "card_ID"
display_name = "NOME"
type = "Consumable"
rarity = "RARIDADE"
description = "DESCRIÇÃO"
icon = ExtResource("2_icon")
max_charges = MAX_CHARGES
charge_cooldown = 0.5
activation_input_action = "TECLA"
active_scene = ExtResource("3_scene")
sell_price = 15
drop_weight = 8.0
```

## Passo 7 — Resumo final

Após criar todos os arquivos, exibir:
```
✓ Consumível criado: NOME (card_ID)

  Arquivos gerados:
  - scripts/actives/active_ID.gd
  - scenes/actives/active_ID.tscn   ← sprite placeholder (Kit Médico)
  - assets/sprites/ui/hud_icons/icon_ID.png  ← ícone placeholder
  - resources/cards/card_ID.tres    ← auto-registrado no CardDB

  Próximos passos:
  1. Implementar o efeito em active_ID.gd (onde está o TODO)
  2. Substituir sprite em scenes/actives/active_ID.tscn no editor do Godot
  3. Substituir ícone em assets/sprites/ui/hud_icons/icon_ID.png
  4. Ajustar stats no inspetor do .tres se necessário
```
