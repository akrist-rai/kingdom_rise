class_name AIBrain
extends RefCounted
## Battlefield AI for soldiers on both sides. Roles: melee, archer, cavalry, officer.
## Uses an "attack token" system so only a few enemies attack the player at once
## (others circle and wait), which keeps big fights readable and fair.

var role := "melee"
var target: Unit = null
var think_t := 0.0
var atk_cd := 0.5
var strafe := 1.0
var strafe_t := 0.0
var lane_y := 0.0
var react_id := -1
var guard_t := 0.0
var combo_left := 0
var token := false
var attack_committed := false
var spectate := false
var ring_pos := Vector2.ZERO
var rout := false
var charge_dir := Vector2.ZERO
var charge_t := 0.0
var leader: Unit = null
var slot := 0
var order := "follow"
var order_pt := Vector2.ZERO
var dodge_cd := 0.0
var skill_cd := 6.0
var post := Vector2.INF      # a garrison point to hold (wall defenders, palace guards)
var post_r := 0.0            # how far from it they'll go to fight

func setup(u: Unit) -> void:
	lane_y = u.position.y
	strafe = 1.0 if randf() < 0.5 else -1.0
	atk_cd = randf_range(0.3, 1.5)
	match u.kind:
		"archer":
			role = "archer"
		"cavalry":
			role = "cavalry"
		"officer", "general":
			role = "officer"
		_:
			role = "melee"

func think(u: Unit, delta: float) -> void:
	var _b0 := Time.get_ticks_usec()
	_think(u, delta)
	Prof.add("ai." + role, Time.get_ticks_usec() - _b0)

func _think(u: Unit, delta: float) -> void:
	u.i_move = Vector2.ZERO
	u.i_guard = false
	u.i_goal = Vector2.INF
	atk_cd -= delta
	think_t -= delta
	guard_t -= delta
	strafe_t -= delta
	dodge_cd -= delta
	skill_cd -= delta
	var b = u.battle
	if spectate:
		_spectate(u)
		return
	if rout:
		var rd: Vector2 = b.rout_dir(u.faction)
		u.i_move = rd + (Vector2(0.0, (lane_y - u.position.y) * 0.01) if absf(rd.x) > 0.5 else Vector2.ZERO)
		u.i_aim = u.i_move.normalized()
		u.i_goal = u.global_position + rd * 400.0
		var p := u.position
		if (rd.x < -0.5 and p.x < 30.0) or (rd.x > 0.5 and p.x > Battle.W - 30.0) or (rd.y > 0.5 and p.y > Battle.BOT - 8.0) or (rd.y < -0.5 and p.y < Battle.TOP + 8.0):
			b.retire(u)
		return
	if think_t <= 0.0:
		think_t = randf_range(0.25, 0.5)
		# engaged soldiers keep their opponent and look around less often
		if target != null and is_instance_valid(target) and not target.dead and not target.spectator and u.global_position.distance_squared_to(target.global_position) < 4900.0 and not u.in_squad:
			think_t = randf_range(0.7, 1.1)
		else:
			var _r0 := Time.get_ticks_usec()
			_retarget(u)
			Prof.add("ai.retarget", Time.get_ticks_usec() - _r0)
		if strafe_t <= 0.0:
			strafe_t = randf_range(1.0, 2.5)
			strafe = -strafe
	if target != null and (not is_instance_valid(target) or target.dead or target.spectator):
		target = null
		_release(u)
	match role:
		"archer":
			_archer(u, delta)
		"cavalry":
			_cavalry(u, delta)
		_:
			_melee(u, delta)

func _release(u: Unit) -> void:
	if token:
		token = false
		u.battle.release_token(u)

func _retarget(u: Unit) -> void:
	var b = u.battle
	var center := u.global_position
	var r := 165.0
	if role == "archer":
		r = 340.0
	elif role == "cavalry":
		r = 160.0
	elif role == "officer":
		r = 320.0
	if u.in_squad and leader != null and is_instance_valid(leader):
		if order == "hold":
			center = order_pt
			r = 75.0
		elif order == "charge":
			center = order_pt
			r = 115.0
		else:
			center = leader.global_position
			r = 110.0
	elif post != Vector2.INF:
		if role != "archer":
			center = post
			r = post_r + 110.0
	var best: Unit = null
	var bd := INF
	for e in b.query(center, r):
		if e.faction == u.faction or e.dead or e.spectator:
			continue
		if e.is_player and not b.player_targetable():
			continue
		if role != "archer" and b.level_ctl != null and not b.level_ctl.reachable(u, e):
			continue
		var d: float = u.global_position.distance_squared_to(e.global_position)
		if e.is_player:
			d *= 0.35 if role == "officer" else 0.75
		if d < bd:
			bd = d
			best = e
	if best != target:
		_release(u)
	target = best

func _aim_at(u: Unit, p: Vector2) -> void:
	var to := p - u.global_position
	if to.length_squared() > 1.0:
		u.i_aim = to.normalized()

