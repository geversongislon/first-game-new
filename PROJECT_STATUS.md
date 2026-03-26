# Geometrics Cards - Status do Projeto

Este documento resume o estado atual do desenvolvimento, o que já está funcional e o que ainda falta para o MVP.

*Última atualização: 18/03/2026*

---

## Como Rodar

1. Abra o projeto no **Godot 4.x**
2. Cena principal: `res://scenes/ui/ui_main_menu.tscn`
3. Controles: `A/D` mover, `Espaço` pular, `Mouse Esq.` atacar, `E` interagir, `Tab` mochila, `1/2/3` trocar arma, `R` recarregar, `Q` próxima arma

**Debug (apenas build de desenvolvimento):**
- `Shift+R` — zera o save
- `Shift+9` — adiciona 3 pistolas ao baú e desbloqueia todas as zonas

---

## Sistemas Implementados

### Player
- Movimentação com aceleração/desaceleração independente no chão e no ar
- Pulo com Coyote Time (0.12s), Jump Buffer (0.15s) e Jump Cut (altura controlada)
- Pulo Duplo via carta passiva (`card_puloduplo`)
- Knockback direcional recebido de inimigos e de recuo de armas
- Sistema de vida com flash branco ao receber dano
- Morte com "loot fountain" (dispersa moedas + cartas ao redor)
- `is_dead` guard — impede dano e loot duplo após a morte
- Olhos cosméticos que seguem direção do movimento
- Toggle de mochila (`Tab`) que congela inputs de ataque/pulo

### Sistema de Armas
- **4 arquétipos** de arma definidos por `CardData`:
  - `Projectile` — automático ou semi (SMG, Pistola)
  - `Charge` — dano/velocidade escalam com tempo de carregamento (Arco)
  - `Throwable` — velocidade de arremesso escala com carga (Granada)
  - `Melee` — hitbox em arco, hit stun configurável (Espada)
- 3 slots de loadout com troca por tecla (1/2/3) ou ciclo (Q)
- **Stacking**: cartas duplicadas dão bônus multiplicadores de stats (×2, ×3)
- Gerenciamento de munição com recarga automática ao esvaziar
- Recuo aplicado ao player na direção oposta ao tiro
- Cenas de projétil customizáveis por carta
- **Critical Hit**: `crit_chance` e `crit_multiplier` por carta; números de dano em laranja com `!` nos crits
- **Visual por arma**: cada arma tem cena própria (`WeaponVisual`) com sprite + luzes + SpawnPoint — editável no inspetor sem tocar em código
- **Sniper**: projétil penetrante com raycast anti-tunneling, dano escala com distância (até 3×), partículas de impacto na parede (cor configurável no inspetor)

### Sistema de Cartas
- **CardDB** — banco de dados estático carregado de `resources/cards/*.tres`
- **3 tipos**: Weapon (arma), Passive (passiva permanente), Active (habilidade ativa)
- **5 raridades**: Common, Uncommon, Rare, Epic, Legendary
- **8 cartas implementadas**:
  - SMG (Projectile, Uncommon)
  - Pistola (Projectile, Rare)
  - Arco (Charge, Rare)
  - Granada (Throwable, Rare)
  - Espada (Melee, Uncommon)
  - MAX VIDA — +50 HP permanente (Passive, Rare)
  - Speed — bônus de velocidade (Passive, Uncommon)
  - Pulo Duplo — extra jump (Passive, Epic)
- Seleção aleatória ponderada por `drop_weight`

### Sistema de Passivas
- Instanciadas automaticamente pelo WeaponManager ao equipar
- `passive_health` — adiciona HP máximo; segurança de desequipar (não pode remover se matar o player)
- `passive_double_jump` — incrementa max_jumps
- `passive_speed` — bônus de velocidade máxima
- Limpeza automática via `_exit_tree()` ao desequipar

