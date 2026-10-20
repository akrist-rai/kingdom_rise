class_name Battle
extends Node2D
## Runs one full battle: the two armies, reinforcements, morale, events (volleys,
## cavalry charges, officers), the player's rise through the ranks, taking over a new
## body on death, squad orders, and the final duel with the enemy general.

signal leave_battle(restart: bool)

# Size of the battlefield. Each level sets these (the snow plains are wide, the siege is tall).
static var W := 3200.0
static var H := 960.0
static var TOP := 78.0
static var BOT := 925.0
static var view := Rect2(-1e6, -1e6, 2e6, 2e6)   # this frame's visible world rect (+ margin), for props
const CELL := 40.0
const DUEL_RX := 165.0
const DUEL_RY := 118.0

var units: Array = []
var grid := {}
var player: Unit = null
var world: Node2D
var glowfx: Node2D
var high: Node2D
var shadows: ShadowLayer
var atmos: Atmos
var lp: LightPainter
var ground: ColorRect
var shadow_vec := Vector2(-1.0, 0.8)
var crows: Crows
var duel_rings: Array = []
var fx: Fx
var proj: Projectiles
var decals: Decals
var cam: BattleCam
var hud: Hud
var sky: ColorRect
var banners: Array = []
var flames: Array = []
var hazards: Array = []     # {pos, r, kind: "fire" | "stakes"}: kicked or thrown enemies get hurt here
var fires: Array = []       # burning spots (embers drift from them)
var grass_mat: ShaderMaterial
var terrain: Terrain = null    # solid walls/buildings + navigation (city levels only)
var level := "snow_plains"     # which battle this is
var level_ctl = null           # level controller (the siege's events and layout), or null
var horses: Array = []      # riderless horses that can be mounted
var tactics: FormationDirector
var fg_grass: Node2D

var frozen := false
var enemy_dmg_mult := 0.85
var reserves := [1200, 1800]
var reserves_max := [1200, 1800]
var caps := [150, 230]
var morale := [70.0, 70.0]
var spawn_cd := [4.0, 4.0]
var alive := [0, 0]
var time := 0.0
var front_x := W * 0.5
var front_t := 0.0
var officer_marks := [0.82, 0.6]
var officer_times := [100.0, 230.0]
var debug_kill_at := -1.0
var debug_xp := 0.0
var officer_names := ["FU LING", "BA JIAO", "WU QUE"]
var officers_spawned := 0
var officers_alive: Array = []
var boss: Unit = null
var boss_spawned := false
var boss_phase := 1
var duel := false
var duel_center := Vector2.ZERO
var duel_foe: Unit = null      # the general or an officer you challenged
var duel_kind := ""            # "boss" | "officer"
var clash := {}                # an active blade lock: {p, f, t, push, dur, spark}
var clash_cd := 0.0
var possess := false
var cands: Array = []
var cand_sel := 0
var possess_t := 0.0
var possess_from := Vector2.ZERO
var tokens := {}
var squad: Array = []
var squad_order := "follow"
var squad_pt := Vector2.ZERO
var squad_t := 0.0
var war_cry_cd := 0.0
var volley_cd := 0.0
var pickups: Array = []
var ev := {"volley_e": 38.0, "volley_a": 26.0, "cav_e": 80.0, "cav_a": 115.0}
var ended := false
var end_t := 0.0
var victory := false
var hurt := 0.0
var input_lock := 0.0
var anim_t := 0.0
var anim_f := -1
var cheer_cd := 0.0
var cheer_heat := 0.0
var perk_queue := 0
var perk_delay := 0.0
var blizzard := 0.0
var blizzard_target := 0.0
var force_boss_at := -1.0
var debug_day := -1.0
var debug_bosshp := -1.0
var debug_impact := -1.0
var aura_tick := 0.0
var zoom_t := 0.0
var soft_target: Unit = null   # who the player's next attack will go to (shown with a marker)
var view_rect := Rect2(-1e6, -1e6, 2e6, 2e6)   # the camera view (+ margin) this frame, for culling
var corpses: Array = []         # fallen soldiers still drawn as sprites (oldest are baked into the ground)
const MAX_CORPSES := 160
var unit_shadows: UnitShadows
var fire_emitters: Array = []   # smoke and spark emitters of the fires (paused while off screen)
var emit_t := 0.0
var combat_regression: CombatRegression
var interactables: BattleInteractables
var scenery: Scenery
var soft_t := 0.0
var debug_zoom := -1.0

# ------------------------------------------------------------------ setup
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Engine.time_scale = 1.0
	get_tree().paused = false
	Game.possess_slow = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--boss="):
			force_boss_at = float(a.substr(7))
		elif a.begins_with("--kill="):
			debug_kill_at = float(a.substr(7))
		elif a.begins_with("--xp="):
			debug_xp = float(a.substr(5))
		elif a.begins_with("--day="):
			debug_day = float(a.substr(6))
		elif a.begins_with("--bosshp="):
			debug_bosshp = float(a.substr(9))
		elif a.begins_with("--impact="):
			debug_impact = float(a.substr(9))
		elif a.begins_with("--officer="):
			officer_times[0] = float(a.substr(10))
		elif a.begins_with("--cav="):
			ev["cav_e"] = float(a.substr(6))
		elif a.begins_with("--level="):
			level = a.substr(8)
		elif a.begins_with("--zoom="):
			debug_zoom = float(a.substr(7))
	W = 3200.0
	H = 960.0
	TOP = 78.0
	BOT = 925.0
	if level == "siege":
		level_ctl = SiegeLevel.new()
		var bounds: Rect2 = level_ctl.bounds()
		W = bounds.size.x
		H = bounds.end.y + 40.0
		TOP = bounds.position.y
		BOT = bounds.end.y
	_build()
	_deploy()
	interactables = BattleInteractables.new()
	add_child(interactables)
	interactables.setup(self)
	_rebuild_grid()
	_refresh_squad()
	tactics = FormationDirector.new()
	add_child(tactics)
	tactics.setup(self)
	if OS.get_cmdline_user_args().has("--combat-test"):
		combat_regression = CombatRegression.new()
		combat_regression.run.call_deferred(self)
	Game.rank_changed.connect(_on_rank_changed)
	Sfx.boss_mode = false
	Sfx.intensity = 0.0
	Sfx.start_music()
	Sfx.play("horn", -3.0)
	if OS.get_cmdline_user_args().has("--noprops"):
		_debug_freeze(self)
	if OS.get_cmdline_user_args().has("--census"):
		_debug_census.call_deferred()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--freeze="):
			print("[debug] froze ", _debug_freeze_kind(self, a.substr(9)), " ", a.substr(9))
	if level_ctl != null:
		level_ctl.intro()
	else:
		hud.banner("THE SNOW PLAINS", "MARCH VS CROWN  -  RISE FROM FOOT SOLDIER TO GENERAL", Color("#ffd166"), true, 4.5)

func _exit_tree() -> void:
	Game.possess_slow = false
	Game.command_view = false
	Engine.time_scale = 1.0

func _build() -> void:
	visibility_layer = 3
	if level_ctl != null:
		ground = level_ctl.make_ground(Rect2(-760, -80, W + 1520, H + 560))
	else:
		ground = WorldBuilder.ground(Rect2(-760, -80, W + 1520, H + 560), TOP, W)
	add_child(ground)
	sky = WorldBuilder.sky(Rect2(-760, -760, W + 1520, 800), 40.0)
	add_child(sky)
	decals = Decals.new()
	add_child(decals)
	if level_ctl != null:
		decals.RES = 1.5
	decals.setup(Vector2(W, H))
	scenery = Scenery.new()
	add_child(scenery)
	scenery.setup(self, Rect2(-260, -120, W + 520, H + 260))
	shadows = ShadowLayer.new()
	add_child(shadows)
	unit_shadows = UnitShadows.new()
	unit_shadows.battle = self
	add_child(unit_shadows)
	var signals := CombatSignals.new()
	signals.battle = self
	add_child(signals)
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	glowfx = Node2D.new()
	glowfx.visibility_layer = 3
	add_child(glowfx)
	proj = Projectiles.new()
	proj.battle = self
	add_child(proj)
	fx = Fx.new()
	fx.battle = self
	add_child(fx)
	high = Node2D.new()
	add_child(high)
	fg_grass = ForegroundGrass.new()
	add_child(fg_grass)
	crows = Crows.new()
	add_child(crows)
	crows.setup(Rect2(0, 0, W, H), 14)
	cam = BattleCam.new()
	add_child(cam)
	cam.limit_left = -340
	cam.limit_right = int(W + 340)
	cam.limit_top = -300
	cam.limit_bottom = int(H + 90)
	cam.make_current()
	fg_grass.cam = cam
	atmos = Atmos.new()
	add_child(atmos)
	atmos.setup(self, cam)
	atmos.sky_mat = sky.material
	atmos.ground_mat = ground.material
	atmos.snow_nodes = WorldBuilder.snow_layers(cam)
	if debug_day >= 0.0:
		atmos.day = debug_day
		atmos.day_target = debug_day
	if OS.get_cmdline_user_args().has("--lowgfx"):
		Game.low_gfx = true
	lp = LightPainter.new()
	lp.atmos = atmos
	add_child(lp)
	lp.sources.append(fx.draw_lights)
	lp.sources.append(proj.draw_lights)
	lp.sources.append(_draw_unit_lights)
	var hl := CanvasLayer.new()
	hl.layer = 10
	add_child(hl)
	hud = Hud.new()
	hud.battle = self
	hl.add_child(hud)
	if level_ctl != null:
		atmos.base_key = level_ctl.atmos_key()
		level_ctl.populate(self)
	else:
		WorldBuilder.populate(self)

