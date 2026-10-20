class_name Skills
extends RefCounted
## Weapon skills (Elden Ring calls these "Ashes of War"). Each costs Spirit.

static func start(u: Unit) -> bool:
	var w := u.weapon
	if w.skill == "":
		return false
	if u.spirit < w.skill_cost:
		if u.is_player:
			u.battle.fx.text(u.global_position + Vector2(0, -30), "NEED SPIRIT", Color("#8fb6ff"))
			Sfx.play("ui", -8.0, 0.5)
		return false
	u.spirit -= w.skill_cost
	_begin(u, w.skill, w.skill_name)
	return true

## Used by the boss to use skills that are not tied to its weapon or Spirit.
static func start_forced(u: Unit, id: String) -> void:
	_begin(u, id, "")

static func _begin(u: Unit, id: String, label: String) -> void:
	u.state = Unit.St.SKILL
	u.st_t = 0.0
	u.skill_id = id
	u.sk = {"move": 0.0, "dur": 0.6}
	u.skill_hit.clear()
	u.hyper = false
	u.charging = false
	if u.is_player:
		u._face_aim()
	Sfx.play_at("skill", u.global_position, -2.0 if u.is_player else -5.0)
	u.battle.fx.skill_flash(u)
	if u.is_player:
		u.battle.hud.skill_callout(label)
		Game.add_style("skill_" + id, 30.0, "", Color.WHITE)
	match u.skill_id:
		"gale_slash":
			u.sk["dur"] = 0.36
		"tempest":
			u.sk["dur"] = 1.35 if u.is_boss else 1.0
			u.sk["move"] = 0.75 if u.is_boss else 0.55
			u.sk["tick"] = -1
			u.hyper = true
		"piercing_charge":
			u.sk["dur"] = 0.6
			u.hyper = true
		"blade_dance":
			u.sk["dur"] = 0.9
			u.sk["move"] = 0.7
			u.sk["tick"] = -1
		"earthsplitter":
			u.sk["dur"] = 0.8
			u.hyper = true
		"horse_cleaver":
			u.sk["dur"] = 0.6
			u.hyper = true
		"bulwark_rush":
			u.sk["dur"] = 0.55
			u.sk["tick"] = -1
			u.sk["armored"] = true
			u.hyper = true
		"arrow_rain":
			u.sk["dur"] = 0.55
		"bolt_storm":
			u.sk["dur"] = 0.45
		"quake":
			u.sk["dur"] = 0.85
			u.hyper = true

static func _once(u: Unit, key: String) -> bool:
	if u.sk.has(key):
		return false
	u.sk[key] = true
	return true

