class_name CineTitle
extends Node2D
## The title painting, after the WLOP references: a cloaked Qin warrior seen from behind at
## blue hour, glaive in hand, facing a misty field of cavalry, raised spears and swallow-tailed
## banners under a peach horizon. Everything is drawn live in layers (sky, far army, riders,
## infantry, hero, foreground grass) so the cloak, banners, mist and embers can move.

const INK := Color("#0a141b")
const RIM := Color(1.0, 0.8, 0.66)
const HORIZON := 214.0

var t := 0.0
var embers: Array = []
var clouds: Array = []
var far_spikes: Array = []
var grass: Array = []
var riders: Array = []
var infantry: Array = []
var p: Painter

func _ready() -> void:
	p = Painter.new(self)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	for i in 9:
		clouds.append([rng.randf_range(-100, 700), rng.randf_range(40, 190), rng.randf_range(120, 320), rng.randf_range(4, 11), rng.randf_range(2.0, 6.0), rng.randf()])
	for i in 260:
		far_spikes.append([rng.randf_range(-40, 680), rng.randf_range(4.0, 14.0), rng.randf() < 0.12])
	for i in 7:
		riders.append([340.0 + i * 52.0 + rng.randf_range(-12, 12), HORIZON + 30.0 + rng.randf_range(-6, 10), rng.randf() * TAU, rng.randf() < 0.5, rng.randi() % 4])
	for i in 6:
		infantry.append([392.0 + i * 46.0 + rng.randf_range(-10, 10), 330.0 + rng.randf_range(-8, 14), rng.randf() * TAU,
			["qin_heavy", "qin_infantry", "qin_spear", "qin_officer"][i % 4], ["glaive", "jian", "spear", "axe", "hammer", "zhanmadao"][i]])
	for i in 140:
		var x := rng.randf_range(-20, 660)
		var edge := absf(x - 320.0) / 340.0
		if rng.randf() > 0.35 + edge * 0.8:
			continue
		grass.append([x, rng.randf_range(16, 46) * (0.6 + edge * 0.6), rng.randf_range(-10, 10), rng.randf_range(1.0, 2.4), rng.randf() * TAU])

func _process(delta: float) -> void:
	t += delta
	if randf() < delta * 14.0:
		embers.append([Vector2(randf_range(-20, 420), randf_range(300, 380)), Vector2(randf_range(10, 40), randf_range(-38, -18)), 0.0, randf_range(3.0, 6.0), randf() * TAU])
	var i := 0
	while i < embers.size():
		var e: Array = embers[i]
		e[2] = float(e[2]) + delta
		if float(e[2]) > float(e[3]):
			embers.remove_at(i)
			continue
		e[0] = e[0] + (e[1] + Vector2(sin(float(e[2]) * 2.0 + float(e[4])) * 10.0, 0.0)) * delta
		i += 1
	queue_redraw()

