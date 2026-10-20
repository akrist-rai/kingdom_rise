class_name WorldBuilder
extends RefCounted
## Builds the environment: shader-painted snowfield and mountains, the massed reserve
## armies along the edges (with torches that light up at dusk), war flags, burning siege
## wrecks with embers and smoke, both war camps and scattered debris. Every prop casts a
## long shadow and every fire is a real light.

const WIND := Vector2(10.0, -2.0)
static var fire_light := 1.0     # strength of fire lights (the burning city has dozens of fires)

static func shader_rect(path: String, rect: Rect2) -> ColorRect:
	var cr := ColorRect.new()
	cr.position = rect.position
	cr.size = rect.size
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load(path)
	cr.material = mat
	mat.set_shader_parameter("origin", rect.position)
	return cr

static func ground(rect: Rect2, top_y: float, map_w: float) -> ColorRect:
	var g := shader_rect("res://shaders/ground.gdshader", rect)
	g.material.set_shader_parameter("top_y", top_y)
	g.material.set_shader_parameter("map_w", map_w)
	return g

static func sky(rect: Rect2, bottom_y: float) -> ColorRect:
	var s := shader_rect("res://shaders/sky.gdshader", rect)
	s.material.set_shader_parameter("bottom_y", bottom_y)
	return s

## Three layers of snow: fine far flakes, soft mid flakes and big out-of-focus bokeh flakes.
static func snow_layers(parent: Node2D) -> Array:
	var out: Array = []
	var specs := [
		{"tex": "px", "n": 240, "v": Vector2(12, 26), "s": Vector2(1, 1), "a": 0.7, "life": 6.0},
		{"tex": "flake", "n": 110, "v": Vector2(20, 40), "s": Vector2(0.45, 0.7), "a": 0.85, "life": 5.0},
		{"tex": "blob", "n": 12, "v": Vector2(60, 110), "s": Vector2(0.5, 1.1), "a": 0.22, "life": 3.0},
	]
	for sp in specs:
		var p := CPUParticles2D.new()
		p.amount = sp["n"]
		p.lifetime = sp["life"]
		p.preprocess = sp["life"]
		p.local_coords = false
		p.texture = Art.tex[sp["tex"]]
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(440, 280)
		p.position = Vector2(-60, -80)
		p.direction = Vector2(0.35, 1)
		p.spread = 14.0
		p.gravity = Vector2(8, 10)
		p.initial_velocity_min = sp["v"].x
		p.initial_velocity_max = sp["v"].y
		p.scale_amount_min = sp["s"].x
		p.scale_amount_max = sp["s"].y
		p.color = Color(1, 1, 1, sp["a"])
		parent.add_child(p)
		out.append(p)
	return out

static func prop(parent: Node, key: String, pos: Vector2, flip: bool = false, shadows: ShadowLayer = null, shadow_k: float = 1.0) -> Sprite2D:
	var s := Sprite2D.new()
	var t: Texture2D = Art.tex[key]
	s.texture = t
	s.centered = false
	s.offset = Vector2(-t.get_width() * 0.5, -t.get_height() + 1)
	s.position = pos
	s.flip_h = flip
	parent.add_child(s)
	if shadows != null:
		s.set_meta("shadow", shadows.add_static(t, pos, s.offset, flip, shadow_k))
	return s

