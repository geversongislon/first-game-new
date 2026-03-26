# Guia: Criando Novos Inimigos

Para criar um novo tipo de inimigo (ex: Voador, Atirador, Chefe):

1.  **Herança de Cena (Recomendado)**:
    - No Godot, clique com o botão direito em `res://scenes/actors/enemy.tscn`.
    - Selecione **"New Inherited Scene"** (Nova Cena Herdada).
    - Salve com o nome do seu novo inimigo (ex: `enemy_fast.tscn`).

2.  **Customização no Inspetor**:
    - Selecione o nó raiz da nova cena.
    - No Inspetor, você poderá ver e alterar as variáveis `@export`:
        - `Speed`: Velocidade de patrulha.
        - `Max Health`: Vida máxima.
        - `Start Direction`: Direção inicial.
        - `Knockback Force`: Resistência a empurrões.
    - Você pode trocar o sprite ou as cores sem quebrar a lógica base.

3.  **Lógicas Únicas**:
    - Se precisar de um comportamento totalmente novo (ex: atirar), você pode estender o script:
    - Clique no ícone de script do nó raiz e escolha **"Extend Script"**.
    - O novo script começará com `extends "res://scripts/actors/enemy.gd"`.

Assim, todos os seus inimigos herdarão automaticamente o sistema de **Barra de Vida**, **Números de Dano**, **Flashes ao levar dano** e o sistema de **Drops**.
