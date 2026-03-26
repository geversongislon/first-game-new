extends Node2D
class_name StanceIndicator

## Indicador visual de imobilidade para armas que exigem player parado.
## Vermelho = em movimento, verde = pronto para atirar.

var progress: float = 0.0  # 0.0 = movendo, 1.0 = pronto

const RADIUS: float = 1.2
const BORDER: float = 0.5

func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	# Borda escura
	draw_circle(Vector2.ZERO, RADIUS + BORDER, Color(0.0, 0.0, 0.0, 0.7))
	# Cor: vermelho → laranja → verde conforme progresso
	var col := Color(1.0, 0.15, 0.1, 0.95).lerp(Color(0.2, 1.0, 0.25, 0.95), progress)
	draw_circle(Vector2.ZERO, RADIUS, col)
	# Arco de progresso externo
	if progress > 0.0 and progress < 1.0:
		draw_arc(Vector2.ZERO, RADIUS + BORDER + 1.5, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, Color(1, 1, 1, 0.4), 1.5)