func _march(u: Unit) -> void:
	var b = u.battle
	if u.in_squad and leader != null and is_instance_valid(leader) and not leader.dead:
		var goal: Vector2 = b.tactics.squad_goal(u) if b.tactics != null else leader.position + Vector2((slot % 4) * 17.0, (slot / 4) * 20.0)
		var to := goal - u.global_position
		u.i_goal = goal
		if to.length() > 8.0:
			u.i_move = to.normalized() * clampf(to.length() / 40.0, 0.3, 1.0)
			_aim_at(u, goal)
		else:
			u.i_aim = u.formation_dir if b.tactics != null and b.tactics.formation == 2 else leader.aim
		return
	if b.tactics != null and u.regiment >= 0 and post == Vector2.INF:
		var goal: Vector2 = b.tactics.regiment_goal(u)
		if goal != Vector2.INF:
			u.i_goal = goal
			var to: Vector2 = goal - u.global_position
			u.i_move = to.normalized() * clampf(to.length() / 32.0, 0.0, 0.85) if to.length() > 5.0 else Vector2.ZERO
			u.i_aim = b.tactics.regiments[u.regiment]["dir"]
			return
	if post != Vector2.INF:
		var tp := post - u.global_position
		u.i_goal = post
		if tp.length() > 6.0:
			u.i_move = tp.normalized() * clampf(tp.length() / 30.0, 0.3, 1.0)
			_aim_at(u, post)
		else:
			u.i_aim = Vector2(-1.0 if u.faction == 1 else 1.0, 0.0)
		return
	var dir_x := 1.0 if u.faction == 0 else -1.0
	var hold_x: float = b.front_x - dir_x * (110.0 if role == "archer" else 10.0)
	var dx := hold_x - u.global_position.x
	var mx := 0.0
	if dx * dir_x > 0.0:
		mx = dir_x
	else:
		mx = dir_x * 0.25
	u.i_move = Vector2(mx, clampf((lane_y - u.position.y) * 0.02, -0.6, 0.6)) * 0.7
	u.i_aim = Vector2(dir_x, 0.0)
	u.i_goal = Vector2(hold_x, lane_y) if dx * dir_x > 0.0 else Vector2.INF
	var mg: Vector2 = b.march_goal(u)
	if mg != Vector2.INF:
		u.i_goal = mg
		var to_g := mg - u.global_position
		u.i_move = to_g.normalized() * (0.75 if to_g.length() > 20.0 else 0.0)

func _melee(u: Unit, delta: float) -> void:
	var b = u.battle
	if target == null:
		_march(u)
		return
	# Square and line keep their ranks under pressure; wedge can pursue farther.
	if u.in_squad and b.tactics != null:
		var station: Vector2 = b.tactics.squad_goal(u)
		var leash: float = 145.0 if b.tactics.formation == 1 and order == "charge" else 78.0
		if target.global_position.distance_to(station) > leash:
			target = null
			_release(u)
			_march(u)
			return
	if not u.in_squad and u.regiment >= 0 and b.tactics != null and post == Vector2.INF:
		var station: Vector2 = b.tactics.regiment_goal(u)
		if target.position.distance_to(station) > 150.0:
			target = null
			_release(u)
			_march(u)
			return
	var tp := target.global_position
	var to := tp - u.global_position
	var d := to.length()
	_aim_at(u, tp)
	u.i_goal = tp
	var reach := u.weapon.reach * (1.25 if u.is_boss else 1.0)
	var rng := reach * 0.8 + target.radius
	# Leash squad members to their leader, and garrison soldiers to their post.
	if u.in_squad and leader != null and is_instance_valid(leader) and order == "follow":
		if u.global_position.distance_to(leader.global_position) > 230.0:
			target = null
			_release(u)
			_march(u)
			return
	if post != Vector2.INF and u.global_position.distance_to(post) > post_r + 60.0 and tp.distance_to(post) > post_r + 30.0:
		target = null
		_release(u)
		_march(u)
		return
	# Defensive reactions to the target's attacks.
	if u.state in [Unit.St.IDLE, Unit.St.GUARD] and target.state == Unit.St.ATTACK and target.attack_id != react_id and d < target.weapon.reach + 34.0:
		react_id = target.attack_id
		var chance := u.ai_skill * (1.0 if target.is_player else 0.4)
		if randf() < chance:
			if role == "officer" and dodge_cd <= 0.0 and randf() < 0.45:
				dodge_cd = 1.6
				u.i_move = (-to.normalized()).rotated(randf_range(-0.8, 0.8))
				u.try_dash()
				return
			guard_t = randf_range(0.35, 0.7)
			if role == "officer" and randf() < 0.45:
				u.open_parry()
	if guard_t > 0.0 and (u.state == Unit.St.IDLE or u.state == Unit.St.GUARD) and not u.weapon.ranged:
		u.i_guard = true
		if u.state == Unit.St.IDLE:
			u.enter_guard()
		u.i_move = to.normalized().orthogonal() * strafe * 0.4
		return
	# Yield the opening to another soldier after a completed exchange.
	if target.is_player and attack_committed and u.state == Unit.St.IDLE:
		_release(u)
		attack_committed = false
		atk_cd = maxf(atk_cd, randf_range(0.65, 1.0))
	# Attack tokens for the player.
	if target.is_player:
		if not token and atk_cd <= 0.0:
			token = b.request_token(u)
		if not token:
			var want := 64.0 + slot % 3 * 14.0
			var radial := (d - want) / 30.0
			u.i_move = (to.normalized() * clampf(radial, -1.0, 1.0) + to.normalized().orthogonal() * strafe * 0.6).limit_length(0.8)
			return
	if d > rng:
		u.i_move = (to.normalized() + to.normalized().orthogonal() * strafe * 0.15).normalized()
		# officers close distance with a dash attack
		if role == "officer" and d < rng + 70.0 and atk_cd <= 0.0 and u.state == Unit.St.IDLE and randf() < 0.02:
			u.start_move(u.weapon.dash_atk, "dash")
			atk_cd = randf_range(0.8, 1.5)
		return
	if d < rng * 0.45:
		u.i_move = -to.normalized() * 0.5
	if u.state == Unit.St.ATTACK and combo_left > 0 and u.mv_phase == 2 and u.mv_t > 0.05:
		combo_left -= 1
		u.do_light()
		return
	# Officers unleash their weapon skill now and then.
	if role == "officer" and skill_cd <= 0.0 and u.state == Unit.St.IDLE and not u.is_boss and u.weapon.skill != "arrow_rain":
		skill_cd = randf_range(7.0, 11.0)
		Skills.start_forced(u, u.weapon.skill)
		return
	if atk_cd <= 0.0 and u.state == Unit.St.IDLE:
		var vs_player := target.is_player
		attack_committed = vs_player
		if randf() < (0.22 if role == "officer" else 0.12):
			u.do_heavy()
		else:
			u.do_light()
			combo_left = 0
			if role == "officer":
				combo_left = randi_range(1, 2)
			elif randf() < 0.3:
				combo_left = 1
		var base_cd := randf_range(0.7, 1.5) if vs_player else randf_range(1.2, 2.6)
		atk_cd = base_cd / maxf(0.3, u.ai_aggro)

