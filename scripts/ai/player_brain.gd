class_name PlayerBrain
extends RefCounted
## Reads keyboard/mouse or gamepad and writes the unit's intents.
## With --autotest it plays itself (used to smoke-test the game headlessly).

var pad := false
var last_mouse := Vector2.ZERO
var mouse_used := false     # once used, a resting cursor remains authoritative
var bot_t := 0.0
var bot_target: Unit = null

func think(u: Unit, delta: float) -> void:
	var b = u.battle
	if Game.command_view or (Game.autotest and Game.noauto):
		_clear(u)
		return
	if Game.autotest:
		_bot(u, delta)
		return
	if b.input_locked() or Game.command_view:
		_clear(u)
		return
	u.i_move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	var vp_mouse := u.get_viewport().get_mouse_position()
	if stick.length() > 0.35:
		pad = true
	elif vp_mouse.distance_to(last_mouse) > 0.5:
		pad = false
		mouse_used = true
	last_mouse = vp_mouse
	if pad:
		if stick.length() > 0.35:
			u.i_aim = stick.normalized()
		elif u.i_move.length() > 0.2:
			u.i_aim = u.i_move.normalized()
		u.i_aim_pt = u.global_position + u.i_aim * 150.0
	elif not mouse_used and u.i_move.length() > 0.2:
		# Until the mouse is first used, keyboard-only play aims with movement.
		# Once used, the cursor remains authoritative even when it rests.
		u.i_aim = u.i_move.normalized()
		u.i_aim_pt = u.global_position + u.i_aim * 150.0
	else:
		var mp := u.get_global_mouse_position()
		var to := mp - (u.global_position + Vector2(0, -10))
		if to.length() > 2.0:
			u.i_aim = to.normalized()
		u.i_aim_pt = mp
	u.i_light = Input.is_action_just_pressed("attack")
	u.i_light_held = Input.is_action_pressed("attack")
	u.i_heavy = Input.is_action_just_pressed("heavy")
	u.i_heavy_held = Input.is_action_pressed("heavy")
	u.i_dash = Input.is_action_just_pressed("dash")
	u.i_guard = Input.is_action_pressed("guard")
	u.i_guard_pressed = Input.is_action_just_pressed("guard")
	u.i_skill = Input.is_action_just_pressed("skill")
	u.i_flask = Input.is_action_just_pressed("flask")
	u.i_kick = Input.is_action_just_pressed("kick") or u.i_kick
	u.i_throw = Input.is_action_just_pressed("throw")

func _clear(u: Unit) -> void:
	u.i_move = Vector2.ZERO
	u.i_light = false
	u.i_light_held = false
	u.i_heavy = false
	u.i_heavy_held = false
	u.i_dash = false
	u.i_guard = false
	u.i_guard_pressed = false
	u.i_skill = false
	u.i_flask = false
	u.i_kick = false
	u.i_throw = false

## Simple self-play used by the automated smoke test.
func _bot(u: Unit, delta: float) -> void:
	_clear(u)
	var b = u.battle
	bot_t -= delta
	if bot_t <= 0.0 or bot_target == null or not is_instance_valid(bot_target) or bot_target.dead:
		bot_t = 0.4
		bot_target = null
		var bd := INF
		for e in b.query(u.global_position, 500.0):
			if e.faction == u.faction or e.dead or e.spectator:
				continue
			var d: float = u.global_position.distance_squared_to(e.global_position)
			if e.is_boss:
				d *= 0.2
			if d < bd:
				bd = d
				bot_target = e
	if bot_target == null:
		u.i_move = Vector2(1, 0)
		u.i_aim = Vector2(1, 0)
		u.i_goal = b.march_goal(u)
		if u.i_goal != Vector2.INF:
			u.i_move = (u.i_goal - u.global_position).normalized()
		return
	var to := bot_target.global_position - u.global_position
	var d := to.length()
	u.i_goal = bot_target.global_position
	u.i_aim = to.normalized()
	u.i_aim_pt = bot_target.global_position
	if d > u.weapon.reach * 0.8 + 4.0 and not u.weapon.ranged:
		u.i_move = to.normalized()
	elif u.weapon.ranged and d < 90.0:
		u.i_move = -to.normalized()
	var r := randf()
	if d < 26.0 and (bot_target.state == Unit.St.GUARD or r < 0.02) and not bot_target.is_boss:
		u.i_kick = true
		return
	if d > 90.0 and d < 220.0 and r < 0.004 and u.weapon.id != "sidearm" and not u.weapon.ranged:
		u.i_throw = true
		return
	if not u.mounted and not b.horses.is_empty() and not b.duel:
		var hz = null
		for h in b.horses:
			if is_instance_valid(h) and (hz == null or u.global_position.distance_to(h.global_position) < u.global_position.distance_to(hz.global_position)):
				hz = h
		if hz != null and u.global_position.distance_to(hz.global_position) < 900.0:
			u.i_move = (hz.global_position - u.global_position).normalized()
			if u.global_position.distance_to(hz.global_position) < 20.0:
				b._try_pickup()
			return
	if u.mounted and d > 40.0 and d < 120.0 and r < 0.03:
		u.i_dash = true
	if u.weapon.id == "sidearm" and not b.pickups.is_empty():
		# go and get a real weapon back
		var best = b.pickups[0]
		for pk in b.pickups:
			if u.global_position.distance_to(pk["pos"]) < u.global_position.distance_to(best["pos"]):
				best = pk
		var tp: Vector2 = best["pos"]
		if u.global_position.distance_to(tp) < 300.0:
			u.i_move = (tp - u.global_position).normalized()
			if u.global_position.distance_to(tp) < 20.0:
				b._try_pickup()
			return
	if bot_target.state == Unit.St.ATTACK and bot_target.mv_phase == 0 and d < 70.0 and r < 0.08:
		u.i_dash = true
		u.i_move = to.normalized().orthogonal()
	elif r < 0.05:
		u.i_guard = true
		u.i_guard_pressed = true
	elif u.spirit >= u.weapon.skill_cost and r < 0.08:
		u.i_skill = true
	elif r < 0.12:
		u.i_heavy = true
	elif r < 0.6:
		u.i_light = true
		u.i_light_held = true
	if u.hp < u.max_hp * 0.35 and u.flasks > 0 and randf() < 0.05:
		u.i_flask = true