# ------------------------------------------------------------------ helpers
## Fills a polygon; shapes bent by the wind can self-intersect, so those are repaired
## (split into simple polygons by Clipper) instead of failing to triangulate.
func _fill(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3:
		return
	if not Geometry2D.triangulate_polygon(pts).is_empty():
		draw_colored_polygon(pts, col)
		return
	for poly in Geometry2D.merge_polygons(pts, PackedVector2Array()):
		if not Geometry2D.is_polygon_clockwise(poly) or true:
			if not Geometry2D.triangulate_polygon(poly).is_empty():
				draw_colored_polygon(poly, col)
func _vgrad(y0: float, y1: float, c0: Color, c1: Color) -> void:
	draw_polygon(PackedVector2Array([Vector2(-40, y0), Vector2(680, y0), Vector2(680, y1), Vector2(-40, y1)]),
		PackedColorArray([c0, c0, c1, c1]))

func _mist(y: float, h: float, col: Color, drift: float) -> void:
	# a soft horizontal mist bank, thicker in some places than others
	var n := 24
	for k in n:
		var x0 := -40.0 + k * 30.0
		var amp := 0.6 + 0.4 * sin(k * 1.7 + t * 0.15 + drift)
		var c_mid := Color(col.r, col.g, col.b, col.a * amp)
		var c_out := Color(col.r, col.g, col.b, 0.0)
		draw_polygon(PackedVector2Array([Vector2(x0, y - h), Vector2(x0 + 31, y - h), Vector2(x0 + 31, y), Vector2(x0, y)]),
			PackedColorArray([c_out, c_out, c_mid, c_mid]))
		draw_polygon(PackedVector2Array([Vector2(x0, y), Vector2(x0 + 31, y), Vector2(x0 + 31, y + h * 0.6), Vector2(x0, y + h * 0.6)]),
			PackedColorArray([c_mid, c_mid, c_out, c_out]))

func _tex_sil(tex: Texture2D, pos: Vector2, sc: float, col: Color, flip: bool = false) -> void:
	var sz := tex.get_size() * sc
	var r := Rect2(pos - Vector2(sz.x * 0.5, sz.y), sz)
	if flip:
		r = Rect2(r.position + Vector2(sz.x, 0), Vector2(-sz.x, sz.y))
	draw_texture_rect(tex, r, false, col)

func _banner(pole_base: Vector2, h: float, w: float, col: Color, ph: float) -> void:
	var top := pole_base + Vector2(0, -h)
	draw_line(pole_base, top + Vector2(0, -4), Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, col.a), 1.2, true)
	var pts := PackedVector2Array()
	var steps := 8
	for s in steps + 1:
		var k := float(s) / steps
		pts.append(top + Vector2(k * w, sin(k * 4.0 - t * 3.0 + ph) * 2.5 * k))
	for tail in 3:
		var k := 1.0
		var ty := w * 0.55 * (0.15 + tail * 0.35)
		pts.append(top + Vector2(w * (1.05 + 0.25 * (tail % 2)), ty + sin(t * 3.0 + ph + tail) * 3.0))
		pts.append(top + Vector2(w * 0.86, ty + w * 0.12))
	for s in steps + 1:
		var k := 1.0 - float(s) / steps
		pts.append(top + Vector2(k * w * 0.86, w * 0.55 + sin(k * 4.0 - t * 3.0 + ph) * 2.5 * k))
	_fill(pts, col)