func _deploy() -> void:
	if level_ctl != null:
		level_ctl.deploy(self)
		return
	var n0 := 112
	var n1 := 168
	for i in n0:
		var k := _pick_kind()
		var x := 1080.0 - (i / 8) * 18.0 - (90.0 if k == "archer" else 0.0)
		spawn(0, k, Vector2(x, lerpf(TOP + 50, BOT - 50, (i + randf()) / n0)))
	for i in n1:
		var k := _pick_kind()
		var x := 1800.0 + (i / 12) * 18.0 + (90.0 if k == "archer" else 0.0)
		spawn(1, k, Vector2(x, lerpf(TOP + 50, BOT - 50, (i + randf()) / n1)))
	reserves[0] -= n0
	reserves[1] -= n1
	var start := Vector2(1120, H * 0.5)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ppos="):
			var xy := a.substr(7).split(",")
			start = Vector2(float(xy[0]), float(xy[1]))
	var p := spawn(0, "infantry", start, "jian")
	take_control(p, true)
	cam.snap_to(p.global_position)

func _pick_kind() -> String:
	var r := randf()
	if r < 0.44:
		return "infantry"
	if r < 0.68:
		return "spear"
	if r < 0.85:
		return "archer"
	return "heavy"

func _pick_weapon(fac: int, kind: String) -> String:
	match kind:
		"infantry":
			return ["jian", "jian", "sword_shield", "sword_shield", "daggers"].pick_random()
		"spear":
			return "spear"
		"archer":
			return ["crossbow", "bow"].pick_random() if fac == 0 else "bow"
		"heavy":
			return ["axe", "hammer", "zhanmadao", "glaive"].pick_random()
		"cavalry":
			return ["spear", "glaive", "zhanmadao"].pick_random()
		"officer":
			return ["glaive", "zhanmadao", "spear", "hammer"].pick_random()
		"guard":
			return ["axe", "hammer", "glaive", "zhanmadao"].pick_random()
	return "jian"

func spawn(fac: int, kind: String, pos: Vector2, wid: String = "", lvl: int = 0) -> Unit:
	var u := Unit.new()
	var w := Weapon.make(wid if wid != "" else _pick_weapon(fac, kind), lvl)
	world.add_child(u)
	u.position = Vector2(clampf(pos.x, 40.0, W - 40.0), clampf(pos.y, TOP, BOT))
	u.setup(self, fac, kind, w)
	var br := AIBrain.new()
	br.setup(u)
	u.brain = br
	units.append(u)
	if tactics != null:
		tactics.enlist(u)
	return u

# ------------------------------------------------------------------ queries
func _key(cx: int, cy: int) -> int:
	return cx * 4096 + cy

func _rebuild_grid() -> void:
	grid.clear()
	alive = [0, 0]
	for u in units:
		var p: Vector2 = u.global_position
		var k := _key(int(floor(p.x / CELL)), int(floor(p.y / CELL)))
		if grid.has(k):
			grid[k].append(u)
		else:
			grid[k] = [u]
		alive[u.faction] += 1

func query(pos: Vector2, r: float) -> Array:
	var out: Array = []
	var x0 := int(floor((pos.x - r) / CELL))
	var x1 := int(floor((pos.x + r) / CELL))
	var y0 := int(floor((pos.y - r) / CELL))
	var y1 := int(floor((pos.y + r) / CELL))
	for cx in range(x0, x1 + 1):
		for cy in range(y0, y1 + 1):
			var k := _key(cx, cy)
			if grid.has(k):
				out.append_array(grid[k])
	return out

var frame_no := 0

func _separation() -> void:
	frame_no += 1
	# LOD: soldiers well outside the view think and move every third frame (time accumulates);
	# soldiers not fighting near the player think every other frame.
	var near := view_rect.grow(110.0)
	var pp := player.global_position if player != null and is_instance_valid(player) else Vector2.INF
	var idx := 0
	for u in units:
		idx += 1
		var p: Vector2 = u.global_position
		var tick: bool = u.is_player or near.has_point(p) or (idx + frame_no) % 3 == 0
		u.lod_tick = tick
		u.brain_tick = u.is_player or (idx + frame_no) % 2 == 0 or (pp != Vector2.INF and p.distance_squared_to(pp) < 32400.0)
		if not tick:
			continue
		# push apart from neighbours (inline grid walk: no temporary arrays)
		var s := Vector2.ZERO
		var cx := int(floor(p.x / CELL))
		var cy := int(floor(p.y / CELL))
		var ur: float = u.radius
		for gx in range(cx - 1, cx + 2):
			for gy in range(cy - 1, cy + 2):
				var cell = grid.get(gx * 4096 + gy)
				if cell == null:
					continue
				for e in cell:
					if e == u:
						continue
					var d: Vector2 = p - e.global_position
					var min_d: float = ur + e.radius
					var l2 := d.length_squared()
					if l2 < min_d * min_d:
						var l := sqrt(l2)
						if l < 0.01:
							d = Vector2(randf() - 0.5, randf() - 0.5)
							l = 0.5
						s += d / l * (min_d - l) * 12.0
		u.sep = s.limit_length(120.0)

## Culling rectangle: the visible world area plus a margin (soldiers are drawn above their feet).
func _update_view_rect() -> void:
	if cam == null:
		return
	var c := cam.get_screen_center_position()
	var half := Game.VIEW * 0.5 / maxf(0.05, cam.zoom.x)
	view_rect = Rect2(c - half - Vector2(40, 30), half * 2.0 + Vector2(80, 90))
	Battle.view = view_rect

func in_view(pos: Vector2) -> bool:
	return view_rect.has_point(pos)

func add_corpse(u) -> void:
	corpses.append(u)
	while corpses.size() > MAX_CORPSES:
		var old = corpses.pop_front()
		if is_instance_valid(old):
			old.settle_corpse()

func on_screen(pos: Vector2) -> bool:
	return view_rect.has_point(pos)

## A manga impact frame: two-tone ink flash, speed lines, aberration and shake.
func impact(pos: Vector2, dur: float = 0.1) -> void:
	atmos.impact_frame(dur * 2.2)
	atmos.impact_uv = hud._to_screen(pos) / Game.VIEW
	cam.punch(0.06)
	atmos.aberrate(5.0)
	hud.speed_lines(hud._to_screen(pos), dur + 0.1)
	cam_shake(7.0)

func cam_shake(a: float) -> void:
	cam.shake = maxf(cam.shake, a)

func morale_mult(f: int) -> float:
	return 0.8 + morale[f] / 250.0

func army_strength(f: int) -> float:
	return float(reserves[f] + alive[f])

func player_targetable() -> bool:
	return player != null and not possess and not player.dead

func input_locked() -> bool:
	return get_tree().paused or possess or input_lock > 0.0 or ended

func request_token(u: Unit) -> bool:
	for k in tokens.keys():
		if not is_instance_valid(k) or k.dead or float(tokens[k]) < time:
			tokens.erase(k)
	if tokens.has(u):
		tokens[u] = time + 3.0
		return true
	var max_t := 2 + (1 if Game.rank >= 3 else 0)
	if tokens.size() < max_t:
		tokens[u] = time + 3.0
		return true
	return false

func release_token(u: Unit) -> void:
	tokens.erase(u)

func clamp_unit(u: Unit, pos: Vector2) -> Vector2:
	if level_ctl != null and level_ctl.falling(u):
		return pos
	pos.x = clampf(pos.x, 40.0, W - 40.0)
	pos.y = clampf(pos.y, TOP, BOT)
	if terrain != null:
		if level_ctl != null and level_ctl.try_fall(u, pos):
			return pos
		pos = terrain.push_out(pos, u.radius)
	if duel:
		var rel := pos - duel_center
		var l := Vector2(rel.x / DUEL_RX, rel.y / DUEL_RY).length()
		if u.duelist:
			if l > 1.0:
				pos = duel_center + rel / l
		elif not u.spectator and l < 1.4 and l > 0.001:
			pos = duel_center + rel / l * 1.4
	return pos

