# CLAUDE.md — Instruções permanentes para este projeto

## Sobre o jogo

Roguelike 2D de ação em pixel art. O player percorre áreas sequenciais em runs, coletando cartas (armas, ativos, passivos) e ouro. Cada run é independente — o que persiste entre runs é o desbloqueio de cartas e progresso de meta.

**Identidade do jogo:** risco e recompensa constantes, builds emergentes via cartas, inimigos com comportamento distinto, game feel satisfatório (hitstop, knockback, shake).

---

## Comportamento esperado de mim (Claude)

### Senso crítico de game designer

Antes de implementar qualquer feature de gameplay, verificar:

- **Quebra o loop?** A feature remove risco, torna o jogo trivial ou elimina decisões interessantes?
- **Incentivo errado?** Pode criar comportamento não intencional no jogador (farming, cheese, exploits)?
- **Consistência com roguelike?** Faz sentido num sistema run-based com risco de perder progresso?
- **Interação não intencional?** Combina mal com sistemas existentes (loot, spawns, save)?

Se detectar risco, **alertar antes de implementar** — não apenas executar o que foi pedido.

Exemplos de alertas que devo dar:
- "Isso pode remover rejogabilidade porque..."
- "Com esse valor, o sistema vai se comportar diferente do esperado em..."
- "Isso conflita com X que já existe — considerar usar o mesmo sistema"

### Organização e arquitetura

- **Nunca fazer gambiarra** — se a solução certa exige refatorar, apontar isso ao invés de contornar
- **Preferir estender sistemas existentes** a criar arquivos novos (ex: flag no card_data antes de novo script)
- **Alertar acoplamento** — se uma implementação vai dificultar mudanças futuras, dizer antes
- Manter o código legível para futuras sessões: sem lógica escondida, sem hacks silenciosos

### Atualização contínua do projeto

- Ao implementar algo relevante, verificar se algum skill ou memória precisa ser atualizado
- Se o usuário mencionar uma decisão de design nova, salvar em memória imediatamente
- Manter o entendimento do estado atual do jogo — não assumir que está igual à última sessão

---

## Regras técnicas obrigatórias

### Navegação de cenas
- **Nunca** usar `change_scene_to_file()` diretamente
- Sempre: `SceneManager.go_to()` ou `SceneManager.load_area()`
- `swap_area_now()` apenas no `_ready()` da run (go_to já gerencia o fade)

### UI
- Toda tela/popup deve ser uma **cena .tscn editável no Godot** — nunca construída 100% em código
- Cores no estilo **pixel art escuro** (paleta escura, contrastes fortes, sem gradientes suaves)
- Visual próximo ao **main_menu** — usar como referência de estilo
- **Pips de nível** devem ser idênticos em todos os lugares (tamanho, cor, espaçamento, posição)

### Timing
- Timers críticos (hitstop, stun, slow-mo) usam `Time.get_ticks_msec()` — imune a `Engine.time_scale`
- Nunca acumular `delta` para timing de game feel

### Resources compartilhados
- Resources `@export` modificados em runtime devem ser `.duplicate()` no `_ready()`

### Sistema de armas
- Comportamentos específicos vão no arquétipo com flag do `card_data` (ex: `has_scope`)
- Não existe `custom_weapon_scene` — foi descartado

---

## Arquitetura — referência rápida

```
ui_main_menu → ui_run_selection → run.tscn (Player + WorldContainer)
                                       ↓ swap_area_now() no _ready()
                                  WorldContainer/area_01.tscn
                                       ↓ ExitZone → load_area()
                                  WorldContainer/area_02.tscn
```

**Sistemas principais:**
- `SceneManager` — autoload, gerencia todas as transições
- `GameManager` — autoload, save/load, estado da run
- `enemy.gd` — base com 3 estados independentes: LifeState / MoveMode / AttackPhase
- `attack_behavior.gd` — Resource base; subclasses: MeleeSwing, MeleePounce, RangedProjectile
- `card_data.gd` — Resource data-driven para armas, ativos e passivos

**Antes de implementar algo novo:**
1. Verificar se já existe sistema para isso
2. Preferir flag/parâmetro no sistema existente antes de criar arquivo novo
3. Só criar arquivo novo se o comportamento for realmente exclusivo e complexo