# ------------------------------------------------------------------ painting
func _draw() -> void:
	var drift := sin(t * 0.08) * 6.0
	# --- sky
	_vgrad(-20, 120, Color("#152431"), Color("#3c5568"))
	_vgrad(120, 180, Color("#3c5568"), Color("#8098a6"))
	_vgrad(180, HORIZON + 2, Color("#8098a6"), Color("#e6ad95"))
	_vgrad(HORIZON, 380, Color("#9db0ba"), Color("#5f7684"))
	# sun glow low behind the clouds
	var gl: Texture2D = Art.tex["glow"]
	var sun := Vector2(470 + drift * 0.3, HORIZON - 6)
	draw_texture_rect(gl, Rect2(sun - Vector2(140, 70), Vector2(280, 140)), false, Color(1.0, 0.72, 0.55, 0.55))
	draw_texture_rect(gl, Rect2(sun - Vector2(40, 22), Vector2(80, 44)), false, Color(1.0, 0.9, 0.78, 0.8))
	# clouds: long brush strokes with a peach underside
	for c in clouds:
		var x: float = fposmod(float(c[0]) + t * float(c[4]), 840.0) - 100.0
		var y: float = c[1]
		var w: float = c[2]
		var th: float = c[3]
		var path := Painter.curve(PackedVector2Array([Vector2(x, y), Vector2(x + w * 0.35, y - th * 0.5), Vector2(x + w * 0.7, y + th * 0.2), Vector2(x + w, y - th * 0.1)]), 6)
		var k: float = clampf((y - 40.0) / 160.0, 0.0, 1.0)
		var body := Color("#2e4555").lerp(Color("#7d8f9c"), k)
		_fill(Painter.stroke(path, th * 0.5, th * 0.15), Color(body.r, body.g, body.b, 0.85))
		var under := Painter.stroke(Painter.curve(PackedVector2Array([Vector2(x + w * 0.1, y + th * 0.35), Vector2(x + w * 0.5, y + th * 0.25), Vector2(x + w * 0.9, y + th * 0.3)]), 5), th * 0.12, 0.3)
		_fill(under, Color(1.0, 0.72, 0.58, 0.35 + 0.4 * k))
	# --- far army on the horizon: a band of spear tips, banners and helmets in the mist
	for s in far_spikes:
		var x: float = s[0] + drift * 0.2
		var h: float = s[1]
		var col := Color(0.42, 0.52, 0.6, 0.9)
		draw_line(Vector2(x, HORIZON + 4), Vector2(x, HORIZON + 4 - h), col, 0.8, true)
		if s[2]:
			_fill(PackedVector2Array([Vector2(x, HORIZON + 4 - h), Vector2(x + 6, HORIZON + 5 - h), Vector2(x + 4, HORIZON + 8 - h), Vector2(x, HORIZON + 8 - h)]), Color(0.5, 0.36, 0.4, 0.9))
	draw_rect(Rect2(-40, HORIZON + 2, 720, 6), Color(0.44, 0.54, 0.62, 0.95))
	_mist(HORIZON + 6, 26, Color(0.72, 0.78, 0.82, 0.55), 0.0)
	# --- cavalry silhouettes with spears and banners
	for r in riders:
		var rx: float = float(r[0]) + drift * 0.45
		var ry: float = float(r[1])
		_rider_sil(Vector2(rx, ry), 1.15, float(r[2]), Color(0.22, 0.29, 0.35), int(r[4]) % 2 == 0)
	_mist(HORIZON + 44, 30, Color(0.6, 0.68, 0.74, 0.5), 1.3)
	# --- infantry with raised weapons
	for f in infantry:
		var fx: float = float(f[0]) + drift * 0.8
		var fy: float = float(f[1])
		_foot_sil(Vector2(fx, fy), 2.2, float(f[2]), Color(0.1, 0.15, 0.19), int(f[2] * 10.0) % 4)
	_mist(330, 40, Color(0.5, 0.6, 0.67, 0.35), 2.1)
	# --- the hero
	_hero(Vector2(232 + drift * 1.1, 0))
	# --- foreground grass silhouettes
	for g in grass:
		var gx: float = float(g[0]) + drift * 1.6
		var h: float = g[1]
		var lean: float = float(g[2]) + sin(t * 1.2 + float(g[4])) * 3.0
		var path := Painter.curve(PackedVector2Array([Vector2(gx, 364), Vector2(gx + lean * 0.35, 364 - h * 0.55), Vector2(gx + lean, 364 - h)]), 5)
		_fill(Painter.stroke(path, float(g[3]), 0.15), Color(0.02, 0.05, 0.07, 0.97))
	# --- embers
	for e in embers:
		var k: float = float(e[2]) / float(e[3])
		var a: float = sin(k * PI) * (0.6 + 0.4 * sin(t * 9.0 + float(e[4]) * 5.0))
		var ep: Vector2 = e[0]
		draw_texture_rect(gl, Rect2(ep - Vector2(3, 3), Vector2(6, 6)), false, Color(1.0, 0.45, 0.15, 0.6 * a))
		draw_rect(Rect2(ep - Vector2(0.6, 0.6), Vector2(1.2, 1.2)), Color(1.0, 0.85, 0.55, a))