## Draws a dense crowd of soldiers in one canvas item (cheap, static). Figures are baked soldiers
## (UnitArt.crowd_figures), team-coloured.
class Crowd extends Node2D:
	var figs: Array = []       # [figure dict, position, flip]
	var torches: Array = []
	static func _pal(fac: String) -> String:
		return "march" if fac == "qin" else "crown"
	func add_row(fac: String, x0: float, x1: float, y: float, spacing: float, jitter: float, rng: RandomNumberGenerator, torch_every: int = 0) -> void:
		var arr: Array = UnitArt.crowd_figures(_pal(fac))
		if arr.is_empty():
			return
		var x := x0
		var i := 0
		while x < x1:
			var p := Vector2(x + rng.randf_range(-jitter, jitter), y + rng.randf_range(-jitter, jitter)).floor()
			var flip := rng.randf() < 0.5
			if torch_every > 0 and i % torch_every == torch_every / 2:
				torches.append(p + Vector2(-2.0 if flip else 2.0, -20.0))
			figs.append([arr[rng.randi() % arr.size()], p, flip])
			x += spacing * 1.6 + rng.randf_range(-1.0, 2.0)
			i += 1
	func add_ring(fac_left: String, fac_right: String, c: Vector2, rx: float, ry: float, rows: int, rng: RandomNumberGenerator, half: int = 0, torch_every: int = 0) -> void:
		for r in rows:
			var rr := 1.0 + r * 0.11
			var n := int(TAU * rx * rr / 11.0)
			for i in n:
				var a := TAU * i / n + rng.randf_range(-0.01, 0.01)
				if (half == 1 and sin(a) > 0.0) or (half == 2 and sin(a) <= 0.0):
					continue
				var p := (c + Vector2(cos(a) * rx * rr, sin(a) * ry * rr) + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))).floor()
				var fac := fac_left if cos(a) < 0.0 else fac_right
				var flip := cos(a) > 0.0
				if torch_every > 0 and r == 0 and i % torch_every == 0:
					torches.append(p + Vector2(-2.0 if flip else 2.0, -20.0))
				var arr: Array = UnitArt.crowd_figures(_pal(fac))
				if not arr.is_empty():
					figs.append([arr[rng.randi() % arr.size()], p, flip])
	func finish() -> void:
		figs.sort_custom(func(a, b): return a[1].y < b[1].y)
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/crowd.gdshader")
		material = m
		queue_redraw()
	func set_excite(v: float) -> void:
		(material as ShaderMaterial).set_shader_parameter("excite", v)
	func _draw() -> void:
		for f in figs:
			var d: Dictionary = f[0]
			var t: Texture2D = d["tex"]
			var p: Vector2 = f[1]
			var sz := t.get_size()
			var ax: float = d["ax"]
			if f[2]:
				ax = sz.x - ax
			var rect := Rect2(p - Vector2(ax, float(d["ay"])), sz)
			if f[2]:
				rect = Rect2(rect.position + Vector2(sz.x, 0), Vector2(-sz.x, sz.y))
			var ph := fposmod(p.x * 0.618 + p.y * 0.377, 1.0) / 97.0 * 97.0
			draw_texture_rect(t, rect, false, Color(1.0, 1.0, ph))

## Registers night-only torch lights for a crowd and remembers the flames for flicker.
static func light_torches(b, c: Crowd) -> void:
	for tp in c.torches:
		b.atmos.add_light(tp, 16.0, Color(1.0, 0.58, 0.28) * 0.7, 0.35, true)

