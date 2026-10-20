class_name Fx
extends Node2D
## Combat effects, drawn above the soldiers with textures from the Kenney Particle Pack and
## Smoke Particles (CC0, assets/fx). Two layers: this node draws normally blended things (blood,
## dust, debris, text, markers); a child layer adds light (slashes, sparks, flashes, rings).
## Slash trails follow the weapon-tip path baked with each swing animation.

var battle = null
var add_layer: Node2D
var tex := {}
var parts: Array = []       # blended particles
var glow: Array = []        # additive particles
var trails: Array = []      # weapon-tip ribbons
var lines: Array = []       # straight streaks (dash slashes, kicks)
var rings: Array = []
var texts: Array = []
var glints: Array = []
var wisps: Array = []
var stars: Array = []       # impact flashes
var arcs: Array = []        # blood sprays
var spins: Array = []
var embers: Array = []      # drifting sparks: [pos, vel, life, max, phase]
var ember_acc := 0.0
var t := 0.0

const MAX_PARTS := 700
const MAX_GLOW := 500
const DUST_SNOW := Color(0.86, 0.88, 0.94)
const DUST_EARTH := Color(0.6, 0.52, 0.4)
var DUST := DUST_EARTH
const BLOOD := Color(0.55, 0.04, 0.08)

func _ready() -> void:
	for n in ["spark_1", "spark_3", "star_1", "star_2", "star_3", "flare", "light_1", "light_2", "circle_1", "ring_1", "ring_2",
			"slash_1", "slash_2", "slash_3", "slash_4", "trace_1", "trace_2", "smoke_1", "smoke_2", "smoke_3", "dirt_1", "dirt_2",
			"dirt_3", "magic_1", "magic_2", "flame_1", "flame_2", "puff_1", "puff_2", "puff_3", "puff_4", "puff_5", "puff_6",
			"smoke_dark_1", "smoke_dark_2", "boom_1", "boom_2", "flash_1", "flash_2", "twirl_1", "scratch_1"]:
		tex[n] = load("res://assets/fx/%s.png" % n)
	if battle != null and battle.level == "snow_plains":
		DUST = DUST_SNOW
	add_layer = Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_layer.material = m
	add_layer.draw.connect(_draw_add)
	add_child(add_layer)
	if DUST == DUST_SNOW:
		# additive light piles up into white blots on white snow: keep it to a sparkle
		add_layer.modulate = Color(0.6, 0.6, 0.6)

func _process(delta: float) -> void:
	if battle == null:
		return
	var _e0 := Time.get_ticks_usec()
	_process_impl(delta)
	Prof.add("fx.process", Time.get_ticks_usec() - _e0)

func _process_impl(delta: float) -> void:
	delta = minf(delta, 1.0 / 30.0)
	t += delta
	_tick(trails, delta, func(e): return e["t"] < float(e["dur"]) + 0.14)
	_tick(lines, delta, func(e): return e["t"] < 0.28)
	_tick(rings, delta, func(e): return e["t"] < float(e["dur"]))
	_tick(texts, delta, func(e): return e["t"] < 0.9)
	_tick(glints, delta, func(e): return e["t"] < 0.34)
	_tick(wisps, delta, func(e): return e["t"] < float(e["dur"]))
	_tick(stars, delta, func(e): return e["t"] < float(e["dur"]))
	_tick(arcs, delta, func(e): return e["t"] < 0.32)
	_tick(spins, delta, func(e): return e["t"] < float(e["dur"]))
	_embers(delta)
	parts = _step_parts(parts, delta, true)
	glow = _step_parts(glow, delta, false)
	queue_redraw()
	add_layer.queue_redraw()

func _step_parts(arr: Array, delta: float, land: bool) -> Array:
	var keep: Array = []
	for p in arr:
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			continue
		p["p"] = p["p"] + p["v"] * delta
		var drag: float = p["drag"]
		if drag > 0.0:
			p["v"] = p["v"] * maxf(0.0, 1.0 - drag * delta)
		p["rot"] = float(p["rot"]) + float(p["spin"]) * delta
		if p["grav"]:
			p["vz"] = float(p["vz"]) - 300.0 * delta
			p["z"] = float(p["z"]) + float(p["vz"]) * delta
			if float(p["z"]) <= 0.0:
				if land and p["kind"] == "blood" and battle.decals:
					battle.decals.blood_drop(p["p"])
				continue
		else:
			p["z"] = float(p["z"]) + float(p["vz"]) * delta
		keep.append(p)
	return keep

func _tick(arr: Array, delta: float, alive: Callable) -> void:
	var i := 0
	while i < arr.size():
		var e: Dictionary = arr[i]
		e["t"] = float(e["t"]) + delta
		if alive.call(e):
			i += 1
		else:
			arr.remove_at(i)

