class_name Projectiles
extends Node2D
## All projectiles in one node: arrows/bolts, sword waves, ground shockwaves and
## arrow-rain volleys (with a telegraph circle on the ground before they land).

var battle = null
var shots: Array = []
var waves: Array = []
var rains: Array = []

func _valid_owner(o) -> Unit:
	if o != null and is_instance_valid(o) and not o.dead:
		return o
	return null

func shoot(owner: Unit, pos: Vector2, dir: Vector2, speed: float, hit: Dictionary, kind: String, pierce: int) -> void:
	shots.append({"pos": pos, "vel": dir.normalized() * speed, "owner": owner, "faction": owner.faction,
		"hit": hit, "kind": kind, "pierce": pierce, "life": 1.3, "hits": {}})

func wave(owner: Unit, pos: Vector2, dir: Vector2, speed: float, rng: float, hit: Dictionary) -> void:
	waves.append({"pos": pos, "dir": dir.normalized(), "speed": speed, "left": rng, "range": rng, "owner": owner,
		"faction": owner.faction, "hit": hit, "hits": {}, "kind": "wave", "width": 30.0})

func shock(owner: Unit, pos: Vector2, dir: Vector2, speed: float, rng: float, hit: Dictionary) -> void:
	waves.append({"pos": pos, "dir": dir.normalized(), "speed": speed, "left": rng, "range": rng, "owner": owner,
		"faction": owner.faction, "hit": hit, "hits": {}, "kind": "shock", "width": 18.0, "trail": []})

func rain(owner: Unit, target: Vector2, radius: float, count: int, delay: float, hit: Dictionary, faction: int = -1, gold: bool = false) -> void:
	var arrows := []
	var last := 0.0
	for i in count:
		var ang := randf() * TAU
		var d := sqrt(randf()) * radius
		var land := delay + randf() * 0.75
		last = maxf(last, land)
		arrows.append({"p": target + Vector2(cos(ang) * d, sin(ang) * d * 0.7), "land": land, "done": false})
	rains.append({"target": target, "radius": radius, "owner": owner,
		"faction": owner.faction if owner else faction, "hit": hit, "t": 0.0, "arrows": arrows, "last": last, "gold": gold})

func _process(delta: float) -> void:
	if battle == null or battle.frozen:
		return
	delta = minf(delta, 1.0 / 30.0)
	_update_shots(delta)
	_update_waves(delta)
	_update_rains(delta)
	queue_redraw()

func _update_shots(delta: float) -> void:
	var keep: Array = []
	for s in shots:
		var step: Vector2 = s["vel"] * delta
		var prev: Vector2 = s["pos"]
		s["pos"] = prev + step
		s["life"] -= delta
		var dead := false
		var pos: Vector2 = s["pos"]
		for e in battle.query(pos, 20.0):
			if e.dead or e.faction == s["faction"] or s["hits"].has(e):
				continue
			var c: Vector2 = e.global_position + Vector2(0, -9)
			var cp := Geometry2D.get_closest_point_to_segment(c, prev, pos)
			if cp.distance_to(c) > e.radius + 3.0:
				continue
			s["hits"][e] = true
			var h: Dictionary = s["hit"].duplicate()
			h["src_pos"] = pos - step.normalized() * 30.0
			h["ranged"] = true
			var res: String = e.take_hit(_valid_owner(s["owner"]), h)
			if res == "reflect":
				s["vel"] = -s["vel"] * 1.3
				s["faction"] = e.faction
				s["owner"] = e
				s["hit"]["dmg"] = float(s["hit"]["dmg"]) * 2.0 + 10.0
				s["hit"]["src_pos"] = e.global_position
				s["hits"] = {e: true}
				s["life"] = 1.2
				break
			if res == "dodged":
				continue
			Sfx.play_at("arrow_hit", pos, -6.0)
			if int(s["pierce"]) > 0:
				s["pierce"] = int(s["pierce"]) - 1
			else:
				dead = true
				break
		if s["life"] <= 0.0 or pos.x < -40 or pos.x > Battle.W + 40 or pos.y < -40 or pos.y > Battle.H + 40:
			if not dead and s["life"] <= 0.0 and randf() < 0.5:
				battle.decals.stuck_arrow(pos + Vector2(0, 10))
			dead = true
		if not dead:
			keep.append(s)
	shots = keep

