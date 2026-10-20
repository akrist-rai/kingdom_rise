class_name SiegeLevel
extends RefCounted
## Chapter I: the Siege of Veyre, a burning night. The Qin attack goes north, up the screen.
## Phase 1, storm the wall: a great wall runs across the whole map, its stone face as tall as
## three men. Zhao archers and spearmen hold the wall-walk and keep coming up the stairs from the
## city. Qin climb ladders, ride two siege towers, and guard the covered ram to the arched gate,
## under burning oil and flaming stones. Soldiers knocked off a ladder or over the parapet fall.
## Phase 2, take the city: the avenue, the market, the temple of the pagoda, the canal bridges;
## two Zhao commanders hold out. Phase 3: the grand stairs up the palace terrace, and General
## Aldric in the courtyard before the golden hall.

# ------------------------------------------------------------------ layout (world units)
const MAP := Rect2(0, 110, 2200, 2450)
const INNER_Y := 1762.0        # city side of the wall (inner parapet)
const WALK_Y0 := 1770.0        # north edge of the wall-walk
const WALK_Y1 := 1840.0        # south edge of the walk (outer parapet, top of the face)
const GROUND_Y := 1990.0       # foot of the wall's outer face
const GATE_X0 := 1060.0
const GATE_X1 := 1140.0
const GH_X0 := 950.0
const GH_X1 := 1250.0
const LADDERS_X := [170.0, 470.0, 820.0, 1380.0, 1730.0, 2030.0]
const DOCKS_X := [620.0, 1580.0]
const STAIRS_X := [330.0, 700.0, 1500.0, 1870.0]
const TOWERS_X := [250.0, 1950.0]
const CANAL := Rect2(-200, 1200, 2600, 65)
const BRIDGES := [Rect2(370, 1192, 90, 81), Rect2(1015, 1192, 170, 81), Rect2(1740, 1192, 90, 81)]
const AVE_X0 := 1040.0
const AVE_X1 := 1160.0
const TERRACE_Y0 := 810.0      # edge of the palace platform
const TERRACE_Y1 := 920.0      # foot of the terrace face
const GRAND_STAIRS := Rect2(1000, 810, 200, 110)
const PGATE := Rect2(1000, 780, 200, 30)
const HALL := Rect2(780, 220, 640, 220)
const SIDE_HALLS := [Rect2(140, 300, 420, 140), Rect2(1640, 300, 420, 140)]
const GATE_PLAZA := Rect2(880, 1560, 440, 140)
const MARKET := Rect2(1160, 1290, 580, 210)
const TEMPLE := Rect2(450, 1290, 590, 210)
const PAGODA_POS := Vector2(745, 1390)
const DRUM := Rect2(1330, 1030, 64, 56)
const BLOCKS := [
	Rect2(40, 1560, 340, 140), Rect2(450, 1560, 430, 140), Rect2(1320, 1560, 420, 140), Rect2(1820, 1560, 340, 140),
	Rect2(40, 1290, 340, 210), Rect2(1820, 1290, 340, 210),
	Rect2(40, 990, 340, 160), Rect2(450, 990, 590, 160), Rect2(1560, 990, 180, 160), Rect2(1820, 990, 340, 160),
]
const OFFICER_POINTS := [Vector2(1450, 1430), Vector2(745, 1460)]
const BOSS_POINT := Vector2(1100, 620)
const START := Vector2(1060, 2310)
const RAM_STOP := 2089.0

var b = null                  # the Battle
var phase := 1
var phase_t := 0.0
var t := 0.0
var gate_broken := false
var gate_hp := 10
var gate_shake := 0.0
var palace_open := false
var palace_open_t := 0.0
var stones: Array = []        # flaming stones in flight {t, dur, a, b, h, zhao}
var oil: Array = []           # burning oil pools {pos, r, state, t, tick}
var fallers: Array = []       # soldiers falling off the wall {u, t, dur, y0, y1, x, src}
var houses: Array = []
var towers: Array = []        # SiegeProps.SiegeTowerV
var ram = null
var trebs: Array = []
var zhao_trebs := [Vector2(600, 1620), Vector2(1600, 1620)]
var treb_cd := [3.0, 5.0, 7.0]
var ztreb_cd := 7.0
var oil_cd := 6.0
var ram_cd := 0.0
var wall_back = null
var merlons = null
var gatehouse = null
var palace_gate = null
var fx_node = null
var fires_lit := 0
var objective_txt := ""
var wall_posts: Array = []
var section_owner := [1, 1]   # who holds the west and east halves of the wall-walk
var section_t := 0.0
var banner_x := [100.0, 360.0, 560.0, 720.0, 900.0, 1300.0, 1480.0, 1660.0, 1860.0, 2120.0]
var torch_x: Array = []
var tour: Array = []          # debug (--tour=SECONDS): camera stops for screenshots
var tour_dt := 0.0
var tour_t0 := 0

# ------------------------------------------------------------------ hooks called by Battle
func bounds() -> Rect2:
	return MAP

func atmos_key() -> String:
	return "siege"

func cavalry_ok() -> bool:
	return false

func officers_ok() -> bool:
	return phase >= 2

func officer_point(i: int) -> Vector2:
	return OFFICER_POINTS[i % OFFICER_POINTS.size()]

func boss_point() -> Vector2:
	return BOSS_POINT

func rout_dir(f: int) -> Vector2:
	return Vector2(0, 1) if f == 0 else Vector2(0, -1)

func boss_ready() -> bool:
	if not palace_open:
		return false
	if palace_open_t > 40.0:
		return true
	return b.player != null and is_instance_valid(b.player) and b.player.global_position.y < TERRACE_Y0 - 10.0

## Debug (--boss=N): skip straight to the palace.
func force_palace() -> void:
	if not gate_broken:
		_break_gate()
	if phase < 2:
		_start_phase2()
	if not palace_open:
		_open_palace()

func intro() -> void:
	b.hud.banner("THE SIEGE OF VEYRE", "THE GOLDEN MARCH  /  BREAK THE CROWN'S LAST STRONGHOLD", Color("#ffb070"), true, 5.0)
	b.hud.tip("siege", "TAB COMMAND VIEW   /   Q CHANGE FORMATION   /   1 FOLLOW   2 ADVANCE   3 HOLD")

func make_ground(rect: Rect2) -> ColorRect:
	var g := WorldBuilder.shader_rect("res://shaders/harvest_ground.gdshader", rect)
	var m: ShaderMaterial = g.material
	m.set_shader_parameter("wall_y", INNER_Y)
	m.set_shader_parameter("ground_y", GROUND_Y)
	m.set_shader_parameter("terrace_y", TERRACE_Y0)
	m.set_shader_parameter("ave_x0", AVE_X0)
	m.set_shader_parameter("ave_x1", AVE_X1)
	return g

func objective() -> String:
	return objective_txt

## Off-screen objective markers for the HUD: [pos, colour, label].
func markers() -> Array:
	var out: Array = []
	if phase == 1 and not gate_broken:
		out.append([Vector2((GATE_X0 + GATE_X1) * 0.5, GROUND_Y), Color("#ffb070"), "GATE"])
	elif phase == 3 and not b.boss_spawned:
		out.append([Vector2(GRAND_STAIRS.get_center().x, TERRACE_Y0), Color("#ffd166"), "PALACE"])
	return out

## Slower going up a ladder.
func on_ladder(p: Vector2) -> bool:
	return p.y > WALK_Y1 - 8.0 and p.y < GROUND_Y + 20.0 and _ladder_at(p.x) >= 0

func _ladder_at(x: float) -> int:
	for i in LADDERS_X.size():
		if absf(x - LADDERS_X[i]) < 12.0:
			return i
	return -1

func _in_tunnel(p: Vector2) -> bool:
	return p.x > GATE_X0 - 2.0 and p.x < GATE_X1 + 2.0 and p.y > INNER_Y - 4.0 and p.y < GROUND_Y + 4.0

