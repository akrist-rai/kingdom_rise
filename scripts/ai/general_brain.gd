class_name GeneralBrain
extends AIBrain
## Boss AI for the enemy general. Three phases:
##  1) glaive combos, a red (unblockable) lunge and a red double spin
##  2) at 60% HP: summons elite guards, adds a ground shockwave at range
##  3) at 30% HP: "Wrath" - faster windups, longer combos, Black Tempest spin and archer volleys

var phase := 1
var pattern_cd := 1.2
var volley_cd := 6.0
var blades_cd := 3.0

func think(u: Unit, delta: float) -> void:
	u.i_move = Vector2.ZERO
	u.i_guard = false
	atk_cd -= delta
	pattern_cd -= delta
	guard_t -= delta
	strafe_t -= delta
	volley_cd -= delta
	blades_cd -= delta
	var b = u.battle
	if strafe_t <= 0.0:
		strafe_t = randf_range(1.0, 2.2)
		strafe = -strafe
	var frac := u.hp / u.max_hp
	if phase == 1 and frac <= 0.6:
		phase = 2
		b.on_boss_phase(2)
	elif phase == 2 and frac <= 0.3:
		phase = 3
		b.on_boss_phase(3)
	var p = b.player
	if p == null or not is_instance_valid(p) or p.dead or not b.player_targetable():
		target = null
		if b.duel:
			var tc: Vector2 = b.duel_center - u.global_position
			if tc.length() > 20.0:
				u.i_move = tc.normalized() * 0.5
		return
	target = p
	var tp: Vector2 = p.global_position
	var to := tp - u.global_position
	var d := to.length()
	_aim_at(u, tp)
	if not b.duel:
		u.speed_mult = 1.7
		if d > 150.0:
			u.i_move = to.normalized()
			return
	else:
		u.speed_mult = 1.0 + (phase - 1) * 0.12
	# continue combos
	if u.state == Unit.St.ATTACK:
		if combo_left > 0 and u.mv_kind == "light" and u.mv_phase == 2 and u.mv_t > 0.04:
			combo_left -= 1
			u.do_light()
		return
	if u.state != Unit.St.IDLE and u.state != Unit.St.GUARD:
		return
	if phase == 3 and blades_cd <= 0.0:
		blades_cd = randf_range(9.0, 12.0)
		volley_cd = maxf(volley_cd, 4.0)
		b.heaven_blades(u, p)
	elif phase == 3 and volley_cd <= 0.0:
		volley_cd = randf_range(9.0, 13.0)
		b.enemy_volley(tp, 70.0, 26)
	# react to the player's attacks (block / parry)
	if p.state == Unit.St.ATTACK and p.attack_id != react_id and d < p.weapon.reach + 40.0:
		react_id = p.attack_id
		var r := randf()
		if r < 0.1 + phase * 0.04:
			u.open_parry()
			guard_t = 0.35
		elif r < 0.3:
			guard_t = 0.45
	if guard_t > 0.0:
		u.i_guard = true
		if u.state == Unit.St.IDLE:
			u.enter_guard()
		return
	if pattern_cd > 0.0:
		var want := 70.0
		var radial := clampf((d - want) / 40.0, -1.0, 1.0)
		u.i_move = (to.normalized() * radial + to.normalized().orthogonal() * strafe * 0.55).limit_length(1.0)
		return
	var reach := u.weapon.reach * 1.25
	var r2 := randf()
	if d > 150.0:
		if phase >= 2 and r2 < 0.35:
			Skills.start_forced(u, "earthsplitter")
		elif r2 < 0.75:
			u.start_move(u.weapon.dash_atk, "dash")
		else:
			u.i_move = to.normalized()
			pattern_cd = 0.4
			return
	elif d <= reach + 12.0:
		if phase == 3 and r2 < 0.22:
			Skills.start_forced(u, "tempest")
		elif r2 < 0.24:
			u.do_heavy()
		else:
			u.combo = 0
			u.do_light()
			combo_left = 1 + (1 if phase >= 2 else 0) + (1 if phase >= 3 and randf() < 0.5 else 0)
	else:
		if r2 < 0.3:
			u.start_move(u.weapon.dash_atk, "dash")
		else:
			u.i_move = to.normalized()
			pattern_cd = 0.25
			return
	pattern_cd = maxf(0.25, randf_range(0.6, 1.2) - phase * 0.12)