func _update_waves(delta: float) -> void:
	var keep: Array = []
	for w in waves:
		var dir: Vector2 = w["dir"]
		var stepl: float = w["speed"] * delta
		w["pos"] = w["pos"] + dir * stepl
		w["left"] = float(w["left"]) - stepl
		var pos: Vector2 = w["pos"]
		var width: float = w["width"]
		for e in battle.query(pos, width + 16.0):
			if e.dead or e.faction == w["faction"] or w["hits"].has(e):
				continue
			var to: Vector2 = e.global_position + Vector2(0, -6) - pos
			if absf(to.dot(dir)) < 14.0 + e.radius and absf(to.cross(dir)) < width + e.radius:
				w["hits"][e] = true
				var h: Dictionary = w["hit"].duplicate()
				h["src_pos"] = pos - dir * 20.0
				e.take_hit(_valid_owner(w["owner"]), h)
		if w["kind"] == "shock":
			var tr: Array = w["trail"]
			tr.append(pos)
			if randf() < 0.6:
				battle.fx.debris_at(pos + Vector2(randf_range(-6, 6), randf_range(-4, 4)))
			battle.decals.crack(pos, dir)
		if float(w["left"]) > 0.0 and pos.x > -50 and pos.x < Battle.W + 50:
			keep.append(w)
	waves = keep

func _update_rains(delta: float) -> void:
	var keep: Array = []
	for r in rains:
		r["t"] = float(r["t"]) + delta
		var t: float = r["t"]
		for a in r["arrows"]:
			if a["done"] or t < float(a["land"]):
				continue
			a["done"] = true
			var p: Vector2 = a["p"]
			for e in battle.query(p, 12.0):
				if e.dead or e.faction == r["faction"]:
					continue
				if e.global_position.distance_to(p) <= 6.0 + e.radius:
					var h: Dictionary = r["hit"].duplicate()
					h["src_pos"] = p + Vector2(-6, -12)
					h["ranged"] = true
					e.take_hit(_valid_owner(r["owner"]), h)
			if r["gold"]:
				battle.decals.stamp(Art.tex["gold_sword_stuck"], p - Vector2(4, 14), randf() < 0.5, Color.WHITE)
				battle.fx.hit_star(p + Vector2(0, -4), 9.0, Color(1.0, 0.85, 0.4), 0.14)
				battle.fx.sparks(p, Color(1.0, 0.85, 0.4), 4)
				battle.fx.snow_puff(p)
				if battle.on_screen(p) and randf() < 0.3:
					Sfx.play_at("clank", p, -10.0, randf_range(1.1, 1.4))
			elif randf() < 0.55:
				battle.decals.stuck_arrow(p)
			else:
				battle.fx.snow_puff(p)
		if t < float(r["last"]) + 0.25:
			keep.append(r)
	rains = keep

func draw_lights(l: LightPainter) -> void:
	for w in waves:
		var life := clampf(float(w["left"]) / float(w["range"]), 0.0, 1.0)
		var c := Color(0.7, 0.9, 1.0) if w["kind"] == "wave" else Color(1.0, 0.8, 0.6)
		l.glow(w["pos"], 30.0, c * (0.8 * life))
	for r in rains:
		var t: float = r["t"]
		if t > float(r["last"]):
			continue
		var col := Color(1.0, 0.2, 0.15) if r["faction"] == 1 else Color(1.0, 0.75, 0.3)
		if r.get("gold", false):
			col = Color(1.0, 0.8, 0.3)
		l.glow(r["target"], float(r["radius"]) * 1.1, col * (0.18 + 0.1 * sin(t * 18.0)))
		if r.get("gold", false):
			for a in r["arrows"]:
				if a["done"]:
					continue
				var k: float = (float(a["land"]) - t) / 0.5
				if k < 0.0 or k > 1.0:
					continue
				l.glow(a["p"] + Vector2(-0.2, -1.0) * k * 200.0, 18.0, Color(1.0, 0.82, 0.4) * 0.9)