func _archer(u: Unit, _delta: float) -> void:
	if target == null:
		_march(u)
		return
	var tp := target.global_position
	var to := tp - u.global_position
	var d := to.length()
	u.i_goal = tp
	# lead the target a little
	var lead := tp + target.move_vel * clampf(d / u.weapon.proj_speed, 0.0, 0.6)
	_aim_at(u, lead + Vector2(0, -8))
	if d < 110.0:
		u.i_move = -to.normalized()
	elif d > 300.0:
		u.i_move = to.normalized() * 0.8
	else:
		u.i_move = to.normalized().orthogonal() * strafe * 0.25
	if atk_cd <= 0.0 and u.state == Unit.St.IDLE and d < 330.0:
		u.do_light()
		atk_cd = randf_range(1.8, 3.0)

func _cavalry(u: Unit, delta: float) -> void:
	var b = u.battle
	charge_t -= delta
	if charge_t <= 0.0:
		# pick a new charge line through enemies (prefer the player sometimes)
		var goal := Vector2.ZERO
		var p = b.player
		if p != null and is_instance_valid(p) and not p.dead and p.faction != u.faction and u.global_position.distance_to(p.global_position) < 520.0 and randf() < 0.5:
			goal = p.global_position
		elif target != null:
			goal = target.global_position
		else:
			goal = Vector2(b.front_x + (200.0 if u.faction == 0 else -200.0), lane_y + randf_range(-120, 120))
		charge_dir = (goal - u.global_position).normalized()
		if charge_dir == Vector2.ZERO:
			charge_dir = Vector2(1.0 if u.faction == 0 else -1.0, 0.0)
		charge_t = randf_range(1.8, 2.6)
	u.i_move = charge_dir
	u.i_aim = charge_dir
	u.i_goal = u.global_position + charge_dir * 200.0
	if target != null and u.state == Unit.St.IDLE and atk_cd <= 0.0:
		var d := u.global_position.distance_to(target.global_position)
		if d < u.weapon.reach + 6.0:
			u.do_light()
			atk_cd = randf_range(1.0, 1.8)
	var pos: Vector2 = u.global_position
	if pos.y < Battle.TOP + 20.0 or pos.y > Battle.BOT - 20.0 or pos.x < 60.0 or pos.x > Battle.W - 60.0:
		charge_t = 0.0

func _spectate(u: Unit) -> void:
	var b = u.battle
	var to := ring_pos - u.global_position
	u.i_goal = ring_pos
	if to.length() > 4.0:
		u.i_move = to.normalized() * clampf(to.length() / 30.0, 0.25, 1.0)
	_aim_at(u, b.duel_center)