func _corridor(x: float) -> bool:
	if _ladder_at(x) >= 0:
		return true
	for i in DOCKS_X.size():
		if towers.size() > i and towers[i].docked and absf(x - DOCKS_X[i]) < 22.0:
			return true
	return x > GATE_X0 and x < GATE_X1

## Height level of a point: 0 the ground (field, gate tunnel, city), 1 the wall-walk and the
## upper ladders, 2 the palace platform.
func elevation(p: Vector2) -> int:
	if p.y < TERRACE_Y0 + 4.0:
		return 2
	if p.y < TERRACE_Y1 + 4.0 and p.x > GRAND_STAIRS.position.x - 4.0 and p.x < GRAND_STAIRS.end.x + 4.0:
		return 2 if p.y < (TERRACE_Y0 + TERRACE_Y1) * 0.5 else 0
	if _in_tunnel(p):
		return 0
	if p.y > WALK_Y0 - 10.0 and p.y < GROUND_Y - 30.0:
		return 1
	return 0

## Can a soldier at u fight e hand to hand (same level, or close enough at a ladder top)?
func reachable(u, e) -> bool:
	var a: Vector2 = u.global_position
	var c: Vector2 = e.global_position
	return elevation(a) == elevation(c) or a.distance_to(c) < 46.0

func section_of(x: float) -> int:
	return 0 if x < (GH_X0 + GH_X1) * 0.5 else 1

# ------------------------------------------------------------------ falling off the wall
func falling(u) -> bool:
	for f in fallers:
		if f["u"] == u:
			return true
	return false

## Called before a soldier is pushed out of the walls: a soldier knocked off a ladder or over
## the parapet falls to the foot of the wall instead.
func try_fall(u, pos: Vector2) -> bool:
	if u.dead:
		return false
	var knocked: bool = u.flung_t > 0.0 or u.state == Unit.St.STAGGER or u.state == Unit.St.KNOCKDOWN
	if not knocked:
		return false
	var shoved: bool = u.flung_t > 0.0 or u.vel.y > 60.0
	# shoved over the parapet (it only ever moves a few units a frame, so it came from the walk)
	if shoved and pos.y > WALK_Y1 - 6.0 and pos.y < WALK_Y1 + 24.0 and not _corridor(pos.x):
		_start_fall(u, Vector2(pos.x, WALK_Y1 - 4.0))
		return true
	# knocked off a ladder
	if _ladder_at(pos.x) >= 0 and pos.y > WALK_Y1 + 6.0 and pos.y < GROUND_Y - 24.0 and u.vel.y > 20.0:
		_start_fall(u, pos)
		return true
	return false

func _start_fall(u, from: Vector2) -> void:
	var y1 := GROUND_Y + 14.0 + randf() * 12.0
	var src = u.flung_by if u.flung_t > 0.0 else null
	fallers.append({"u": u, "t": 0.0, "dur": 0.22 + (y1 - from.y) / 520.0, "y0": from.y, "y1": y1, "x": from.x, "src": src})
	u.stagger(1.0)
	Game.stats["falls"] = int(Game.stats.get("falls", 0)) + 1
	if u.is_player:
		b.hud.alert("YOU FALL FROM THE WALL!", Color("#ff9a3d"))

func _falls(delta: float) -> void:
	for f in fallers:
		var u = f["u"]
		if not is_instance_valid(u) or u.dead:
			f["done"] = true
			continue
		f["t"] = float(f["t"]) + delta
		var k := clampf(float(f["t"]) / float(f["dur"]), 0.0, 1.0)
		u.global_position = Vector2(float(f["x"]), lerpf(float(f["y0"]), float(f["y1"]), k * k))
		u.vel = Vector2.ZERO
		if k >= 1.0:
			f["done"] = true
			var h_fall := float(f["y1"]) - float(f["y0"])
			var dmg := 16.0 + h_fall * 0.6
			if u.is_player:
				dmg *= 0.45
			var h: Dictionary = b.impact_hit(dmg, u.global_position + Vector2(0, -12))
			h["knockdown"] = true
			h["pz"] = 999.0
			h["kb"] = 10.0
			var src = f["src"]
			if src != null and not is_instance_valid(src):
				src = null
			u.take_hit(src, h)
			b.fx.debris(u.global_position, 12.0)
			b.fx.text(u.global_position + Vector2(0, -30), "FELL", Color("#ffb070"))
			Sfx.play_at("hit_heavy", u.global_position, -2.0, 0.6)
			if src != null and src.is_player:
				Game.add_style("off_wall", 170.0, "OFF THE WALL", Color("#ffb070"))
				b.cam_shake(5.0)
	fallers = fallers.filter(func(f): return not f.has("done"))

# ------------------------------------------------------------------ building the city
func populate(battle) -> void:
	b = battle
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	b.terrain = Terrain.new()
	b.add_child(b.terrain)
	b.terrain.setup(Rect2(40, Battle.TOP, Battle.W - 80.0, Battle.BOT - Battle.TOP))
	b.reserves = [1400, 2000]
	b.reserves_max = [1400, 2000]
	b.caps = [150, 230]
	b.officer_times = [9999.0, 9999.0]
	b.officer_marks = [-1.0, -1.0]
	b.officer_names = ["LORD VALE", "SER ASH"]
	b.atmos.light_soft = 0.8
	WorldBuilder.fire_light = 0.6
	for s in b.atmos.snow_nodes:
		s.color = Color(1.0, 0.72, 0.56, s.color.a * 0.75)
		s.gravity = Vector2(8, -6)
	for x in range(60, 2160, 110):
		var fx := float(x)
		var ok := true
		for list in [LADDERS_X, DOCKS_X, banner_x]:
			for v in list:
				if absf(fx - v) < 30.0:
					ok = false
		for v in TOWERS_X:
			if absf(fx - v) < 70.0:
				ok = false
		if fx > GH_X0 - 10.0 and fx < GH_X1 + 10.0:
			ok = false
		if ok:
			torch_x.append(fx)
	_build_wall(rng)
	_build_city(rng)
	_build_palace(rng)
	_build_field(rng)
	var landscape := GoldenLandscape.new()
	b.add_child(landscape)
	b.move_child(landscape, b.world.get_index())
	landscape.setup(b)
	fx_node = SiegeProps.SiegeFx.new()
	fx_node.lv = self
	b.high.add_child(fx_node)
	var sky := SiegeProps.Skyline.new()
	sky.base = 70.0
	sky.x0 = -300.0
	sky.x1 = Battle.W + 300.0
	b.add_child(sky)
	b.move_child(sky, b.sky.get_index() + 1)

## Adds a solid band across the map at y0..y1, open at the gaps ([x0, x1, tag]; a tagged gap is
## a door that stays solid until its tag is switched off).
func _band(y0: float, y1: float, gaps: Array) -> void:
	var T: Terrain = b.terrain
	gaps.sort_custom(func(a, c): return a[0] < c[0])
	var x := -300.0
	for g in gaps:
		if g[0] > x:
			T.add(Rect2(x, y0, g[0] - x, y1 - y0))
		if g[2] != "":
			T.add(Rect2(g[0], y0, g[1] - g[0], y1 - y0), g[2])
		x = g[1]
	T.add(Rect2(x, y0, Battle.W + 300.0 - x, y1 - y0))

## Puts a node on the ground layer, under the soldiers but over the ground (decals go on top).
func _ground_layer(n: Node) -> void:
	b.add_child(n)
	b.move_child(n, b.decals.get_index())

func _face(y0: float, y1: float, marble: bool) -> void:
	var r := Rect2(-300.0, y0, Battle.W + 600.0, y1 - y0)
	var f := WorldBuilder.shader_rect("res://shaders/wall_face.gdshader", r)
	f.material.set_shader_parameter("rsize", r.size)
	f.material.set_shader_parameter("marble", 1.0 if marble else 0.0)
	_ground_layer(f)

