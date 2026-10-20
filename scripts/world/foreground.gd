class_name ForegroundGrass
extends Node2D
## Dark silhouettes of tall grass very close to the camera, along the bottom of the view and
## heavier toward the corners (the framing in the WLOP references). They slide past faster
## than the battlefield (parallax) and sway with the wind.

var cam: Camera2D
var blades: Array = []     # [x 0..1, height, lean, width, phase, shade]
var gust := 0.0

func _ready() -> void:
	z_index = 5
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for i in 110:
		var x := rng.randf()
		# density: mostly in the left and right thirds, sparse in the middle
		var edge := absf(x - 0.5) * 2.0
		if rng.randf() > 0.25 + edge * edge * 0.9:
			continue
		blades.append([x, rng.randf_range(14.0, 30.0) * (0.6 + edge * 0.7), rng.randf_range(-9.0, 9.0),
			rng.randf_range(0.9, 2.0), rng.randf() * TAU, rng.randf()])

func _process(_delta: float) -> void:
	if cam == null:
		return
	visible = not Game.low_gfx
	global_position = cam.get_screen_center_position()
	scale = Vector2.ONE / cam.zoom.x
	queue_redraw()

func _draw() -> void:
	var w := Game.VIEW.x + 80.0
	var base_y := Game.VIEW.y * 0.5 + 4.0
	var t := Time.get_ticks_msec() / 1000.0
	var cx: float = global_position.x * 0.45
	for b in blades:
		var x := fposmod(float(b[0]) * w - cx, w) - w * 0.5
		var h: float = b[1]
		var sway := sin(t * 1.3 + float(b[4])) * 2.5 + sin(t * 2.7 + float(b[4]) * 2.0) * 1.0 + gust * 6.0
		var lean: float = float(b[2]) + sway
		var path := Painter.curve(PackedVector2Array([Vector2(x, base_y), Vector2(x + lean * 0.35, base_y - h * 0.55), Vector2(x + lean, base_y - h)]), 5)
		var col := Color(0.02, 0.05, 0.07, 0.96) if float(b[5]) < 0.6 else Color(0.05, 0.09, 0.12, 0.92)
		draw_colored_polygon(Painter.stroke(path, float(b[3]), 0.15), col)