static func update(u: Unit, delta: float) -> void:
	u.st_t += delta
	var t := u.st_t
	var dur: float = u.sk.get("dur", 0.6)
	var b = u.battle
	match u.skill_id:
		"gale_slash":
			if t < 0.06:
				u._set_wangle(deg_to_rad(-130.0))
			elif t < 0.22:
				if _once(u, "go"):
					u.sk["p0"] = u.global_position
					u.invuln = maxf(u.invuln, 0.2)
					Sfx.play_at("swing_heavy", u.global_position, -2.0, 1.3)
				u.vel = u.aim * 760.0
				u._set_wangle(deg_to_rad(lerpf(-130.0, 85.0, (t - 0.06) / 0.16)))
				_line_hits(u, u.sk["p0"], u.global_position, 16.0, 1.75, {"pz": 40.0, "st": 28.0, "kb": 90.0})
				b.fx.afterimage(u)
			elif _once(u, "trail"):
				b.fx.line_slash(u.sk["p0"] + Vector2(0, -10), u.global_position + Vector2(0, -10), Color(0.85, 0.95, 1.0))
		"tempest":
			var spins := 4.0 if u.is_boss else 3.0
			u._set_wangle(t / dur * TAU * spins)
			var tick := int(t / 0.2)
			if tick != int(u.sk["tick"]):
				u.sk["tick"] = tick
				u.skill_hit.clear()
				var rr := u.weapon.reach * (1.35 if u.is_boss else 1.1)
				b.fx.spin(u, rr)
				Sfx.play_at("swing_heavy", u.global_position, -4.0, 1.1)
			var r := u.weapon.reach * (1.35 if u.is_boss else 1.1)
			_circle_hits(u, r, 0.75, {"pz": 30.0, "st": 18.0, "kb": 110.0, "perilous": u.is_boss})
			if not u.is_player and u.brain and u.brain.target and is_instance_valid(u.brain.target):
				u.i_move = (u.brain.target.global_position - u.global_position).normalized()
		"piercing_charge":
			if t < 0.14:
				u._set_wangle(deg_to_rad(10.0))
			elif t < 0.4:
				if _once(u, "go"):
					u.sk["p0"] = u.global_position
					Sfx.play_at("swing_heavy", u.global_position, -2.0, 0.9)
				u.vel = u.aim * 720.0
				u._set_wangle(0.0)
				_line_hits(u, u.sk["p0"], u.global_position, 12.0, 1.6, {"pz": 50.0, "st": 30.0, "kb": 160.0})
				b.fx.afterimage(u)
			elif _once(u, "trail"):
				b.fx.line_slash(u.sk["p0"] + Vector2(0, -12), u.global_position + Vector2(0, -12), Color(1.0, 0.85, 0.6))
		"blade_dance":
			if t < 0.45:
				u.invuln = maxf(u.invuln, 0.05)
			u._set_wangle(t * 32.0)
			var tick := int(t / 0.1)
			if tick != int(u.sk["tick"]):
				u.sk["tick"] = tick
				u.skill_hit.clear()
				b.fx.spin(u, 40.0)
				Sfx.play_at("swing_fast", u.global_position, -5.0, 1.2)
			_circle_hits(u, 40.0, 0.55, {"pz": 10.0, "st": 8.0, "kb": 30.0, "bleed": 22.0})
		"earthsplitter":
			if t < 0.38:
				u._set_wangle(deg_to_rad(lerpf(30.0, -150.0, t / 0.38)))
			elif _once(u, "slam"):
				u._set_wangle(deg_to_rad(40.0))
				var h := u.make_hit({"dmg": 1.9, "pz": 70.0, "st": 50.0, "kb": 150.0})
				h["skill"] = true
				h["knockdown"] = true
				b.proj.shock(u, u.global_position + u.aim * 14.0, u.aim, 560.0, 270.0, h)
				b.cam_shake(7.0)
				Sfx.play_at("boom", u.global_position, -1.0)
				b.fx.ring(u.global_position, 26.0, Color(0.9, 0.95, 1.0, 0.9), 0.3)
		"horse_cleaver":
			if t < 0.26:
				u._set_wangle(deg_to_rad(lerpf(30.0, -130.0, t / 0.26)))
			elif _once(u, "cut"):
				u._set_wangle(deg_to_rad(90.0))
				var h := u.make_hit({"dmg": 1.7, "pz": 50.0, "st": 35.0, "kb": 140.0})
				h["skill"] = true
				b.proj.wave(u, u.global_position + Vector2(0, -10) + u.aim * 12.0, u.aim, 430.0, 240.0, h)
				Sfx.play_at("swing_heavy", u.global_position, 0.0, 0.8)
				b.cam_shake(4.0)
		"bulwark_rush":
			if t < 0.38:
				u.vel = u.aim * 520.0
				var tick := int(t / 0.1)
				if tick != int(u.sk["tick"]):
					u.sk["tick"] = tick
					u.skill_hit.clear()
				_arc_hits(u, 26.0, 70.0, 0.6, {"pz": 50.0, "st": 32.0, "kb": 230.0})
				b.fx.afterimage(u)
			else:
				u.sk.erase("armored")
		"arrow_rain":
			u._set_wangle(deg_to_rad(-70.0))
			if t >= 0.3 and _once(u, "fire"):
				var target := u.i_aim_pt
				if target.distance_to(u.global_position) > 320.0:
					target = u.global_position + (target - u.global_position).normalized() * 320.0
				var h := u.make_hit({"dmg": 1.0, "pz": 20.0, "st": 12.0, "kb": 40.0})
				h["skill"] = true
				b.proj.rain(u, target, 64.0, 28, 0.45, h)
				Sfx.play_at("volley", u.global_position, -2.0)
		"bolt_storm":
			if t >= 0.15 and _once(u, "fire"):
				for i in 13:
					var d := u.aim.rotated(lerpf(-0.9, 0.9, i / 12.0))
					var h := u.make_hit({"dmg": 1.0, "pz": 12.0, "st": 8.0, "kb": 40.0})
					h["skill"] = true
					b.proj.shoot(u, u.global_position + Vector2(0, -12), d, 560.0, h, "bolt", 1)
				Sfx.play_at("bow", u.global_position, 0.0, 1.4)
				b.cam_shake(3.0)
		"quake":
			if t < 0.42:
				u._set_wangle(deg_to_rad(lerpf(20.0, -160.0, t / 0.42)))
			elif _once(u, "slam"):
				u._set_wangle(deg_to_rad(50.0))
				_circle_hits(u, 95.0, 1.6, {"pz": 80.0, "st": 60.0, "kb": 200.0, "knockdown": true})
				b.fx.ring(u.global_position, 95.0, Color(0.95, 0.95, 1.0, 0.9), 0.45)
				b.fx.ring(u.global_position, 60.0, Color(1.0, 0.8, 0.5, 0.8), 0.35)
				b.fx.debris(u.global_position, 95.0)
				b.cam_shake(9.0)
				Sfx.play_at("boom", u.global_position, 0.0)
	if t >= dur:
		u.state = Unit.St.IDLE
		u.hyper = false
		u.sk.erase("armored")

