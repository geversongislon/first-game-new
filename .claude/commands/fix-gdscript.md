---
name: fix-gdscript
description: Varre todos os scripts GDScript do projeto em busca de erros comuns (stray chars, enums inválidos, signals desconectados, métodos inexistentes) e corrige automaticamente o que for seguro.
---

Você é um assistente especializado neste projeto Godot 4. Sua tarefa é **encontrar e corrigir erros comuns em GDScript** antes que causem bugs em runtime ou parse errors.

## Passo 1 — Varredura completa

Use o Glob para listar todos os arquivos `.gd` do projeto:
- `scripts/**/*.gd`

Para cada arquivo encontrado, leia e inspecione os seguintes problemas:

---

## Categorias de erros a verificar

### 🔴 Críticos (causam parse error / crash)

**1. Stray characters no início de linha**
Linhas que começam com um caractere solto antes de whitespace/código:
```
d		var x = ...      ← 'd' solto
s	func foo():         ← 's' solto
```
Fix: remover o caractere solto mantendo a indentação correta.

**2. Enums e constantes inexistentes**
Verificar usos comuns que mudam entre versões do Godot 4:
- `TextServer.AUTOWRAP_NO` → deve ser `TextServer.AUTOWRAP_OFF`
- `TextServer.AUTOWRAP_WORD` → verificar se existe
- `Control.SIZE_FILL` sem namespace → verificar se é `Control.SizeFlags.FILL`
- `Tween.TRANS_*` e `Tween.EASE_*` → verificar se os nomes batem

**3. Métodos chamados em null sem guard**
Padrão: `node.metodo()` sem `if is_instance_valid(node)` ou `if node:`

**4. `await` fora de função `async` ou em contexto errado**
`await` dentro de `_ready()` é permitido, mas `await` dentro de um lambda passado para `connect()` pode causar problemas.

---

### 🟡 Avisos (causam bugs silenciosos)

**5. Signals conectados manualmente que já existem no .tscn**
Padrão no projeto: se o `.tscn` tem uma entrada `[connection]`, NÃO conectar manualmente no `_ready()` — duplica a conexão.

**6. `randf()` usado onde deveria ser `randf_range()`**
`randf()` retorna 0.0–1.0. Verificar se o contexto exige um range específico.

**7. Variáveis declaradas mas nunca usadas**
Especialmente `var _foo` sem uso — pode indicar refactor incompleto.

**8. `get_node()` hardcoded sem `get_node_or_null()`**
Nós que podem não existir devem usar `get_node_or_null()` para evitar crash.

---

### 🔵 Padrões do projeto (consistência)

**9. SceneManager não respeitado**
Uso de `get_tree().change_scene_to_file()` diretamente — deve ser `SceneManager.go_to()` ou `SceneManager.load_area()`.

**10. `Engine.time_scale` para timing**
Timers críticos (hitstop, stun) devem usar `Time.get_ticks_msec()`, não `delta` acumulado (que é afetado por `Engine.time_scale`).

**11. Recursos compartilhados sem `.duplicate()`**
Resources passados como `@export` e modificados em runtime devem ser duplicados no `_ready()` para não afetar todas as instâncias.

---

## Passo 2 — Reportar antes de corrigir

Antes de fazer qualquer edição, liste todos os problemas encontrados no formato:

```
ARQUIVO: scripts/ui/loot_box_choice_ui.gd
  🔴 Linha 131: stray char 'd' antes de 'name_lbl.autowrap_mode'
  🔴 Linha 131: TextServer.AUTOWRAP_NO não existe → deve ser AUTOWRAP_OFF

ARQUIVO: scripts/interactables/loot_box.gd
  🔴 Linha 98: stray char 'd' antes de 'var ui = choice_ui_scene.instantiate()'

ARQUIVO: scripts/actors/player.gd
  🟡 Linha 45: get_node("Weapon") sem guard — pode crashar se nó não existir
```

Se não encontrar nenhum problema: informar "✓ Nenhum erro encontrado em X arquivos verificados."

---

## Passo 3 — Confirmar e corrigir

Perguntar ao usuário:
> "Encontrei N problemas. Corrigir todos os 🔴 críticos automaticamente? Os 🟡 avisos precisam de revisão manual."

Se confirmado:
- Usar Edit para corrigir **apenas os críticos** (🔴)
- Para cada fix: mostrar o antes/depois da linha
- Não alterar lógica — apenas corrigir o erro sintático/semântico

Os 🟡 e 🔵 devem ser listados para o usuário decidir manualmente.

---

## Passo 4 — Resumo final

```
✓ Fix-GDScript concluído

  Arquivos verificados: N
  Problemas encontrados: X críticos, Y avisos, Z padrões

  Corrigidos automaticamente (🔴):
  - scripts/ui/loot_box_choice_ui.gd:131 — stray 'd' + AUTOWRAP_OFF
  - scripts/interactables/loot_box.gd:98  — stray 'd'

  Revisar manualmente (🟡):
  - scripts/actors/player.gd:45 — get_node sem guard

  Padrões violados (🔵):
  - (nenhum)
```