## A burning spot: animated flames, glowing embers, a smoke column and a flickering light.
static func fire(b, pos: Vector2, size: int, parent: Node = null) -> void:
	var keys := ["flame_sm", "flame_med", "flame_big"]
	var counts := [1, 2, 3]
	var spread := [2.0, 6.0, 12.0]
	var host: Node = parent if parent != null else b.world
	for i in counts[size]:
		var key: String = keys[clampi(size - (1 if i > 0 else 0), 0, 2)]
		var fp := pos + Vector2(randf_range(-spread[size], spread[size]), randf_range(-2.0, 3.0))
		var s := Sprite2D.new()
		s.texture = Art.tex[key + "0"]
		s.centered = false
		var ts: Vector2 = s.texture.get_size()
		s.offset = Vector2(-ts.x * 0.5, -ts.y + 1)
		s.position = fp
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = m
		host.add_child(s)
		b.flames.append([s, key, randi() % 4])
	var r: float = [28.0, 55.0, 90.0][size]
	b.atmos.add_light(pos + Vector2(0, -4), r, Color(1.0, 0.5, 0.2) * (0.75 + size * 0.1) * fire_light, 0.28)
	if "hazards" in b:
		b.hazards.append({"pos": pos, "r": [9.0, 14.0, 22.0][size], "kind": "fire"})
		b.fires.append(pos)
	var em := CPUParticles2D.new()
	em.amount = [5, 10, 18][size]
	em.lifetime = 2.2
	em.preprocess = 2.0
	em.local_coords = false
	em.texture = Art.tex["px"]
	em.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	em.emission_rect_extents = Vector2(spread[size] + 2.0, 2)
	em.position = pos + Vector2(0, -6)
	em.direction = Vector2(0.2, -1)
	em.spread = 25.0
	em.gravity = Vector2(WIND.x * 0.8, -18)
	em.initial_velocity_min = 12.0
	em.initial_velocity_max = 34.0
	em.scale_amount_min = 1.0
	em.scale_amount_max = 1.0
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.45, 1.0))
	grad.set_color(1, Color(1.0, 0.25, 0.1, 0.0))
	em.color_ramp = grad
	var am := CanvasItemMaterial.new()
	am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	em.material = am
	em.visibility_layer = 3
	b.glowfx.add_child(em)
	if "fire_emitters" in b:
		b.fire_emitters.append(em)
	if size >= 1:
		var sm := CPUParticles2D.new()
		sm.amount = [0, 5, 8][size]
		sm.lifetime = 4.5
		sm.preprocess = 4.5
		sm.local_coords = false
		sm.texture = Art.tex["blob"]
		sm.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		sm.emission_rect_extents = Vector2(spread[size], 2)
		sm.position = pos + Vector2(0, -16)
		sm.direction = Vector2(0.15, -1)
		sm.spread = 12.0
		sm.gravity = Vector2(WIND.x * 0.6, -4)
		sm.initial_velocity_min = 10.0
		sm.initial_velocity_max = 18.0
		sm.scale_amount_min = 0.8
		sm.scale_amount_max = 1.3
		var sc := Curve.new()
		sc.add_point(Vector2(0.0, 0.5))
		sc.add_point(Vector2(1.0, 2.4))
		sm.scale_amount_curve = sc
		var sg := Gradient.new()
		sg.set_color(0, Color(0.5, 0.44, 0.48, 0.0))
		sg.add_point(0.12, Color(0.42, 0.38, 0.4, 0.42))
		sg.set_color(sg.get_point_count() - 1, Color(0.7, 0.68, 0.76, 0.0))
		sm.color_ramp = sg
		sm.texture = load("res://assets/fx/smoke_2.png")
		sm.scale_amount_min = 0.1
		sm.scale_amount_max = 0.16
		b.high.add_child(sm)
		if "fire_emitters" in b:
			b.fire_emitters.append(sm)