static func _hit(u: Unit, e, mult: float, extra: Dictionary) -> void:
	var h := u.make_hit({"dmg": mult, "pz": extra.get("pz", 20.0), "st": extra.get("st", 15.0), "kb": extra.get("kb", 60.0)})
	h["skill"] = true
	if extra.has("bleed"):
		h["bleed"] = float(h["bleed"]) + float(extra["bleed"])
	if extra.get("knockdown", false):
		h["knockdown"] = true
	if extra.get("perilous", false):
		h["perilous"] = true
	e.take_hit(u, h)

static func _circle_hits(u: Unit, r: float, mult: float, extra: Dictionary) -> void:
	for e in u.battle.query(u.global_position, r + 12.0):
		if e == u or e.dead or e.faction == u.faction or u.skill_hit.has(e):
			continue
		if e.global_position.distance_to(u.global_position) <= r + e.radius:
			u.skill_hit[e] = true
			_hit(u, e, mult, extra)

static func _arc_hits(u: Unit, r: float, half_deg: float, mult: float, extra: Dictionary) -> void:
	for e in u.battle.query(u.global_position, r + 12.0):
		if e == u or e.dead or e.faction == u.faction or u.skill_hit.has(e):
			continue
		var to: Vector2 = e.global_position - u.global_position
		if to.length() <= r + e.radius and absf(angle_difference(u.aim.angle(), to.angle())) <= deg_to_rad(half_deg):
			u.skill_hit[e] = true
			_hit(u, e, mult, extra)

static func _line_hits(u: Unit, a: Vector2, b: Vector2, width: float, mult: float, extra: Dictionary) -> void:
	var mid := (a + b) * 0.5
	var r := a.distance_to(b) * 0.5 + width + 12.0
	for e in u.battle.query(mid, r):
		if e == u or e.dead or e.faction == u.faction or u.skill_hit.has(e):
			continue
		var p: Vector2 = e.global_position
		var cp := Geometry2D.get_closest_point_to_segment(p, a, b)
		if cp.distance_to(p) <= width + e.radius:
			u.skill_hit[e] = true
			_hit(u, e, mult, extra)
