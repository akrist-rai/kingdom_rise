class_name Fx
extends Node2D
## Short-lived visual effects drawn above the soldiers: slash arcs, sparks, blood,
## damage numbers, attack glints (white = parryable, red = must dodge), dash
## after-images, rings, the possession wisp. Also draws health/stance bars and markers.

var battle = null
var trails: Array = []
var lines: Array = []
var rings: Array = []
var parts: Array = []
var texts: Array = []
var glints: Array = []
var ghosts: Array = []
var wisps: Array = []
var stars: Array = []
var arcs: Array = []
var t := 0.0

const MAX_PARTS := 800

func _process(delta: float) -> void:
	if battle == null:
		return
	delta = minf(delta, 1.0 / 30.0)
	t += delta
	_tick(trails, delta, func(e): return e["t"] < float(e["act"]) + 0.16)
	_tick(lines, delta, func(e): return e["t"] < 0.3)
	_tick(rings, delta, func(e): return e["t"] < float(e["dur"]))
	_tick(texts, delta, func(e): return e["t"] < 0.8)
	_tick(glints, delta, func(e): return e["t"] < 0.34)
	_tick(ghosts, delta, func(e): return e["t"] < 0.2)
	_tick(wisps, delta, func(e): return e["t"] < float(e["dur"]))
	_tick(stars, delta, func(e): return e["t"] < float(e["dur"]))
	_tick(arcs, delta, func(e): return e["t"] < 0.28)
	var keep: Array = []
	for p in parts:
		p["life"] = float(p["life"]) - delta
		p["p"] = p["p"] + p["v"] * delta
		p["v"] = p["v"] * (1.0 - minf(1.0, float(p["drag"]) * delta))
		if p["grav"]:
			p["vz"] = float(p["vz"]) - 260.0 * delta
			p["z"] = float(p["z"]) + float(p["vz"]) * delta
			if float(p["z"]) <= 0.0:
				if p["kind"] == "blood" and battle.decals:
					battle.decals.blood_drop(p["p"])
				continue
		else:
			p["z"] = float(p["z"]) + float(p["vz"]) * delta
		if float(p["life"]) > 0.0:
			keep.append(p)
	parts = keep
	queue_redraw()

func _tick(arr: Array, delta: float, alive: Callable) -> void:
	var i := 0
	while i < arr.size():
		var e: Dictionary = arr[i]
		e["t"] = float(e["t"]) + delta
		if alive.call(e):
			i += 1
		else:
			arr.remove_at(i)

# ------------------------------------------------------------------ spawners
func swing_trail(u: Unit, mv: Dictionary) -> void:
	if not battle.on_screen(u.global_position):
		return
	var col := Color(1.0, 0.97, 0.88, 0.95)
	if not u.is_player:
		col = Color(0.88, 0.9, 1.0, 0.55) if u.faction == 0 else Color(0.9, 0.85, 1.0, 0.55)
	if u.is_boss:
		col = Color(0.8, 0.62, 1.0, 0.9)
	if mv.get("perilous", false):
		col = Color(1.0, 0.35, 0.3, 0.9)
	var reach: float = u.weapon.reach * float(mv.get("rng", 1.0)) * (1.25 if u.is_boss else 1.0)
	trails.append({"u": u, "shape": mv.get("shape", "arc"), "a0": u.aim.angle() + deg_to_rad(float(mv["a0"])) * u.face,
		"a1": u.aim.angle() + deg_to_rad(float(mv["a1"])) * u.face, "r": reach, "act": float(mv["a"]),
		"t": 0.0, "col": col, "w": float(mv.get("trail", 1.0)), "aim": u.aim, "c": u.global_position + Vector2(0, -10)})

func spin(u: Unit, r: float) -> void:
	var col := Color(1.0, 0.97, 0.88, 0.9) if u.is_player else Color(0.8, 0.62, 1.0, 0.85)
	trails.append({"u": u, "shape": "circle", "a0": t * 7.0, "a1": t * 7.0 + TAU, "r": r, "act": 0.18,
		"t": 0.0, "col": col, "w": 0.8, "aim": u.aim, "c": u.global_position + Vector2(0, -10)})