# ------------------------------------------------------------------ main loop
func _process(delta: float) -> void:
	var rdt := minf(delta / maxf(Engine.time_scale, 0.0001), 0.1)
	delta = minf(delta, 1.0 / 30.0)
	anim_t += delta
	if not ended:
		time += delta
		Game.stats["time"] = time
	Prof.frames += 1
	_update_view_rect()
	_cull_emitters(delta)
	var _q0 := Time.get_ticks_usec()
	_rebuild_grid()
	var _q1 := Time.get_ticks_usec()
	Prof.add("b.grid", _q1 - _q0)
	_separation()
	Prof.add("b.sep", Time.get_ticks_usec() - _q1)
	if debug_xp > 0.0 and time > 1.0:
		Game.add_xp(debug_xp)
		debug_xp = 0.0
	if debug_impact >= 0.0 and time >= debug_impact and player != null:
		debug_impact = -1.0
		impact(player.global_position + Vector2(0, -10), 0.6)
	if debug_kill_at >= 0.0 and time >= debug_kill_at and player != null:
		debug_kill_at = -1.0
		player.die(null, {})
	input_lock -= rdt
	hurt = maxf(0.0, hurt - rdt * 1.5)
	war_cry_cd -= delta * (2.0 if Game.rank >= 4 else 1.0)
	volley_cd -= delta * (2.0 if Game.rank >= 4 else 1.0)
	if possess:
		_possess_update(rdt)
	elif player != null and not ended:
		_commands()
	var _q2 := Time.get_ticks_usec()
	_spawning(delta)
	_events(delta)
	_morale_update(delta)
	_officer_boss_checks()
	_duel_update(delta)
	_clash_update(rdt)
	_squad_update(delta)
	_pickups_update(delta)
	_aura_update(delta)
	if level_ctl != null:
		level_ctl.update(delta)
	_props_anim()
	_perk_update(rdt)
	_camera_shaders(rdt)
	_front(delta)
	Prof.add("b.rest", Time.get_ticks_usec() - _q2)
	if ended:
		end_t += rdt
		if end_t > (6.5 if victory else 4.5) and not hud.results_open:
			hud.show_results(victory)
			Sfx.boss_mode = false

func _front(delta: float) -> void:
	front_t -= delta
	if front_t > 0.0:
		return
	front_t = 0.5
	var ax := 0.0
	var an := 0
	var ex := 0.0
	var en := 0
	for u in units:
		if u.faction == 0:
			ax += u.global_position.x
			an += 1
		else:
			ex += u.global_position.x
			en += 1
	if an > 0 and en > 0:
		front_x = lerpf(front_x, (ax / an + ex / en) * 0.5, 0.3)

# ------------------------------------------------------------------ player commands
func _commands() -> void:
	if input_locked():
		return
	if Input.is_action_just_pressed("interact"):
		_try_pickup()
	if Input.is_action_just_pressed("aura"):
		if Game.aura_ready():
			activate_aura()
		elif not Game.aura_active():
			hud.alert("THE AURA IS NOT READY  -  FIGHT WITH STYLE TO FILL IT", Color("#a9a3b8"))
	if not squad.is_empty():
		if Input.is_action_just_pressed("order_follow"):
			_set_order("follow", player.global_position)
		elif Input.is_action_just_pressed("order_charge"):
			_set_order("charge", player.i_aim_pt)
		elif Input.is_action_just_pressed("order_hold"):
			_set_order("hold", player.i_aim_pt if Game.command_view else player.global_position)
	if Game.rank >= 3:
		if Input.is_action_just_pressed("war_cry"):
			if war_cry_cd <= 0.0:
				_war_cry()
			else:
				hud.alert("WAR CRY RECHARGING", Color("#a9a3b8"))
		if Input.is_action_just_pressed("volley"):
			if volley_cd <= 0.0:
				_player_volley(player.i_aim_pt)
			else:
				hud.alert("ARCHERS ARE RELOADING", Color("#a9a3b8"))
	if Game.autotest and Game.aura_ready() and not possess:
		activate_aura()
	if Game.autotest and Game.rank >= 3 and randf() < 0.005:
		if war_cry_cd <= 0.0:
			_war_cry()
		elif volley_cd <= 0.0:
			_player_volley(player.i_aim_pt)

func _set_order(o: String, pt: Vector2) -> void:
	squad_order = o
	squad_pt = pt
	for i in squad.size():
		var u = squad[i]
		u.brain.order = o
		u.brain.order_pt = pt
		u.brain.target = null
	fx.ring(pt, 26.0, Color(1.0, 0.85, 0.4, 0.9), 0.4)
	Sfx.play("drum", -4.0)
	hud.alert("SQUAD: " + o.to_upper(), Color("#ffd166"))

func _war_cry() -> void:
	war_cry_cd = 40.0
	var p := player
	for u in query(p.global_position, 260.0):
		if u.dead:
			continue
		if u.faction == 0:
			if u.global_position.distance_to(p.global_position) <= 260.0:
				u.buff_mult = 1.25
				u.speed_mult = 1.15
				u.buff_t = 10.0
		elif u.global_position.distance_to(p.global_position) < 140.0 and not u.is_boss:
			u.stagger(0.7)
	morale[0] = minf(100.0, morale[0] + 6.0)
	fx.ring(p.global_position, 140.0, Color(1.0, 0.5, 0.35, 0.9), 0.5)
	fx.ring(p.global_position, 260.0, Color(1.0, 0.75, 0.4, 0.6), 0.7)
	cam_shake(6.0)
	Sfx.play("horn_short", 0.0)
	Sfx.play("drum", 0.0)
	hud.alert("WAR CRY! NEARBY ALLIES FIGHT HARDER", Color("#ff8a80"))
	Game.add_style("warcry", 60.0, "WAR CRY", Color("#ff8a80"))

## The General's Aura: the player's presence overwhelms the field for a few seconds.
func activate_aura() -> void:
	Game.aura = 0.0
	Game.aura_t = Game.AURA_DUR
	Game.stats["auras"] = int(Game.stats.get("auras", 0)) + 1
	var p := player
	for e in query(p.global_position, 130.0):
		if e.dead or e.faction == 0 or e.is_boss:
			continue
		var d: Vector2 = e.global_position - p.global_position
		if d.length() < 130.0:
			e.vel += d.normalized() * 220.0
			e.stagger(0.9)
	morale[0] = minf(100.0, morale[0] + 10.0)
	morale[1] = maxf(0.0, morale[1] - 6.0)
	Game.slowmo(0.25, 0.7)
	cam.push(0.38, 1.1)
	atmos.impact_frame(0.14)
	atmos.do_flash(0.45, Color(1.0, 0.8, 0.5))
	fx.ring(p.global_position, 130.0, Color(1.0, 0.62, 0.28, 1.0), 0.6)
	fx.ring(p.global_position, 60.0, Color(1.0, 0.9, 0.6, 1.0), 0.4)
	fx.aura_burst(p)
	cam_shake(9.0)
	Sfx.play("gong", 0.0)
	Sfx.play("horn", -2.0, 1.15)
	Sfx.play("boom", -4.0, 0.8)
	hud.aura_banner()
	Game.add_style("aura", 120.0, "GENERAL'S AURA", Color("#ffb347"))
	Game.event_log("aura at t=%.0f" % time)

func _aura_update(delta: float) -> void:
	if Game.aura_t <= 0.0:
		return
	Game.aura_t = maxf(0.0, Game.aura_t - delta)
	if player == null or possess:
		return
	fx.aura_flames(player, delta)
	morale[1] = maxf(0.0, morale[1] - 0.35 * delta)
	aura_tick -= delta
	if aura_tick > 0.0:
		return
	aura_tick = 0.5
	var pp := player.global_position
	for u in query(pp, 230.0):
		if u.dead or u == player:
			continue
		var d: float = u.global_position.distance_to(pp)
		if u.faction == 0 and d < 230.0:
			# allies surge forward behind you
			u.buff_mult = maxf(u.buff_mult, 1.3)
			u.speed_mult = maxf(u.speed_mult, 1.12)
			u.buff_t = maxf(u.buff_t, 0.8)
		elif u.faction == 1 and d < 120.0 and not u.is_boss and not u.is_officer and not u.spectator:
			# enemies falter before the aura
			if randf() < 0.12 and u.state == Unit.St.IDLE:
				u.stagger(0.45)
				fx.text(u.global_position + Vector2(0, -26), "FALTERS", Color("#ffcf8a"))

func _player_volley(target: Vector2) -> void:
	var p := player
	if target.distance_to(p.global_position) > 380.0:
		target = p.global_position + (target - p.global_position).normalized() * 380.0
	volley_cd = 25.0
	var h := p.make_hit({"dmg": 1.0, "pz": 25.0, "st": 15.0, "kb": 30.0})
	h["dmg"] = 28.0 + Game.rank * 4.0
	h["skill"] = true
	h["bleed"] = 0.0
	proj.rain(p, target, 78.0, 36, 0.8, h)
	Sfx.play("volley", 0.0)
	hud.alert("ARCHERS, LOOSE!", Color("#ffd166"))