## A particle. size/size1: start and end size in world units; col/col1: start and end colour.
func _p(add: bool, tx: String, p: Vector2, v: Vector2, life: float, size: float, size1: float, col: Color, col1: Color,
		z: float = 0.0, vz: float = 0.0, grav: bool = false, drag: float = 0.0, rot: float = 0.0, spin: float = 0.0,
		kind: String = "", stretch: float = 0.0) -> void:
	var arr := glow if add else parts
	if arr.size() >= (MAX_GLOW if add else MAX_PARTS):
		return
	arr.append({"tx": tx, "p": p, "v": v, "life": life, "max": life, "s0": size, "s1": size1, "c0": col, "c1": col1,
		"z": z, "vz": vz, "grav": grav, "drag": drag, "rot": rot, "spin": spin, "kind": kind, "st": stretch})

# ------------------------------------------------------------------ ambient embers
func _embers(delta: float) -> void:
	var c: Vector2 = battle.cam.get_screen_center_position()
	ember_acc += delta * (3.0 + 10.0 * float(battle.atmos.cur.get("night", 0.0)))
	while ember_acc > 1.0:
		ember_acc -= 1.0
		var p := c + Vector2(randf_range(-360.0, 300.0), randf_range(-200.0, 200.0))
		embers.append([p, Vector2(randf_range(18.0, 40.0), randf_range(-16.0, -4.0)), 0.0, randf_range(3.0, 6.0), randf() * TAU])
	for fp in battle.fires:
		var f: Vector2 = fp
		if absf(f.x - c.x) < 380.0 and absf(f.y - c.y) < 240.0 and randf() < delta * 3.0:
			embers.append([f + Vector2(randf_range(-6, 6), -6), Vector2(randf_range(4.0, 26.0), randf_range(-40.0, -20.0)), 0.0, randf_range(1.6, 3.2), randf() * TAU])
	var i := 0
	while i < embers.size():
		var e: Array = embers[i]
		e[2] = float(e[2]) + delta
		if float(e[2]) >= float(e[3]):
			embers.remove_at(i)
			continue
		var v: Vector2 = e[1]
		e[0] = e[0] + (v + Vector2(sin(float(e[2]) * 2.0 + float(e[4])) * 8.0, 0.0)) * delta
		i += 1
	if embers.size() > 160:
		embers = embers.slice(embers.size() - 160)

# ------------------------------------------------------------------ spawners (public API)
## The slash of a swing: a ribbon along the weapon tip's baked path (straight streak for thrusts).
func swing_trail(u: Unit, mv: Dictionary) -> void:
	if not battle.on_screen(u.global_position):
		return
	var col := Color(1.0, 0.95, 0.82, 0.85)
	var w: float = float(mv.get("trail", 1.0))
	if not u.is_player:
		col = Color(0.75, 0.82, 1.0, 0.35) if u.faction == 0 else Color(0.8, 0.85, 1.0, 0.35)
		w *= 0.6
	if u.is_boss:
		col = Color(0.78, 0.55, 1.0, 0.9)
		w = 1.3
	if mv.get("perilous", false):
		col = Color(1.0, 0.3, 0.25, 0.95)
	if u.is_player:
		w *= 1.7
		if mv.get("finisher", false):
			col = Color(1.0, 0.72, 0.35, 0.95)
			w *= 1.35
	if u.is_player and mv.get("riposte", false):
		col = Color(0.55, 1.0, 0.87, 0.95)
		w *= 1.2
	var pts := UnitArt.trail(u.aset, u.mv_anim, u.dir8)
	if pts.size() < 2:
		return
	trails.append({"u": u, "pts": pts, "s": u.base_scale.x, "t": 0.0, "dur": maxf(0.09, float(mv["a"]) * 1.4),
		"col": col, "w": w, "o": u.trail_origin()})

func spin(u: Unit, r: float) -> void:
	var col := Color(1.0, 0.95, 0.85, 0.85) if u.is_player else Color(0.78, 0.55, 1.0, 0.8)
	spins.append({"u": u, "r": r, "t": 0.0, "dur": 0.2, "col": col, "a": randf() * TAU})

func line_slash(a: Vector2, b: Vector2, col: Color) -> void:
	lines.append({"a": a, "b": b, "t": 0.0, "col": col})

func ring(p: Vector2, r: float, col: Color, dur: float) -> void:
	rings.append({"p": p, "r": r, "col": col, "dur": dur, "t": 0.0})

func text(p: Vector2, s: String, col: Color) -> void:
	# Merge repeated messages in a crowd and stack the few distinct ones.
	var close := 0
	for e in texts:
		if (e["p"] as Vector2).distance_squared_to(p)<1600 and float(e["t"])<0.55:
			if e["s"]==s:
				return
			close += 1
	if close>=3:
		return
	if texts.size()>20:
		texts.remove_at(0)
	texts.append({"p":p+Vector2(0,-close*10),"s":s,"col":col,"t":0.0})

func glint(u: Unit, red: bool) -> void:
	if battle.on_screen(u.global_position):
		glints.append({"u": u, "red": red, "t": 0.0})
		if red:
			Sfx.play_at("ui", u.global_position, -2.0, 0.5)

var ghost_mat: ShaderMaterial

