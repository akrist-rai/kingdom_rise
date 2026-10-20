class_name Battle
extends Node2D
## Runs one full battle: the two armies, reinforcements, morale, events (volleys,
## cavalry charges, officers), the player's rise through the ranks, taking over a new
## body on death, squad orders, and the final duel with the enemy general.

signal leave_battle(restart: bool)

const W := 3200.0
const H := 960.0
const TOP := 78.0
const BOT := 925.0
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

var frozen := false
var enemy_dmg_mult := 1.0
var reserves := [470, 640]
var reserves_max := [470, 640]
var caps := [40, 44]
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

# ------------------------------------------------------------------ setup
func _ready() -> void:
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
	_build()
	_deploy()
	Game.rank_changed.connect(_on_rank_changed)
	Sfx.boss_mode = false
	Sfx.intensity = 0.0
	Sfx.start_music()
	Sfx.play("horn", -3.0)
	hud.banner("THE SNOW PLAINS", "QIN VS ZHAO  -  RISE FROM FOOT SOLDIER TO GENERAL", Color("#ffd166"), true, 4.5)

func _exit_tree() -> void:
	Game.possess_slow = false
	Engine.time_scale = 1.0

func _build() -> void:
	visibility_layer = 3
	ground = WorldBuilder.ground(Rect2(-760, -80, W + 1520, H + 560), TOP, W)
	add_child(ground)
	sky = WorldBuilder.sky(Rect2(-760, -760, W + 1520, 800), 40.0)
	add_child(sky)
	decals = Decals.new()
	add_child(decals)
	decals.setup(Vector2(W, H))
	shadows = ShadowLayer.new()
	add_child(shadows)
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
	WorldBuilder.populate(self)

func _deploy() -> void:
	var n0 := 32
	var n1 := 38
	for i in n0:
		var k := _pick_kind()
		var x := randf_range(560, 760) - (140.0 if k == "archer" else 0.0)
		spawn(0, k, Vector2(x, lerpf(TOP + 50, BOT - 50, (i + randf()) / n0)))
	for i in n1:
		var k := _pick_kind()
		var x := randf_range(2380, 2600) + (140.0 if k == "archer" else 0.0)
		spawn(1, k, Vector2(x, lerpf(TOP + 50, BOT - 50, (i + randf()) / n1)))
	reserves[0] -= n0
	reserves[1] -= n1
	var start := Vector2(840, H * 0.5)
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

func _separation() -> void:
	for u in units:
		var s := Vector2.ZERO
		var p: Vector2 = u.global_position
		for e in query(p, 18.0):
			if e == u:
				continue
			var d: Vector2 = p - e.global_position
			var min_d: float = u.radius + e.radius
			var l2 := d.length_squared()
			if l2 < min_d * min_d:
				var l := sqrt(l2)
				if l < 0.01:
					d = Vector2(randf() - 0.5, randf() - 0.5)
					l = 0.5
				s += d / l * (min_d - l) * 12.0
		u.sep = s.limit_length(120.0)

func on_screen(pos: Vector2) -> bool:
	var c := cam.get_screen_center_position()
	return absf(pos.x - c.x) < 360.0 and absf(pos.y - c.y) < 220.0

## A manga impact frame: two-tone ink flash, speed lines, aberration and shake.
func impact(pos: Vector2, dur: float = 0.1) -> void:
	atmos.impact_frame(dur)
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
	var max_t := 2 + (1 if Game.rank >= 2 else 0) + (1 if Game.rank >= 4 else 0)
	if tokens.size() < max_t:
		tokens[u] = time + 3.0
		return true
	return false

func release_token(u: Unit) -> void:
	tokens.erase(u)

func clamp_unit(u: Unit, pos: Vector2) -> Vector2:
	pos.x = clampf(pos.x, 40.0, W - 40.0)
	pos.y = clampf(pos.y, TOP, BOT)
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
	_rebuild_grid()
	_separation()
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
	_spawning(delta)
	_events(delta)
	_morale_update(delta)
	_officer_boss_checks()
	_duel_update(delta)
	_squad_update(delta)
	_pickups_update(delta)
	_props_anim()
	_perk_update(rdt)
	_camera_shaders(rdt)
	_front(delta)
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
	if Game.rank >= 2:
		if Input.is_action_just_pressed("order_follow"):
			_set_order("follow", player.global_position)
		elif Input.is_action_just_pressed("order_charge"):
			_set_order("charge", player.i_aim_pt)
		elif Input.is_action_just_pressed("order_hold"):
			_set_order("hold", player.global_position)
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
		return
	var old := player.weapon
	pickups.erase(best)
	player.set_weapon(best["w"])
	player.base_speed = (210.0 if player.mounted else 150.0) - player.weapon.weight * 8.0
	drop_weapon(old, player.global_position + Vector2(randf_range(-8, 8), 6))
	Sfx.play("pickup", -2.0)
	hud.alert("TOOK " + player.weapon.display_name() + "  -  SKILL: " + player.weapon.skill_name, Color("#ffe8a3"))

