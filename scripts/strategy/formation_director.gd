class_name FormationDirector
extends Node2D
## Regiments retain ranks until contact. Cohesion, direction and formation affect combat.
## World units are shared with the existing combat and navigation systems.
const FORMS = ["LINE", "WEDGE", "SQUARE"]
const INK = Color("#263c3b")
const GOLD = Color("#f8df9a")
var battle
var regiments: Array = []
var formation = 0
var face_dir = Vector2.UP
var tick = 0.0
var command_t = 0.0
var pressure_t = 0.0
var preview = Vector2.ZERO
var density = 1
var objectives: Array = []
var initialized = false
var tests = false
var test_step = 0
var stats = {"orders": 0, "captures": 0, "formation_changes": 0}

func setup(b) -> void:
	battle = b
	initialized = true
	if b.level_ctl != null:
		face_dir = Vector2.UP
		objectives = [
			{"p": Vector2(570, 2200), "name": "WEST ORCHARD", "v": 0.0, "owner": -1},
			{"p": Vector2(1100, 2200), "name": "RAM ROAD", "v": 0.0, "owner": -1},
			{"p": Vector2(1660, 2200), "name": "EAST FIELDS", "v": 0.0, "owner": -1}]
	else:
		face_dir = Vector2.RIGHT
		objectives = [
			{"p": Vector2(1400, 260), "name": "NORTH RIDGE", "v": 0.0, "owner": -1},
			{"p": Vector2(1600, 520), "name": "KING'S ROAD", "v": 0.0, "owner": -1},
			{"p": Vector2(1480, 790), "name": "SOUTH MEADOW", "v": 0.0, "owner": -1}]
	for u in b.units:
		enlist(u)
	tests = OS.get_cmdline_user_args().has("--tactics-test")
	if OS.get_cmdline_user_args().has("--command"):
		Game.command_view = true
	_update_regiments(0.25)

func enlist(u) -> void:
	if not initialized or u.is_player or u.is_boss or u.is_officer or u.in_squad:
		return
	var chosen = -1
	var ranged = u.weapon.ranged
	for i in regiments.size():
		var r = regiments[i]
		if r["f"] == u.faction and r["ranged"] == ranged and r["men"].size() < (12 if ranged else 24) and u.position.distance_to(r["at"]) < 260.0:
			chosen = i
			break
	if chosen < 0:
		chosen = regiments.size()
		regiments.append({"f": u.faction, "ranged": ranged, "men": [], "at": u.position,
			"dir": Vector2.UP if u.faction == 0 else Vector2.DOWN, "cohesion": 1.0, "form": 0})
	u.regiment = chosen
	regiments[chosen]["men"].append(u)

func _unhandled_input(event: InputEvent) -> void:
	if battle == null or battle.ended or battle.possess or battle.duel or battle.hud.pause_open or battle.hud.perk_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_TAB:
				Game.command_view = not Game.command_view
				battle.cam.command_pan = Vector2.ZERO
				command_t = 3.0
				get_viewport().set_input_as_handled()
			KEY_Q:
				set_formation((formation + 1) % 3)
			KEY_4: set_formation(0)
			KEY_5: set_formation(1)
			KEY_6: set_formation(2)
			KEY_F6:
				density = (density + 1) % 3
				_apply_density()
	if event is InputEventMouseButton and event.pressed:
		if Game.command_view and event.button_index == MOUSE_BUTTON_LEFT:
			var mouse = get_viewport().get_mouse_position()
			for i in 3:
				if Rect2(185+i*94,269,90,52).has_point(mouse):
					set_formation(i)
			get_viewport().set_input_as_handled()
		if Game.command_view and event.button_index == MOUSE_BUTTON_RIGHT:
			issue_move(get_global_mouse_position())
			get_viewport().set_input_as_handled()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			battle.cam.manual_zoom = clampf(battle.cam.manual_zoom + 0.08, -0.18, 0.6)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			battle.cam.manual_zoom = clampf(battle.cam.manual_zoom - 0.08, -0.18, 0.6)