### Inimigos
- **3 estados de vida**: ALIVE → DEAD
- **3 estados de movimento** independentes: PATROL, CHASE, STUNNED
- **2 tipos de ataque** independentes do movimento: MELEE, RANGED
- `follow_on_detect` — controla se o inimigo persegue ao detectar o player
- **`keep_distance`** — inimigo mantém distância preferida do player enquanto atira; recua se muito perto, para na zona ideal
- Dano de contato (contact damage) com cooldown, funciona mesmo com player em cima do inimigo
- Knockback configurável por inimigo (`attack_knockback`, `contact_knockback`)
- Drop de ouro (min/max configurável) e chance de drop de carta
- Barra de vida flutuante + números de dano
- Flash branco ao receber dano
- Suporte a inimigos voadores (`is_flying`) com patrulha aérea
- **Wall-loop fix**: timer real no STUNNED, cooldown pós-stun no jump, wall ray corrigido, `patrol_ray_distance=18`, `_check_patrol_stuck()` como fallback

### Loot & Pickups
- **Master Pickup** — sistema unificado para qualquer carta/item
  - Física manual (gravidade + quique)
  - Suporte `@tool` no editor (luz e ícone mudam em tempo real)
  - Modo aleatório (drop de carta randômica por tipo)
  - Loot fountain ao morrer
  - Cooldown de 1.2s antes de poder pegar
  - Partículas de coleta em arco (ColorRect, LIGHT_MODE_UNSHADED) + PointLight2D fade
- **Pickup Coin** — moeda com física, partículas âmbar ao coletar e PointLight2D fade
- **Pickup Health** — poção com física, partículas vermelhas ao coletar e PointLight2D fade

### Progressão & Loop de Run
- **Tela de seleção de extração** (`ui_run_selection.tscn`) — escolha do ponto de entrada
- **3 zonas de extração**: ext_0 (início, sempre disponível), ext_1, ext_2
- Cada zona desbloqueada ao extrair por ela — sem sequência obrigatória
- Player spawna no Marker2D correspondente ao ponto escolhido
- Progressão salva no arquivo de save entre sessões
- **Timer de Run**: 10 minutos de contagem regressiva no topo da tela
  - Pisca vermelho nos últimos 30 segundos
  - Player morre ao chegar a zero

### ExtractionZone
- Segurar `E` por 2 segundos para extrair
- Barra de progresso visual
- Transfere mochila da run para o inventário permanente
- Sincroniza loadout equipado → LoadoutManager → save
- Desbloqueia a própria zona como spawn futuro
- Retorna ao menu principal

### Inventário & Menu Principal
- Grid de inventário com drag-and-drop
- 3 slots de loadout editáveis no menu
- 5 slots de mochila durante a run (Tab para abrir)
- Venda de cartas com preço por raridade
- Ordenação por raridade e tipo
- Visualização de stacks (bordas coloridas, badges ×2/×3, linhas conectoras)
- Dois tipos de moeda: `run_coins` (temporárias) e `total_coins` (permanentes)

### HUD In-Game
- Barra de vida (canto superior esquerdo)
- Contador de moedas da run com ícone de coin
- 3 slots de arma com ícone, badge de stack e overlay de cooldown
- 5 indicadores de mochila
- Timer de run (topo centralizado)
- HUD definido visualmente na cena `.tscn` — todos os elementos editáveis no inspetor
- Números de dano sempre visíveis (LIGHT_MODE_UNSHADED) — crits em laranja maior com `!`
- Stance indicator (ponto colorido) no topo do sprite da arma — vermelho em movimento, verde pronto para atirar

### Ambiente & Visual
- **Background procedural de cidade** (`scripts/props/background_city.gd`) — CanvasLayer com layer=-1
  - 3 camadas de parallax (speeds 0.01 / 0.04 / 0.08)
  - Prédios gerados por seed fixa com 8 variações de silhueta
  - 25% dos prédios são largos/horizontais
  - Janelas âmbar sutis, scroll seamless via `fposmod`

### Save System
- Arquivo: `user://savegame.cfg` (ConfigFile)
- Seções: `[Inventory]` (moedas, cartas, loadout) e `[Progression]` (zonas desbloqueadas)
- Validação ao carregar — remove IDs inválidos de bugs anteriores
- Salva automaticamente ao equipar, coletar, vender e extrair

