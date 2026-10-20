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
	u.i_move = Vector2.ZERO
	u.i_guard = false
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
		u.i_move = Vector2(-1.0 if u.faction == 0 else 1.0, (lane_y - u.position.y) * 0.01)
		u.i_aim = u.i_move.normalized()
		if (u.faction == 0 and u.position.x < 30.0) or (u.faction == 1 and u.position.x > Battle.W - 30.0):
			b.retire(u)
		return
	if think_t <= 0.0:
		think_t = randf_range(0.25, 0.5)
		_retarget(u)
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
	var r := 230.0
	if role == "archer":
		r = 340.0
	elif role == "cavalry":
		r = 160.0
	elif role == "officer":
		r = 320.0
	if u.in_squad and leader != null and is_instance_valid(leader):
		if order == "hold":
			center = order_pt
			r = 120.0
		elif order == "charge":
			center = order_pt
			r = 170.0
		else:
			center = leader.global_position
			r = 150.0
	var best: Unit = null
	var bd := INF
	for e in b.query(center, r):
		if e.faction == u.faction or e.dead or e.spectator:
			continue
		if e.is_player and not b.player_targetable():
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
		var goal: Vector2
		if order == "hold":
			goal = order_pt + Vector2((slot % 4) * 14.0 - 21.0, (slot / 4) * 14.0)
		elif order == "charge":
			goal = order_pt + Vector2((slot % 4) * 16.0 - 24.0, (slot / 4) * 16.0 - 16.0)
		else:
			var back := -leader.aim
			if back.length_squared() < 0.1:
				back = Vector2.LEFT
			var side := back.orthogonal()
			goal = leader.global_position + back * (22.0 + (slot / 4) * 14.0) + side * ((slot % 4) * 14.0 - 21.0)
		var to := goal - u.global_position
		if to.length() > 8.0:
			u.i_move = to.normalized() * clampf(to.length() / 40.0, 0.3, 1.0)
			_aim_at(u, goal)
		else:
			u.i_aim = leader.aim
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

func _melee(u: Unit, delta: float) -> void:
	var b = u.battle
	if target == null:
		_march(u)
		return
	var tp := target.global_position
	var to := tp - u.global_position
	var d := to.length()
	_aim_at(u, tp)
	var reach := u.weapon.reach * (1.25 if u.is_boss else 1.0)
	var rng := reach * 0.8 + target.radius
	# Leash squad members to their leader.
	if u.in_squad and leader != null and is_instance_valid(leader) and order == "follow":
		if u.global_position.distance_to(leader.global_position) > 230.0:
			target = null
			_release(u)
			_march(u)
			return
	# Defensive reactions to the target's attacks.
	if target.state == Unit.St.ATTACK and target.attack_id != react_id and d < target.weapon.reach + 34.0:
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
	# Attack tokens for the player.
	if target.is_player:
		if not token:
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
	if to.length() > 4.0:
		u.i_move = to.normalized() * clampf(to.length() / 30.0, 0.25, 1.0)
	_aim_at(u, b.duel_center)