func _try_pickup() -> void:
	var best = null
	var bd := 26.0
	for pk in pickups:
		var d: float = player.global_position.distance_to(pk["pos"])
		if d < bd:
			bd = d
			best = pk
	if best == null:
		if player.mounted:
			player.dismount(false)
			hud.alert("DISMOUNTED", Color("#d9e7ff"))
			return
		var hz := _near_horse()
		if hz != null:
			player.mount(hz.fac)
			hz.remove()
			hud.alert("MOUNTED  -  GALLOP TO TRAMPLE, DASH TO CHARGE", Color("#ffe8a3"))
			hud.tip("horse", "ON HORSEBACK: SPEARS HURT YOU DOUBLE. IF YOUR HORSE FALLS, SO DO YOU. F TO DISMOUNT")
			Game.add_style("mount", 40.0, "MOUNTED", Color("#ffe8a3"))
			return
		var o := _challengeable_officer()
		if o != null:
			challenge_officer(o)
			return
		# nothing to pick up: F kicks instead (the gamepad has no separate kick button)
		player.i_kick = true
		return
	var old := player.weapon
	pickups.erase(best)
	player.set_weapon(best["w"])
	player.base_speed = (210.0 if player.mounted else 150.0) - player.weapon.weight * 8.0
	if old.id != "sidearm":
		drop_weapon(old, player.global_position + Vector2(randf_range(-8, 8), 6))
	Sfx.play("pickup", -2.0)
	hud.alert("TOOK " + player.weapon.display_name() + "  -  SKILL: " + player.weapon.skill_name, Color("#ffe8a3"))

func drop_weapon(w: Weapon, pos: Vector2) -> void:
	pickups.append({"pos": pos, "w": w, "t": 50.0})
	if pickups.size() > 24:
		pickups.remove_at(0)

func spawn_horse(fac: String, pos: Vector2, v: Vector2) -> void:
	if horses.size() >= 10:
		horses[0].remove()
	var h := Horse.new()
	world.add_child(h)
	h.setup(self, fac, pos, v)
	horses.append(h)

func _near_horse() -> Horse:
	if player == null or player.mounted:
		return null
	for h in horses:
		if is_instance_valid(h) and h.global_position.distance_to(player.global_position) < 24.0:
			return h
	return null

func _pickups_update(delta: float) -> void:
	for pk in pickups:
		pk["t"] = float(pk["t"]) - delta
	pickups = pickups.filter(func(pk): return float(pk["t"]) > 0.0)
	if player != null and not possess:
		for pk in pickups:
			if player.global_position.distance_to(pk["pos"]) < 26.0:
				hud.prompt("F", "TAKE " + pk["w"].display_name())
				hud.tip("pickup", "PRESS F TO SWAP WEAPONS - EACH HAS ITS OWN MOVES AND SKILL")
				break
		if _near_horse() != null:
			hud.prompt("F", "MOUNT THE HORSE")

# ------------------------------------------------------------------ taking over bodies
func take_control(u: Unit, first: bool = false) -> void:
	if u.in_squad:
		squad.erase(u)
	if u.brain is AIBrain:
		u.brain._release(u)
	u.brain = PlayerBrain.new()
	u.become_player()
	u.tint = Color.WHITE
	if duel:
		u.spectator = false
		u.duelist = true
	player = u
	cam.target = u
	input_lock = 0.25
	u.queued = ""
	if not first:
		Game.stats["bodies"] += 1
		hud.banner(u.uname, "%s  -  %s  -  VIG %d  END %d  STR %d  DEX %d" % [u.kind_label(), u.weapon.display_name(), u.vig, u.endu, u.stren, u.dex], Color("#ffd166"), false, 3.0)
	_refresh_squad()

func _on_player_death(u: Unit) -> void:
	possess_from = u.global_position
	player = null
	tokens.clear()
	for e in units:
		if e.brain is AIBrain:
			e.brain.token = false
	Game.stats["deaths"] += 1
	Game.style_reset()
	Game.aura *= 0.5
	Game.aura_t = 0.0
	morale[0] -= 5.0
	_gather_cands()
	if cands.is_empty():
		_defeat("NO ONE IS LEFT TO CARRY YOUR WILL")
		return
	possess = true
	possess_t = 0.0
	Game.possess_slow = true
	atmos.impact_frame(0.16)
	Sfx.play("possess", -2.0, 0.8)
	Sfx.play("drum", -2.0)
	hud.tip("possess", "CHOOSE WHO CARRIES ON - EVERY SOLDIER HAS DIFFERENT STATS AND WEAPONS")

func _gather_cands() -> void:
	cands.clear()
	var list: Array = []
	for e in units:
		if e.faction != 0 or e.dead:
			continue
		var d: float = e.global_position.distance_to(possess_from)
		list.append([d - (400.0 if e.in_squad else 0.0), e])
	list.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(8, list.size()):
		cands.append(list[i][1])
	cand_sel = 0

func _possess_update(rdt: float) -> void:
	possess_t += rdt
	cands = cands.filter(func(c): return is_instance_valid(c) and not c.dead)
	if cands.is_empty():
		_gather_cands()
		if cands.is_empty():
			_defeat("NO ONE IS LEFT TO CARRY YOUR WILL")
			possess = false
			Game.possess_slow = false
			return
	cand_sel = clampi(cand_sel, 0, cands.size() - 1)
	var mp := get_global_mouse_position()
	var bd := 26.0
	for i in cands.size():
		var d: float = (cands[i].global_position + Vector2(0, -10)).distance_to(mp)
		if d < bd:
			bd = d
			cand_sel = i
	if Input.is_action_just_pressed("cycle"):
		cand_sel = (cand_sel + 1) % cands.size()
		Sfx.play("ui", -6.0)
	cam.target = cands[cand_sel]
	var go := Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("confirm")
	if (possess_t > 0.5 and go) or possess_t > 7.0 or (Game.autotest and not Game.noauto and possess_t > 1.2):
		var u: Unit = cands[cand_sel]
		fx.wisp(possess_from, u.global_position)
		possess = false
		Game.possess_slow = false
		take_control(u)
		Sfx.play("possess", 0.0, 1.25)
		hud.screen_flash(0.6)

# ------------------------------------------------------------------ squad
func _squad_update(delta: float) -> void:
	squad_t -= delta
	if squad_t <= 0.0:
		squad_t = 1.5
		_refresh_squad()

func _refresh_squad() -> void:
	squad = squad.filter(func(s): return is_instance_valid(s) and not s.dead and not s.is_player)
	if player == null:
		return
	var want := maxi(16, Game.squad_size())
	while squad.size() > want:
		var s = squad.pop_back()
		s.in_squad = false
		s.brain.leader = null
	if squad.size() < want:
		var pool: Array = []
		for e in query(player.global_position, 480.0):
			if e.faction != 0 or e.dead or e.is_player or e.in_squad or e.mounted or e.spectator:
				continue
			pool.append(e)
		var pp := player.global_position
		pool.sort_custom(func(a, b): return a.global_position.distance_squared_to(pp) < b.global_position.distance_squared_to(pp))
		for e in pool:
			if squad.size() >= want:
				break
			e.in_squad = true
			squad.append(e)
	for i in squad.size():
		var s = squad[i]
		if s.brain is AIBrain:
			s.brain.leader = player
			s.brain.slot = i
			s.brain.order = squad_order
			s.brain.order_pt = squad_pt

# ------------------------------------------------------------------ armies
func _spawning(delta: float) -> void:
	if ended:
		return
	for f in 2:
		spawn_cd[f] -= delta
		if spawn_cd[f] <= 0.0:
			spawn_cd[f] = randf_range(1.7, 2.4)
			var room: int = caps[f] - alive[f]
			var n: int = mini(mini(16, room), reserves[f])
			if n >= 3 or (n > 0 and alive[f] < 10):
				_spawn_group(f, n)

func _spawn_group(f: int, n: int) -> void:
	if level_ctl != null:
		level_ctl.spawn_group(f, n)
		reserves[f] -= n
		return
	var dir := 1.0 if f == 0 else -1.0
	var x := 50.0 if f == 0 else W - 50.0
	var y := randf_range(TOP + 60.0, BOT - 60.0)
	if player != null:
		y = lerpf(y, player.global_position.y, 0.45)
	for i in n:
		spawn(f, _pick_kind(), Vector2(x - dir * (i / 3) * 16.0, y + ((i % 3) - 1) * 18.0 + randf_range(-4, 4)))
	reserves[f] -= n

func retire(u: Unit) -> void:
	units.erase(u)
	tokens.erase(u)
	squad.erase(u)
	u.dead = true
	u.queue_free()

func _events(delta: float) -> void:
	if ended:
		return
	for k in ev.keys():
		ev[k] = float(ev[k]) - delta
	if ev["volley_e"] <= 0.0:
		ev["volley_e"] = randf_range(28.0, 42.0)
		_enemy_volley_event()
	if ev["volley_a"] <= 0.0:
		ev["volley_a"] = randf_range(24.0, 38.0)
		_ally_volley_event()
	if level_ctl != null and not level_ctl.cavalry_ok():
		return
	if ev["cav_e"] <= 0.0:
		ev["cav_e"] = randf_range(80.0, 110.0)
		_cavalry(1, 5)
	if ev["cav_a"] <= 0.0:
		ev["cav_a"] = randf_range(100.0, 130.0)
		_cavalry(0, 4)

## A generic blunt hit from the environment (collisions, hazards).
func impact_hit(dmg: float, src_pos: Vector2) -> Dictionary:
	var h := _volley_hit(dmg)
	h["ranged"] = false
	h["src_pos"] = src_pos
	h["pz"] = 40.0
	h["kb"] = 60.0
	return h

