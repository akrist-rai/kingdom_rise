class_name CityArt
extends RefCounted
## Drawings for the Siege of Handan, all vector shapes in the painted-poster style:
## houses (tiled hip roofs seen from above, lit facades along the south side), wall towers and
## the gatehouse, the palace hall with its double golden roof, the drum tower, market stalls,
## lantern strings, and the Qin siege engines (siege towers, the covered ram, trebuchets).
## The scene is a burning night: roofs are indigo, plaster and lacquer are lit by firelight.

const INK := Color("#0b0a16")
const ROOFS := [
	[Color("#a06145"), Color("#66473c"), Color("#cc9863")],     # indigo slate
	[Color("#45646a"), Color("#2b444c"), Color("#72908b")],     # teal
	[Color("#7e805f"), Color("#4d5f4c"), Color("#a4a477")],     # plum
]
const GOLD_ROOF := [Color("#b98a34"), Color("#6c4718"), Color("#f0cc6a")]
const PLASTER := [Color("#c4a689"), Color("#7a6458")]
const LACQUER := [Color("#6c5640"), Color("#3d4637")]
const WOOD := [Color("#6a4632"), Color("#3a2418")]
const STONE := [Color("#a3aa91"), Color("#57675b"), Color("#c8c4a5")]
const GLOW := Color("#ffbe6a")

# ------------------------------------------------------------------ roofs
## A hip roof seen from above, covering rect r (local coords). The ridge runs along the long
## side; the south plane catches the firelight, the north one is in shadow; tile courses run
## down the slopes; the eaves curl up at the corners.
static func roof(ci: CanvasItem, r: Rect2, pal: Array, charred: float = 0.0, ornate: bool = false) -> void:
	var p := Painter.new(ci)
	p.ink_w = 0.6
	var horiz := r.size.x >= r.size.y
	var c := r.get_center()
	var inset := minf(r.size.x, r.size.y) * 0.5
	var a: Vector2
	var b: Vector2
	if horiz:
		# seen from the south and above: the ridge sits high, the lit south slope fills most of it
		var ry := r.position.y + r.size.y * 0.36
		a = Vector2(r.position.x + inset * 0.8, ry)
		b = Vector2(r.end.x - inset * 0.8, ry)
	else:
		a = Vector2(c.x, r.position.y + inset)
		b = Vector2(c.x, r.end.y - inset)
	var tl := r.position
	var tr := Vector2(r.end.x, r.position.y)
	var br := r.end
	var bl := Vector2(r.position.x, r.end.y)
	var lit: Color = pal[2] if not ornate else GOLD_ROOF[0]
	var mid: Color = pal[0] if not ornate else GOLD_ROOF[0].darkened(0.15)
	var dark: Color = pal[1] if not ornate else GOLD_ROOF[1]
	if charred > 0.0:
		lit = lit.lerp(Color("#3a2220"), charred)
		mid = mid.lerp(Color("#2a1a1a"), charred)
	var south := PackedVector2Array([bl, br, b if horiz else b, a if horiz else b])
	var north := PackedVector2Array([tl, tr, b, a])
	if horiz:
		south = PackedVector2Array([bl, br, b, a])
		p.fill(north, dark)
		p.fill(south, lit)
		p.fill(PackedVector2Array([tl, a, bl]), mid)
		p.fill(PackedVector2Array([tr, br, b]), mid.darkened(0.15))
	else:
		p.fill(PackedVector2Array([tl, tr, a]), dark)
		p.fill(PackedVector2Array([bl, br, b]), lit)
		p.fill(PackedVector2Array([tl, a, b, bl]), mid)
		p.fill(PackedVector2Array([tr, br, b, a]), mid.darkened(0.2))
	# tile courses
	var tile := Color(0, 0, 0, 0.22)
	var step := 3.2
	if horiz:
		var x := r.position.x + step
		while x < r.end.x - 1.0:
			var tx := clampf(x, a.x, b.x)
			ci.draw_line(Vector2(x, r.end.y - 0.5), Vector2(lerpf(x, tx, 0.9), a.y + 0.6), tile, 0.5, true)
			ci.draw_line(Vector2(x, r.position.y + 0.5), Vector2(lerpf(x, tx, 0.9), a.y - 0.6), Color(0, 0, 0, 0.25), 0.5, true)
			x += step
	else:
		var y := r.position.y + step
		while y < r.end.y - 1.0:
			var ty := clampf(y, a.y, b.y)
			ci.draw_line(Vector2(r.position.x + 0.5, y), Vector2(a.x - 0.6, lerpf(y, ty, 0.9)), tile, 0.5, true)
			ci.draw_line(Vector2(r.end.x - 0.5, y), Vector2(a.x + 0.6, lerpf(y, ty, 0.9)), Color(0, 0, 0, 0.25), 0.5, true)
			y += step
	# hip lines, ridge with end ornaments, eave outline with upturned corners
	var hip := Color(1, 1, 1, 0.12)
	for e in [[tl, a], [bl, a], [tr, b], [br, b]]:
		ci.draw_line(e[0], e[1], hip, 0.8, true)
	var ridge_col: Color = (GOLD_ROOF[2] if ornate else pal[2].lightened(0.1))
	ci.draw_line(a, b, INK, 2.6, true)
	ci.draw_line(a, b, ridge_col, 1.3, true)
	var outline := PackedVector2Array([tl, tr, br, bl])
	p.ink(outline, true, 0.9)
	# Tall chimney and straight eaves give the town a medieval European silhouette.
	if r.size.x > 40.0 and not ornate:
		var chimney := Rect2(r.position.x + r.size.x * 0.7, a.y - 9.0, 5.0, 12.0)
		p.shape(Painter.rect(chimney.position.x, chimney.position.y, 5.0, 12.0), PLASTER[0], STONE[1])
	if charred > 0.2:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(r.position.x * 13.0 + r.position.y)
		for i in 5:
			var q := r.position + Vector2(rng.randf_range(0.15, 0.85) * r.size.x, rng.randf_range(0.2, 0.8) * r.size.y)
			p.fill(Painter.circle(q, rng.randf_range(2.0, 5.0), 8), Color(0.08, 0.04, 0.05, 0.7 * charred))