func afterimage(u: Unit, col: Color = Color(0.45, 0.75, 1.0, 0.34)) -> void:
	if not u.body.visible or u.body.texture == null or get_child_count() > 60:
		return
	# one echo every few hundredths of a second, and only once the body has moved on, so
	# a long rush leaves a spaced trail instead of a white smear piling up in one spot
	var last: Vector2 = u.get_meta("echo_p", Vector2.INF)
	if t - float(u.get_meta("echo_t", -1.0)) < 0.035 or last.distance_to(u.global_position) < 7.0:
		return
	u.set_meta("echo_t", t)
	u.set_meta("echo_p", u.global_position)
	if u.is_player and col.b > col.r:
		col = Color(1.0, 0.62, 0.3, col.a)
	if ghost_mat == null:
		ghost_mat = ShaderMaterial.new()
		ghost_mat.shader = load("res://shaders/ghost.gdshader")
	for src in [u.body, u.wpn]:
		if not src.visible:
			continue
		var s := Sprite2D.new()
		s.texture = src.texture
		s.region_enabled = true
		s.region_rect = src.region_rect
		s.centered = false
		s.offset = src.offset
		s.flip_h = src.flip_h
		s.material = ghost_mat
		s.modulate = col
		add_child(s)
		s.global_transform = src.get_global_transform()
		var tw := s.create_tween()
		tw.tween_property(s, "modulate:a", 0.0, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(s.queue_free)

## A burst of hot metal: streaks flying out, a flare at the point.
func sparks(p: Vector2, col: Color, n: int) -> void:
	if not battle.on_screen(p):
		return
	for i in n:
		var a := randf() * TAU
		var s := randf_range(80, 240)
		var v := Vector2(cos(a), sin(a) * 0.7) * s
		_p(true, "trace_2", p, v, randf_range(0.1, 0.24), randf_range(4.0, 7.0), 1.0, col, Color(col.r, col.g * 0.6, col.b * 0.3, 0.0),
			0.0, 0.0, false, 7.0, v.angle() + PI * 0.5, 0.0, "streak", 1.0)
	_p(true, "flare", p, Vector2.ZERO, 0.12, 14.0, 22.0, Color(col.r, col.g, col.b, 0.9), Color(col.r, col.g, col.b, 0.0))

## Droplets thrown off a wound, falling to the ground (where they stain it).
func blood(p: Vector2, dir: Vector2, n: int) -> void:
	if not battle.on_screen(p):
		return
	for i in n:
		var d := dir.rotated(randf_range(-0.9, 0.9)) * randf_range(40, 150)
		var c := BLOOD.lightened(randf_range(0.0, 0.25))
		_p(false, "circle_1", p + Vector2(0, 10), d, 1.2, randf_range(1.4, 2.6), 1.2, c, c, 10.0, randf_range(30, 100), true, 1.4, 0.0, 0.0, "blood")
	if n >= 10:
		_p(false, "smoke_2", p, dir * 30.0, 0.35, 8.0, 18.0, Color(0.5, 0.03, 0.06, 0.55), Color(0.4, 0.02, 0.05, 0.0), 0.0, 0.0, false, 3.0, randf() * TAU)

func burst(p: Vector2, col: Color, n: int) -> void:
	for i in n:
		var a := randf() * TAU
		_p(false, "circle_1", p + Vector2(0, 10), Vector2(cos(a), sin(a)) * randf_range(40, 160), 1.4, randf_range(1.4, 2.8), 1.0,
			col, col, 10.0, randf_range(40, 140), true, 1.5, 0.0, 0.0, "blood" if col.r > col.g * 2.0 else "")

## A low puff of dust kicked up from the ground (landings, falls, skids).
func dust(p: Vector2, n: int = 6) -> void:
	if not battle.on_screen(p):
		return
	for i in n:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a) * 0.45) * randf_range(14, 50)
		_p(false, "puff_%d" % (1 + randi() % 6), p + Vector2(cos(a) * 3.0, sin(a) * 1.5), v, randf_range(0.45, 0.8),
			randf_range(6.0, 9.0), randf_range(14.0, 22.0), Color(DUST.r, DUST.g, DUST.b, 0.55), Color(DUST.r, DUST.g, DUST.b, 0.0),
			2.0, randf_range(4, 14), false, 3.0, randf() * TAU, randf_range(-1.0, 1.0))

## Golden-red flames of the General's Aura licking upward around the player.
func aura_flames(u: Unit, delta: float) -> void:
	var n := int(delta * 40.0 + randf())
	for i in n:
		var a := randf() * TAU
		var r := randf_range(4.0, 12.0)
		var col := Color(1.0, 0.8, 0.4, 0.8) if randf() < 0.5 else Color(1.0, 0.42, 0.18, 0.8)
		_p(true, "flame_%d" % (1 + randi() % 2), u.global_position + Vector2(cos(a) * r, sin(a) * r * 0.5), Vector2(randf_range(-6, 6), 0),
			randf_range(0.35, 0.7), randf_range(5.0, 8.0), 2.0, col, Color(col.r, col.g * 0.5, 0.1, 0.0), randf_range(0, 14), randf_range(30, 70))