## A flung soldier lands in a fire or on stakes.
func hazard_hurt(u: Unit, hz: Dictionary, src: Unit) -> void:
	var h := impact_hit(0.0, hz["pos"])
	h["knockdown"] = true
	h["pz"] = 999.0
	var src_player := src != null and src.is_player
	if hz["kind"] == "fire":
		h["dmg"] = 26.0 + u.max_hp * 0.3
		fx.burst(u.global_position + Vector2(0, -10), Color(1.0, 0.55, 0.2), 18)
		fx.text(u.global_position + Vector2(0, -32), "BURNED", Color("#ff9a3d"))
		Sfx.play_at("boom", u.global_position, -8.0, 1.4)
		if src_player:
			Game.add_style("fire", 130.0, "INTO THE FIRE", Color("#ff9a3d"))
	else:
		h["dmg"] = 40.0 + u.max_hp * 0.45
		h["bleed"] = 60.0
		fx.blood(u.global_position + Vector2(0, -10), Vector2.UP, 14)
		fx.text(u.global_position + Vector2(0, -32), "IMPALED", Color("#ff4d4d"))
		Sfx.play_at("hit_heavy", u.global_position, -2.0, 0.7)
		if src_player:
			Game.add_style("stakes", 150.0, "IMPALED", Color("#ff4d4d"))
	if src_player:
		cam_shake(6.0)
	u.take_hit(src, h)

func _volley_hit(dmg: float) -> Dictionary:
	return {"dmg": dmg, "pz": 18.0, "st": 10.0, "kb": 30.0, "perilous": false, "bleed": 0.0, "anti_cav": false,
		"guard_break": 1.0, "src_pos": Vector2.ZERO, "ranged": true, "skill": false, "crit": false, "heavy": false, "bash": false}

func enemy_volley(target: Vector2, r: float, n: int) -> void:
	proj.rain(null, target, r, n, 1.1, _volley_hit(12.0), 1)
	Sfx.play_at("volley", target, -2.0)
	if player != null and player.global_position.distance_to(target) < 220.0:
		hud.alert("ENEMY VOLLEY! GET OUT OF THE RED CIRCLE", Color("#ff5a5a"))

## Aldric's Wrath: golden blades fall from the burning sky around the player.
func heaven_blades(src: Unit, target: Unit) -> void:
	var h := _volley_hit(22.0)
	h["pz"] = 40.0
	var base: Vector2 = target.global_position
	for i in 4:
		var off := Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(50.0, 90.0)
		proj.rain(src, base + off + target.move_vel * 0.4 * (1 if i == 0 else 0), 52.0, 16, 1.0 + i * 0.45, h, 1, true)
	atmos.do_flash(0.35, Color(1.0, 0.85, 0.5))
	Sfx.play("horn_short", -4.0, 1.2)
	Sfx.play("volley", -4.0, 1.3)
	hud.alert("A THOUSAND BLADES FALL FROM THE HEAVENS!", Color("#ffd166"))
	hud.tip("blades", "GOLDEN CIRCLES: KEEP MOVING. (THE KING'S UMBRELLA LEGACY KEEPS YOU DRY.)")

func _enemy_volley_event() -> void:
	if duel:
		return
	var target := Vector2.ZERO
	if player != null and randf() < 0.55:
		target = player.global_position + player.move_vel * 0.5
	else:
		var allies := units.filter(func(u): return u.faction == 0)
		if allies.is_empty():
			return
		target = allies.pick_random().global_position
	enemy_volley(target, 72.0, 24)

func _ally_volley_event() -> void:
	var foes := units.filter(func(u): return u.faction == 1 and not u.is_boss and not u.spectator)
	if foes.is_empty():
		return
	var t: Vector2 = foes.pick_random().global_position
	if duel and t.distance_to(duel_center) < 300.0:
		return
	proj.rain(null, t, 72.0, 28, 1.0, _volley_hit(16.0), 0)
	Sfx.play_at("volley", t, -4.0)

func _cavalry(f: int, n: int) -> void:
	if reserves[f] < n or duel:
		return
	reserves[f] -= n
	var x := 60.0 if f == 0 else W - 60.0
	var y := randf_range(TOP + 80.0, BOT - 80.0)
	if player != null:
		y = clampf(player.global_position.y + randf_range(-80, 80), TOP + 60.0, BOT - 60.0)
	for i in n:
		spawn(f, "cavalry", Vector2(x - (1.0 if f == 0 else -1.0) * (i % 2) * 20.0, y + (i - n * 0.5) * 22.0))
	if f == 1:
		hud.alert("ENEMY CAVALRY CHARGE!", Color("#ff5a5a"))
		hud.tip("cav", "SPEARS AND THE ZHANMADAO DEAL DOUBLE DAMAGE TO CAVALRY")
		Sfx.play("horn_short", -4.0, 0.9)
	else:
		hud.alert("MARCH CAVALRY JOINS THE FIGHT", Color("#ff8a80"))

func _morale_update(delta: float) -> void:
	for f in 2:
		if morale[f] < 50.0:
			morale[f] += 0.12 * delta
		morale[f] = clampf(morale[f], 0.0, 100.0)
	if ended:
		return
	if morale[0] <= 0.0:
		_defeat("THE MARCH'S MORALE HAS COLLAPSED")
	elif alive[0] == 0 and reserves[0] <= 0 and player == null:
		_defeat("NO ONE IS LEFT TO CARRY YOUR WILL")
	if morale[1] < 12.0 and randf() < delta * 0.6:
		var foes := units.filter(func(u): return u.faction == 1 and not u.is_boss and not u.is_officer and not u.spectator)
		if not foes.is_empty():
			foes.pick_random().brain.rout = true

func on_unit_killed(u: Unit, killer: Unit, h: Dictionary) -> void:
	if u == boss:
		_victory()
	units.erase(u)
	tokens.erase(u)
	if u.in_squad:
		squad.erase(u)
	var f := u.faction
	var loss := 0.16
	if u.is_officer:
		loss = 14.0
	elif u.is_boss:
		loss = 100.0
	elif u.kind in ["heavy", "cavalry", "guard"]:
		loss = 0.4
	morale[f] -= loss
	morale[1 - f] = minf(100.0, morale[1 - f] + loss * 0.6)
	var kv := killer != null and is_instance_valid(killer)
	if kv and killer.is_player:
		morale[0] = minf(100.0, morale[0] + 0.22)
		Game.register_kill(u.xp_value, h.get("crit", false), h.get("skill", false))
		killer.spirit = minf(Unit.MAX_SPIRIT, killer.spirit + 6.0)
		if u.is_officer:
			impact(u.global_position + Vector2(0, -10), 0.14)
			decals.splat(u.global_position, (u.global_position - killer.global_position).normalized())
			Game.stats["officers"] += 1
			cam.push(0.32, 1.3)
			Game.add_style("officer", 300.0, "OFFICER SLAIN", Color("#ff9a3d"))
			hud.banner("OFFICER SLAIN", u.uname + " HAS FALLEN", Color("#ff9a3d"))
			Sfx.play("gong", -4.0)
		var chance := 0.08
		match u.kind:
			"heavy":
				chance = 0.22
			"guard":
				chance = 0.35
			"cavalry":
				chance = 0.3
			"officer":
				chance = 1.0
		if randf() < chance and not u.is_boss:
			var lvl := 2 if u.is_officer else (1 if (u.kind in ["guard", "heavy"] and randf() < 0.5) else 0)
			drop_weapon(Weapon.make(u.weapon.id, lvl), u.global_position)
	elif kv and killer.in_squad:
		Game.add_xp(u.xp_value * 0.25)
	if u == player and not ended:
		_on_player_death(u)

func on_player_hurt(dmg: float) -> void:
	hurt = minf(1.0, hurt + dmg / 40.0)
	if player != null and player.hp < player.max_hp * 0.3:
		hud.tip("lowhp", "LOW HP: PRESS R TO DRINK A FLASK, OR HIT BACK TO RECOVER THE ORANGE (RALLY)")

# ------------------------------------------------------------------ officers, general, duel
func _officer_boss_checks() -> void:
	if ended:
		return
	var frac := float(reserves[1]) / float(reserves_max[1])
	var officer_ok: bool = level_ctl == null or level_ctl.officers_ok()
	if officer_ok and officers_spawned < officer_marks.size() and (frac <= officer_marks[officers_spawned] or time >= officer_times[officers_spawned]):
		_spawn_officer()
	officers_alive = officers_alive.filter(func(o): return is_instance_valid(o) and not o.dead)
	if not boss_spawned:
		var cond: bool = frac <= 0.3 or (Game.rank >= 3 and time > 240.0) or time > 540.0 or morale[1] < 15.0 or (alive[1] < 6 and reserves[1] <= 0)
		if level_ctl != null:
			cond = level_ctl.boss_ready()
		if force_boss_at >= 0.0 and time >= force_boss_at:
			cond = true
			if level_ctl != null:
				level_ctl.force_palace()
		if cond:
			_spawn_boss()