func _build_wall(rng: RandomNumberGenerator) -> void:
	var T: Terrain = b.terrain
	# the outer face and parapet: solid, open at the ladders and the gate tunnel, with docks
	# that open when a siege tower drops its bridge
	var gaps: Array = []
	for lx in LADDERS_X:
		gaps.append([lx - 11.0, lx + 11.0, ""])
	for i in DOCKS_X.size():
		gaps.append([DOCKS_X[i] - 21.0, DOCKS_X[i] + 21.0, "dock%d" % i])
	gaps.append([GATE_X0, GATE_X1, ""])
	_band(WALK_Y1 - 6.0, GROUND_Y, gaps)
	T.add(Rect2(GATE_X0, GROUND_Y - 36.0, GATE_X1 - GATE_X0, 36.0), "gate")
	# the inner parapet, open at the stairs down into the city and at the tunnel
	var ig: Array = []
	for sx in STAIRS_X:
		ig.append([sx - 16.0, sx + 16.0, ""])
	ig.append([GATE_X0, GATE_X1, ""])
	_band(INNER_Y - 8.0, WALK_Y0, ig)
	# the gatehouse blocks the walk on both sides of the tunnel
	T.add(Rect2(GH_X0, WALK_Y0 - 1.0, GATE_X0 - GH_X0, WALK_Y1 - WALK_Y0 + 1.0))
	T.add(Rect2(GATE_X1, WALK_Y0 - 1.0, GH_X1 - GATE_X1, WALK_Y1 - WALK_Y0 + 1.0))
	_face(WALK_Y1, GROUND_Y, false)
	wall_back = SiegeProps.WallBack.new()
	wall_back.lv = self
	_ground_layer(wall_back)
	merlons = SiegeProps.Merlons.new()
	merlons.lv = self
	merlons.position = Vector2(0, WALK_Y1)
	b.world.add_child(merlons)
	for tx in TOWERS_X:
		var tw := SiegeProps.WallTower.new()
		tw.battle = b
		tw.lv = self
		tw.position = Vector2(tx, WALK_Y1 + 2.0)
		b.world.add_child(tw)
		b.atmos.add_light(Vector2(tx, WALK_Y1 + 40.0), 70.0, Color(1.0, 0.6, 0.3) * 0.4, 0.1)
	gatehouse = SiegeProps.GateHouse.new()
	gatehouse.battle = b
	gatehouse.lv = self
	gatehouse.position = Vector2((GATE_X0 + GATE_X1) * 0.5, GROUND_Y + 1.0)
	b.world.add_child(gatehouse)
	b.atmos.add_light(Vector2(1100, GROUND_Y - 40.0), 90.0, Color(1.0, 0.55, 0.25) * 0.55, 0.15)
	b.atmos.add_light(Vector2(1100, INNER_Y - 260.0), 160.0, Color(1.0, 0.62, 0.32) * 0.45, 0.08)
	# braziers along the walk, torches on the face
	for x in range(90, 2150, 150):
		var bx := float(x)
		if bx > GH_X0 - 20.0 and bx < GH_X1 + 20.0:
			continue
		var bp := Vector2(bx, WALK_Y0 + 10.0)
		WorldBuilder.prop(b.world, "brazier", bp)
		WorldBuilder.fire(b, bp + Vector2(0, -6), 0)
	for tx in torch_x:
		b.atmos.add_light(Vector2(tx, WALK_Y1 + 26.0), 42.0, Color(1.0, 0.58, 0.28) * 0.6, 0.3)
	# Zhao banners on the parapet
	var flags := SiegeProps.PennantRow.new()
	b.high.add_child(flags)
	for x in range(40, 2200, 170):
		var fx := float(x)
		if fx > GH_X0 and fx < GH_X1:
			continue
		flags.add(Vector2(fx, WALK_Y1 - 16.0), Color("#3c5aa8"), rng.randf() * 6.0)
	for s in [-1.0, 1.0]:
		flags.add(Vector2(1100.0 + s * 130.0, INNER_Y - 52.0), Color("#3c5aa8"), s)
	# garrison points on the walk
	for lx in LADDERS_X:
		wall_posts.append(Vector2(lx, WALK_Y0 + 30.0))
	for dx in DOCKS_X:
		wall_posts.append(Vector2(dx, WALK_Y0 + 30.0))
	for sx in STAIRS_X:
		wall_posts.append(Vector2(sx, WALK_Y0 + 14.0))

func _build_city(rng: RandomNumberGenerator) -> void:
	var T: Terrain = b.terrain
	# the canal, crossed by three bridges
	var cg: Array = []
	for br in BRIDGES:
		cg.append([br.position.x, br.end.x, ""])
	_band(CANAL.position.y, CANAL.end.y, cg)
	var water := WorldBuilder.shader_rect("res://shaders/canal.gdshader", CANAL)
	water.material.set_shader_parameter("rsize", CANAL.size)
	_ground_layer(water)
	for br in BRIDGES:
		var bridge := SiegeProps.Bridge.new()
		bridge.r = br
		_ground_layer(bridge)
	# houses in every block
	for blk in BLOCKS:
		T.add(blk.grow(-1.0))
		_fill_block(blk, rng)
	# the temple: a five-storey pagoda in a paved yard
	var pg := MedievalProps.Chapel.new()
	pg.battle = b
	pg.position = PAGODA_POS
	b.world.add_child(pg)
	T.add(Rect2(PAGODA_POS.x - 46.0, PAGODA_POS.y - 54.0, 92.0, 54.0))
	b.atmos.add_light(PAGODA_POS + Vector2(0, -30), 110.0, Color(1.0, 0.6, 0.3) * 0.5, 0.06)
	for s in [-1.0, 1.0]:
		var bp := PAGODA_POS + Vector2(s * 90.0, 40.0)
		WorldBuilder.prop(b.world, "brazier", bp, false, b.shadows)
		WorldBuilder.fire(b, bp + Vector2(0, -6), 0)
	# the drum tower in its plaza
	T.add(DRUM)
	var dt := SiegeProps.DrumTower.new()
	dt.setup(b, DRUM)
	b.world.add_child(dt)
	b.atmos.add_light(Vector2(DRUM.get_center().x, DRUM.end.y - 20.0), 70.0, Color(1.0, 0.6, 0.3) * 0.6, 0.1)
	# the market: stalls in rows, lantern strings above
	var cols := [Color("#b8322a"), Color("#2f6e8e"), Color("#c98a2a"), Color("#6a3a7a"), Color("#3a7a5a")]
	for row in 3:
		for k in 8:
			var sp := Vector2(MARKET.position.x + 50.0 + k * 66.0 + rng.randf_range(-6, 6), MARKET.position.y + 50.0 + row * 62.0)
			if sp.distance_to(OFFICER_POINTS[0]) < 50.0:
				continue
			var st := SiegeProps.Stall.new()
			st.w = rng.randf_range(26.0, 36.0)
			st.col = cols[rng.randi() % cols.size()]
			st.seed = rng.randi()
			st.position = sp
			b.world.add_child(st)
			b.atmos.add_light(sp + Vector2(0, -14), 22.0, Color(1.0, 0.66, 0.34) * 0.35, 0.15)
			if rng.randf() < 0.1:
				WorldBuilder.fire(b, sp + Vector2(rng.randf_range(-8, 8), -2), 1)
	for k in 4:
		var y0: float = MARKET.position.y + 20.0 + k * 55.0
		_lantern_line(Vector2(MARKET.position.x - 10.0, y0 - 24.0), Vector2(MARKET.end.x + 10.0, y0 - 14.0 + rng.randf_range(-8, 8)), 9, rng)
	# lanterns strung across the avenue and the streets
	var y := INNER_Y - 90.0
	while y > TERRACE_Y1 + 60.0:
		_lantern_line(Vector2(AVE_X0 - 6.0, y), Vector2(AVE_X1 + 6.0, y + rng.randf_range(-6, 6)), 3, rng)
		y -= rng.randf_range(80.0, 120.0)
	for sx in [415.0, 1780.0]:
		for yy in [1640.0, 1420.0, 1070.0]:
			_lantern_line(Vector2(sx - 34.0, yy - 20.0), Vector2(sx + 34.0, yy - 16.0), 2, rng)
	# braziers and burning carts
	for p in [Vector2(910, 1600), Vector2(1290, 1600), Vector2(1190, 1010), Vector2(1540, 1010), Vector2(980, 960), Vector2(1220, 960)]:
		WorldBuilder.prop(b.world, "brazier", p, false, b.shadows)
		WorldBuilder.fire(b, p + Vector2(0, -6), 0)
	for p in [Vector2(1000, 1650), Vector2(415, 1530), Vector2(1780, 1180), Vector2(560, 1170), Vector2(1450, 1530), Vector2(1250, 1110)]:
		WorldBuilder.prop(b.world, "wreck_cart", p, rng.randf() < 0.5, b.shadows)
		WorldBuilder.fire(b, p + Vector2(0, -3), 1)
		b.decals.scorch(p, 24.0)