func line_slash(a: Vector2, b: Vector2, col: Color) -> void:
	lines.append({"a": a, "b": b, "t": 0.0, "col": col})

func ring(p: Vector2, r: float, col: Color, dur: float) -> void:
	rings.append({"p": p, "r": r, "col": col, "dur": dur, "t": 0.0})

func text(p: Vector2, s: String, col: Color) -> void:
	if texts.size() > 40:
		texts.remove_at(0)
	texts.append({"p": p, "s": s, "col": col, "t": 0.0})

func glint(u: Unit, red: bool) -> void:
	if battle.on_screen(u.global_position):
		glints.append({"u": u, "red": red, "t": 0.0})
		if red:
			Sfx.play_at("ui", u.global_position, -2.0, 0.5)

func afterimage(u: Unit) -> void:
	ghosts.append({"tex": u.body.texture, "p": u.body.global_position + u.body.offset * u.body.scale,
		"flip": u.body.flip_h, "t": 0.0, "scale": u.body.scale})

## Anime-style impact star at the point of a hit.
func hit_star(p: Vector2, size: float, col: Color = Color(1.0, 0.97, 0.88), dur: float = 0.12) -> void:
	if not battle.on_screen(p) or stars.size() > 30:
		return
	stars.append({"p": p, "s": size, "col": col, "t": 0.0, "dur": dur, "rot": randf() * 0.8})

## A crescent spray of blood flying off a heavy hit.
func blood_arc(p: Vector2, dir: Vector2, size: float = 8.0) -> void:
	if not battle.on_screen(p) or arcs.size() > 30:
		return
	arcs.append({"p": p, "dir": dir.normalized(), "s": size, "t": 0.0, "side": 1.0 if randf() < 0.5 else -1.0})

func wisp(a: Vector2, b: Vector2) -> void:
	wisps.append({"a": a, "b": b, "t": 0.0, "dur": 0.45})

func _part(p: Vector2, v: Vector2, z: float, vz: float, life: float, col: Color, kind: String, grav: bool, drag: float = 2.0, size: float = 1.0) -> void:
	if parts.size() >= MAX_PARTS:
		return
	parts.append({"p": p, "v": v, "z": z, "vz": vz, "life": life, "max": life, "col": col, "kind": kind,
		"grav": grav, "drag": drag, "size": size})

func sparks(p: Vector2, col: Color, n: int) -> void:
	for i in n:
		var a := randf() * TAU
		var s := randf_range(60, 200)
		_part(p, Vector2(cos(a), sin(a)) * s, 0.0, 0.0, randf_range(0.12, 0.3), col, "spark", false, 6.0)

func blood(p: Vector2, dir: Vector2, n: int) -> void:
	if not battle.on_screen(p):
		return
	for i in n:
		var d := dir.rotated(randf_range(-0.9, 0.9)) * randf_range(30, 130)
		_part(p + Vector2(0, 10), d, 10.0, randf_range(20, 90), 1.5, Color(0.65, 0.05, 0.12), "blood", true, 1.5)

func burst(p: Vector2, col: Color, n: int) -> void:
	for i in n:
		var a := randf() * TAU
		_part(p + Vector2(0, 10), Vector2(cos(a), sin(a)) * randf_range(40, 160), 10.0, randf_range(40, 140), 1.5, col, "blood", true, 1.5)

func heal(u: Unit) -> void:
	for i in 18:
		_part(u.global_position + Vector2(randf_range(-8, 8), 0), Vector2(randf_range(-10, 10), 0), randf_range(0, 10),
			randf_range(25, 55), randf_range(0.5, 0.9), Color(1.0, 0.85, 0.45), "heal", false, 1.0)
	ring(u.global_position, 18.0, Color(1.0, 0.85, 0.45, 0.8), 0.35)