static func populate(b) -> void:
	fire_light = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var W: float = Battle.W
	var H: float = Battle.H
	var world: Node2D = b.world
	var sh: ShadowLayer = b.shadows
	# --- reserve armies along the top (behind) and bottom (in front) edges
	var back := Crowd.new()
	b.add_child(back)
	b.move_child(back, b.world.get_index())
	for row in 3:
		var y := 44.0 + row * 9.0
		var te := 9 if row == 2 else 0
		back.add_row("qin", -200.0, W * 0.47, y, 7.0, 1.2, rng, te)
		back.add_row("zhao", W * 0.53, W + 200.0, y, 7.0, 1.2, rng, te)
	back.finish()
	sh.add_crowd(back)
	light_torches(b, back)
	var front := Crowd.new()
	b.add_child(front)
	b.move_child(front, b.world.get_index() + 1)
	for row in 4:
		var y := H - 6.0 + row * 10.0
		var te := 8 if row == 0 else 0
		front.add_row("qin", -200.0, W * 0.47, y, 7.0, 1.4, rng, te)
		front.add_row("zhao", W * 0.53, W + 200.0, y, 7.0, 1.4, rng, te)
	front.finish()
	light_torches(b, front)
	# --- war flags along both edges, great banners at intervals
	for i in range(0, int(W / 120.0) + 1):
		var x := i * 120.0 + rng.randf_range(-20, 20)
		var fac := "qin" if x < W * 0.5 else "zhao"
		var big := i % 3 == 1
		var key := ("gbanner_%s_0" if big else "banner_%s_0") % fac
		var s := prop(world, key, Vector2(x, 72.0 + rng.randf_range(-3, 3)), false, sh)
		b.banners.append([s, fac, rng.randi() % 3, big])
		var s2 := prop(world, "banner_%s_0" % fac, Vector2(x + 50.0, H - 10.0 + rng.randf_range(-3, 3)), false, sh)
		b.banners.append([s2, fac, rng.randi() % 3, false])
	# --- burning siege wrecks across the field
	var wrecks: Array = []
	var tries := 0
	while wrecks.size() < 9 and tries < 400:
		tries += 1
		var wp := Vector2(rng.randf_range(260, W - 260), rng.randf_range(Battle.TOP + 60, Battle.BOT - 50))
		var ok := true
		for o in wrecks:
			if o.distance_to(wp) < 300.0:
				ok = false
		if absf(wp.x - 840.0) < 120.0 and absf(wp.y - H * 0.5) < 120.0:
			ok = false
		if ok:
			wrecks.append(wp)
	for i in wrecks.size():
		var wp: Vector2 = wrecks[i]
		var kind: String = ["wreck_tower", "wreck_cart", "wreck_chariot"][i % 3]
		# a burnt-out engine or wagon: charred timbers and spilled stores (baked props)
		var char_mod := Color(0.42, 0.37, 0.35)
		var parts: Array = {"wreck_tower": [["scaffold", Vector2.ZERO, 0.9], ["lumber", Vector2(26, 10), 0.8], ["ladder", Vector2(-22, 14), 0.8]],
			"wreck_cart": [["cart", Vector2.ZERO, 1.0], ["barrel", Vector2(-20, 8), 0.8], ["crate_open", Vector2(18, 12), 0.8]],
			"wreck_chariot": [["crates_long", Vector2.ZERO, 0.9], ["pallet", Vector2(-18, 10), 0.8], ["sack", Vector2(16, 6), 0.9]]}[kind]
		for pt in parts:
			b.scenery.prop(pt[0], wp + pt[1], {"scale": pt[2], "flip": rng.randf() < 0.5, "mod": char_mod, "solid": pt[1] == Vector2.ZERO})
		fire(b, wp + Vector2(rng.randf_range(-6, 6), -2), 2 if kind == "wreck_tower" else 1)
		for k in 6:
			b.decals.stamp(Art.tex["arrow_stuck"], wp + Vector2(rng.randf_range(-40, 40), rng.randf_range(-20, 24)), rng.randf() < 0.5, Color.WHITE)
		b.decals.scorch(wp + Vector2(0, 2), 30.0 if kind == "wreck_tower" else 20.0)
	# --- scattered debris of earlier fighting
	var keys := ["sword_stuck", "sword_tilt", "spear_stuck", "shield_drop", "stakes", "arrow_stuck"]
	var weights := [10, 8, 6, 4, 3, 12]
	var total := 0
	for wv in weights:
		total += wv
	for i in 170:
		var pos := Vector2(rng.randf_range(80, W - 80), rng.randf_range(Battle.TOP + 10, Battle.BOT - 10))
		var r := rng.randi() % total
		var k := 0
		while r >= weights[k]:
			r -= weights[k]
			k += 1
		if keys[k] == "arrow_stuck" or keys[k] == "shield_drop":
			b.decals.stamp(Art.tex[keys[k]], pos, rng.randf() < 0.5, Color.WHITE)
		else:
			prop(world, keys[k], pos, rng.randf() < 0.5, sh, 0.8 if keys[k].begins_with("sword") or keys[k] == "spear_stuck" else 1.0)
			if keys[k] == "stakes":
				b.hazards.append({"pos": pos + Vector2(0, -3), "r": 9.0, "kind": "stakes"})
	# tall winter grass, swaying (thicker toward the edges of the field)
	var sway := ShaderMaterial.new()
	sway.shader = load("res://shaders/sway.gdshader")
	b.grass_mat = sway
	for i in 300:
		var gp := Vector2(rng.randf_range(20, W - 20), rng.randf_range(Battle.TOP - 4, Battle.BOT + 10))
		var edge := minf(absf(gp.y - Battle.TOP), absf(gp.y - Battle.BOT))
		if edge > 150.0 and rng.randf() < 0.6:
			continue
		var gs := prop(world, "tallgrass%d" % (rng.randi() % 3), gp, rng.randf() < 0.5)
		gs.material = sway
		var sc := rng.randf_range(0.8, 1.25)
		gs.scale = Vector2(sc, sc)
	_dress_snow(b, rng, wrecks)
	# --- war camps (just outside the playable area)
	_camp(b, rng, "qin", -230.0, 20.0)
	_camp(b, rng, "zhao", W + 20.0, W + 230.0)