## Splits a city block into buildings: a courtyard house (halls around a garden) or rows of
## shophouses facing south, a few of them already burning.
func _fill_block(r: Rect2, rng: RandomNumberGenerator) -> void:
	var rects: Array = []
	if r.size.y >= 190.0:
		var x := r.position.x
		while x < r.end.x - 1.0:
			var cw := minf(rng.randf_range(150.0, 190.0), r.end.x - x)
			if r.end.x - (x + cw) < 90.0:
				cw = r.end.x - x
			var c := Rect2(x, r.position.y, cw, r.size.y)
			var dn := rng.randf_range(54.0, 64.0)
			var ds := rng.randf_range(50.0, 58.0)
			var ww := rng.randf_range(34.0, 42.0)
			rects.append(Rect2(c.position.x, c.position.y, c.size.x, dn))
			_split_row(rects, Rect2(c.position.x, c.end.y - ds, c.size.x, ds), rng)
			rects.append(Rect2(c.position.x, c.position.y + dn, ww, c.size.y - dn - ds))
			rects.append(Rect2(c.end.x - ww, c.position.y + dn, ww, c.size.y - dn - ds))
			var court := Rect2(c.position.x + ww, c.position.y + dn, c.size.x - ww * 2.0, c.size.y - dn - ds)
			var tree := WorldBuilder.prop(b.world, "pine" if rng.randf() < 0.6 else "dead_tree", court.get_center() + Vector2(0, court.size.y * 0.3))
			tree.modulate = Color(0.8, 0.75, 0.9)
			x += cw
	else:
		var half := r.size.y * rng.randf_range(0.45, 0.55)
		_split_row(rects, Rect2(r.position.x, r.position.y, r.size.x, half), rng)
		_split_row(rects, Rect2(r.position.x, r.position.y + half, r.size.x, r.size.y - half), rng)
	for hr in rects:
		var h := SiegeProps.House.new()
		h.setup(b, hr, rng.randi())
		var near_wall := clampf((hr.position.y - 1000.0) / 700.0, 0.0, 1.0)
		if rng.randf() < 0.15 + near_wall * 0.2:
			h.charred = rng.randf_range(0.4, 0.9)
			h.glow = 0.0
		b.world.add_child(h)
		houses.append(h)
		if h.charred > 0.0 or rng.randf() < 0.12:
			_ignite(h, rng.randf() < 0.5)

func _split_row(out: Array, r: Rect2, rng: RandomNumberGenerator) -> void:
	var x := r.position.x
	while x < r.end.x - 1.0:
		var w := rng.randf_range(54.0, 96.0)
		if r.end.x - (x + w) < 44.0:
			w = r.end.x - x
		out.append(Rect2(x, r.position.y, w, r.size.y))
		x += w

## Sets a house on fire: flames and smoke on its roof, and a big flickering light.
func _ignite(h, big: bool = false) -> void:
	if h.burning or fires_lit > 60:
		return
	h.burning = true
	h.charred = maxf(h.charred, 0.35)
	h.queue_redraw()
	fires_lit += 1
	var r: Rect2 = h.rect
	var roof_c := Vector2(r.get_center().x, r.end.y - h.fh - r.size.y * 0.55)
	WorldBuilder.fire(b, roof_c, 2 if big else 1, b.high)
	b.hazards.pop_back()
	b.atmos.add_light(Vector2(r.get_center().x, r.end.y), 110.0 if big else 80.0, Color(1.0, 0.48, 0.2) * 0.5, 0.3)

func _lantern_line(a: Vector2, c: Vector2, n: int, rng: RandomNumberGenerator) -> void:
	var ll := SiegeProps.LanternLine.new()
	ll.a = a
	ll.b = c
	ll.n = n
	ll.ph = rng.randf() * 6.0
	b.high.add_child(ll)
	for i in n:
		var k := (i + 1.0) / (n + 1.0)
		var p := a.lerp(c, k) + Vector2(0, sin(k * PI) * a.distance_to(c) * 0.12 + 5.0)
		b.atmos.add_light(p, 16.0, Color(1.0, 0.4, 0.25) * 0.45, 0.12)

func _build_palace(rng: RandomNumberGenerator) -> void:
	var T: Terrain = b.terrain
	# the terrace face with the grand stairs, the balustrade and the gate pavilion on top
	_band(TERRACE_Y0 - 4.0, TERRACE_Y1, [[GRAND_STAIRS.position.x, GRAND_STAIRS.end.x, ""]])
	T.add(PGATE, "pgate")
	_face(TERRACE_Y0, TERRACE_Y1, true)
	var st := SiegeProps.TerraceStairs.new()
	st.lv = self
	_ground_layer(st)
	var bal := SiegeProps.Balustrade.new()
	bal.lv = self
	bal.position = Vector2(0, TERRACE_Y0)
	b.world.add_child(bal)
	palace_gate = SiegeProps.PalaceGate.new()
	palace_gate.battle = b
	palace_gate.lv = self
	palace_gate.position = Vector2(GRAND_STAIRS.get_center().x, PGATE.end.y + 2.0)
	b.world.add_child(palace_gate)
	b.atmos.add_light(Vector2(1100, TERRACE_Y1 - 20.0), 120.0, Color(1.0, 0.62, 0.32) * 0.45, 0.06)
	# the hall and the side halls, facing south over the courtyard
	T.add(HALL)
	var hall := MedievalProps.Keep.new()
	hall.setup(b, HALL)
	b.world.add_child(hall)
	b.atmos.add_light(Vector2(HALL.get_center().x, HALL.end.y + 10.0), 200.0, Color(1.0, 0.7, 0.4) * 0.6, 0.05)
	for sh in SIDE_HALLS:
		T.add(sh)
		var h := SiegeProps.House.new()
		h.setup(b, sh, 500 + int(sh.position.x))
		h.ornate = true
		h.storeys = 2
		h.fh = 36.0
		b.world.add_child(h)
		b.atmos.add_light(Vector2(sh.get_center().x, sh.end.y), 120.0, Color(1.0, 0.66, 0.36) * 0.4, 0.05)
	# braziers lining the imperial way, bronze cauldrons, guardian lions
	for k in 5:
		for s in [-1.0, 1.0]:
			var p := Vector2(1100.0 + s * 150.0, 500.0 + k * 66.0)
			WorldBuilder.prop(b.world, "brazier", p, false, b.shadows)
			WorldBuilder.fire(b, p + Vector2(0, -6), 0)
	for p in [Vector2(640, 660), Vector2(1560, 660)]:
		var d := SiegeProps.Ding.new()
		d.position = p
		b.world.add_child(d)
		T.add(Rect2(p.x - 16.0, p.y - 10.0, 32.0, 12.0))
		b.atmos.add_light(p + Vector2(0, -20), 60.0, Color(1.0, 0.55, 0.25) * 0.8, 0.25)
		WorldBuilder.fire(b, p + Vector2(0, -26), 1, b.high)
		b.hazards.pop_back()
	for s in [-1.0, 1.0]:
		var lp := Vector2(1100.0 + s * 90.0, HALL.end.y + 30.0)
		var lion := SiegeProps.Lion.new()
		lion.position = lp
		lion.flip = s > 0.0
		b.world.add_child(lion)
		T.add(Rect2(lp.x - 11.0, lp.y - 8.0, 22.0, 9.0))
	for k in 8:
		var tp := Vector2(260.0 + k * 240.0 + (60.0 if k >= 4 else 0.0), 760.0)
		if absf(tp.x - 1100.0) < 140.0:
			continue
		var tree := WorldBuilder.prop(b.world, "pine", tp, false, b.shadows)
		tree.modulate = Color(0.85, 0.8, 0.95)
	var pf := SiegeProps.PennantRow.new()
	b.high.add_child(pf)
	for k in 8:
		for s in [-1.0, 1.0]:
			pf.add(Vector2(1100.0 + s * (40.0 + k * 120.0), TERRACE_Y0 - 14.0), Color("#3c5aa8") if k % 2 == 0 else Color("#c9a24a"), k * 0.7 + s)