func aura_burst(u: Unit) -> void:
	for i in 40:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a) * 0.6) * randf_range(80, 260)
		_p(true, "trace_2", u.global_position + Vector2(0, -10), v, randf_range(0.3, 0.6), 8.0, 2.0, Color(1.0, 0.75, 0.35, 0.9),
			Color(1.0, 0.4, 0.1, 0.0), 0.0, 0.0, false, 3.0, v.angle() + PI * 0.5, 0.0, "streak", 1.0)
	_p(true, "flash_1", u.global_position + Vector2(0, -12), Vector2.ZERO, 0.4, 30.0, 90.0, Color(1.0, 0.7, 0.35, 0.8), Color(1.0, 0.5, 0.2, 0.0))

## The quick streak of a front kick and the dust it throws up.
func kick_streak(u: Unit) -> void:
	var a := u.global_position + Vector2(0, -8)
	line_slash(a + u.aim * 4.0, a + u.aim * 24.0, Color(0.85, 0.92, 1.0))
	dust(u.global_position + u.aim * 8.0, 3)

func heal(u: Unit) -> void:
	for i in 16:
		_p(true, "star_1", u.global_position + Vector2(randf_range(-9, 9), 0), Vector2(randf_range(-8, 8), 0), randf_range(0.5, 0.9),
			randf_range(4.0, 7.0), 1.0, Color(1.0, 0.86, 0.5, 0.9), Color(1.0, 0.7, 0.3, 0.0), randf_range(0, 16), randf_range(25, 55), false, 1.0, randf() * TAU)
	ring(u.global_position, 18.0, Color(1.0, 0.85, 0.45, 0.8), 0.35)

func skill_flash(u: Unit) -> void:
	var col := Color(0.65, 0.88, 1.0, 0.9) if u.faction == 0 else Color(0.85, 0.6, 1.0, 0.9)
	ring(u.global_position, 24.0, col, 0.32)
	_p(true, "magic_1", u.global_position + Vector2(0, -14), Vector2.ZERO, 0.3, 16.0, 40.0, col, Color(col.r, col.g, col.b, 0.0), 0.0, 0.0, false, 0.0, randf() * TAU, 3.0)
	sparks(u.global_position + Vector2(0, -14), col, 8)

## Earth thrown up by a slam: chunks of dirt arcing out and a ring of dust.
func debris(p: Vector2, r: float) -> void:
	for i in 26:
		var a := randf() * TAU
		var q := p + Vector2(cos(a), sin(a) * 0.6) * randf_range(0.2, 1.0) * r
		_p(false, "dirt_%d" % (1 + randi() % 3), q, Vector2(cos(a), sin(a)) * randf_range(20, 80), 1.1, randf_range(3.0, 6.0), 2.0,
			Color(0.5, 0.42, 0.3), Color(0.45, 0.38, 0.28), 0.0, randf_range(60, 140), true, 1.0, randf() * TAU, randf_range(-8, 8))
	for i in 10:
		var a := TAU * i / 10.0
		var q := p + Vector2(cos(a), sin(a) * 0.5) * r * 0.7
		_p(false, "puff_%d" % (1 + randi() % 6), q, Vector2(cos(a), sin(a) * 0.5) * 50.0, 0.7, 10.0, 26.0, Color(DUST.r, DUST.g, DUST.b, 0.6),
			Color(DUST.r, DUST.g, DUST.b, 0.0), 2.0, 8.0, false, 2.5, randf() * TAU)

func debris_at(p: Vector2) -> void:
	_p(false, "dirt_%d" % (1 + randi() % 3), p, Vector2(randf_range(-20, 20), randf_range(-10, 10)), 1.0, 4.0, 2.0,
		Color(0.55, 0.46, 0.34), Color(0.5, 0.42, 0.3), 0.0, randf_range(60, 120), true, 1.0, randf() * TAU, randf_range(-6, 6))

## Dust and turf kicked up behind a dash or a galloping horse.
func snow_kick(p: Vector2, dir: Vector2, n: int = 8) -> void:
	if not battle.on_screen(p):
		return
	for i in mini(n, 6):
		var d := dir.rotated(randf_range(-0.6, 0.6)) * randf_range(30, 90)
		_p(false, "puff_%d" % (1 + randi() % 6), p + Vector2(randf_range(-3, 3), 0), d, randf_range(0.35, 0.6), 5.0, 14.0,
			Color(DUST.r, DUST.g, DUST.b, 0.5), Color(DUST.r, DUST.g, DUST.b, 0.0), 1.0, 6.0, false, 4.0, randf() * TAU)
	for i in n / 2:
		var d := dir.rotated(randf_range(-0.7, 0.7)) * randf_range(40, 110)
		_p(false, "dirt_%d" % (1 + randi() % 3), p, d, 0.8, randf_range(2.0, 3.5), 1.5, Color(0.42, 0.36, 0.26), Color(0.4, 0.34, 0.24),
			0.0, randf_range(30, 70), true, 2.0, randf() * TAU, randf_range(-6, 6))