## A rider seen from the side: galloping horse, rider with a tall spear, maybe a banner.
func _rider_sil(c: Vector2, k: float, ph: float, col: Color, flag: bool) -> void:
	var g := sin(t * 5.0 + ph)
	var rim := Color(RIM.r, RIM.g, RIM.b, 0.35)
	var body := Painter.blob(PackedVector2Array([c + Vector2(-16, -14) * k, c + Vector2(4, -17) * k, c + Vector2(17, -15) * k,
		c + Vector2(19, -8) * k, c + Vector2(10, -4) * k, c + Vector2(-12, -4) * k, c + Vector2(-19, -9) * k]), 3)
	_fill(body, col)
	var neck := PackedVector2Array([c + Vector2(12, -15) * k, c + Vector2(20, -27) * k, c + Vector2(28, -26) * k, c + Vector2(27, -21) * k, c + Vector2(19, -11) * k])
	_fill(neck, col)
	for leg in [[-13.0, 0.0], [-9.0, 1.5], [10.0, 3.0], [14.0, 4.5]]:
		var top: Vector2 = c + Vector2(leg[0], -6) * k
		var sw: float = sin(t * 5.0 + ph + float(leg[1])) * 6.0
		draw_line(top, top + Vector2(sw, 14) * k, col, 2.2 * k, true)
	_fill(Painter.stroke(Painter.curve(PackedVector2Array([c + Vector2(-18, -12) * k, c + Vector2(-26, -8 + g * 2.0) * k, c + Vector2(-30, -2) * k]), 3), 1.6 * k, 0.4), col)
	# rider
	var rc := c + Vector2(1, -19 + g * 0.6) * k
	_fill(Painter.blob(PackedVector2Array([rc + Vector2(-5, 2) * k, rc + Vector2(5, 2) * k, rc + Vector2(4, -12) * k, rc + Vector2(-4, -12) * k]), 2), col)
	_fill(Painter.circle(rc + Vector2(0, -16) * k, 4.0 * k, 10), col)
	_fill(PackedVector2Array([rc + Vector2(-1, -20) * k, rc + Vector2(1, -26) * k, rc + Vector2(-5, -24) * k]), col)
	var sp0 := rc + Vector2(-8, 6) * k
	var sp1 := rc + Vector2(18, -60) * k
	draw_line(sp0, sp1, col, 1.2 * k, true)
	_fill(PackedVector2Array([sp1, sp1 + Vector2(-2, 6) * k, sp1 + Vector2(2, 5) * k]), col)
	draw_line(rc + Vector2(-4, -12) * k, rc + Vector2(4, -12) * k, rim, 0.8, true)
	if flag:
		_banner(rc + Vector2(-2, -14) * k, 58.0 * k, 20.0 * k, Color(0.4, 0.13, 0.14, 0.95), ph)

## A foot soldier from the side with a weapon raised high (spear, sword, axe or banner).
func _foot_sil(c: Vector2, k: float, ph: float, col: Color, wpn: int) -> void:
	var sway := sin(t * 1.6 + ph) * 0.06
	for side in [-1.0, 1.0]:
		_fill(Painter.limb(c + Vector2(side * 3.0, -20) * k, c + Vector2(side * 5.0, 0) * k, 3.0 * k, 2.2 * k), col)
	var torso := Painter.blob(PackedVector2Array([c + Vector2(-7, -19) * k, c + Vector2(7, -19) * k, c + Vector2(8, -36) * k, c + Vector2(-6, -38) * k]), 2)
	_fill(torso, col)
	var hd := c + Vector2(1, -43) * k
	_fill(Painter.circle(hd, 5.0 * k, 12), col)
	_fill(Painter.ellipse(hd + Vector2(0, -1) * k, 6.0 * k, 5.0 * k, 12, PI, TAU), col)
	_fill(Painter.stroke(Painter.curve(PackedVector2Array([hd + Vector2(0, -5) * k, hd + Vector2(-5, -9) * k, hd + Vector2(-9, -7) * k]), 3), 1.5 * k, 0.4), Color(0.32, 0.1, 0.11))
	# raised arm and weapon
	var sh := c + Vector2(5, -34) * k
	var ang := -1.2 + sway
	var hand := sh + Vector2.from_angle(ang) * 13.0 * k
	_fill(Painter.limb(sh, hand, 2.6 * k, 2.0 * k), col)
	var dir := Vector2.from_angle(ang - 0.25)
	match wpn:
		0:
			draw_line(hand - dir * 14.0 * k, hand + dir * 34.0 * k, col, 1.4 * k, true)
			var tip := hand + dir * 34.0 * k
			_fill(PackedVector2Array([tip + dir * 7.0 * k, tip + dir.orthogonal() * 2.0 * k, tip - dir.orthogonal() * 2.0 * k]), col)
		1:
			_fill(Painter.limb(hand, hand + dir * 20.0 * k, 1.6 * k, 0.6 * k), col)
			draw_line(hand + dir.orthogonal() * 3.0 * k, hand - dir.orthogonal() * 3.0 * k, col, 1.4 * k, true)
		2:
			draw_line(hand - dir * 4.0 * k, hand + dir * 18.0 * k, col, 1.4 * k, true)
			var hb := hand + dir * 16.0 * k
			_fill(Painter.blob(PackedVector2Array([hb + dir.orthogonal() * 1.0 * k, hb + dir.orthogonal() * 7.0 * k + dir * 3.0 * k, hb + dir * 6.0 * k, hb - dir * 2.0 * k]), 2), col)
		_:
			draw_line(hand - dir * 10.0 * k, hand + dir * 40.0 * k, col, 1.2 * k, true)
			_banner(hand + dir * 32.0 * k + Vector2(0, 24.0 * k), 24.0 * k, 16.0 * k, Color(0.36, 0.12, 0.13, 0.95), ph)
	draw_line(c + Vector2(-6, -38) * k, c + Vector2(8, -36) * k, Color(RIM.r, RIM.g, RIM.b, 0.3), 0.8, true)