func _build_field(rng: RandomNumberGenerator) -> void:
	# the Qin army massed along the bottom of the field, torches lit
	var front := WorldBuilder.Crowd.new()
	b.add_child(front)
	b.move_child(front, b.world.get_index() + 1)
	for row in 4:
		front.add_row("qin", -200.0, Battle.W + 200.0, Battle.BOT + 8.0 + row * 10.0, 7.0, 1.4, rng, 8 if row == 0 else 0)
	front.finish()
	WorldBuilder.light_torches(b, front)
	# the camp: tents, braziers, banners
	for i in 26:
		var tp := Vector2(rng.randf_range(40, Battle.W - 40), rng.randf_range(2490, 2550))
		if absf(tp.x - START.x) < 80.0:
			continue
		WorldBuilder.prop(b.world, "tent_qin", tp, rng.randf() < 0.5, b.shadows)
		if rng.randf() < 0.5:
			var bp := tp + Vector2(rng.randf_range(24, 36), rng.randf_range(4, 12))
			WorldBuilder.prop(b.world, "brazier", bp, false, b.shadows)
			WorldBuilder.fire(b, bp + Vector2(0, -6), 0)
	for i in 14:
		var bp := Vector2(rng.randf_range(60, Battle.W - 60), rng.randf_range(2440, 2530))
		var s := WorldBuilder.prop(b.world, "gbanner_qin_0" if i % 3 == 0 else "banner_qin_0", bp, false, b.shadows)
		b.banners.append([s, "qin", rng.randi() % 3, i % 3 == 0])
	# trebuchets, siege towers and the ram
	for tx in [380.0, 1100.0, 1820.0]:
		var tr := SiegeProps.Trebuchet.new()
		tr.position = Vector2(tx, 2450.0 if tx != 1100.0 else 2475.0)
		b.world.add_child(tr)
		trebs.append(tr)
	for i in DOCKS_X.size():
		var st := SiegeProps.SiegeTowerV.new()
		st.x = DOCKS_X[i]
		st.y = 2400.0
		st.dock_y = GROUND_Y + 10.0
		st.speed = 10.0
		st.delay = 4.0 + i * 10.0
		st.position = Vector2(st.x, st.y)
		b.world.add_child(st)
		towers.append(st)
	ram = SiegeProps.RamV.new()
	ram.y = 2460.0
	ram.position = Vector2((GATE_X0 + GATE_X1) * 0.5, ram.y)
	b.world.add_child(ram)
	# battle debris: arrows, dropped weapons, stakes, burning wrecks, scorched ground
	for i in 90:
		var p := Vector2(rng.randf_range(60, Battle.W - 60), rng.randf_range(GROUND_Y + 40.0, 2460.0))
		if absf(p.x - 1100.0) < 50.0 or p.distance_to(START) < 90.0:
			continue
		var k := rng.randi() % 10
		if k < 4:
			b.decals.stamp(Art.tex["arrow_stuck"], p, rng.randf() < 0.5, Color.WHITE)
		elif k < 6:
			WorldBuilder.prop(b.world, ["sword_stuck", "spear_stuck", "rock1"][rng.randi() % 3], p, rng.randf() < 0.5, b.shadows)
		elif k < 7:
			WorldBuilder.prop(b.world, "shield_drop", p, rng.randf() < 0.5)
		elif k < 8 and p.y < 2250.0:
			WorldBuilder.prop(b.world, "stakes", p, false, b.shadows)
			b.hazards.append({"pos": p + Vector2(0, -3), "r": 9.0, "kind": "stakes"})
		else:
			b.decals.scorch(p, rng.randf_range(10.0, 22.0))
	for p in [Vector2(300, 2180), Vector2(880, 2120), Vector2(1460, 2240), Vector2(1960, 2150), Vector2(560, 2330)]:
		WorldBuilder.prop(b.world, "wreck_tower" if p.y < 2200.0 else "wreck_cart", p, rng.randf() < 0.5, b.shadows)
		WorldBuilder.fire(b, p + Vector2(0, -2), 1)
		b.decals.scorch(p, 26.0)
	# arrows stuck all over the foot of the wall
	for i in 60:
		b.decals.stamp(Art.tex["arrow_stuck"], Vector2(rng.randf_range(40, Battle.W - 40), rng.randf_range(GROUND_Y + 6.0, GROUND_Y + 60.0)), rng.randf() < 0.5, Color.WHITE)

# ------------------------------------------------------------------ armies
func deploy(battle) -> void:
	b = battle
	# Five companies, each six files by four ranks, ready at the three approaches.
	for company in 5:
		for i in 24:
			var k: String = "spear" if i < 6 else "archer" if i >= 18 else "infantry"
			var center := Vector2(510.0 + company * 275.0, 2300.0 + (company % 2) * 36.0)
			var p := center + Vector2((i % 6 - 2.5) * 18.0, (i / 6) * 21.0)
			b.spawn(0, k, p)
	var n := 0
	# Zhao archers line the outer parapet, spearmen hold the ladder tops and docks, guards the gate
	var ax := 70.0
	while ax < Battle.W - 60.0:
		var ok := not (ax > GH_X0 - 20.0 and ax < GH_X1 + 20.0)
		for v in TOWERS_X:
			if absf(ax - v) < 66.0:
				ok = false
		for v in LADDERS_X + DOCKS_X:
			if absf(ax - v) < 18.0:
				ok = false
		if ok:
			var u = b.spawn(1, "archer", Vector2(ax, WALK_Y1 - 20.0 + randf_range(-4, 4)))
			_post(u, u.global_position, 16.0)
			n += 1
		ax += 48.0
	for wp in wall_posts:
		for k in 4:
			var u = b.spawn(1, ["spear", "infantry", "heavy"][randi() % 3], wp + Vector2(randf_range(-14, 14), randf_range(-8, 10)))
			_post(u, wp, 60.0)
			n += 1
	for k in 8:
		var u = b.spawn(1, ["heavy", "spear", "infantry"][k % 3], Vector2(randf_range(1040, 1160), randf_range(1600, 1690)))
		_post(u, Vector2(1100, 1650), 90.0)
		n += 1
	# Defender sorties contest the field so the first contact is an actual battle line.
	for company in 4:
		for i in 24:
			var k: String = "spear" if i < 8 else "heavy" if i % 7 == 0 else "infantry"
			var center := Vector2(570.0 + company * 350.0, 2134.0)
			var pos := center + Vector2((i % 8 - 3.5) * 17.0, (i / 8) * 20.0)
			var u = b.spawn(1, k, pos)
			u.aim = Vector2.DOWN
			n += 1
	b.reserves[0] -= 120
	b.reserves[1] -= n
	var start := START
	var jump := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--phase="):
			jump = int(a.substr(8))
			start = Vector2(1100, 1640) if jump == 2 else Vector2(1100, 760)
		elif a.begins_with("--ppos="):
			var xy := a.substr(7).split(",")
			start = Vector2(float(xy[0]), float(xy[1]))
		elif a.begins_with("--tour="):
			tour_dt = float(a.substr(7))
			tour_t0 = Time.get_ticks_msec()
			tour = [[Vector2(1100, 2150), 0.62], [Vector2(560, 1900), 0.9], [Vector2(1100, 1820), 0.75], [Vector2(250, 1800), 1.0],
				[Vector2(1100, 1450), 0.62], [Vector2(745, 1330), 0.9], [Vector2(1450, 1300), 0.9], [Vector2(1100, 1150), 0.8],
				[Vector2(1100, 880), 0.8], [Vector2(1100, 500), 0.7], [Vector2(1100, 1300), 0.42]]
	var p = b.spawn(0, "infantry", start, "jian")
	b.take_control(p, true)
	b.cam.snap_to(p.global_position)
	if jump >= 2:
		_break_gate()
		_start_phase2()
		for k in 10:
			b.spawn(0, b._pick_kind(), start + Vector2((k % 5 - 2) * 18.0, 40.0 + (k / 5) * 16.0))
	if jump >= 3:
		_open_palace()