func _draw() -> void:
	var at: Texture2D = Art.tex["arrow"]
	var bt: Texture2D = Art.tex["bolt"]
	# Rain telegraphs first (on the ground).
	for r in rains:
		var t: float = r["t"]
		var col := Color(1.0, 0.25, 0.2) if r["faction"] == 1 else Color(1.0, 0.8, 0.35)
		if r["gold"]:
			col = Color(1.0, 0.82, 0.35)
		var fade := clampf(1.0 - (t - float(r["last"])) / 0.25, 0.0, 1.0)
		var pulse := 0.55 + 0.45 * sin(t * 18.0)
		var c: Vector2 = r["target"]
		var rad: float = r["radius"]
		_draw_ellipse(c, rad, rad * 0.7, Color(col.r, col.g, col.b, 0.5 * pulse * fade), 1.0)
		_draw_ellipse(c, rad * 0.45, rad * 0.45 * 0.7, Color(col.r, col.g, col.b, 0.25 * pulse * fade), 1.0)
		if r["gold"]:
			var st: Texture2D = Art.tex["gold_sword"]
			for a in r["arrows"]:
				if a["done"]:
					continue
				var k: float = (float(a["land"]) - t) / 0.5
				if k > 1.0 or k < 0.0:
					continue
				var p: Vector2 = a["p"]
				var fall := Vector2(-0.2, -1.0).normalized()
				var from := p + fall * k * 200.0
				draw_rect(Rect2(p.x - 2, p.y, 5, 1), Color(0.1, 0.06, 0.12, 0.4 * (1.0 - k)))
				draw_line(from, from + fall * 46.0, Color(1.0, 0.85, 0.45, 0.55), 2.0)
				draw_line(from, from + fall * 20.0, Color(1.0, 0.97, 0.85, 0.9), 1.0)
				draw_set_transform(from, (-fall).angle() - PI * 0.5, Vector2.ONE)
				draw_texture(st, Vector2(-3.5, -19))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			continue
		for a in r["arrows"]:
			if a["done"]:
				continue
			var k: float = (float(a["land"]) - t) / 0.4
			if k > 1.0 or k < 0.0:
				continue
			var p: Vector2 = a["p"]
			var from := p + Vector2(-0.45, -1.0) * k * 170.0
			draw_rect(Rect2(p.x - 1, p.y, 3, 1), Color(0.1, 0.1, 0.2, 0.35 * (1.0 - k)))
			draw_set_transform(from, Vector2(0.45, 1.0).angle(), Vector2.ONE)
			draw_texture(at, Vector2(-10, -1))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for s in shots:
		var p: Vector2 = s["pos"]
		var v: Vector2 = s["vel"]
		draw_set_transform(p, v.angle(), Vector2.ONE)
		var tex := at if s["kind"] == "arrow" else bt
		draw_texture(tex, Vector2(-tex.get_width() + 2, -1))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for w in waves:
		var p: Vector2 = w["pos"]
		var dir: Vector2 = w["dir"]
		var life := clampf(float(w["left"]) / float(w["range"]), 0.0, 1.0)
		if w["kind"] == "wave":
			var n := 10
			var ang := dir.angle()
			var wc := Color(0.85, 0.95, 1.0, 0.85 * life)
			var wcols := PackedColorArray([wc, wc, wc, wc])
			for i in n:
				var a0 := ang - 1.2 + 2.4 * i / n
				var a1 := ang - 1.2 + 2.4 * (i + 1) / n
				var b0 := ang - 1.0 + 2.0 * i / n
				var b1 := ang - 1.0 + 2.0 * (i + 1) / n
				draw_primitive(PackedVector2Array([p + Vector2.from_angle(a0) * 22.0, p + Vector2.from_angle(a1) * 22.0,
					p + Vector2.from_angle(b1) * 16.0 - dir * 2.0, p + Vector2.from_angle(b0) * 16.0 - dir * 2.0]), wcols, PackedVector2Array())
			var core := PackedVector2Array()
			for i in n + 1:
				var a := ang - 0.9 + 1.8 * i / n
				core.append(p + Vector2.from_angle(a) * 21.0)
			draw_polyline(core, Color(1, 1, 1, life), 1.0)
		else:
			var tr: Array = w["trail"]
			if tr.size() > 1:
				var pts := PackedVector2Array()
				for q in tr:
					pts.append(q)
				draw_polyline(pts, Color(0.25, 0.22, 0.35, 0.8), 2.0)
			draw_circle(p, 5.0, Color(1, 1, 1, 0.8 * life))

func _draw_ellipse(c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	var n := 28
	for i in n + 1:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, w)
