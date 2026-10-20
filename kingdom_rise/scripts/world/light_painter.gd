class_name LightPainter
extends Node2D
## Draws every light source into the light buffer (visibility layer 2 only, additive).
## The post shader multiplies the scene by this buffer, so fires, lanterns, sword trails,
## sparks and spells light up the snow and the soldiers around them.

var atmos: Atmos
var sources: Array[Callable] = []
var tex: Texture2D
var t := 0.0

func _ready() -> void:
	visibility_layer = 2
	z_index = 100
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	tex = Art.tex["light"]

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func view_rect() -> Rect2:
	var c := atmos.cam_center if atmos else Vector2.ZERO
	return Rect2(c - Game.VIEW * 0.5 - Vector2(120, 120), Game.VIEW + Vector2(240, 240))

## A soft elliptical light (flattened for the angled top-down view).
func glow(pos: Vector2, r: float, col: Color) -> void:
	draw_texture_rect(tex, Rect2(pos - Vector2(r, r * 0.72), Vector2(r * 2.0, r * 1.44)), false, col)

func glow_line(a: Vector2, b: Vector2, r: float, col: Color) -> void:
	var n := maxi(2, int(a.distance_to(b) / (r * 0.6)))
	for i in n + 1:
		glow(a.lerp(b, float(i) / n), r, col)

func _draw() -> void:
	if atmos == null:
		return
	var vr := view_rect()
	var nk := atmos.night()
	for l in atmos.lights:
		var p: Vector2 = l["pos"]
		if not vr.has_point(p):
			continue
		var k := 1.0
		if l["night"]:
			k = nk
			if k < 0.02:
				continue
		var f: float = l["flick"]
		if f > 0.0:
			var ph: float = l["ph"]
			k *= 1.0 - f * (0.5 + 0.5 * sin(t * 9.0 + ph) * sin(t * 13.7 + ph * 2.0))
		var col: Color = l["col"]
		glow(p, float(l["r"]) * (0.95 + 0.05 * sin(t * 7.0 + float(l["ph"]))), Color(col.r * k, col.g * k, col.b * k))
	for s in sources:
		if s.is_valid():
			s.call(self)