func _post(u, at: Vector2, r: float) -> void:
	if u.brain is AIBrain:
		u.brain.post = at
		u.brain.post_r = r

## Spawn points for reinforcements, in order of preference; the nearest one the player can't
## see is used, so soldiers never pop into view.
func _spawn_point(cands: Array) -> Vector2:
	var cc: Vector2 = b.cam.get_screen_center_position()
	var best := Vector2.INF
	var bd := INF
	var far := Vector2.INF
	var fd := -1.0
	for c in cands:
		var d: float = c.distance_to(cc)
		var off: bool = absf(c.x - cc.x) > 420.0 or absf(c.y - cc.y) > 260.0
		if off and d < bd:
			bd = d
			best = c
		if d > fd:
			fd = d
			far = c
	return best if best != Vector2.INF else far

func spawn_group(f: int, n: int) -> void:
	var pts: Array
	if f == 0:
		match phase:
			1:
				var x := randf_range(200.0, Battle.W - 200.0)
				if b.player != null:
					x = lerpf(x, b.player.global_position.x, 0.4)
				pts = [Vector2(x, Battle.BOT - 20.0)]
			2:
				pts = [Vector2(1100, GROUND_Y + 80.0), Vector2(1100, 1620), Vector2(415, 1720), Vector2(1780, 1720), Vector2(1100, Battle.BOT - 20.0)]
			_:
				pts = [Vector2(1100, 1000), Vector2(1100, 1350), Vector2(1100, 1620)]
	else:
		match phase:
			1:
				pts = [Vector2(330, 1690), Vector2(700, 1690), Vector2(1500, 1690), Vector2(1870, 1690), Vector2(1100, 1620)]
			2:
				pts = [Vector2(1100, 960), Vector2(415, 1050), Vector2(1780, 1050), Vector2(415, 1400), Vector2(1780, 1400), Vector2(1100, 1170)]
			_:
				pts = [Vector2(500, 620), Vector2(1700, 620), Vector2(1100, 470), Vector2(300, 520), Vector2(1900, 520)]
	var base := _spawn_point(pts)
	for i in n:
		var k: String = b._pick_kind()
		var p := base + Vector2(((i % 3) - 1) * 16.0 + randf_range(-4, 4), (i / 3) * 16.0 * (1.0 if f == 0 else -1.0))
		var u = b.spawn(f, k, b.terrain.push_out(p, 7.0))
		if f == 1 and phase == 1:
			# reinforcements climb the stairs onto the wall
			if k == "archer" or randf() < 0.6:
				var wp: Vector2 = wall_posts[randi() % wall_posts.size()]
				if section_owner[section_of(wp.x)] == 0:
					wp = wall_posts[(randi() % 2) * (wall_posts.size() - 1)]
				if k == "archer":
					wp = Vector2(clampf(wp.x + randf_range(-60, 60), 60.0, Battle.W - 60.0), WALK_Y1 - 20.0)
				_post(u, wp, 16.0 if k == "archer" else 60.0)
			else:
				_post(u, Vector2(1100, 1650), 90.0)
		elif f == 1 and phase == 3 and randf() < 0.5:
			_post(u, Vector2(1100.0 + randf_range(-90, 90), TERRACE_Y0 - 40.0), 110.0)

## Where a soldier with nobody to fight heads: Qin up the ladders, towers and gate, then down the
## stairs and through the city to the palace; Zhao toward the fighting.
func march_goal(u) -> Vector2:
	var p: Vector2 = u.global_position
	var h: int = u.get_instance_id()
	var jx := float(h % 41) - 20.0
	if u.faction == 0:
		if p.y > GROUND_Y - 6.0 and not _in_tunnel(p):
			return _entry(u, h)
		if _in_tunnel(p):
			return Vector2(1100.0 + jx, INNER_Y - 70.0)
		if p.y >= WALK_Y0 - 8.0 and p.y < GROUND_Y:
			if p.y > WALK_Y1 - 4.0:
				return Vector2(p.x, WALK_Y0 + 24.0)
			var best := INF
			var goal := Vector2(STAIRS_X[0], INNER_Y - 40.0)
			for sx in STAIRS_X:
				if section_of(sx) != section_of(p.x):
					continue
				if absf(sx - p.x) < best:
					best = absf(sx - p.x)
					goal = Vector2(sx, INNER_Y - 44.0)
			return goal
		if p.y > TERRACE_Y1:
			if palace_open:
				return Vector2(1100.0 + jx, TERRACE_Y0 - 100.0)
			if phase == 2 and b.officers_alive.size() > 0:
				var o = b.officers_alive[h % b.officers_alive.size()]
				if is_instance_valid(o):
					return o.global_position + Vector2(jx, -jx)
			return Vector2(1100.0 + jx * 2.5, TERRACE_Y1 + 40.0 + float(h % 50))
		return BOSS_POINT + Vector2(jx * 3.0, 60.0 + float(h % 40))
	# Zhao
	var pl = b.player
	if pl != null and is_instance_valid(pl) and not pl.dead and pl.global_position.y < GROUND_Y + 60.0 and pl.global_position.distance_to(p) < 900.0:
		return pl.global_position + Vector2(jx, -jx)
	if phase == 1:
		return Vector2(1100.0 + jx, 1650.0)
	if phase == 2:
		return Vector2(1100.0 + jx * 3.0, 1480.0 - float(h % 200))
	return Vector2(1100.0 + jx * 3.0, TERRACE_Y0 - 60.0)

## The way up this Qin soldier is assigned to: a ladder, a docked tower, the broken gate, or
## escorting the ram until then.
func _entry(u, h: int) -> Vector2:
	var opts: Array = []
	for lx in LADDERS_X:
		opts.append(Vector2(lx, WALK_Y0 + 28.0))
	for i in towers.size():
		if towers[i].docked:
			opts.append(Vector2(DOCKS_X[i], WALK_Y0 + 28.0))
			opts.append(Vector2(DOCKS_X[i], WALK_Y0 + 28.0))
	if gate_broken:
		for k in 4:
			opts.append(Vector2(1100.0, INNER_Y - 80.0))
	elif h % 3 == 0 and ram != null:
		return Vector2(1100.0 + float(h % 60) - 30.0, ram.y + 30.0 + float(h % 40))
	var px: float = u.global_position.x
	opts.sort_custom(func(a, c): return absf(a.x - px) < absf(c.x - px))
	return opts[(h / 3) % mini(2, opts.size())]