func _exit_tree() -> void:
	Game.command_view = false

func _apply_density() -> void:
	var limits = [[90, 130], [150, 230], [220, 340]][density]
	battle.caps = limits.duplicate()
	for faction in 2:
		var pool = battle.units.filter(func(u): return u.faction == faction and not u.is_player and not u.in_squad and not u.is_boss and not u.is_officer)
		var center = battle.player.position
		pool.sort_custom(func(a,b): return a.position.distance_squared_to(center) > b.position.distance_squared_to(center))
		var excess = maxi(0, battle.alive[faction] - limits[faction])
		for i in mini(excess, pool.size()):
			battle.retire(pool[i])
			battle.reserves[faction] += 1
	battle._rebuild_grid()
	battle.hud.alert("ARMY DENSITY  /  " + ["STANDARD", "WAR", "EPIC"][density], GOLD)

func set_formation(id: int) -> void:
	formation = id
	stats["formation_changes"] += 1
	command_t = 3.5
	Sfx.play("drum", -9.0)
	battle.hud.alert(FORMS[id] + " FORMATION", GOLD)
	for u in battle.squad:
		if is_instance_valid(u):
			u.formation_bonus = 0.0

func issue_move(pt: Vector2) -> void:
	if battle.player == null:
		return
	pt.x = clampf(pt.x, 45.0, Battle.W - 45.0)
	pt.y = clampf(pt.y, Battle.TOP + 10.0, Battle.BOT - 10.0)
	if battle.terrain != null:
		pt = battle.terrain.push_out(pt, 12.0)
	var origin = battle.player.global_position
	if pt.distance_to(origin) > 12.0:
		face_dir = (pt - origin).normalized()
	battle._set_order("charge", pt)
	stats["orders"] += 1
	command_t = 4.0

func _process(delta: float) -> void:
	if not initialized or get_tree().paused:
		return
	var _f0 := Time.get_ticks_usec()
	command_t = maxf(0.0, command_t - delta)
	if battle.ended or battle.possess:
		Game.command_view = false
	preview = get_global_mouse_position()
	tick -= delta
	if tick <= 0.0:
		tick = 0.3
		_update_regiments(0.3)
		_update_objectives(0.3)
		_update_squad()
	if tests:
		_test_commands()
	queue_redraw()
	Prof.add("formdir", Time.get_ticks_usec() - _f0)

func _test_commands() -> void:
	if battle.time > 0.8 and test_step == 0:
		set_formation(1)
		issue_move(battle.player.position + Vector2(30, -90))
		assert(battle.squad_order == "charge", "Move order was not applied")
		assert(formation == 1, "Wedge selection failed")
		test_step = 1
	elif battle.time > 1.6 and test_step == 1:
		set_formation(2)
		battle._set_order("hold", battle.player.position)
		assert(battle.squad_order == "hold", "Hold order was not applied")
		assert(formation == 2, "Square selection failed")
		test_step = 2
	elif battle.time > 2.4 and test_step == 2:
		set_formation(0)
		battle._set_order("follow", battle.player.position)
		assert(battle.squad_order == "follow", "Follow order was not applied")
		assert(battle.squad.size() > 0, "No soldiers recruited")
		for u in battle.squad:
			assert(squad_goal(u).is_finite(), "Invalid formation slot")
		Game.command_view = true
		assert(not battle.input_locked(), "Command view unexpectedly locks orders")
		Game.command_view = false
		var strength = [battle.army_strength(0), battle.army_strength(1)]
		density = 0
		_apply_density()
		assert(battle.alive[0] <= 90 and battle.alive[1] <= 130, "Standard density cap not applied")
		assert(battle.army_strength(0) == strength[0] and battle.army_strength(1) == strength[1], "Density changes lost reserve strength")
		density = 1
		_apply_density()
		test_step = 3
		print("[tactics-test] PASS: line / wedge / square, move / hold / follow; squad=", battle.squad.size(), " regiments=", regiments.size())