func drop_weapon(w: Weapon, pos: Vector2) -> void:
	pickups.append({"pos": pos, "w": w, "t": 50.0})
	if pickups.size() > 24:
		pickups.remove_at(0)

func _pickups_update(delta: float) -> void:
	for pk in pickups:
		pk["t"] = float(pk["t"]) - delta
	pickups = pickups.filter(func(pk): return float(pk["t"]) > 0.0)
	if player != null and not possess:
		for pk in pickups:
			if player.global_position.distance_to(pk["pos"]) < 26.0:
				hud.tip("pickup", "PRESS F TO SWAP WEAPONS - EACH HAS ITS OWN MOVES AND SKILL")
				break

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
	var want := Game.squad_size()
	while squad.size() > want:
		var s = squad.pop_back()
		s.in_squad = false
		s.brain.leader = null
	if squad.size() < want:
		var pool: Array = []
		for e in query(player.global_position, 320.0):
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
			spawn_cd[f] = randf_range(2.4, 3.4)
			var room: int = caps[f] - alive[f]
			var n: int = mini(mini(8, room), reserves[f])
			if n >= 3 or (n > 0 and alive[f] < 10):
				_spawn_group(f, n)

func _spawn_group(f: int, n: int) -> void:
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
	if ev["cav_e"] <= 0.0:
		ev["cav_e"] = randf_range(80.0, 110.0)
		_cavalry(1, 5)
	if ev["cav_a"] <= 0.0:
		ev["cav_a"] = randf_range(100.0, 130.0)
		_cavalry(0, 4)

func _volley_hit(dmg: float) -> Dictionary:
	return {"dmg": dmg, "pz": 18.0, "st": 10.0, "kb": 30.0, "perilous": false, "bleed": 0.0, "anti_cav": false,
		"guard_break": 1.0, "src_pos": Vector2.ZERO, "ranged": true, "skill": false, "crit": false, "heavy": false, "bash": false}

func enemy_volley(target: Vector2, r: float, n: int) -> void:
	proj.rain(null, target, r, n, 1.1, _volley_hit(12.0), 1)
	Sfx.play_at("volley", target, -2.0)
	if player != null and player.global_position.distance_to(target) < 220.0:
		hud.alert("ENEMY VOLLEY! GET OUT OF THE RED CIRCLE", Color("#ff5a5a"))

## Heng Yao's Wrath: golden blades fall from the burning sky around the player.
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
		hud.alert("QIN CAVALRY JOINS THE FIGHT", Color("#ff8a80"))

func _morale_update(delta: float) -> void:
	for f in 2:
		if morale[f] < 50.0:
			morale[f] += 0.12 * delta
		morale[f] = clampf(morale[f], 0.0, 100.0)
	if ended:
		return
	if morale[0] <= 0.0:
		_defeat("QIN'S MORALE HAS COLLAPSED")
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
	if officers_spawned < officer_marks.size() and (frac <= officer_marks[officers_spawned] or time >= officer_times[officers_spawned]):
		_spawn_officer()
	officers_alive = officers_alive.filter(func(o): return is_instance_valid(o) and not o.dead)
	if not boss_spawned:
		var cond: bool = frac <= 0.3 or (Game.rank >= 3 and time > 240.0) or time > 540.0 or morale[1] < 15.0 or (alive[1] < 6 and reserves[1] <= 0)
		if force_boss_at >= 0.0 and time >= force_boss_at:
			cond = true
		if cond:
			_spawn_boss()

func _spawn_officer() -> void:
	officers_spawned += 1
	Game.event_log("officer %d spawned at t=%.0f" % [officers_spawned, time])
	var y := player.global_position.y if player != null else H * 0.5
	var x := W - 70.0
	var o := spawn(1, "officer", Vector2(x, y), _pick_weapon(1, "officer"), 2)
	o.uname = "COMMANDER " + officer_names[(officers_spawned - 1) % officer_names.size()]
	officers_alive.append(o)
	for i in 5:
		spawn(1, "guard" if i < 2 else "heavy", Vector2(x - 20.0 - i * 10.0, y + (i % 2 * 2 - 1) * 16.0))
	hud.cutin(o.uname, "A ZHAO 1000-MAN COMMANDER TAKES THE FIELD", Art.tex["portrait_zhao_officer"], Color(1.0, 0.55, 0.2), 2.0)
	Game.slowmo(0.3, 1.8)
	Sfx.play("horn_short", -2.0)
	hud.tip("officer", "FILL AN OFFICER'S YELLOW STANCE BAR TO MAKE HIM KNEEL, THEN ATTACK FOR A CRITICAL")