# ------------------------------------------------------------------ the battle unfolds
func _navtest() -> void:
	var map: RID = b.terrain.get_world_2d().navigation_map
	var np: NavigationPolygon = b.terrain.region.navigation_polygon
	print("[navtest] iteration=%d polys=%d verts=%d dirty=%s regions=%d" % [NavigationServer2D.map_get_iteration_id(map), np.get_polygon_count() if np else -1,
		np.vertices.size() if np else -1, str(b.terrain.nav_dirty), NavigationServer2D.map_get_regions(map).size()])
	print("[navtest] closest to (470,2300): %s" % str(NavigationServer2D.map_get_closest_point(map, Vector2(470, 2300))))
	var tests := [["field->ladder top", Vector2(470, 2300), Vector2(470, 1800)], ["walk->city via stairs", Vector2(560, 1800), Vector2(700, 1730)],
		["city south->north of canal", Vector2(415, 1400), Vector2(415, 1100)], ["street->platform (palace open)", Vector2(1100, 1100), Vector2(1100, 600)],
		["field->city (gate open)", Vector2(1100, 2200), Vector2(1100, 1600)], ["walk west->walk east", Vector2(800, 1800), Vector2(1400, 1800)]]
	for tst in tests:
		var path: PackedVector2Array = b.terrain.path(tst[1], tst[2])
		var l := 0.0
		for i in range(1, path.size()):
			l += path[i].distance_to(path[i - 1])
		var end_ok := path.size() > 0 and path[path.size() - 1].distance_to(tst[2]) < 20.0
		print("[navtest] %s: points=%d length=%d reaches=%s" % [tst[0], path.size(), int(l), str(end_ok)])

func update(delta: float) -> void:
	if OS.get_cmdline_user_args().has("--navtest") and ((t > 0.3 and t - delta <= 0.3) or (t > 3.0 and t - delta <= 3.0)):
		_navtest()
	if not tour.is_empty():
		var i := int(((Time.get_ticks_msec() - tour_t0) / 1000.0 + tour_dt * 0.5) / tour_dt) % tour.size()
		b.frozen = true
		b.cam.target = null
		b.cam.global_position = tour[i][0]
		b.debug_zoom = tour[i][1]
		b.cam.base_zoom = tour[i][1]
	if b.ended:
		return
	t += delta
	phase_t += delta
	gate_shake = maxf(0.0, gate_shake - delta * 8.0)
	# the defenders of a capital do not run: Zhao's morale never breaks before its general falls
	b.morale[1] = maxf(b.morale[1], 24.0)
	_falls(delta)
	_engines(delta)
	_trebuchets(delta)
	_stones(delta)
	_oil(delta)
	_sections(delta)
	if phase == 1:
		var in_city := 0
		for u in b.units:
			if u.faction == 0 and u.global_position.y < INNER_Y - 10.0:
				in_city += 1
		if gate_broken or in_city >= 8 or (section_owner[0] == 0 and section_owner[1] == 0) or t > 170.0:
			if not gate_broken and t > 170.0:
				_break_gate()
			_start_phase2()
	elif phase == 2:
		var slain: int = b.officers_spawned - b.officers_alive.size()
		var frac := float(b.reserves[1]) / float(b.reserves_max[1])
		if (b.officers_spawned >= 2 and slain >= 2) or phase_t > 210.0 or frac < 0.3:
			_open_palace()
	if palace_open:
		palace_open_t += delta
	_objective()

func _objective() -> void:
	match phase:
		1:
			var ram_k := clampf((2460.0 - ram.y) / (2460.0 - RAM_STOP), 0.0, 1.0) if ram != null else 1.0
			var docked := 0
			for st in towers:
				if st.docked:
					docked += 1
			var held := (1 if section_owner[0] == 0 else 0) + (1 if section_owner[1] == 0 else 0)
			objective_txt = "STORM THE WALLS   RAM %d%%   GATE %d/10   TOWERS %d/2   WALL %d/2" % [int(ram_k * 100.0), 10 - gate_hp, docked, held]
		2:
			var slain: int = b.officers_spawned - b.officers_alive.size()
			objective_txt = "TAKE THE CITY   COMMANDERS SLAIN %d/2" % slain
		_:
			objective_txt = "THE KEEP   DEFEAT LORD ALDRIC" if b.boss_spawned else "THE KEEP IS OPEN   CLIMB THE GRAND STAIRS"

## Who holds each half of the wall-walk: once Qin clear a half, its banners turn red.
func _sections(delta: float) -> void:
	section_t -= delta
	if section_t > 0.0:
		return
	section_t = 0.5
	for s in 2:
		if section_owner[s] == 0:
			continue
		var q := 0
		var z := 0
		for u in b.units:
			var p: Vector2 = u.global_position
			if p.y < WALK_Y0 - 6.0 or p.y > WALK_Y1 or section_of(p.x) != s:
				continue
			if u.faction == 0:
				q += 1
			else:
				z += 1
		if q >= 3 and z == 0:
			section_owner[s] = 0
			wall_back.queue_redraw()
			b.hud.alert("THE %s WALL IS TAKEN - QIN BANNERS RISE" % ("WEST" if s == 0 else "EAST"), Color("#ff8a80"))
			b.morale[0] = minf(100.0, b.morale[0] + 6.0)
			Sfx.play("horn_short", -4.0, 1.1)
			for u in b.units:
				if u.faction == 1 and u.brain is AIBrain and u.brain.post != Vector2.INF and section_of(u.brain.post.x) == s and u.brain.post.y > WALK_Y0 - 10.0:
					u.brain.post = Vector2.INF

func _engines(delta: float) -> void:
	# siege towers roll up to the wall, drop their bridges and unload a squad onto the walk
	for i in towers.size():
		var st = towers[i]
		st.delay -= delta
		if st.delay > 0.0 or st.docked:
			if st.docked and st.bridge < 1.0:
				st.bridge = minf(1.0, st.bridge + delta * 1.5)
			continue
		st.started = true
		st.y = maxf(st.dock_y, st.y - st.speed * delta)
		st.position = Vector2(st.x, st.y)
		if st.y <= st.dock_y:
			st.docked = true
			b.terrain.set_active("dock%d" % i, false)
			merlons.queue_redraw()
			for k in 6:
				var u = b.spawn(0, ["infantry", "spear", "heavy"][k % 3], Vector2(DOCKS_X[i] + (k % 3 - 1) * 12.0, WALK_Y0 + 14.0 + (k / 3) * 14.0))
				u.vel = Vector2(0, -60)
			var dp := Vector2(DOCKS_X[i], WALK_Y1)
			b.fx.debris(dp, 20.0)
			if _near_player(dp, 420.0):
				b.cam_shake(4.0)
			Sfx.play_at("hit_heavy", dp, 0.0, 0.6)
			b.hud.alert("A SIEGE TOWER REACHES THE WALL!", Color("#ffb070"))
			b.morale[0] = minf(100.0, b.morale[0] + 5.0)
	# the ram: faster with more Qin around it; it beats the gate until it breaks
	if ram == null or gate_broken:
		if ram != null:
			ram.moving = false
		return
	var crew := 0
	for u in b.query(Vector2(1100.0, ram.y), 80.0):
		if u.faction == 0 and not u.dead:
			crew += 1
	if ram.y > RAM_STOP:
		ram.moving = true
		ram.y = maxf(RAM_STOP, ram.y - (5.0 + minf(crew, 6) * 1.4) * delta)
		ram.position = Vector2(1100.0, ram.y)
	else:
		ram.moving = false
		ram_cd -= delta
		if ram_cd <= 0.0:
			ram_cd = 2.8
			ram.swing = 1.0
			gate_hp -= 1
			gate_shake = 3.0
			var gp := Vector2(1100.0, GROUND_Y - 20.0)
			b.fx.debris(gp, 14.0)
			b.fx.sparks(gp, Color(1.0, 0.8, 0.5), 12)
			Sfx.play_at("boom", gp, -2.0, 0.6)
			Sfx.play_at("hit_heavy", gp, -2.0, 0.5)
			if _near_player(gp, 380.0):
				b.cam_shake(5.0)
			if gate_hp <= 0:
				_break_gate()

func _near_player(p: Vector2, r: float) -> bool:
	return b.player != null and is_instance_valid(b.player) and b.player.global_position.distance_to(p) < r