func _spawn_officer() -> void:
	officers_spawned += 1
	Game.event_log("officer %d spawned at t=%.0f" % [officers_spawned, time])
	var y := player.global_position.y if player != null else H * 0.5
	var x := W - 70.0
	if level_ctl != null:
		var op: Vector2 = level_ctl.officer_point(officers_spawned - 1)
		x = op.x
		y = op.y
	var o := spawn(1, "officer", Vector2(x, y), _pick_weapon(1, "officer"), 2)
	o.uname = "COMMANDER " + officer_names[(officers_spawned - 1) % officer_names.size()]
	officers_alive.append(o)
	for i in 5:
		spawn(1, "guard" if i < 2 else "heavy", Vector2(x - 20.0 - i * 10.0, y + (i % 2 * 2 - 1) * 16.0))
	hud.cutin(o.uname, "A CROWN COMMANDER TAKES THE FIELD", Art.tex["portrait_zhao_officer"], Color(1.0, 0.55, 0.2), 2.0)
	Game.slowmo(0.3, 1.8)
	Sfx.play("horn_short", -2.0)
	hud.tip("officer", "FILL AN OFFICER'S YELLOW STANCE BAR TO MAKE HIM KNEEL, THEN ATTACK FOR A CRITICAL")

func _spawn_boss() -> void:
	boss_spawned = true
	Game.event_log("general spawned at t=%.0f rank=%d" % [time, Game.rank])
	var y := player.global_position.y if player != null else H * 0.5
	var bx := W - 90.0
	if level_ctl != null:
		var bp: Vector2 = level_ctl.boss_point()
		bx = bp.x
		y = bp.y
	boss = spawn(1, "general", Vector2(bx, y), "black_glaive", 0)
	boss.uname = "ALDRIC"
	if debug_bosshp > 0.0:
		boss.hp = boss.max_hp * debug_bosshp
	var gb := GeneralBrain.new()
	gb.setup(boss)
	boss.brain = gb
	for i in 4:
		spawn(1, "guard", Vector2(bx - 30.0 - i * 12.0, y + (i - 1.5) * 20.0))
	Sfx.play("horn", 0.0)
	Sfx.boss_mode = true
	blizzard_target = 0.5
	# Zhao rallies around its general.
	morale[1] = maxf(morale[1], 45.0)
	for u in units:
		if u.faction == 1 and u.brain is AIBrain:
			u.brain.rout = false
	hud.cutin("ALDRIC", "THE BLACK GLAIVE OF THE CROWN  -  GENERAL", Art.tex["portrait_zhao_general"], Color(0.95, 0.22, 0.3), 2.8)
	Game.slowmo(0.2, 2.6)

func _duel_update(delta: float) -> void:
	cheer_cd -= delta
	clash_cd -= delta
	if duel and duel_kind == "officer":
		if duel_foe == null or not is_instance_valid(duel_foe) or duel_foe.dead or player == null or ended:
			_end_duel(duel_foe != null and is_instance_valid(duel_foe) and duel_foe.dead)
		return
	if not duel and player != null and not possess:
		var o := _challengeable_officer()
		if o != null:
			hud.prompt("F", "CHALLENGE " + o.uname)
			if Game.autotest and randf() < delta * 0.5:
				challenge_officer(o)
	if boss == null or not is_instance_valid(boss) or boss.dead or ended:
		return
	if not duel and player != null and boss.global_position.distance_to(player.global_position) < 200.0:
		_start_duel(boss, "boss")

func _challengeable_officer() -> Unit:
	if duel or player == null or possess:
		return null
	for o in officers_alive:
		if is_instance_valid(o) and not o.dead and o.global_position.distance_to(player.global_position) < 170.0:
			return o
	return null

## Kingdom-style one-on-one: you call out a Zhao commander and both armies stop to watch.
func challenge_officer(o: Unit) -> void:
	hud.cutin(o.uname, "ACCEPTS YOUR CHALLENGE  -  ONE ON ONE", Art.tex["portrait_zhao_officer"], Color(1.0, 0.55, 0.2), 1.6)
	Game.slowmo(0.3, 1.2)
	_start_duel(o, "officer")

func _end_duel(won: bool) -> void:
	duel = false
	duel_kind = ""
	duel_foe = null
	clash = {}
	for u in units:
		u.duelist = false
		if u.spectator:
			u.spectator = false
			if u.brain is AIBrain:
				u.brain.spectate = false
	if won:
		hud.banner("DUEL WON", "BOTH ARMIES SAW IT  -  THE MARCH'S MORALE SOARS", Color("#ffd166"), true, 3.0)
		morale[0] = minf(100.0, morale[0] + 12.0)
		morale[1] = maxf(0.0, morale[1] - 8.0)
		cheer_heat = 1.0
		Sfx.play("gong", -2.0)
	Game.event_log("officer duel ended won=%s at t=%.0f" % [str(won), time])

func _start_duel(foe: Unit = null, kind: String = "boss") -> void:
	if foe == null:
		foe = boss
	duel = true
	duel_foe = foe
	duel_kind = kind
	Game.event_log("duel (%s) started at t=%.0f" % [kind, time])
	var c := (player.global_position + foe.global_position) * 0.5
	c.x = clampf(c.x, DUEL_RX + 60.0, W - DUEL_RX - 60.0)
	c.y = clampf(c.y, TOP + DUEL_RY + 30.0, BOT - DUEL_RY - 30.0)
	duel_center = c
	player.duelist = true
	foe.duelist = true
	tokens.clear()
	var buckets := {}
	var per_ring := int(TAU * DUEL_RX / 9.0)
	for u in units:
		if u == player or u == foe:
			continue
		if u.global_position.distance_to(c) > (560.0 if kind == "boss" else 420.0):
			continue
		var a: float = (u.global_position - c).angle()
		var bi := int(floor((a + PI) / TAU * per_ring)) % per_ring
		var row: int = buckets.get(bi, 0)
		buckets[bi] = row + 1
		var ang := (bi + 0.5) / per_ring * TAU - PI
		var s := 1.1 + row * 0.1
		u.spectator = true
		if u.brain is AIBrain:
			u.brain.spectate = true
			u.brain.token = false
			u.brain.ring_pos = c + Vector2(cos(ang) * DUEL_RX * s, sin(ang) * DUEL_RY * s)
	if kind == "officer":
		hud.banner("ONE ON ONE", foe.uname + "  -  THE ARMIES STOP TO WATCH", Color("#ff9a3d"), true, 3.0)
		Sfx.play("gong", -4.0)
		hud.tip("clash", "WHEN YOUR BLOWS MEET IN MID-SWING THE BLADES LOCK: MASH ATTACK TO WIN THE CLASH")
		return
	# The rest of both armies close in and form a great ring around the duel.
	var rng := RandomNumberGenerator.new()
	for half in [1, 2]:
		var ring := WorldBuilder.Crowd.new()
		ring.add_ring("qin", "zhao", c, DUEL_RX * 1.55, DUEL_RY * 1.55, 4, rng, half, 7)
		ring.finish()
		duel_rings.append(ring)
		shadows.add_crowd(ring)
		for tp in ring.torches:
			atmos.add_light(tp, 16.0, Color(1.0, 0.58, 0.28) * 0.6, 0.35, false)
		ring.modulate.a = 0.0
		add_child(ring)
		move_child(ring, world.get_index() + (0 if half == 1 else 1))
		create_tween().tween_property(ring, "modulate:a", 1.0, 1.6)
	hud.banner("THE DUEL", "THE ARMIES FORM A RING. DEFEAT GENERAL ALDRIC.", Color("#ff3d5a"), true, 3.5)
	Sfx.play("gong", -2.0)
	hud.tip("duel", "WATCH HIS GLINTS: WHITE = PARRY OR BLOCK.  RED = DASH THROUGH IT")

# ------------------------------------------------------------------ blade lock (clash)
func can_clash(a: Unit, b: Unit) -> bool:
	return clash.is_empty() and clash_cd <= 0.0 and (a.is_player or b.is_player) and not a.dead and not b.dead

func start_clash(a: Unit, b: Unit) -> void:
	var p: Unit = a if a.is_player else b
	var f: Unit = b if p == a else a
	var dir := (f.global_position - p.global_position).normalized()
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT
	var mid := (p.global_position + f.global_position) * 0.5
	for u in [p, f]:
		u.state = Unit.St.CLASH
		u.st_t = 0.0
		u.vel = Vector2.ZERO
		u.hyper = false
		u.charging = false
	p.global_position = mid - dir * 13.0
	f.global_position = mid + dir * 13.0
	p.aim = dir
	f.aim = -dir
	clash = {"p": p, "f": f, "t": 0.0, "push": 0.5, "dur": 2.4, "spark": 0.0, "dir": dir}
	cam.push(0.6, 2.6)
	Game.slowmo(0.6, 2.4)
	atmos.impact_frame(0.08)
	atmos.aberrate(4.0)
	Sfx.play("parry", 0.0, 0.8)
	Sfx.play("clank", -2.0, 0.7)
	fx.hit_star(mid + Vector2(0, -16), 18.0, Color(1.0, 0.95, 0.75), 0.2)
	hud.speed_lines(hud._to_screen(mid + Vector2(0, -12)), 0.4)
	cheer_heat = 1.0