## The warrior seen from behind, three-quarter turned toward the enemy: topknot with a red tie,
## a high collar, broad scaled pauldrons, a long oxblood cloak streaming left in the wind, and a
## glaive held up and out to the right. One dark silhouette with a peach rim light on the side
## facing the low sun.
func _hero(o: Vector2) -> void:
	var br := sin(t * 1.4) * 0.8
	var wind := sin(t * 0.9) * 0.5 + sin(t * 2.3) * 0.25
	var dark := Color("#0b141a")
	var rimc := Color(RIM.r, RIM.g, RIM.b, 0.85)
	# glaive behind the arm
	var a0 := o + Vector2(34, 352)
	var a1 := o + Vector2(196, 96 + br)
	var dir := (a1 - a0).normalized()
	var n := dir.orthogonal()
	draw_line(a0, a1, dark, 3.4, true)
	draw_line(a0 - n * 1.6, a1 - n * 1.6, Color(RIM.r, RIM.g, RIM.b, 0.5), 0.9, true)
	var blade := Painter.blob(PackedVector2Array([a1 - dir * 2.0 + n * 2.5, a1 + dir * 26.0 + n * 10.0, a1 + dir * 50.0 + n * 2.0,
		a1 + dir * 30.0 - n * 6.0, a1 - dir * 2.0 - n * 3.0]), 3)
	_fill(blade, Color("#16222a"))
	draw_polyline(PackedVector2Array([a1 - n * 3.0, a1 + dir * 30.0 - n * 6.0, a1 + dir * 50.0 + n * 2.0]), Color(1.0, 0.92, 0.84, 0.95), 1.2, true)
	_fill(Painter.rotated(Painter.rect(a1.x - 9, a1.y - 3, 10, 6), a1, dir.angle()), Color("#7a2a24"))
	# cloak (behind the body), streaming left
	var hem := PackedVector2Array()
	var cl := PackedVector2Array([o + Vector2(-46, 168 + br), o + Vector2(44, 166 + br), o + Vector2(58, 220), o + Vector2(66, 300), o + Vector2(70 + wind * 6.0, 380)])
	for k in 9:
		var x := 62.0 - k * 26.0 + wind * (8.0 + k * 5.0)
		cl.append(o + Vector2(x, 384.0 + (8.0 if k % 2 == 0 else -6.0) - k * 2.0))
	cl.append(o + Vector2(-178 + wind * 34.0, 334))
	cl.append(o + Vector2(-140 + wind * 26.0, 290))
	cl.append(o + Vector2(-108 + wind * 16.0, 240))
	cl.append(o + Vector2(-70 + wind * 6.0, 196))
	var cloak := Painter.blob(cl, 3)
	_fill(cloak, Color("#1d0a0d"))
	var fold_x := [-74.0, -50.0, -38.0, -12.0, 8.0, 30.0, 44.0]
	for k in fold_x.size():
		var fx: float = fold_x[k]
		var fold := Painter.curve(PackedVector2Array([o + Vector2(fx * 0.35, 192 + k % 3 * 6), o + Vector2(fx * 0.85 + wind * 6.0, 276 - k % 2 * 10), o + Vector2(fx * 1.3 + wind * (14.0 + k * 3.0), 372 + k % 2 * 8)]), 6)
		_fill(Painter.stroke(fold, 0.5, 2.0 + (k * 7 % 5) * 0.6), Color(0.32, 0.1, 0.11, 0.3 + (k * 3 % 4) * 0.1))
	draw_polyline(Painter.curve(PackedVector2Array([o + Vector2(44, 166 + br), o + Vector2(58, 220), o + Vector2(66, 300), o + Vector2(70 + wind * 6.0, 378)]), 6), rimc, 1.2, true)
	# torso: shoulders slope down from the collar toward the pauldrons
	var torso := Painter.blob(PackedVector2Array([o + Vector2(-46, 184 + br), o + Vector2(-20, 152 + br), o + Vector2(20, 150 + br),
		o + Vector2(48, 180 + br), o + Vector2(44, 212), o + Vector2(-44, 214)]), 3)
	_fill(torso, dark)
	# pauldrons: three overlapping scale plates hanging over each upper arm, angled outward
	for side in [-1.0, 1.0]:
		for row in 3:
			var pc := o + Vector2(side * (36.0 + row * 5.0), 170.0 + row * 8.0 + br)
			var plate := Painter.ellipse(Vector2.ZERO, 19.0 - row * 2.5, 9.0, 16, PI, TAU)
			plate.append(Vector2(19.0 - row * 2.5, 4.0))
			plate.append(Vector2(-19.0 + row * 2.5, 4.0))
			var xf := Transform2D(side * (0.32 + row * 0.1), pc)
			_fill(xf * plate, Color("#0e1a22") if row % 2 == 0 else Color("#142430"))
			if side > 0.0:
				draw_polyline(xf * Painter.ellipse(Vector2.ZERO, 19.0 - row * 2.5, 9.0, 12, PI * 1.25, PI * 1.95), Color(RIM.r, RIM.g, RIM.b, 0.8 - row * 0.2), 1.1, true)
			else:
				draw_polyline(xf * Painter.ellipse(Vector2.ZERO, 19.0 - row * 2.5, 9.0, 8, PI * 1.45, PI * 1.75), Color(RIM.r, RIM.g, RIM.b, 0.35), 0.9, true)
	for row in 2:
		draw_polyline(Painter.curve(PackedVector2Array([o + Vector2(-26, 188 + row * 8 + br), o + Vector2(0, 192 + row * 8 + br), o + Vector2(26, 188 + row * 8 + br)]), 4), Color(0.2, 0.28, 0.33, 0.55), 0.8, true)
	# right arm: hangs from the pauldron, bends at the elbow, fist on the shaft
	var shp := o + Vector2(52, 186 + br)
	var hand := a0.lerp(a1, 0.47)
	var elbow := o + Vector2(70, 232 + br)
	_fill(Painter.limb(shp, elbow, 11.0, 9.0), dark)
	_fill(Painter.limb(elbow, hand, 9.0, 7.0), dark)
	_fill(Painter.rotated(Painter.rect(elbow.x + 3, elbow.y - 6, 16, 12), elbow, (hand - elbow).angle()), Color("#142430"))
	_fill(Painter.circle(hand, 7.0, 14), dark)
	draw_polyline(PackedVector2Array([shp + Vector2(9, -4), elbow + Vector2(8, -3), hand + Vector2(5, -6)]), rimc, 1.1, true)
	# collar, head, topknot and red tie
	_fill(Painter.blob(PackedVector2Array([o + Vector2(-16, 140 + br), o + Vector2(16, 139 + br), o + Vector2(20, 156 + br), o + Vector2(-20, 157 + br)]), 2), dark)
	var hc := o + Vector2(3, 127 + br)
	_fill(Painter.circle(hc, 11.0, 22), dark)
	draw_polyline(Painter.ellipse(hc, 11.0, 11.0, 14, PI * 1.35, PI * 2.05), rimc, 1.4, true)
	var knot := hc + Vector2(-3, -15)
	_fill(Painter.circle(knot, 6.0, 14), dark)
	draw_polyline(Painter.ellipse(knot, 6.0, 6.0, 10, PI * 1.3, PI * 2.0), rimc, 1.0, true)
	for k in 2:
		var tie := Painter.curve(PackedVector2Array([knot + Vector2(-3, 2), knot + Vector2(-18 + wind * 5.0, 7 + k * 3.0 + wind * 2.0), knot + Vector2(-38 + wind * 12.0, 6 + k * 6.0 + sin(t * 3.0 + k) * 4.0)]), 6)
		_fill(Painter.stroke(tie, 2.2 - k * 0.6, 0.4), Color("#9a2228") if k == 0 else Color("#6e161b"))
	for k in 4:
		var hs := Painter.curve(PackedVector2Array([hc + Vector2(-8 + k * 3, -6), hc + Vector2(-20 + k * 2 + wind * 4.0, 0), hc + Vector2(-28 + k + wind * 7.0, 8 + k)]), 4)
		draw_polyline(hs, dark, 1.3, true)