func _break_gate() -> void:
	if gate_broken:
		return
	gate_broken = true
	gate_hp = 0
	b.terrain.set_active("gate", false)
	gatehouse.queue_redraw()
	var gp := Vector2(1100.0, GROUND_Y - 10.0)
	b.impact(gp, 0.12)
	b.fx.debris(gp, 40.0)
	b.decals.scorch(gp + Vector2(0, 20), 40.0)
	WorldBuilder.fire(b, Vector2(GATE_X0 - 30.0, GROUND_Y + 12.0), 1)
	WorldBuilder.fire(b, Vector2(GATE_X1 + 34.0, GROUND_Y + 16.0), 1)
	Sfx.play("boom", 0.0, 0.5)
	Sfx.play("horn", -2.0)
	b.cam.push(0.25, 1.2)
	b.hud.banner("THE GATE IS BROKEN", "POUR INTO VEYRE", Color("#ffb070"), true, 3.0)
	b.morale[0] = minf(100.0, b.morale[0] + 12.0)
	b.morale[1] = maxf(0.0, b.morale[1] - 10.0)
	Game.event_log("gate broken at t=%.0f" % b.time)

func _start_phase2() -> void:
	if phase >= 2:
		return
	phase = 2
	phase_t = 0.0
	b.officer_times = [b.time + 8.0, b.time + 40.0]
	b.officer_marks = [-1.0, -1.0]
	for u in b.units:
		if u.faction == 1 and u.brain is AIBrain and u.kind != "archer":
			u.brain.post = Vector2.INF
	if not gate_broken:
		b.hud.banner("THE WALL IS TAKEN", "FIGHT THROUGH THE BURNING CITY", Color("#ffb070"), true, 3.0)
	Game.event_log("phase 2 at t=%.0f" % b.time)

func _open_palace() -> void:
	if palace_open:
		return
	if phase < 3:
		phase = 3
		phase_t = 0.0
	palace_open = true
	palace_open_t = 0.0
	b.terrain.set_active("pgate", false)
	palace_gate.queue_redraw()
	var gp := Vector2(1100.0, PGATE.end.y)
	b.fx.debris(gp, 40.0)
	Sfx.play("boom", -2.0, 0.6)
	Sfx.play("gong", -2.0)
	if _near_player(gp, 600.0):
		b.impact(gp, 0.1)
	b.hud.banner("THE KEEP GATE FALLS", "ALDRIC AWAITS ABOVE THE GRAND STAIRS", Color("#ffd166"), true, 3.5)
	b.morale[0] = minf(100.0, b.morale[0] + 8.0)
	for u in b.units:
		if u.faction == 1 and u.brain is AIBrain and u.global_position.y < TERRACE_Y0:
			u.brain.post = Vector2(1100.0 + randf_range(-110, 110), TERRACE_Y0 - 50.0)
			u.brain.post_r = 120.0
	Game.event_log("palace open at t=%.0f" % b.time)

# ------------------------------------------------------------------ artillery and oil
func _trebuchets(delta: float) -> void:
	for i in trebs.size():
		treb_cd[i] -= delta
		if treb_cd[i] > 0.0:
			continue
		treb_cd[i] = randf_range(6.0, 9.0)
		var tr = trebs[i]
		tr.throw()
		var target: Vector2
		if randf() < 0.35 and phase == 1:
			target = Vector2(randf_range(60.0, Battle.W - 60.0), WALK_Y0 + randf_range(16.0, 50.0))
		else:
			var h = houses[randi() % houses.size()]
			target = Vector2(h.rect.get_center().x, h.rect.end.y + 6.0)
		_throw(tr.position + Vector2(0, -60), target, false)
	if phase == 1:
		ztreb_cd -= delta
		if ztreb_cd <= 0.0:
			ztreb_cd = randf_range(6.0, 9.0)
			var target := Vector2(randf_range(100.0, Battle.W - 100.0), randf_range(GROUND_Y + 90.0, 2440.0))
			if b.player != null and is_instance_valid(b.player) and b.player.global_position.y > GROUND_Y + 40.0 and randf() < 0.5:
				target = b.player.global_position + b.player.move_vel * 0.8
			_throw(zhao_trebs[randi() % zhao_trebs.size()] + Vector2(0, -50), target, true)

func _throw(a: Vector2, target: Vector2, zhao: bool) -> void:
	var d := a.distance_to(target)
	stones.append({"t": 0.0, "dur": clampf(d / 520.0, 1.4, 2.6), "a": a, "b": target, "h": 180.0 + d * 0.15, "zhao": zhao})

func _stones(delta: float) -> void:
	for s in stones:
		s["t"] = float(s["t"]) + delta
		if float(s["t"]) >= float(s["dur"]):
			_stone_land(s)
	stones = stones.filter(func(s): return float(s["t"]) < float(s["dur"]))

func _stone_land(s: Dictionary) -> void:
	var p: Vector2 = s["b"]
	var zhao: bool = s["zhao"]
	b.fx.debris(p, 22.0)
	b.fx.burst(p + Vector2(0, -6), Color(1.0, 0.55, 0.2), 16)
	b.decals.scorch(p, 18.0)
	b.decals.crack(p, Vector2.RIGHT.rotated(randf() * TAU))
	Sfx.play_at("boom", p, -2.0, randf_range(0.6, 0.8))
	if _near_player(p, 300.0):
		b.cam_shake(6.0)
	var victims_f := 0 if zhao else 1
	for u in b.query(p, 40.0):
		if u.dead or u.faction != victims_f or u.is_boss or u.spectator:
			continue
		if u.global_position.distance_to(p) < 38.0:
			var h: Dictionary = b.impact_hit(30.0 if not u.is_player else 22.0, p)
			h["knockdown"] = true
			h["kb"] = 160.0
			u.take_hit(null, h)
	if not zhao:
		for hs in houses:
			if hs.rect.grow(30.0).has_point(p):
				_ignite(hs, randf() < 0.4)
				break

## Burning oil poured from the wall onto the Qin crowding the gate or a ladder foot.
func _oil(delta: float) -> void:
	if phase == 1:
		oil_cd -= delta
		if oil_cd <= 0.0:
			var spots: Array = []
			if not gate_broken:
				spots.append(Vector2(1100.0, GROUND_Y + 30.0))
			for lx in LADDERS_X:
				if section_owner[section_of(lx)] == 1:
					spots.append(Vector2(lx, GROUND_Y + 26.0))
			var best := Vector2.INF
			var bc := 2
			for sp in spots:
				var c := 0
				for u in b.query(sp, 60.0):
					if u.faction == 0 and not u.dead:
						c += 1
				if c > bc:
					bc = c
					best = sp
			if best != Vector2.INF:
				oil_cd = randf_range(5.0, 8.0)
				var pos := best + Vector2(randf_range(-20, 20), randf_range(-6, 20))
				oil.append({"pos": pos, "r": 34.0, "state": "warn", "t": 0.0, "tick": 0.0})
				if _near_player(pos, 260.0):
					b.hud.alert("BOILING OIL FROM THE WALL!", Color("#ff9a3d"))
			else:
				oil_cd = 1.0
	for o in oil:
		o["t"] = float(o["t"]) + delta
		if o["state"] == "warn" and float(o["t"]) > 1.3:
			o["state"] = "burn"
			o["t"] = 0.0
			b.fx.burst(o["pos"], Color(1.0, 0.5, 0.15), 18)
			Sfx.play_at("boom", o["pos"], -6.0, 1.3)
			o["light"] = b.atmos.add_light(o["pos"], 70.0, Color(1.0, 0.5, 0.18) * 0.9, 0.3)
		elif o["state"] == "burn":
			o["tick"] = float(o["tick"]) - delta
			if float(o["tick"]) <= 0.0:
				o["tick"] = 0.5
				var c: Vector2 = o["pos"]
				for u in b.query(c, float(o["r"])):
					if u.dead or u.faction != 0:
						continue
					var d: Vector2 = (u.global_position - c) / Vector2(1.0, 0.6)
					if d.length() < float(o["r"]):
						var h: Dictionary = b.impact_hit(9.0, c)
						h["kb"] = 20.0
						h["pz"] = 6.0
						u.take_hit(null, h)
	for o in oil:
		if o["state"] == "burn" and float(o["t"]) > 4.0 and o.has("light"):
			b.atmos.lights.erase(o["light"])
	oil = oil.filter(func(o): return not (o["state"] == "burn" and float(o["t"]) > 4.0))