## A small puff of breath vapour in the cold air.
func breath(p: Vector2, dir_x: float) -> void:
	_p(false, "puff_%d" % (1 + randi() % 6), p, Vector2(dir_x * randf_range(8, 14), randf_range(-3, 3)), randf_range(0.6, 1.0), 2.0, 6.0,
		Color(0.92, 0.95, 1.0, 0.35), Color(0.92, 0.95, 1.0, 0.0), 0.0, randf_range(3, 8), false, 1.5, randf() * TAU)

## A small kick of earth (or snow) where an arrow or a thrown weapon lands. Volleys drop
## dozens at once, so each one stays light.
func snow_puff(p: Vector2) -> void:
	if not battle.on_screen(p) or parts.size() > 500:
		return
	for i in 2:
		var a := randf() * TAU
		_p(false, "puff_%d" % (1 + randi() % 6), p, Vector2(cos(a), sin(a) * 0.4) * randf_range(8, 22), randf_range(0.3, 0.5), 3.0, 8.0,
			Color(DUST.r, DUST.g, DUST.b, 0.38), Color(DUST.r, DUST.g, DUST.b, 0.0), 1.0, 4.0, false, 3.0, randf() * TAU)

## Anime-style impact flash at the point of a hit: a four-point star and a soft bloom.
func hit_star(p: Vector2, size: float, col: Color = Color(1.0, 0.97, 0.88), dur: float = 0.12) -> void:
	if not battle.on_screen(p) or stars.size() > 30:
		return
	stars.append({"p": p, "s": size, "col": col, "t": 0.0, "dur": dur, "rot": randf_range(-0.4, 0.4), "tx": ["star_2", "star_3"][randi() % 2]})

## A crescent spray of blood flying off a heavy hit.
func blood_arc(p: Vector2, dir: Vector2, size: float = 8.0) -> void:
	if not battle.on_screen(p) or arcs.size() > 30:
		return
	arcs.append({"p": p, "dir": dir.normalized(), "s": size, "t": 0.0, "tx": "slash_%d" % (1 + randi() % 4), "flip": randf() < 0.5})

func wisp(a: Vector2, b: Vector2) -> void:
	wisps.append({"a": a, "b": b, "t": 0.0, "dur": 0.45})

# ------------------------------------------------------------------ light emission
## Everything bright in the effects also lights its surroundings (see LightPainter).
func draw_lights(l: LightPainter) -> void:
	for e in trails:
		var k: float = clampf(float(e["t"]) / float(e["dur"]), 0.0, 1.0)
		var col: Color = e["col"]
		var pts: PackedVector2Array = e["pts"]
		var o: Vector2 = e["o"]
		var tip := o + pts[int(k * (pts.size() - 1))] * float(e["s"])
		l.glow(tip, 18.0, Color(col.r, col.g, col.b) * (0.5 * col.a * (1.0 - k * 0.5)))
	for e in lines:
		var k := float(e["t"]) / 0.28
		var col: Color = e["col"]
		l.glow_line(e["a"], e["b"], 14.0, Color(col.r, col.g, col.b) * (0.7 * (1.0 - k)))
	for e in rings:
		var k := float(e["t"]) / float(e["dur"])
		var col: Color = e["col"]
		l.glow(e["p"], float(e["r"]) * 1.3, Color(col.r, col.g, col.b) * (col.a * 0.6 * (1.0 - k)))
	for g in glints:
		var u = g["u"]
		if not is_instance_valid(u) or u.dead:
			continue
		var k := float(g["t"]) / 0.34
		var c := Color(1.0, 0.2, 0.15) if g["red"] else Color(1.0, 0.95, 0.85)
		l.glow(u.global_position + Vector2(0, -16), 30.0, c * (sin(k * PI) * (1.2 if g["red"] else 0.7)))
	for e in stars:
		var k := float(e["t"]) / float(e["dur"])
		var col: Color = e["col"]
		l.glow(e["p"], float(e["s"]) * 3.0, Color(col.r, col.g, col.b) * (1.0 - k) * 0.9)
	for w in wisps:
		var k := float(w["t"]) / float(w["dur"])
		var a: Vector2 = w["a"]
		var b: Vector2 = w["b"]
		var mid := a.lerp(b, 0.5) + Vector2(0, -60)
		l.glow(a.lerp(mid, k).lerp(mid.lerp(b, k), k), 40.0, Color(1.0, 0.75, 0.4) * 1.2)

# ------------------------------------------------------------------ drawing: blended layer
func _draw() -> void:
	var _d0 := Time.get_ticks_usec()
	_draw_impl()
	Prof.add("fx.draw", Time.get_ticks_usec() - _d0)

func _draw_part(p: Dictionary) -> void:
	var k := float(p["life"]) / float(p["max"])
	var tx: Texture2D = tex[p["tx"]]
	var s: float = lerpf(float(p["s1"]), float(p["s0"]), k)
	var col: Color = (p["c1"] as Color).lerp(p["c0"], k)
	var pos: Vector2 = p["p"] - Vector2(0, float(p["z"]))
	var ts := tx.get_size()
	var sc := s / maxf(ts.x, ts.y)
	var st: float = p["st"]
	if st > 0.0:
		# streaks stretch with their speed
		var v: Vector2 = p["v"]
		var len := clampf(v.length() * 0.05, 1.0, 5.0)
		draw_set_transform(pos, float(p["rot"]), Vector2(sc, sc * len))
	else:
		draw_set_transform(pos, float(p["rot"]), Vector2(sc, sc))
	draw_texture(tx, -ts * 0.5, col)