## Winter dressing from the baked CC0 nature set: a dark pine forest climbing the foothills
## behind the far army and closing in at both flanks, lone dead trees and snow-capped boulders
## across the field, frozen brush, and frosted grass in clumps. Everything takes the snow look.
static func _dress_snow(b, rng: RandomNumberGenerator, wrecks: Array) -> void:
	var S: Scenery = b.scenery
	var W: float = Battle.W
	var top: float = Battle.TOP
	var bot: float = Battle.BOT
	S.set_snow(0.8)
	var start := Vector2(840.0, Battle.H * 0.5)
	var clear := func(p: Vector2) -> bool:
		if p.distance_to(start) < 150.0:
			return true
		for w in wrecks:
			if p.distance_to(w) < 70.0:
				return true
		return false
	# the forest on the foothills: rows of pines, bigger and denser further back
	var y := 14.0
	while y > -230.0:
		var x := -380.0 + rng.randf_range(0.0, 30.0)
		while x < W + 380.0:
			var depth := clampf(-y / 230.0, 0.0, 1.0)
			S.prop("pine_%d" % rng.randi_range(1, 5), Vector2(x, y + rng.randf_range(-8.0, 8.0)),
				{"scale": rng.randf_range(1.0, 1.35) + depth * 0.4, "flip": rng.randf() < 0.5, "sway": "tree",
				"mod": Color(1.0 - depth * 0.25, 1.0 - depth * 0.2, 1.0 - depth * 0.1)})
			x += rng.randf_range(34.0, 62.0) * (1.0 - depth * 0.3)
		y -= rng.randf_range(26.0, 36.0)
	# the flanks beyond the camps
	for side in [-1.0, 1.0]:
		for i in 70:
			var fx: float = (-250.0 - rng.randf_range(0.0, 200.0)) if side < 0.0 else (W + 250.0 + rng.randf_range(0.0, 200.0))
			var fy := rng.randf_range(top - 40.0, bot + 120.0)
			S.prop("pine_%d" % rng.randi_range(1, 5), Vector2(fx, fy), {"scale": rng.randf_range(1.0, 1.5), "flip": rng.randf() < 0.5, "sway": "tree"})
	# lone trees in the field: mostly dead, a few pines
	for i in 22:
		var p := Vector2(rng.randf_range(120.0, W - 120.0), rng.randf_range(top + 30.0, bot - 30.0))
		if clear.call(p):
			continue
		var dead := rng.randf() < 0.7
		var kind: String = "dead_%d" % rng.randi_range(1, 5) if dead else "pine_%d" % rng.randi_range(1, 5)
		# bare wood is baked dark: lift it so the frost and snow on the branches can show
		S.prop(kind, p, {"scale": rng.randf_range(0.85, 1.2), "flip": rng.randf() < 0.5, "sway": "tree", "solid": Rect2(-5, -3, 10, 6),
			"mod": Color(1.9, 1.8, 1.7) if dead else Color.WHITE})
		for k in rng.randi_range(1, 3):
			var q := p + Vector2(rng.randf_range(-26.0, 26.0), rng.randf_range(-6.0, 16.0))
			S.prop(["bush_2", "bush_2", "rock_1", "rock_2"][rng.randi() % 4], q, {"scale": rng.randf_range(0.6, 0.95), "flip": rng.randf() < 0.5, "sway": "bush"})
	# boulders, some in little groups
	for i in 26:
		var p := Vector2(rng.randf_range(60.0, W - 60.0), rng.randf_range(top + 20.0, bot - 20.0))
		if clear.call(p):
			continue
		var big := rng.randf() < 0.35
		S.prop("boulder_%d" % rng.randi_range(1, 3) if big else "rock_%d" % rng.randi_range(1, 3), p,
			{"scale": rng.randf_range(0.7, 1.1), "flip": rng.randf() < 0.5, "solid": big})
		if rng.randf() < 0.5:
			S.prop("rock_%d" % rng.randi_range(1, 3), p + Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(4.0, 12.0)), {"scale": rng.randf_range(0.45, 0.7)})
	# frozen brush and frosted grass
	for i in 40:
		var p := Vector2(rng.randf_range(40.0, W - 40.0), rng.randf_range(top + 10.0, bot))
		if not clear.call(p):
			S.prop("bush_2", p, {"scale": rng.randf_range(0.6, 1.0), "flip": rng.randf() < 0.5, "sway": "bush"})
	var field := Rect2(-200.0, top - 30.0, W + 400.0, bot - top + 90.0)
	S.scatter_clumps(field, 70, Vector2i(3, 7), 24.0, ["grass_1", "grass_2", "grass_3", "grass_4"], rng, clear, Vector2(0.7, 1.05), Color(1.0, 0.92, 0.75))
	S.scatter_clumps(Rect2(-300.0, top - 60.0, W + 600.0, 70.0), 60, Vector2i(3, 7), 30.0, ["grass_1", "grass_3", "fern"], rng, Callable(), Vector2(0.8, 1.2))

