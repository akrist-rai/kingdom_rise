class_name Painter
extends RefCounted
## Vector drawing helpers for the "painted poster" style: flat fills, automatic cel
## shading (the shape is clipped against a copy of itself shifted toward the light, so a
## shadow crescent appears on the far side) and ink outlines.
## All coordinates are in world units; `xf` maps the figure's local space into the canvas.

const INK := Color("#0a141d")

var ci: CanvasItem
var xf := Transform2D.IDENTITY
var tint := Color(1, 1, 1, 1)
var ink_w := 0.5
var ink_col := INK
var light := Vector2(0.75, -0.6)

func _init(canvas: CanvasItem = null) -> void:
	ci = canvas

func tp(pts: PackedVector2Array) -> PackedVector2Array:
	return xf * pts

func col(c: Color) -> Color:
	return Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a * tint.a)

static func shift(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var o := PackedVector2Array()
	o.resize(pts.size())
	for i in pts.size():
		o[i] = pts[i] + d
	return o

func fill(pts: PackedVector2Array, c: Color) -> void:
	if pts.size() < 3:
		return
	ci.draw_colored_polygon(tp(pts), col(c))

func ink(pts: PackedVector2Array, closed: bool = true, w: float = -1.0) -> void:
	if pts.size() < 2:
		return
	var p := tp(pts)
	if closed:
		p.append(p[0])
	ci.draw_polyline(p, col(ink_col), ink_w if w < 0.0 else w, true)

func line(a: Vector2, b: Vector2, c: Color, w: float) -> void:
	ci.draw_line(xf * a, xf * b, col(c), w, true)

func polyline(pts: PackedVector2Array, c: Color, w: float) -> void:
	ci.draw_polyline(tp(pts), col(c), w, true)

## Fill with cel shading: `base` on the lit side, `shadow` on the side away from the light,
## an optional `hi` highlight sliver on the lit edge, then an ink outline.
func shape(pts: PackedVector2Array, base: Color, shadow: Color = Color(0, 0, 0, 0), hi: Color = Color(0, 0, 0, 0), outline: bool = true, depth: float = 1.0) -> void:
	if pts.size() < 3:
		return
	if shadow.a > 0.0:
		fill(pts, shadow)
		for poly in Geometry2D.intersect_polygons(pts, shift(pts, light * depth)):
			fill(poly, base)
	else:
		fill(pts, base)
	if hi.a > 0.0:
		for poly in Geometry2D.intersect_polygons(pts, shift(pts, light * depth * 2.6)):
			fill(poly, hi)
	if outline:
		ink(pts)

# ------------------------------------------------------------------ shape builders
static func ellipse(c: Vector2, rx: float, ry: float, n: int = 16, a0: float = 0.0, a1: float = TAU) -> PackedVector2Array:
	var o := PackedVector2Array()
	var full := absf(a1 - a0) >= TAU - 0.001
	var cnt := n if full else n + 1
	for i in cnt:
		var a := a0 + (a1 - a0) * float(i) / float(n)
		o.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return o

static func circle(c: Vector2, r: float, n: int = 14) -> PackedVector2Array:
	return ellipse(c, r, r, n)

static func capsule(a: Vector2, b: Vector2, r: float, n: int = 6) -> PackedVector2Array:
	var d := (b - a)
	var ang := d.angle()
	var o := PackedVector2Array()
	for i in n + 1:
		var t := ang + PI * 0.5 + PI * float(i) / n
		o.append(b + Vector2.from_angle(t - PI) * r)
	for i in n + 1:
		var t := ang + PI * 0.5 + PI * float(i) / n
		o.append(a + Vector2.from_angle(t) * r)
	return o

## A tapered limb from a (width wa) to b (width wb).
static func limb(a: Vector2, b: Vector2, wa: float, wb: float) -> PackedVector2Array:
	var n := (b - a).normalized().orthogonal()
	return PackedVector2Array([a + n * wa, b + n * wb, b - n * wb, a - n * wa])

static func rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])

static func rotated(pts: PackedVector2Array, pivot: Vector2, ang: float) -> PackedVector2Array:
	var o := PackedVector2Array()
	o.resize(pts.size())
	for i in pts.size():
		o[i] = pivot + (pts[i] - pivot).rotated(ang)
	return o

## A smooth closed blob through the given points (Catmull-Rom).
static func blob(pts: PackedVector2Array, steps: int = 4) -> PackedVector2Array:
	var o := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var p0 := pts[(i - 1 + n) % n]
		var p1 := pts[i]
		var p2 := pts[(i + 1) % n]
		var p3 := pts[(i + 2) % n]
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			o.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	return o

## An open stroke through points (Catmull-Rom), returned as a polyline.
static func curve(pts: PackedVector2Array, steps: int = 5) -> PackedVector2Array:
	var o := PackedVector2Array()
	var n := pts.size()
	for i in n - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, n - 1)]
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			o.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	o.append(pts[n - 1])
	return o

## A tapered brush stroke along a polyline (width w0 at the start to w1 at the end).
static func stroke(path: PackedVector2Array, w0: float, w1: float) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var n := path.size()
	for i in n:
		var d := (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		var w := lerpf(w0, w1, float(i) / maxf(1.0, n - 1.0))
		left.append(path[i] + d.orthogonal() * w)
		right.append(path[i] - d.orthogonal() * w)
	right.reverse()
	left.append_array(right)
	return left