func _draw_impl() -> void:
	if battle == null:
		return
	_draw_pickups()
	_draw_soft_target()
	for p in parts:
		_draw_part(p)
	for e in arcs:
		var k := float(e["t"]) / 0.32
		var dir: Vector2 = e["dir"]
		var tx: Texture2D = tex[e["tx"]]
		var s: float = float(e["s"]) * (1.6 + k * 1.6)
		var sc := s / tx.get_width()
		draw_set_transform(e["p"] + dir * s * 0.3, dir.angle() + PI * 0.5, Vector2(sc * (-1.0 if e["flip"] else 1.0), sc * 0.8))
		draw_texture(tx, -tx.get_size() * 0.5, Color(BLOOD.r, BLOOD.g, BLOOD.b, 0.9 * (1.0 - k * k)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_bars()
	for e in texts:
		var k := float(e["t"]) / 0.9
		var rise := 1.0 - pow(1.0 - minf(k * 1.6, 1.0), 3.0)
		var p: Vector2 = e["p"] + Vector2(0, -rise * 16.0)
		var col: Color = e["col"]
		var a := 1.0 - smoothstep(0.65, 1.0, k)
		Game.text(self, p, e["s"], 5, Color(col.r, col.g, col.b, a), 1)

# ------------------------------------------------------------------ drawing: additive layer
func _draw_add() -> void:
	if battle == null:
		return
	var L := add_layer
	var eg: Texture2D = tex["light_2"]
	for e in embers:
		var k: float = float(e[2]) / float(e[3])
		var a: float = sin(k * PI) * (0.6 + 0.4 * sin(t * 9.0 + float(e[4]) * 5.0))
		L.draw_texture_rect(eg, Rect2(e[0] - Vector2(3, 3), Vector2(6, 6)), false, Color(1.0, 0.5, 0.2, 0.7 * a))
	for e in trails:
		_draw_trail(e)
	for e in spins:
		var u = e["u"]
		var c: Vector2 = (u.global_position if is_instance_valid(u) else Vector2.ZERO) + Vector2(0, -12)
		var k := float(e["t"]) / float(e["dur"])
		var tx: Texture2D = tex["slash_2"]
		var r: float = e["r"]
		var sc := r * 2.2 / tx.get_width()
		var col: Color = e["col"]
		L.draw_set_transform(c, float(e["a"]) + k * TAU * 1.2, Vector2(sc, sc * 0.6))
		L.draw_texture(tx, -tx.get_size() * 0.5, Color(col.r, col.g, col.b, col.a * (1.0 - k)))
	L.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for e in lines:
		var k := float(e["t"]) / 0.28
		var a: Vector2 = e["a"]
		var b: Vector2 = e["b"]
		var col: Color = e["col"]
		var n := (b - a).normalized().orthogonal()
		var w := 4.5 * (1.0 - k)
		var lc := Color(col.r, col.g, col.b, 0.85 * (1.0 - k))
		var cc := Color(col.r, col.g, col.b, 0.0)
		if w > 0.15 and a.distance_squared_to(b) > 1.0:
			L.draw_polygon(PackedVector2Array([a, a.lerp(b, 0.6) + n * w, b, a.lerp(b, 0.6) - n * w]), PackedColorArray([cc, lc, cc, lc]))
		L.draw_line(a, b, Color(1, 1, 1, 0.9 * (1.0 - k)), 1.0)
	for e in rings:
		var k := float(e["t"]) / float(e["dur"])
		var col: Color = e["col"]
		var r: float = float(e["r"]) * (0.3 + 0.7 * (1.0 - (1.0 - k) * (1.0 - k)))
		var tx: Texture2D = tex["ring_2"]
		L.draw_texture_rect(tx, Rect2(e["p"] - Vector2(r, r * 0.58), Vector2(r * 2.0, r * 1.16)), false, Color(col.r, col.g, col.b, col.a * (1.0 - k)))
	for p in glow:
		_draw_add_part(p)
	L.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for g in glints:
		var u = g["u"]
		if not is_instance_valid(u) or u.dead:
			continue
		var tip: Vector2 = u.weapon_tip()
		var k := float(g["t"]) / 0.34
		var s := sin(k * PI) * (26.0 if g["red"] else 16.0)
		var col := Color(1.0, 0.25, 0.15) if g["red"] else Color(1, 1, 0.95)
		var tx: Texture2D = tex["star_3"]
		L.draw_set_transform(tip, k * 1.5, Vector2(s, s) / tx.get_width())
		L.draw_texture(tx, -tx.get_size() * 0.5, col)
		L.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if g["red"]:
			var rt: Texture2D = tex["ring_1"]
			var rr := 14.0 + k * 12.0
			L.draw_texture_rect(rt, Rect2(u.global_position - Vector2(rr, rr * 0.58), Vector2(rr * 2.0, rr * 1.16)), false, Color(1, 0.2, 0.15, 0.8 * (1.0 - k)))
	for e in stars:
		var k := float(e["t"]) / float(e["dur"])
		var sz: float = float(e["s"]) * 2.6 * sin(minf(1.0, k * 1.8) * PI * 0.5 + 0.25) * (1.0 - k * 0.35)
		var col: Color = e["col"]
		var tx: Texture2D = tex[e["tx"]]
		L.draw_set_transform(e["p"], float(e["rot"]), Vector2(sz, sz) / tx.get_width())
		L.draw_texture(tx, -tx.get_size() * 0.5, Color(col.r, col.g, col.b, 1.0 - k * k))
		var lt: Texture2D = tex["light_1"]
		L.draw_set_transform(e["p"], 0.0, Vector2(sz, sz * 0.7) * 1.2 / lt.get_width())
		L.draw_texture(lt, -lt.get_size() * 0.5, Color(col.r, col.g * 0.85, col.b * 0.7, 0.6 * (1.0 - k)))
	L.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for w in wisps:
		var k := float(w["t"]) / float(w["dur"])
		var a: Vector2 = w["a"]
		var b: Vector2 = w["b"]
		var gl: Texture2D = tex["light_1"]
		for i in 6:
			var kk := clampf(k - i * 0.04, 0.0, 1.0)
			var mid := a.lerp(b, 0.5) + Vector2(0, -60)
			var q := a.lerp(mid, kk).lerp(mid.lerp(b, kk), kk) + Vector2(0, -12)
			var sc := (1.0 - i * 0.14) * 22.0
			L.draw_texture_rect(gl, Rect2(q - Vector2(sc, sc), Vector2(sc, sc) * 2.0), false, Color(1.0, 0.8, 0.45, 0.85 - i * 0.12))

func _draw_add_part(p: Dictionary) -> void:
	var L := add_layer
	var k := float(p["life"]) / float(p["max"])
	var tx: Texture2D = tex[p["tx"]]
	var s: float = lerpf(float(p["s1"]), float(p["s0"]), k)
	var col: Color = (p["c1"] as Color).lerp(p["c0"], k)
	var pos: Vector2 = p["p"] - Vector2(0, float(p["z"]))
	var ts := tx.get_size()
	var sc := s / maxf(ts.x, ts.y)
	var st: float = p["st"]
	if st > 0.0:
		var v: Vector2 = p["v"]
		var len := clampf(v.length() * 0.035, 1.0, 6.0)
		L.draw_set_transform(pos, float(p["rot"]), Vector2(sc * 0.6, sc * len))
	else:
		L.draw_set_transform(pos, float(p["rot"]), Vector2(sc, sc))
	L.draw_texture(tx, -ts * 0.5, col)

## A slash ribbon: the weapon tip's path revealed over the active part of the swing, wide and
## bright at the head, thinning and fading toward the tail.
func _draw_trail(e: Dictionary) -> void:
	var L := add_layer
	var u = e["u"]
	var o: Vector2 = e["o"]
	if is_instance_valid(u) and not u.dead:
		o = u.trail_origin()
		e["o"] = o
	var pts: PackedVector2Array = e["pts"]
	var n := pts.size()
	var s: float = e["s"]
	var dur: float = e["dur"]
	var tt: float = e["t"]
	var head := clampf(tt / dur, 0.0, 1.0) * (n - 1)
	var tail := clampf((tt - dur * 0.35) / (dur * 0.65 + 0.14), 0.0, 1.0) * (n - 1)
	if head - tail < 0.3:
		return
	var col: Color = e["col"]
	var w: float = 6.0 * float(e["w"]) * s
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var cols := PackedColorArray()
	var steps := 14
	var center := o + Vector2(0, -12) * s
	for i in steps + 1:
		var f := lerpf(tail, head, float(i) / steps)
		var i0 := int(floor(f))
		var i1 := mini(i0 + 1, n - 1)
		var q: Vector2 = o + pts[i0].lerp(pts[i1], f - i0) * s
		var rel := float(i) / steps
		var away := (q - center).normalized()
		var th := w * rel * rel
		outer.append(q + away * th * 0.25)
		inner.append(q - away * th)
		cols.append(Color(col.r, col.g, col.b, col.a * rel))
	var no_uv := PackedVector2Array()
	for i in steps:
		var c0: Color = cols[i]
		var c1: Color = cols[i + 1]
		L.draw_primitive(PackedVector2Array([outer[i], outer[i + 1], inner[i + 1], inner[i]]),
			PackedColorArray([c0, c1, Color(c1.r, c1.g, c1.b, 0.0), Color(c0.r, c0.g, c0.b, 0.0)]), no_uv)
	L.draw_polyline(outer, Color(1.0, 1.0, 1.0, col.a * 0.9 * (1.0 - clampf((tt - dur) / 0.14, 0.0, 1.0))), 0.8, true)

# ------------------------------------------------------------------ markers and bars
## A light bracket under the enemy your next attack will go to.
func _draw_soft_target() -> void:
	var tg = battle.soft_target
	if tg == null or not is_instance_valid(tg) or tg.dead or battle.possess:
		return
	var p: Vector2 = tg.global_position
	var r: float = tg.radius + 6.0
	var col := Color(1.0, 0.86, 0.55, 0.6)
	if tg.state == Unit.St.BROKEN or tg.state == Unit.St.KNOCKDOWN:
		col = Color(1.0, 0.4, 0.32, 0.9)
	draw_set_transform(p, 0.0, Vector2(1.0, 0.5))
	for i in 4:
		var a := i * PI * 0.5 + PI * 0.25 + t * 0.8
		draw_arc(Vector2.ZERO, r, a - 0.3, a + 0.3, 6, col, 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_bars() -> void:
	# Ordinary soldiers fall in a blow or two and carry no bars. Elites show a hairline bar
	# (and their stance) only once wounded; officers carry their name.
	for u in battle.units:
		if u.dead or u.is_player or u.is_boss or u.spectator or not battle.in_view(u.global_position):
			continue
		var elite: bool = u.is_officer or u.kind in ["heavy", "guard", "cavalry"]
		var top: Vector2 = u.global_position + Vector2(0, -42.0 * u.base_scale.y)
		if u.mounted:
			top.y -= 12.0
		var hurt: bool = u.hp < u.max_hp * 0.995
		if elite and u.faction == 1 and (hurt or u.stance > 0.0):
			var bw := 22.0 if u.is_officer else 14.0
			var bp := (top + Vector2(-bw * 0.5, 0)).floor()
			draw_rect(Rect2(bp - Vector2(0.5, 0.5), Vector2(bw + 1.0, 2.6)), Color(0.04, 0.03, 0.06, 0.7))
			draw_rect(Rect2(bp, Vector2(bw * clampf(u.hp / u.max_hp, 0.0, 1.0), 1.4)), Color("#ec5a4a"))
			if u.stance > 0.0:
				draw_rect(Rect2(bp + Vector2(0, 1.4), Vector2(bw * clampf(u.stance / u.max_stance, 0.0, 1.0), 0.8)), Color("#ffd23f"))
		if u.is_officer and u.faction == 1:
			Game.text(self, top + Vector2(0, -4), u.uname, 5, Color("#ffd9b0"), 1)
		if u.state == Unit.St.BROKEN and u.faction == 1 and battle.player != null and battle.player.global_position.distance_to(u.global_position) < 150.0:
			var pk := 0.5 + 0.5 * sin(t * 16.0)
			var cp := top + Vector2(0, -8)
			draw_colored_polygon(PackedVector2Array([cp + Vector2(0, -4), cp + Vector2(4, 0), cp + Vector2(0, 4), cp + Vector2(-4, 0)]), Color(1, 0.25, 0.2, 0.6 + 0.4 * pk))
			if u == battle.soft_target:
				Game.text(self, cp + Vector2(0, -7), "CRITICAL", 5, Color(1, 0.9, 0.5), 1)

func _draw_pickups() -> void:
	for pk in battle.pickups:
		var p: Vector2 = pk["pos"]
		if not battle.on_screen(p):
			continue
		var w: Weapon = pk["w"]
		var wd: Dictionary = Art.weapons[w.tex_key]
		var tx: Texture2D = wd["tex"]
		var bob := sin(t * 3.0 + p.x) * 1.5
		var rt: Texture2D = tex["ring_1"]
		draw_texture_rect(rt, Rect2(p - Vector2(10, 5), Vector2(20, 10)), false, Color(1, 0.88, 0.5, 0.45 + 0.25 * sin(t * 5.0)))
		draw_set_transform(p + Vector2(1.5, 0.5), -0.5, Vector2(0.72, 0.3))
		draw_texture(tx, -Vector2(tx.get_width() * 0.5, tx.get_height() * 0.5), Color(0.0, 0.0, 0.05, 0.35))
		draw_set_transform(p + Vector2(0, -5 + bob), -0.5, Vector2(0.72, 0.72))
		draw_texture(tx, -Vector2(tx.get_width() * 0.5, tx.get_height() * 0.5))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_candidates() -> void:
	if not battle.possess:
		return
	for i in battle.cands.size():
		var u = battle.cands[i]
		if not is_instance_valid(u) or u.dead:
			continue
		var sel: bool = i == battle.cand_sel
		var col := Color("#ffd23f") if sel else Color(1, 1, 1, 0.55)
		draw_set_transform(u.global_position, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, 12.0 if sel else 9.0, 0.0, TAU, 24, col, 1.0)
		if sel:
			draw_arc(Vector2.ZERO, 15.0 + sin(t * 30.0) * 1.0, 0.0, TAU, 24, Color(1, 0.85, 0.3, 0.6), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if sel:
			var tp: Vector2 = u.global_position + Vector2(0, -44)
			draw_colored_polygon(PackedVector2Array([tp + Vector2(-4, -4), tp + Vector2(4, -4), tp + Vector2(0, 1)]), col)