func skill_flash(u: Unit) -> void:
	ring(u.global_position + Vector2(0, -8), 22.0, Color(0.7, 0.9, 1.0, 0.9) if u.faction == 0 else Color(0.85, 0.6, 1.0, 0.9), 0.3)
	sparks(u.global_position + Vector2(0, -12), Color(0.8, 0.95, 1.0) if u.faction == 0 else Color(0.85, 0.6, 1.0), 10)

func debris(p: Vector2, r: float) -> void:
	for i in 40:
		var a := randf() * TAU
		var q := p + Vector2(cos(a), sin(a) * 0.7) * randf_range(0.2, 1.0) * r
		_part(q, Vector2(cos(a), sin(a)) * randf_range(20, 70), 0.0, randf_range(50, 130), 1.2,
			Color(0.95, 0.96, 1.0) if randf() < 0.7 else Color(0.4, 0.4, 0.55), "snow", true, 1.0)

func debris_at(p: Vector2) -> void:
	_part(p, Vector2(randf_range(-20, 20), randf_range(-10, 10)), 0.0, randf_range(60, 120), 1.0,
		Color(0.95, 0.96, 1.0) if randf() < 0.6 else Color(0.35, 0.35, 0.5), "snow", true, 1.0)

## Snow kicked up behind a dash or a galloping horse.
func snow_kick(p: Vector2, dir: Vector2, n: int = 8) -> void:
	if not battle.on_screen(p):
		return
	for i in n:
		var d := dir.rotated(randf_range(-0.7, 0.7)) * randf_range(30, 110)
		_part(p + Vector2(randf_range(-3, 3), 0), d, 0.0, randf_range(30, 80), 0.9,
			Color(0.97, 0.98, 1.0) if randf() < 0.75 else Color(0.78, 0.82, 0.95), "snow", true, 2.5)

## A small puff of breath vapour in the cold air.
func breath(p: Vector2, dir_x: float) -> void:
	for i in 3:
		_part(p + Vector2(dir_x * 2.0, 0), Vector2(dir_x * randf_range(6, 14) + 4.0, randf_range(-3, 3)), 0.0,
			randf_range(4, 9), randf_range(0.6, 1.0), Color(0.92, 0.95, 1.0), "breath", false, 1.5)

func snow_puff(p: Vector2) -> void:
	for i in 3:
		_part(p, Vector2(randf_range(-25, 25), randf_range(-8, 8)), 0.0, randf_range(30, 70), 0.8, Color(0.95, 0.96, 1.0), "snow", true, 2.0)