func _update_regiments(dt: float) -> void:
	for r in regiments:
		r["men"] = r["men"].filter(func(u): return is_instance_valid(u) and not u.dead and not u.is_player and not u.in_squad)
		var men: Array = r["men"]
		if men.is_empty():
			continue
		var center = Vector2.ZERO
		for u in men:
			center += u.global_position
		center /= men.size()
		var leader = men[0]
		var goal: Vector2 = battle.march_goal(leader)
		if goal == Vector2.INF:
			goal = Vector2(battle.front_x, center.y)
		var defender = r["f"] == 1 and battle.level_ctl != null
		if defender and leader.brain is AIBrain and leader.brain.post != Vector2.INF:
			goal = leader.brain.post
		elif defender and battle.level_ctl.phase == 1 and center.y > SiegeLevel.GROUND_Y:
			goal = r["at"]
			if battle.player != null and center.distance_to(battle.player.position) < 460.0:
				goal = battle.player.position
		var to = goal - r["at"]
		if to.length() > 12.0:
			r["dir"] = r["dir"].lerp(to.normalized(), 0.18).normalized()
			# A company never outruns its rear ranks.
			r["at"] = r["at"].move_toward(goal, dt * (36.0 if r["ranged"] else 49.0))
			if r["at"].distance_to(center) > 150.0:
				r["at"] = r["at"].lerp(center + r["dir"] * 20.0, 0.12)
		var good = 0
		for i in men.size():
			var u = men[i]
			u.regiment_slot = i
			if u.position.distance_to(regiment_goal(u)) < 52.0:
				good += 1
		r["cohesion"] = float(good) / maxf(1.0, men.size())
		for u in men:
			u.formation_bonus = 0.16 * r["cohesion"] if not u.weapon.ranged else 0.0
			u.formation_dir = r["dir"]

func regiment_goal(u) -> Vector2:
	if u.regiment < 0 or u.regiment >= regiments.size():
		return Vector2.INF
	var r = regiments[u.regiment]
	var at: Vector2 = r["at"]
	var d: Vector2 = r["dir"]
	var i: int = u.regiment_slot
	var cols = 6 if r["ranged"] else 8
	var side = (i % cols - (cols - 1) * 0.5) * 17.0
	var back = floorf(float(i) / cols) * 21.0
	return at + d.orthogonal() * side - d * back

func squad_goal(u) -> Vector2:
	if battle.player == null:
		return u.position
	var b = battle
	var d = face_dir
	var anchor = b.squad_pt
	if b.squad_order == "follow":
		d = b.player.aim
		anchor = b.player.position - d * 32.0
	var i: int = u.brain.slot
	var n: int = maxi(1, b.squad.size())
	var side = d.orthogonal()
	match formation:
		1:
			var row = ceili((i + 1) / 2.0)
			return anchor - d * row * 20.0 + side * row * (14.0 if i % 2 == 0 else -14.0)
		2:
			var count = maxi(3, ceili(n / 4.0))
			var edge = mini(3, i / count)
			var along = (i % count - count * 0.5) * 17.0
			var radius = count * 8.5
			var local = [Vector2(along, -radius), Vector2(radius, along), Vector2(-along, radius), Vector2(-radius, -along)][edge]
			return anchor + side * local.x + d * local.y
		_:
			var columns = mini(8, n)
			return anchor + side * ((i % columns) - (columns - 1) * 0.5) * 17.0 - d * floorf(float(i) / columns) * 22.0

