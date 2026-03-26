extends CanvasLayer

## Fundo de cidade procedural com parallax em 3 camadas.
## Adicione um nó CanvasLayer na cena e anexe este script.
## layer = -1 garante que fique atrás de tudo.

const VIEWPORT_W : int   = 320
const VIEWPORT_H : int   = 180
const STRIP      : float = 640.0

const LAYER_DATA := [
	{ "speed": 0.01, "min_top": 10, "max_top": 55,
	  "min_w": 28, "max_w": 52, "gap": 2,
	  "color": Color(0.04, 0.05, 0.10),
	  "win_color": Color(0.60, 0.50, 0.15, 0.18),
	  "win_size": 2.0, "win_gap": 3.0, "win_chance": 0.25 },
	{ "speed": 0.04, "min_top": 40, "max_top": 90,
	  "min_w": 20, "max_w": 42, "gap": 3,
	  "color": Color(0.06, 0.07, 0.14),
	  "win_color": Color(0.65, 0.55, 0.18, 0.22),
	  "win_size": 2.0, "win_gap": 3.0, "win_chance": 0.30 },
	{ "speed": 0.08, "min_top": 75, "max_top": 115,
	  "min_w": 16, "max_w": 34, "gap": 4,
	  "color": Color(0.08, 0.09, 0.18),
	  "win_color": Color(0.70, 0.58, 0.20, 0.28),
	  "win_size": 2.0, "win_gap": 3.0, "win_chance": 0.35 },
]

var _camera    : Camera2D = null
var _buildings : Array    = []
var _drawers   : Array    = []

func _ready() -> void:
	layer = -1
	_add_sky()
	_generate_all_buildings()
	_create_drawers()

func _add_sky() -> void:
	var sky       := ColorRect.new()
	sky.color      = Color(0.04, 0.04, 0.10)
	sky.size       = Vector2(VIEWPORT_W, VIEWPORT_H)
	sky.position   = Vector2.ZERO
	add_child(sky)

func _generate_all_buildings() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for li in LAYER_DATA.size():
		var ld   : Dictionary = LAYER_DATA[li]
		var list : Array      = []
		var x    : float      = 0.0
		# Gera apenas UM tile — o _draw repete ele para cobrir a tela
		while x < STRIP:
			# 25% chance de ser um prédio horizontal (largo e baixo)
			var is_wide := rng.randf() < 0.25
			var w : float
			var top : float
			if is_wide:
				w   = rng.randf_range(ld["max_w"] * 1.3, ld["max_w"] * 2.2)
				top = rng.randf_range(ld["max_top"] * 0.75, ld["max_top"])
			else:
				w   = rng.randf_range(ld["min_w"], ld["max_w"])
				top = rng.randf_range(ld["min_top"], ld["max_top"])
			var style := rng.randi_range(0, 7)
			list.append({ "x": x, "y": top, "w": w, "style": style })
			x += w + float(ld["gap"])
		_buildings.append(list)

func _create_drawers() -> void:
	for li in LAYER_DATA.size():
		var d          := _BuildingLayer.new()
		d.ld           = LAYER_DATA[li]
		d.buildings    = _buildings[li]
		add_child(d)
		_drawers.append(d)

func _process(_delta: float) -> void:
	if not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_2d()
	if not is_instance_valid(_camera):
		return
	var cam_x : float = _camera.global_position.x
	for d in _drawers:
		(d as _BuildingLayer).scroll_x = cam_x
		d.queue_redraw()


class _BuildingLayer extends Node2D:
	var ld        : Dictionary = {}
	var buildings : Array      = []
	var scroll_x  : float      = 0.0

	const STRIP : float = 640.0

	func _draw() -> void:
		var spd     : float = ld["speed"]
		var bg_col  : Color = ld["color"]
		var win_col : Color = ld["win_color"]
		var win_ch  : float = ld["win_chance"]
		var off     : float = fposmod(scroll_x * spd, STRIP)

		var rng := RandomNumberGenerator.new()

		for b in buildings:
			# Desenha o prédio nas duas cópias do tile para cobrir qualquer posição
			for tile in [b["x"] - off, b["x"] - off + STRIP]:
				var bx : float = tile
				if bx + b["w"] < 0.0 or bx > 320.0: continue

				# Prédio vai do topo até a borda inferior da tela — nunca expõe o fundo
				var by    : float = b["y"]
				var bw    : float = b["w"]
				var bh    : float = 180.0 - by
				var style : int   = b["style"]

				draw_rect(Rect2(bx, by, bw, bh), bg_col)

				var sky_col := Color(0.04, 0.04, 0.10)
				match style:
					1: # Antena fina no centro
						draw_rect(Rect2(bx + bw * 0.5 - 1.0, by - 10.0, 1.0, 10.0), bg_col)
					2: # Degrau central no topo
						var sw : float = bw * 0.55
						draw_rect(Rect2(bx + (bw - sw) * 0.5, by - 8.0, sw, 8.0), bg_col)
					3: # Torres duplas nas bordas
						var tw : float = bw * 0.28
						draw_rect(Rect2(bx + 2.0,            by - 12.0, tw, 12.0), bg_col)
						draw_rect(Rect2(bx + bw - tw - 2.0,  by - 12.0, tw, 12.0), bg_col)
					4: # L-shape — torre alta à esquerda
						draw_rect(Rect2(bx, by - 14.0, bw * 0.35, 14.0), bg_col)
					5: # Entalhe central (recuo no topo)
						draw_rect(Rect2(bx + bw * 0.35, by, bw * 0.3, 8.0), sky_col)
					6: # Pirâmide de 3 degraus
						draw_rect(Rect2(bx + bw * 0.15, by - 7.0,  bw * 0.70, 7.0), bg_col)
						draw_rect(Rect2(bx + bw * 0.30, by - 13.0, bw * 0.40, 6.0), bg_col)
						draw_rect(Rect2(bx + bw * 0.43, by - 18.0, bw * 0.14, 5.0), bg_col)
					7: # Bloco lateral + antena
						draw_rect(Rect2(bx + bw - bw * 0.25, by - 10.0, bw * 0.25, 10.0), bg_col)
						draw_rect(Rect2(bx + bw - bw * 0.125 - 0.5, by - 18.0, 1.0, 8.0), bg_col)

				# Janelas (apenas na parte superior do prédio, não na base)
				rng.seed = int(b["x"] * 7919.0)
				var ws : float = ld["win_size"]
				var wg : float = ld["win_gap"]
				var wx : float = bx + ws
				while wx + ws <= bx + b["w"] - 2.0:
					var wy : float = by + 3.0
					while wy + ws <= by + bh * 0.7:
						if rng.randf() < win_ch:
							var a := rng.randf_range(0.4, 1.0)
							draw_rect(Rect2(wx, wy, ws, ws),
								Color(win_col.r, win_col.g, win_col.b, win_col.a * a))
						wy += ws + wg
					wx += ws + wg