### Autoloads (Singletons)
| Nome | Script | Função |
|------|--------|--------|
| `GameManager` | game_manager.gd | Estado da run, inventário, save/load, progressão |
| `LoadoutManager` | loadout_manager.gd | Sincroniza 3 slots equipados entre cenas |
| `CardDatabase` | card_database.gd | Banco de dados de cartas (acesso estático) |

---

## Roadmap

### Fase 1 — Completar o Loop Jogável (Demo Fechada)

Objetivo: ter uma run completa e jogável do início ao fim, mesmo que curta.

**Mundo & Level Design**
- [ ] Fase 1 jogável com início, meio e zona de extração
- [ ] Spawn points de inimigos distribuídos com densidade equilibrada
- [ ] Pelo menos 1 sala de loot garantida por fase (recompensa de exploração)
- [ ] Tileset e iluminação da fase 1 finalizados

**Boss**
- [ ] Boss simples ao final da fase 1 (padrão de ataque único + fase de fúria)
- [ ] Drop especial ao derrotar o boss (carta rara garantida)

**Inimigos**
- [ ] Pelo menos 3 tipos distintos com comportamentos diferentes (melee, ranged, voador)
- [ ] Variações visuais para diferenciar inimigos do mesmo tipo por zona

**Cartas**
- [ ] Expandir de 8 para ~15 cartas (ao menos 3-4 novas armas, 2-3 passivas, 1 ativa nova)
- [ ] Sniper implementado como carta (`card_sniper.tres` com `weapon_visual_scene`)
- [ ] Garantir que cada arquétipo tenha ao menos 2 opções de arma

---

### Fase 2 — Sistemas de Progressão e Meta

**Loja In-Run**
- [ ] Loja entre salas: comprar cartas com `run_coins`
- [ ] Interface simples (3 cartas aleatórias, preço por raridade)
- [ ] Integração com `GameManager.run_coins`

**Habilidades Ativas**
- [ ] Pelo menos 2 habilidades ativas além do dash (ex: escudo temporário, explosão)
- [ ] Feedback visual de cooldown já funciona — só precisa das cenas `active_*.tscn`

**Progressão Permanente**
- [ ] Moeda permanente (`total_coins`) com uso real no menu (desbloquear cartas no pool)
- [ ] Tela de meta-progressão no menu principal

**Balanceamento**
- [ ] Revisar dano/vida de todos os inimigos vs. DPS das armas
- [ ] Revisar `drop_weight` das cartas para raridades fazerem sentido
- [ ] Stack bonus calibrado (2× e 3× não podem trivializar o jogo)

---

### Fase 3 — Polimento e Juice

**Audio**
- [ ] SFX: tiro por arma (pistola ≠ sniper ≠ espada), dano recebido, morte de inimigo
- [ ] SFX: coleta de carta, moeda, recarregamento, extração concluída
- [ ] Trilha sonora: 1 música de fase + 1 música de menu

**VFX**
- [x] Partículas de impacto na parede (sniper)
- [x] Partículas de impacto em inimigos (sangue/faíscas genéricas)
- [x] VFX de explosão da granada
- [ ] VFX de extração (flash + partículas ao completar)
- [x] Screen shake ao tomar dano e ao disparar armas pesadas (sniper, granada)

**Feedback & Feel**
- [ ] Tela de Game Over dedicada (ao invés de voltar direto ao menu)
- [ ] Tela de vitória / extração com resumo da run (dano total, kills, cartas coletadas)
- [ ] Animação de morte de inimigo (ragdoll simples ou explosão de pixels)
- [ ] Câmera com leve lerp e shake — atualmente é estática

---

### Fase 4 — Expansão de Conteúdo (Pós-MVP)

- [ ] Fase 2 com tileset diferente e novos inimigos
- [ ] Sistema de salas procedurais ou semi-procedurais
- [ ] Mais arquétipos de arma (ex: shotgun / burst / ricochete)
- [ ] Sistema de relíquias/passivas globais de run (bônus persistentes durante a run)
- [ ] Suporte a múltiplos saves / perfis de jogador