# ------------------------------------------------------------------ light emission
## Everything bright in the effects also lights its surroundings (see LightPainter).
func draw_lights(l: LightPainter) -> void:
	for e in trails:
		var act: float = e["act"]
		var tt: float = e["t"]
		var fade := 1.0 if tt < act else clampf(1.0 - (tt - act) / 0.16, 0.0, 1.0)
		var col: Color = e["col"]
		var c: Vector2 = e["c"]
		var r: float = e["r"]
		var lc := Color(col.r, col.g, col.b) * (0.55 * fade * col.a)
		if e["shape"] == "thrust":
			var aim: Vector2 = e["aim"]
			l.glow_line(c + aim * 6.0, c + aim * (r + 6.0), 10.0, lc)
			continue
		var k := clampf(tt / act, 0.0, 1.0)
		var a0: float = e["a0"]
		var end_a := lerpf(a0, float(e["a1"]), 1.0 - (1.0 - k) * (1.0 - k))
		for i in 4:
			var ang := lerpf(a0, end_a, (i + 1) / 4.0)
			l.glow(c + Vector2(cos(ang), sin(ang) * 0.8) * r * 0.85, 14.0, lc)
	for e in lines:
		var k := float(e["t"]) / 0.3
		var col: Color = e["col"]
		l.glow_line(e["a"], e["b"], 14.0, Color(col.r, col.g, col.b) * (0.7 * (1.0 - k)))
	for e in rings:
		var k := float(e["t"]) / float(e["dur"])
		var col: Color = e["col"]
		l.glow(e["p"], float(e["r"]) * 1.3, Color(col.r, col.g, col.b) * (col.a * 0.7 * (1.0 - k)))
	for p in parts:
		if p["kind"] == "spark" or p["kind"] == "heal":
			var k := float(p["life"]) / float(p["max"])
			var col: Color = p["col"]
			l.glow(p["p"] - Vector2(0, float(p["z"])), 7.0, Color(col.r, col.g, col.b) * (0.8 * k))
	for g in glints:
		var u = g["u"]
		if not is_instance_valid(u) or u.dead:
			continue
		var k := float(g["t"]) / 0.34
		var c := Color(1.0, 0.2, 0.15) if g["red"] else Color(1.0, 0.95, 0.85)
		l.glow(u.global_position + Vector2(0, -14), 30.0, c * (sin(k * PI) * (1.2 if g["red"] else 0.7)))
	for e in stars:
		var k := float(e["t"]) / float(e["dur"])
		var col: Color = e["col"]
		l.glow(e["p"], float(e["s"]) * 3.0, Color(col.r, col.g, col.b) * (1.0 - k) * 0.9)
	for w in wisps:
		var k := float(w["t"]) / float(w["dur"])
		var a: Vector2 = w["a"]
		var b: Vector2 = w["b"]
		var mid := a.lerp(b, 0.5) + Vector2(0, -60)
		var q := a.lerp(mid, k).lerp(mid.lerp(b, k), k)
		l.glow(q, 40.0, Color(1.0, 0.75, 0.4) * 1.2)