## The south facade of a building: plaster, lacquered pillars, lattice windows glowing with
## firelight, a door. x0..x1 along the base line y=0, height h (drawn upward).
static func facade(ci: CanvasItem, x0: float, x1: float, h: float, seed: int, glow: float = 1.0) -> void:
	var p := Painter.new(ci)
	p.ink_w = 0.6
	p.fill(Painter.rect(x0, -h, x1 - x0, h), PLASTER[0])
	ci.draw_rect(Rect2(x0, -h, x1 - x0, 2.2), Color(0, 0, 0, 0.3))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var bays := maxi(2, int((x1 - x0) / 15.0))
	var bw := (x1 - x0) / bays
	var door_bay := rng.randi() % bays
	for i in bays:
		var bx := x0 + i * bw
		if i == door_bay:
			p.fill(Painter.rect(bx + bw * 0.22, -h * 0.78, bw * 0.56, h * 0.78), WOOD[1])
			ci.draw_line(Vector2(bx + bw * 0.5, -h * 0.78), Vector2(bx + bw * 0.5, 0), Color(0, 0, 0, 0.5), 0.6)
			if rng.randf() < 0.6:
				p.fill(Painter.rect(bx + bw * 0.3, -h * 0.7, bw * 0.4, h * 0.7), Color(GLOW.r, GLOW.g * 0.8, GLOW.b * 0.6, 0.55 * glow))
		elif rng.randf() < 0.8:
			var wr := Rect2(bx + bw * 0.2, -h * 0.72, bw * 0.6, h * 0.42)
			var lit := rng.randf() < 0.7
			p.fill(Painter.rect(wr.position.x, wr.position.y, wr.size.x, wr.size.y), GLOW if lit and glow > 0.0 else Color("#2a2030"))
			for k in 3:
				var lx := wr.position.x + wr.size.x * (k + 1) / 4.0
				ci.draw_line(Vector2(lx, wr.position.y), Vector2(lx, wr.end.y), WOOD[1], 0.6)
			ci.draw_line(Vector2(wr.position.x, wr.get_center().y), Vector2(wr.end.x, wr.get_center().y), WOOD[1], 0.6)
	for i in bays + 1:
		var px := x0 + i * bw
		p.fill(Painter.rect(px - 1.3, -h, 2.6, h), LACQUER[0])
		ci.draw_line(Vector2(px + 1.3, -h), Vector2(px + 1.3, 0), LACQUER[1], 0.8)
	ci.draw_rect(Rect2(x0, -1.6, x1 - x0, 1.6), STONE[1])
	p.ink(Painter.rect(x0, -h, x1 - x0, h), true, 0.8)

# ------------------------------------------------------------------ hanging lanterns
static func lantern(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	ci.draw_line(c + Vector2(0, -4.5 * s), c + Vector2(0, -3.0 * s), INK, 0.6)
	var body := Painter.ellipse(c, 2.4 * s, 3.0 * s, 12)
	ci.draw_colored_polygon(body, Color("#e0402e"))
	ci.draw_colored_polygon(Painter.ellipse(c + Vector2(-0.6, -0.4) * s, 1.0 * s, 1.8 * s, 8), Color("#ffb070"))
	ci.draw_rect(Rect2(c.x - 1.5 * s, c.y - 3.4 * s, 3.0 * s, 0.9 * s), Color("#2a1810"))
	ci.draw_rect(Rect2(c.x - 1.5 * s, c.y + 2.6 * s, 3.0 * s, 0.9 * s), Color("#2a1810"))
	ci.draw_line(c + Vector2(0, 3.4 * s), c + Vector2(0, 5.6 * s), Color("#f2c14e"), 0.6)

# ------------------------------------------------------------------ banners (swallow-tail)
static func pennant(ci: CanvasItem, base: Vector2, h: float, w: float, col: Color, ph: float, t: float) -> void:
	var top := base + Vector2(0, -h)
	ci.draw_line(base, top + Vector2(0, -3), Color("#3a2418"), 1.4, true)
	var pts := PackedVector2Array()
	for s in 7:
		var k := s / 6.0
		pts.append(top + Vector2(k * w, sin(k * 4.0 - t * 3.0 + ph) * 2.0 * k))
	pts.append(top + Vector2(w * 1.15, w * 0.2 + sin(t * 3.0 + ph) * 2.0))
	pts.append(top + Vector2(w * 0.85, w * 0.3))
	pts.append(top + Vector2(w * 1.1, w * 0.5 + sin(t * 3.0 + ph + 1.0) * 2.0))
	for s in 7:
		var k := 1.0 - s / 6.0
		pts.append(top + Vector2(k * w * 0.85, w * 0.55 + sin(k * 4.0 - t * 3.0 + ph) * 2.0 * k))
	var poly := Geometry2D.merge_polygons(pts, PackedVector2Array())
	for pp in poly:
		if not Geometry2D.triangulate_polygon(pp).is_empty():
			ci.draw_colored_polygon(pp, col)
