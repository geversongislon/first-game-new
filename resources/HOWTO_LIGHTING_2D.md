# Guia de Iluminação 2D no Godot 4

Siga estes passos para criar um sistema de iluminação dinâmico com sombras no seu jogo.

![Estrutura de Nós](file:///Users/geversongislon/.gemini/antigravity/brain/9a3ca44a-f51b-486e-848d-1f6c4aa202e0/godot_lighting_2d_hierarchy_guide_1773081303223.png)

## 1. Criando a "Noite" (Escurecer o Mundo)
Para que as luzes apareçam, o cenário precisa estar escuro.
1. Na sua cena principal (ex: `main.tscn`), adicione um nó **CanvasModulate**.
2. No Inspetor, mude a propriedade **Color**.
   - Escolha um azul escuro ou preto.
   - Note que tudo na tela ficará dessa cor.

## 2. Adicionando a Luz (PointLight2D)
Agora vamos iluminar ao redor do jogador.
1. Clique com o botão direito no seu nó **Player** e adicione um **PointLight2D**.
2. No Inspetor, procure a propriedade **Texture**.
   - Você precisará de uma imagem de "luz" (um círculo branco com degradê suave). 
   - *Dica: Se não tiver uma, pode usar qualquer sprite circular e ajustar a escala.*
3. Ajuste a **Scale** para aumentar o tamanho do brilho.
4. Ajuste a **Energy** para controlar a intensidade.

## 3. Configurando as Sombras (LightOccluder2D)
Para a luz não atravessar as paredes e criar sombras:
1. Selecione o nó que representa suas paredes (pode ser o **TileMap** ou um **StaticBody2D**).
2. Adicione um filho chamado **LightOccluder2D**.
3. No Inspetor, na propriedade **Occluder**, clique em "New OccluderPolygon2D".
4. Clique na tela do Godot para desenhar o polígono envolta da sua parede.
5. **IMPORTANTE**: No seu nó **PointLight2D**, vá na aba **Shadow** e marque a caixa **Enabled**.

## Resumo da Hierarquia
- **MainScene** (Node2D)
  - **CanvasModulate** (Controla a escuridão geral)
  - **Player**
    - **PointLight2D** (A lanterna/brilho do herói)
  - **Paredes / TileMap**
    - **LightOccluder2D** (Onde a luz bate e faz sombra)

---
**💡 Dica Extra**: Você pode mudar a cor da luz (Property `Color` no PointLight2D) para fazer luzes de tochas (laranja) ou luzes de neon!