# ------------------------------------------------------------------ drawing
func _draw() -> void:
	if battle == null:
		return
	_draw_pickups()
	for g in ghosts:
		var k := 1.0 - float(g["t"]) / 0.2
		var tx: Texture2D = g["tex"]
		var sz: Vector2 = tx.get_size() * g["scale"]
		var p: Vector2 = g["p"]
		var rect := Rect2(p, sz)
		if g["flip"]:
			rect = Rect2(p + Vector2(sz.x, 0), Vector2(-sz.x, sz.y))
		draw_texture_rect(tx, rect, false, Color(0.6, 0.85, 1.0, 0.45 * k))
	for e in trails:
		_draw_trail(e)
	for e in lines:
		var k := float(e["t"]) / 0.3
		var a: Vector2 = e["a"]
		var b: Vector2 = e["b"]
		var col: Color = e["col"]
		var n := (b - a).normalized().orthogonal()
		var w := 4.0 * (1.0 - k)
		var lc := Color(col.r, col.g, col.b, 0.9 * (1.0 - k))
		draw_primitive(PackedVector2Array([a, a.lerp(b, 0.5) + n * w, b, a.lerp(b, 0.5) - n * w]), PackedColorArray([lc, lc, lc, lc]), PackedVector2Array())
		draw_line(a, b, Color(1, 1, 1, 1.0 - k), 1.0)
	for e in rings:
		var k := float(e["t"]) / float(e["dur"])
		var col: Color = e["col"]
		var r: float = float(e["r"]) * (0.3 + 0.7 * (1.0 - (1.0 - k) * (1.0 - k)))
		draw_set_transform(e["p"], 0.0, Vector2(1.0, 0.72))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(col.r, col.g, col.b, col.a * (1.0 - k)), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for e in arcs:
		var k := float(e["t"]) / 0.28
		var dir: Vector2 = e["dir"]
		var base := dir.angle()
		var rr: float = float(e["s"]) * (0.5 + k * 1.2)
		var c: Vector2 = e["p"] + dir * rr * 0.6
		var segs := 8
		var sweep := 1.6 * float(e["side"])
		var pts := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in segs + 1:
			var f := float(i) / segs
			var ang := base - sweep * 0.5 + sweep * f
			var th := sin(f * PI) * (3.0 * (1.0 - k) + 0.5)
			pts.append(c + Vector2.from_angle(ang) * rr)
			inner.append(c + Vector2.from_angle(ang) * maxf(0.0, rr - th))
		var bc := Color(0.62, 0.03, 0.1, 1.0 - k * k)
		var bcols := PackedColorArray([bc, bc, bc, bc])
		for i in segs:
			draw_primitive(PackedVector2Array([pts[i], pts[i + 1], inner[i + 1], inner[i]]), bcols, PackedVector2Array())
	for p in parts:
		var k := float(p["life"]) / float(p["max"])
		var col: Color = p["col"]
		var pos: Vector2 = p["p"] - Vector2(0, float(p["z"]))
		if p["kind"] == "spark":
			var v: Vector2 = p["v"]
			draw_line(pos, pos - v * 0.03, Color(col.r, col.g, col.b, k), 1.0)
		elif p["kind"] == "breath":
			var bs := 1.0 + (1.0 - k) * 2.0
			draw_rect(Rect2(pos.floor(), Vector2(bs, bs).floor()), Color(col.r, col.g, col.b, 0.45 * k))
		else:
			draw_rect(Rect2(pos.floor(), Vector2(1, 1)), Color(col.r, col.g, col.b, minf(1.0, k * 2.0)))
	for g in glints:
		var u = g["u"]
		if not is_instance_valid(u) or u.dead:
			continue
		var wd: Dictionary = Art.weapons[u.weapon.tex_key]
		var tip: Vector2 = u.wpn.global_position + Vector2.from_angle(u.weapon_angle) * float(wd["len"]) * 0.8 * u.wpn.scale.x
		var k := float(g["t"]) / 0.34
		var s := sin(k * PI) * (2.2 if g["red"] else 1.5)
		var col := Color(1.0, 0.2, 0.15) if g["red"] else Color(1, 1, 1)
		draw_set_transform(tip, k * 2.0, Vector2(s, s))
		draw_texture(Art.tex["glint"], Vector2(-3.5, -3.5), col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if g["red"]:
			draw_set_transform(u.global_position, 0.0, Vector2(1.0, 0.7))
			draw_arc(Vector2.ZERO, 14.0 + k * 10.0, 0.0, TAU, 24, Color(1, 0.2, 0.15, 0.7 * (1.0 - k)), 1.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for e in stars:
		var k := float(e["t"]) / float(e["dur"])
		var sz: float = float(e["s"]) * sin(minf(1.0, k * 1.6) * PI * 0.5 + 0.2) * (1.0 - k * 0.4)
		var rot: float = e["rot"]
		var col: Color = e["col"]
		var pts := PackedVector2Array()
		for i in 8:
			var rr := sz if i % 2 == 0 else sz * 0.18
			pts.append(e["p"] + Vector2.from_angle(rot + i * PI / 4.0) * rr * (1.0 if i % 4 != 2 else 0.55))
		draw_colored_polygon(pts, Color(col.r, col.g, col.b, 1.0 - k * k))
		var core := PackedVector2Array()
		for i in 8:
			var rr := sz * 0.45 if i % 2 == 0 else sz * 0.1
			core.append(e["p"] + Vector2.from_angle(rot + PI / 8.0 + i * PI / 4.0) * rr)
		draw_colored_polygon(core, Color(1, 1, 1, 1.0 - k))
	for w in wisps:
		var k := float(w["t"]) / float(w["dur"])
		var a: Vector2 = w["a"]
		var b: Vector2 = w["b"]
		for i in 6:
			var kk := clampf(k - i * 0.04, 0.0, 1.0)
			var mid := a.lerp(b, 0.5) + Vector2(0, -60)
			var q := a.lerp(mid, kk).lerp(mid.lerp(b, kk), kk) + Vector2(0, -12)
			var gl: Texture2D = Art.tex["glow"]
			var sc := (1.0 - i * 0.14) * 0.6
			draw_texture_rect(gl, Rect2(q - Vector2(16, 16) * sc, Vector2(32, 32) * sc), false, Color(1.0, 0.85, 0.5, 0.8 - i * 0.12))
	_draw_bars()
	for e in texts:
		var k := float(e["t"]) / 0.8
		var p: Vector2 = e["p"] + Vector2(0, -k * 14.0)
		var s: String = e["s"]
		var col: Color = e["col"]
		Game.text(self, p, s, 8, Color(col.r, col.g, col.b, 1.0 - k * k), 1)

func _draw_trail(e: Dictionary) -> void:
	var u = e["u"]
	var c: Vector2 = e["c"]
	if is_instance_valid(u) and not u.dead:
		c = u.global_position + Vector2(0, -10)
		e["c"] = c
	var act: float = e["act"]
	var tt: float = e["t"]
	var k := clampf(tt / act, 0.0, 1.0)
	var fade := 1.0 if tt < act else clampf(1.0 - (tt - act) / 0.16, 0.0, 1.0)
	var col: Color = e["col"]
	var w: float = e["w"]
	var r: float = e["r"]
	if e["shape"] == "thrust":
		var aim: Vector2 = e["aim"]
		var n := aim.orthogonal()
		var tip := c + aim * (r + 6.0)
		var base := c + aim * 6.0
		var wd := 3.0 * w * fade
		var tc := Color(col.r, col.g, col.b, col.a * fade)
		draw_primitive(PackedVector2Array([base + n * wd, tip, base - n * wd]), PackedColorArray([tc, tc, tc]), PackedVector2Array())
		draw_line(base, tip, Color(1, 1, 1, fade), 1.0)
		return
	var a0: float = e["a0"]
	var a1: float = e["a1"]
	var ek := 1.0 - (1.0 - k) * (1.0 - k)
	var end_a := lerpf(a0, a1, ek)
	var start_a := lerpf(a0, end_a, clampf((tt - act) / 0.16, 0.0, 1.0))
	var span := absf(end_a - start_a)
	if span < 0.02:
		return
	var segs := clampi(int(span * 7.0), 4, 28)
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in segs + 1:
		var f := float(i) / segs
		var ang := lerpf(start_a, end_a, f)
		var dir := Vector2(cos(ang), sin(ang) * 0.8)
		var th := lerpf(0.5, 7.0 * w, f * f) * (0.6 + 0.4 * fade)
		outer.append(c + dir * r)
		inner.append(c + dir * maxf(2.0, r - th))
	var qc := Color(col.r, col.g, col.b, col.a * fade * 0.85)
	var cols := PackedColorArray([qc, qc, qc, qc])
	for i in segs:
		draw_primitive(PackedVector2Array([outer[i], outer[i + 1], inner[i + 1], inner[i]]), cols, PackedVector2Array())
	draw_polyline(outer, Color(1, 1, 1, fade * col.a), 1.0)

func _draw_bars() -> void:
	for u in battle.units:
		if u.dead or not battle.on_screen(u.global_position):
			continue
		var top: Vector2 = u.global_position + Vector2(0, -26)
		if u.mounted:
			top.y -= 10.0
		if u.is_boss:
			top.y -= 10.0
		if u.is_player:
			draw_set_transform(u.global_position, 0.0, Vector2(1.0, 0.45))
			draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 20, Color(1.0, 0.82, 0.3, 0.55), 1.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var bob := sin(t * 5.0) * 1.0
			var tp := top + Vector2(0, -4 + bob)
			draw_colored_polygon(PackedVector2Array([tp + Vector2(-3, -3), tp + Vector2(3, -3), tp + Vector2(0, 1)]), Color("#ffd23f"))
			draw_polyline(PackedVector2Array([tp + Vector2(-3, -3), tp + Vector2(3, -3), tp + Vector2(0, 1), tp + Vector2(-3, -3)]), Color(0.1, 0.05, 0.1), 1.0)
			continue
		if u.in_squad:
			draw_rect(Rect2(top + Vector2(-1, -2), Vector2(3, 3)), Color(0.1, 0.05, 0.1))
			draw_rect(Rect2(top + Vector2(0, -1), Vector2(1, 1)), Color("#ff5a4a"))
		if u.is_boss:
			continue
		var show: bool = (u.show_bar_t > 0.0 or u.is_officer or u.stance > 0.0) and (u.faction == 1 or u.in_squad)
		if show and not u.spectator:
			var bw := 26.0 if u.is_officer else 14.0
			var bp := (top + Vector2(-bw * 0.5, 0)).floor()
			draw_rect(Rect2(bp - Vector2(1, 1), Vector2(bw + 2, 4)), Color(0.08, 0.06, 0.1, 0.85))
			var hc := Color("#e5484d") if u.faction == 1 else Color("#7bd389")
			draw_rect(Rect2(bp, Vector2(bw * clampf(u.hp / u.max_hp, 0.0, 1.0), 2)), hc)
			if u.stance > 0.0 and u.faction == 1:
				draw_rect(Rect2(bp + Vector2(0, 2), Vector2(bw * clampf(u.stance / u.max_stance, 0.0, 1.0), 1)), Color("#ffd23f"))
		if u.is_officer and u.faction == 1:
			var nm: String = u.uname
			Game.text(self, top + Vector2(0, -4), nm, 8, Color("#d9c9ff"), 1)
		if u.state == Unit.St.BROKEN and u.faction == 1 and battle.player != null:
			var pk := 0.5 + 0.5 * sin(t * 16.0)
			var cp := top + Vector2(0, -10)
			draw_colored_polygon(PackedVector2Array([cp + Vector2(0, -4), cp + Vector2(4, 0), cp + Vector2(0, 4), cp + Vector2(-4, 0)]), Color(1, 0.2, 0.2, 0.6 + 0.4 * pk))
			if battle.player.global_position.distance_to(u.global_position) < 60.0:
				Game.text(self, cp + Vector2(0, -6), "CRIT!", 8, Color(1, 0.9, 0.5), 1)

func _draw_pickups() -> void:
	for pk in battle.pickups:
		var p: Vector2 = pk["pos"]
		if not battle.on_screen(p):
			continue
		var w: Weapon = pk["w"]
		var wd: Dictionary = Art.weapons[w.tex_key]
		var tx: Texture2D = wd["tex"]
		var bob := sin(t * 3.0 + p.x) * 1.5
		draw_texture(Art.tex["ring"], p - Vector2(8, 4), Color(1, 0.9, 0.5, 0.5 + 0.3 * sin(t * 5.0)))
		draw_set_transform(p + Vector2(0, -6 + bob), -0.5, Vector2.ONE)
		draw_texture(tx, -Vector2(tx.get_width() * 0.5, tx.get_height() * 0.5))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if battle.player != null and battle.player.global_position.distance_to(p) < 26.0:
			var s := "F: TAKE " + w.display_name()
			Game.text(self, p + Vector2(0, -20), s, 8, Color("#ffe8a3"), 1)

func _draw_candidates() -> void:
	if not battle.possess:
		return
	for i in battle.cands.size():
		var u = battle.cands[i]
		if not is_instance_valid(u) or u.dead:
			continue
		var sel: bool = i == battle.cand_sel
		var col := Color("#ffd23f") if sel else Color(1, 1, 1, 0.55)
		draw_set_transform(u.global_position, 0.0, Vector2(1.0, 0.6))
		draw_arc(Vector2.ZERO, 11.0 if sel else 8.0, 0.0, TAU, 24, col, 1.0)
		if sel:
			draw_arc(Vector2.ZERO, 14.0 + sin(t * 30.0) * 1.0, 0.0, TAU, 24, Color(1, 0.85, 0.3, 0.6), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if sel:
			var tp: Vector2 = u.global_position + Vector2(0, -34)
			draw_colored_polygon(PackedVector2Array([tp + Vector2(-4, -4), tp + Vector2(4, -4), tp + Vector2(0, 1)]), col)