func _clash_update(rdt: float) -> void:
	if clash.is_empty():
		return
	var p: Unit = clash["p"]
	var f: Unit = clash["f"]
	if not is_instance_valid(p) or not is_instance_valid(f) or p.dead or f.dead:
		clash = {}
		return
	clash["t"] = float(clash["t"]) + rdt
	var mash := false
	if Game.autotest:
		mash = randf() < rdt * 7.5
	else:
		mash = Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("heavy")
	var push: float = clash["push"]
	if mash:
		push += 0.075 * (1.25 if Game.aura_active() else 1.0)
		cam_shake(2.0)
	var foe_rate := 0.3 if f.is_officer else (0.4 if boss_phase < 3 else 0.5)
	push -= foe_rate * rdt
	clash["push"] = push
	var dir: Vector2 = clash["dir"]
	var mid := p.global_position.lerp(f.global_position, 0.5)
	# the lock slides toward whoever is losing
	var shift := (push - 0.5) * 10.0
	p.global_position = mid - dir * 13.0 + dir * shift
	f.global_position = mid + dir * 13.0 + dir * shift
	for u in [p, f]:
		u.state = Unit.St.CLASH
		u.vel = Vector2.ZERO
	clash["spark"] = float(clash["spark"]) - rdt
	if float(clash["spark"]) <= 0.0:
		clash["spark"] = 0.09
		fx.sparks(mid + Vector2(0, -15), Color(1.0, 0.9, 0.6), 4)
		Sfx.play_at("clank", mid, -10.0, randf_range(0.8, 1.1))
	var t: float = clash["t"]
	var won := push >= 1.0 or (t >= float(clash["dur"]) and push >= 0.5)
	var lost := push <= 0.0 or (t >= float(clash["dur"]) and push < 0.5)
	if not (won or lost):
		return
	clash = {}
	clash_cd = 5.0
	p.state = Unit.St.IDLE
	f.state = Unit.St.IDLE
	if won:
		f.vel = dir * 220.0
		f.break_stance(p)
		Game.add_style("clash", 150.0, "CLASH WON", Color("#ffd166"))
		impact(f.global_position + Vector2(0, -12), 0.1)
		Game.hitstop(0.12)
		hud.alert("THE LOCK BREAKS  -  STRIKE NOW!", Color("#ffd166"))
		p.spirit = minf(Unit.MAX_SPIRIT, p.spirit + 25.0)
	else:
		p.vel = -dir * 240.0
		p.stagger(0.8)
		p.hp = maxf(1.0, p.hp - p.max_hp * 0.08)
		f.state = Unit.St.IDLE
		cam_shake(8.0)
		hud.alert("OVERPOWERED", Color("#ff5a5a"))
		Sfx.play("hit_heavy", -2.0, 0.7)

func cheer() -> void:
	cheer_heat = minf(1.0, cheer_heat + 0.35)
	if cheer_cd > 0.0:
		return
	cheer_cd = 0.25
	for u in units:
		if u.spectator and randf() < 0.35:
			u.cheer_t = 0.6

func on_boss_phase(ph: int) -> void:
	boss_phase = ph
	Game.event_log("general phase %d at t=%.0f" % [ph, time])
	var c := duel_center if duel else boss.global_position
	if ph == 2:
		impact(boss.global_position + Vector2(0, -14), 0.12)
		hud.banner("\"NOT BAD... FOR A NAMELESS SOLDIER.\"", "ALDRIC CALLS HIS ELITE GUARD INTO THE RING", Color("#d9c9ff"), false, 3.5)
		for i in 3:
			var a := randf() * TAU
			var g := spawn(1, "guard", c + Vector2(cos(a) * DUEL_RX * 0.85, sin(a) * DUEL_RY * 0.85), "", 1)
			g.duelist = duel
		Sfx.play("horn_short", -2.0)
	elif ph == 3:
		hud.banner("WRATH OF THE BLACK GLAIVE", "HE FIGHTS WITH EVERYTHING HE HAS LEFT", Color("#ff3d5a"), true, 3.5)
		boss.tint = Color(1.15, 0.85, 1.3)
		atmos.wrath_target = 1.0
		atmos.lightning = true
		atmos.impact_frame(0.2)
		fx.ring(boss.global_position, 80.0, Color(0.8, 0.4, 1.0, 0.9), 0.6)
		cam_shake(8.0)
		Sfx.play("boom", 0.0)
		Sfx.play("horn", -2.0, 0.8)
		blizzard_target = 1.0

func _victory() -> void:
	Game.campaign["handan" if level == "siege" else "snow_plains"] = true
	if ended:
		return
	Game.event_log("VICTORY at t=%.0f" % time)
	ended = true
	victory = true
	end_t = 0.0
	duel = false
	cam.push(0.35, 2.5)
	Game.promote_to_general()
	Game.slowmo(0.25, 2.5)
	atmos.wrath_target = 0.0
	atmos.victory_target = 1.0
	if player != null:
		hud.ink_slash(hud._to_screen(boss.global_position + Vector2(0, -12)), (boss.global_position - player.global_position).normalized())
		hud.speed_lines(hud._to_screen(boss.global_position + Vector2(0, -12)), 0.5)
	cheer_heat = 1.0
	atmos.lightning = false
	atmos.impact_frame(0.3)
	hud.banner("THE GENERAL HAS FALLEN", "ALDRIC'S HEAD IS TAKEN  -  YOU ARE NAMED GENERAL OF THE MARCH", Color("#ffd166"), true, 6.0)
	Sfx.play("gong", 0.0)
	Sfx.play("horn", -2.0, 1.1)
	Sfx.boss_mode = false
	blizzard_target = 0.0
	morale[1] = 0.0
	for u in units:
		u.spectator = false
		if u.brain is AIBrain:
			u.brain.spectate = false
			if u.faction == 1:
				u.brain.rout = true

func _defeat(reason: String) -> void:
	if ended:
		return
	Game.event_log("DEFEAT at t=%.0f: %s" % [time, reason])
	ended = true
	victory = false
	end_t = 0.0
	hud.banner("THE ARMY BREAKS", reason, Color("#e5484d"), true, 4.5)
	Sfx.play("horn", 0.0, 0.7)
	Sfx.boss_mode = false
	for u in units:
		if u.faction == 0 and u.brain is AIBrain:
			u.brain.rout = true

func leave(restart: bool) -> void:
	get_tree().paused = false
	Game.possess_slow = false
	leave_battle.emit(restart)

# ------------------------------------------------------------------ ranks & perks
func _on_rank_changed(r: int) -> void:
	Game.event_log("rank %d at t=%.0f" % [r, time])
	if r >= Game.RANKS.size() - 1 or ended:
		return
	var unlock: String = ["", "4 SOLDIERS NOW FOLLOW YOU INTO BATTLE",
		"SQUAD OF 8  -  ORDERS: 1 FOLLOW  2 CHARGE  3 HOLD",
		"SQUAD OF 12  -  G: WAR CRY   V: ARROW VOLLEY AT CURSOR",
		"SQUAD OF 16  -  WAR CRY AND VOLLEYS RECHARGE TWICE AS FAST"][r]
	hud.promote_stamp(r)
	cam.push(0.25, 1.6)
	hud.banner(Game.rank_name(r), "PROMOTED  -  " + Game.RANKS[r]["jp"] + "  -  " + unlock, Color("#ffd166"), true, 4.0, "", true)
	Sfx.play("gong", 0.0)
	morale[0] = minf(100.0, morale[0] + 8.0)
	if player != null:
		player.hp = minf(player.max_hp, player.hp + player.max_hp * 0.3)
		fx.heal(player)
		fx.ring(player.global_position, 60.0, Color(1.0, 0.85, 0.4, 0.9), 0.6)
	_refresh_squad()
	perk_queue += 1
	perk_delay = 1.8

func _perk_update(rdt: float) -> void:
	if perk_queue <= 0 or hud.perk_open or possess or ended or get_tree().paused:
		return
	perk_delay -= rdt
	if perk_delay <= 0.0:
		perk_queue -= 1
		perk_delay = 0.6
		hud.open_perks(Game.random_perks(3))

func on_perk_chosen(id: String) -> void:
	if player == null:
		return
	match id:
		"iron_lungs":
			player.max_stamina *= 1.3
			player.stam_regen *= 1.25
		"unbroken":
			player.max_poise *= 1.5
		"field_medic":
			player.max_flasks += 1
			player.flasks += 1
		"veteran":
			player.vig += 3
			player.endu += 3
			player.stren += 3
			player.dex += 3

# ------------------------------------------------------------------ presentation
func _props_anim() -> void:
	var f := int(anim_t * 10.0)
	if f == anim_f:
		return
	anim_f = f
	if f % 2 == 0:
		var bf := f / 2
		for b in banners:
			var t: Texture2D = Art.tex[("gbanner_%s_%d" if b[3] else "banner_%s_%d") % [b[1], (bf + int(b[2])) % 3]]
			b[0].texture = t
			if b[0].has_meta("shadow"):
				b[0].get_meta("shadow").texture = t
	for fl in flames:
		if is_instance_valid(fl[0]):
			fl[0].texture = Art.tex[fl[1] + str((f + int(fl[2])) % 4)]