static func _camp(b, rng: RandomNumberGenerator, fac: String, x0: float, x1: float) -> void:
	var world: Node2D = b.world
	var sh: ShadowLayer = b.shadows
	var H: float = Battle.H
	var y := Battle.TOP + 30.0
	while y < Battle.BOT:
		var x := rng.randf_range(x0 + 20, x1 - 30)
		prop(world, "tent_" + fac, Vector2(x, y), rng.randf() < 0.5, sh)
		if rng.randf() < 0.6:
			var bp := Vector2(x + rng.randf_range(24, 40), y + rng.randf_range(4, 14))
			prop(world, "brazier", bp, false, sh)
			fire(b, bp + Vector2(0, -6), 0)
		if rng.randf() < 0.5:
			prop(world, "barrel", Vector2(x - 16, y + 6), false, sh)
		y += rng.randf_range(56, 80)
	for i in 6:
		var s := prop(world, "gbanner_%s_0" % fac, Vector2(rng.randf_range(x0, x1), rng.randf_range(Battle.TOP + 20, Battle.BOT - 20)), false, sh)
		b.banners.append([s, fac, rng.randi() % 3, true])
	var sx := (x0 + x1) * 0.5
	for i in 5:
		prop(world, "stakes", Vector2(x1 - 6 if fac == "qin" else x0 + 6, Battle.TOP + 60 + i * 170.0), false, sh)
	prop(world, "drum", Vector2(sx, H * 0.5 + 40), false, sh)
	if fac == "qin":
		# a quiet noodle stall under a tree, lanterns glowing in the snow
		var sp := Vector2(x0 + 70, H * 0.5 - 70)
		prop(world, "pine", sp + Vector2(-26, -4), false, sh)
		prop(world, "stall", sp, false, sh)
		b.atmos.add_light(sp + Vector2(0, -12), 46.0, Color(1.0, 0.62, 0.3), 0.08)
		prop(world, "lantern", sp + Vector2(-30, 8))
		prop(world, "lantern", sp + Vector2(30, 8))
		b.atmos.add_light(sp + Vector2(-30, 4), 18.0, Color(1.0, 0.7, 0.35), 0.15)
		b.atmos.add_light(sp + Vector2(30, 4), 18.0, Color(1.0, 0.7, 0.35), 0.15)