func _update_squad() -> void:
	if battle.player == null or not is_instance_valid(battle.player) or battle.player.dead:
		return
	var close = 0
	for u in battle.squad:
		if u.position.distance_to(squad_goal(u)) < 42.0:
			close += 1
	var cohesion = float(close) / maxf(1.0, battle.squad.size())
	for u in battle.squad:
		u.formation_bonus = cohesion * (0.35 if formation == 2 else 0.25 if formation == 0 else 0.08)
		u.formation_dir = face_dir if battle.squad_order != "follow" else battle.player.aim
		if formation == 2:
			var anchor = battle.squad_pt if battle.squad_order != "follow" else battle.player.position - battle.player.aim * 32.0
			u.formation_dir = (squad_goal(u) - anchor).normalized()
		u.formation_attack = 1.0 + (0.22 * cohesion if formation == 1 and battle.squad_order == "charge" else 0.0)

func _update_objectives(dt: float) -> void:
	if battle.duel or battle.ended:
		return
	for ob in objectives:
		var pressure = 0
		for u in battle.query(ob["p"], 90.0):
			if not u.dead and u.position.distance_to(ob["p"]) < 90.0:
				pressure += 1 if u.faction == 0 else -1
		if pressure != 0:
			ob["v"] = clampf(ob["v"] + signf(pressure) * dt * minf(absf(pressure) / 3.0, 1.0) / 12.0, -1.0, 1.0)
		var owner = 0 if ob["v"] >= 1.0 else 1 if ob["v"] <= -1.0 else ob["owner"]
		if owner != ob["owner"]:
			ob["owner"] = owner
			stats["captures"] += 1
			battle.hud.alert(str(ob["name"]) + (" SECURED" if owner == 0 else " LOST"), GOLD)
			battle.morale[owner] = minf(100.0, battle.morale[owner] + 3.0)
	pressure_t += dt
	if pressure_t >= 8.0:
		pressure_t = 0.0
		for ob in objectives:
			if ob["owner"] >= 0:
				var losing = 1 - int(ob["owner"])
				battle.morale[losing] = maxf(0.0, battle.morale[losing] - 0.65)
				battle.reserves[losing] = maxi(0, battle.reserves[losing] - 2)

func _draw() -> void:
	var _d0 := Time.get_ticks_usec()
	_draw_impl()
	Prof.add("formdir.draw", Time.get_ticks_usec() - _d0)

func _draw_impl() -> void:
	if not initialized:
		return
	for ob in objectives:
		var p: Vector2 = ob["p"]
		var c = Color("#a64639") if ob["owner"] == 0 else Color("#39646a") if ob["owner"] == 1 else GOLD
		draw_arc(p, 42, 0, TAU, 48, Color(c, 0.22), 1.0, true)
		draw_line(p, p + Vector2(0, -38), INK, 2.0, true)
		var wave = sin(Time.get_ticks_msec() * 0.002 + p.x) * 2.0
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -38), p + Vector2(23, -35 + wave), p + Vector2(19, -22 + wave), p + Vector2(0, -25)]), c)
		if absf(ob["v"]) > 0.01:
			draw_arc(p, 45, -PI / 2, -PI / 2 + TAU * absf(ob["v"]), 42, c, 2.0, true)
	if battle.player == null or battle.ended or battle.duel:
		return
	if Game.command_view:
		for r in regiments:
			if r["men"].is_empty():
				continue
			var c = Color("#edc982") if r["f"] == 0 else Color("#7facb3")
			var at: Vector2 = r["at"]
			draw_arc(at, 19, 0, TAU, 24, Color(c, 0.75), 1.2, true)
			draw_line(at, at + r["dir"] * 32, c, 1.6, true)
	if not Game.command_view and command_t <= 0:
		return
	var col = Color(GOLD, 0.65 if Game.command_view else command_t * 0.15)
	for u in battle.squad:
		if not is_instance_valid(u):
			continue
		var pt = squad_goal(u)
		draw_arc(pt, 5, 0, TAU, 12, col, 0.8, true)
	if Game.command_view:
		draw_dashed_line(battle.player.position, preview, Color(GOLD, 0.55), 1.0, 8.0, true)
		draw_arc(preview, 22.0, 0, TAU, 32, col, 1.0, true)