## Extra lights tied to units: the player's faint will-glow, the general's aura, pickups.
func _draw_unit_lights(l: LightPainter) -> void:
	var nk := atmos.night()
	if player != null and is_instance_valid(player) and not player.dead:
		l.glow(player.global_position + Vector2(0, -6), 34.0, Color(1.0, 0.78, 0.45) * (0.12 + nk * 0.35))
		if Game.aura_active():
			l.glow(player.global_position + Vector2(0, -8), 70.0, Color(1.0, 0.55, 0.22) * (0.75 + 0.2 * sin(anim_t * 7.0)))
	if boss != null and is_instance_valid(boss) and not boss.dead:
		var c := Color(0.7, 0.35, 1.0) if boss_phase < 3 else Color(1.0, 0.35, 0.2)
		l.glow(boss.global_position + Vector2(0, -10), 54.0, c * (0.45 + 0.15 * sin(anim_t * 4.0)))
	for pk in pickups:
		var p: Vector2 = pk["pos"]
		l.glow(p, 16.0, Color(1.0, 0.85, 0.4) * (0.5 + 0.2 * sin(anim_t * 5.0 + p.x)))

## Where a soldier with no enemy in sight should head. Open battles use the front line
## (INF here); levels can override this (the siege sends Qin to the breaches and gates).
## Which way a routed soldier runs (off the map edge behind their own army).
func rout_dir(f: int) -> Vector2:
	if level_ctl != null:
		return level_ctl.rout_dir(f)
	return Vector2(-1.0 if f == 0 else 1.0, 0.0)

func march_goal(u: Unit) -> Vector2:
	if level_ctl != null:
		return level_ctl.march_goal(u)
	return Vector2.INF

## Auto-target: the best enemy for an attack aimed along `dir` within `rng`. Closer and more
## centred is better; kneeling or fallen enemies (execution chances), officers and the general
## are preferred.
func pick_target(u: Unit, dir: Vector2, rng: float) -> Unit:
	var best: Unit = null
	var bs := INF
	var d0 := dir.normalized() if dir.length_squared() > 0.01 else u.aim
	for e in query(u.global_position, rng + 12.0):
		if e.dead or e.faction == u.faction or e.spectator:
			continue
		if level_ctl != null and not level_ctl.reachable(u, e):
			continue
		var to: Vector2 = e.global_position - u.global_position
		var d := to.length()
		if d > rng + e.radius:
			continue
		var ang := absf(angle_difference(d0.angle(), to.angle())) if d > 1.0 else 0.0
		if ang > deg_to_rad(44.0) and d > 18.0:
			continue
		if terrain != null and terrain.blocked(u.global_position, e.global_position):
			continue
		var score := d * (1.0 + ang * 1.8)
		if e.state == Unit.St.BROKEN or e.state == Unit.St.KNOCKDOWN:
			score *= 0.7
		if e.is_officer or e.is_boss:
			score *= 0.85
		if score < bs:
			bs = score
			best = e
	return best

func _soft_target_update(rdt: float) -> void:
	soft_t -= rdt
	if soft_t > 0.0:
		return
	soft_t = 0.1
	if player == null or possess or not is_instance_valid(player):
		soft_target = null
		return
	var rng: float = 300.0 if player.weapon.ranged else player.weapon.reach + 70.0
	soft_target = pick_target(player, player.i_aim, rng)

## Dynamic zoom: close in when only a few enemies are around you, pull back on a big crowd.
func _crowd_zoom(rdt: float) -> void:
	zoom_t -= rdt
	if zoom_t > 0.0:
		return
	zoom_t = 0.2
	cam.cinematic = 1.0 if not hud.cut.is_empty() else 0.0
	if Game.command_view:
		cam.base_zoom = 0.52
		cam.fight_weight = 0.0
		return
	if debug_zoom > 0.0:
		cam.base_zoom = debug_zoom
		return
	if possess or player == null or not is_instance_valid(player):
		cam.base_zoom = 1.05
		cam.fight_weight = 0.0
		return
	if duel:
		cam.base_zoom = 1.62
		var foe = duel_foe
		if foe != null and is_instance_valid(foe):
			cam.fight_center = (player.global_position + foe.global_position) * 0.5
			cam.fight_weight = 0.5
		return
	# who is fighting near you: their centre pulls the frame, their number sets the zoom
	var near := 0
	var crowd := 0
	var sum := Vector2.ZERO
	var wsum := 0.0
	var pp := player.global_position
	for e in query(pp, 230.0):
		if e.dead or e.faction == player.faction or e.spectator:
			continue
		var d: float = e.global_position.distance_to(pp)
		if d < 230.0:
			crowd += 1
			var w := 1.0 - d / 230.0
			sum += e.global_position * w
			wsum += w
			if d < 120.0:
				near += 1
	var goal := 1.34
	if crowd >= 18:
		goal = 1.12
	elif crowd >= 11:
		goal = 1.22
	elif crowd >= 6:
		goal = 1.32
	elif near >= 1:
		goal = 1.52
	elif crowd >= 1:
		goal = 1.42
	if player.mounted:
		goal -= 0.12
	if player.charging:
		goal += 0.08 * player.charge
	cam.base_zoom = goal
	if wsum > 0.0:
		cam.fight_center = sum / wsum
		cam.fight_weight = clampf(wsum / 4.0, 0.0, 1.0) * 0.3
	else:
		cam.fight_weight = move_toward(cam.fight_weight, 0.0, 0.1)

func _camera_shaders(rdt: float) -> void:
	# lead: where you are going, and a little toward where you aim
	if player != null and not possess and is_instance_valid(player):
		cam.look = cam.look.lerp((player.move_vel * 0.24).limit_length(48.0), 1.0 - exp(-rdt * 2.6))
		var to_aim: Vector2 = player.i_aim_pt - player.global_position
		var pull := (to_aim * 0.16).limit_length(40.0) if to_aim.length() < 600.0 else Vector2.ZERO
		cam.aim_pull = cam.aim_pull.lerp(pull, 1.0 - exp(-rdt * 3.0))
	else:
		cam.look = cam.look.lerp(Vector2.ZERO, 0.1)
		cam.aim_pull = cam.aim_pull.lerp(Vector2.ZERO, 0.1)
	_crowd_zoom(rdt)
	_soft_target_update(rdt)
	blizzard = move_toward(blizzard, blizzard_target, rdt * 0.3)
	atmos.blizzard = blizzard
	atmos.hurt = hurt
	atmos.ink_target = 1.0 if possess else 0.0
	if debug_day < 0.0 and not ended and level_ctl == null:
		# Golden hour -> sunset -> dusk over the battle; the general arrives at nightfall.
		atmos.day_target = 1.0 if boss_spawned else clampf(time / 480.0, 0.0, 0.85)
	shadow_vec = atmos.sun_shadow()
	shadows.set_sun(shadow_vec, atmos.cur["shadow_col"], atmos.cur["shadow_alpha"])
	crows.shadow_vec = shadow_vec
	shadows.visible = not Game.low_gfx
	atmos.blur_target = 1.0 if (get_tree().paused or hud.results_open) else 0.0
	var ex := clampf(cheer_heat, 0.0, 1.0)
	cheer_heat = maxf(0.0, cheer_heat - rdt * 1.5)
	for r in duel_rings:
		r.set_excite(ex)
	if not possess:
		Sfx.intensity = clampf(Game.style_tier() / 6.0, 0.0, 1.0)

func _debug_freeze(n: Node) -> void:
	for c in n.get_children():
		if not (c is Unit) and c != cam and c != fx and c != hud and c != atmos and c != tactics and c != proj and c != unit_shadows and c != decals:
			c.set_process(false)
		_debug_freeze(c)

func _debug_freeze_kind(n: Node, what: String) -> int:
	var k := 0
	for c in n.get_children():
		var hit := false
		match what:
			"emit":
				hit = c is CPUParticles2D
			"siege":
				var s = c.get_script()
				hit = s != null and str(s.resource_path).contains("siege_props")
			"building":
				hit = c is Scenery.Building
			"scenery":
				hit = c == scenery
		if hit:
			c.set_process(false)
			if c is CPUParticles2D:
				(c as CPUParticles2D).emitting = false
				c.visible = false
			k += 1
		k += _debug_freeze_kind(c, what)
	return k

func _debug_census() -> void:
	var counts := {}
	var stack: Array = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
			if c is Unit:
				continue
			var key := c.get_class()
			var s = c.get_script()
			if s != null:
				key += ":" + str(s.resource_path).get_file() + "/" + str(s.get_global_name())
			if c.is_processing():
				key += " [proc]"
			counts[key] = int(counts.get(key, 0)) + 1
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	for k in keys:
		print("[census] ", counts[k], " ", k)

## Fire emitters well outside the view stop simulating (they resume when the camera returns).
func _cull_emitters(delta: float) -> void:
	emit_t -= delta
	if emit_t > 0.0:
		return
	emit_t = 0.25
	var near := view_rect.grow(180.0)
	for e in fire_emitters:
		if not is_instance_valid(e):
			continue
		var on := near.has_point(e.global_position)
		if e.visible != on:
			e.visible = on
			e.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