func _spawn_boss() -> void:
	boss_spawned = true
	Game.event_log("general spawned at t=%.0f rank=%d" % [time, Game.rank])
	var y := player.global_position.y if player != null else H * 0.5
	boss = spawn(1, "general", Vector2(W - 90.0, y), "black_glaive", 0)
	boss.uname = "HENG YAO"
	if debug_bosshp > 0.0:
		boss.hp = boss.max_hp * debug_bosshp
	var gb := GeneralBrain.new()
	gb.setup(boss)
	boss.brain = gb
	for i in 4:
		spawn(1, "guard", Vector2(W - 120.0 - i * 12.0, y + (i - 1.5) * 20.0))
	Sfx.play("horn", 0.0)
	Sfx.boss_mode = true
	blizzard_target = 0.5
	# Zhao rallies around its general.
	morale[1] = maxf(morale[1], 45.0)
	for u in units:
		if u.faction == 1 and u.brain is AIBrain:
			u.brain.rout = false
	boss.enable_cape(Unit.CAPE_GENERAL)
	hud.cutin("HENG YAO", "THE BLACK GLAIVE OF ZHAO  -  GENERAL", Art.tex["portrait_zhao_general"], Color(0.95, 0.22, 0.3), 2.8)
	Game.slowmo(0.2, 2.6)

func _duel_update(delta: float) -> void:
	cheer_cd -= delta
	if boss == null or not is_instance_valid(boss) or boss.dead or ended:
		return
	if not duel and player != null and boss.global_position.distance_to(player.global_position) < 200.0:
		_start_duel()

func _start_duel() -> void:
	duel = true
	Game.event_log("duel started at t=%.0f" % time)
	var c := (player.global_position + boss.global_position) * 0.5
	c.x = clampf(c.x, DUEL_RX + 60.0, W - DUEL_RX - 60.0)
	c.y = clampf(c.y, TOP + DUEL_RY + 30.0, BOT - DUEL_RY - 30.0)
	duel_center = c
	player.duelist = true
	boss.duelist = true
	tokens.clear()
	var buckets := {}
	var per_ring := int(TAU * DUEL_RX / 9.0)
	for u in units:
		if u == player or u == boss:
			continue
		if u.global_position.distance_to(c) > 560.0:
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
	hud.banner("THE DUEL", "THE ARMIES FORM A RING. DEFEAT GENERAL HENG YAO.", Color("#ff3d5a"), true, 3.5)
	Sfx.play("gong", -2.0)
	hud.tip("duel", "WATCH HIS GLINTS: WHITE = PARRY OR BLOCK.  RED = DASH THROUGH IT")

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
		hud.banner("\"NOT BAD... FOR A NAMELESS SOLDIER.\"", "HENG YAO CALLS HIS ELITE GUARD INTO THE RING", Color("#d9c9ff"), false, 3.5)
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
	Game.campaign["snow_plains"] = true
	if ended:
		return
	Game.event_log("VICTORY at t=%.0f" % time)
	ended = true
	victory = true
	end_t = 0.0
	duel = false
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
	hud.banner("THE GENERAL HAS FALLEN", "HENG YAO'S HEAD IS TAKEN  -  YOU ARE NAMED GENERAL (SHOUGUN) OF QIN", Color("#ffd166"), true, 6.0)
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
	if boss != null and is_instance_valid(boss) and not boss.dead:
		var c := Color(0.7, 0.35, 1.0) if boss_phase < 3 else Color(1.0, 0.35, 0.2)
		l.glow(boss.global_position + Vector2(0, -10), 54.0, c * (0.45 + 0.15 * sin(anim_t * 4.0)))
	for pk in pickups:
		var p: Vector2 = pk["pos"]
		l.glow(p, 16.0, Color(1.0, 0.85, 0.4) * (0.5 + 0.2 * sin(anim_t * 5.0 + p.x)))

func _camera_shaders(rdt: float) -> void:
	if player != null and not possess and is_instance_valid(player):
		cam.look = ((player.i_aim_pt - player.global_position) * 0.18).limit_length(52.0)
	else:
		cam.look = cam.look.lerp(Vector2.ZERO, 0.1)
	blizzard = move_toward(blizzard, blizzard_target, rdt * 0.3)
	atmos.blizzard = blizzard
	atmos.hurt = hurt
	atmos.ink_target = 1.0 if possess else 0.0
	if debug_day < 0.0 and not ended:
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
