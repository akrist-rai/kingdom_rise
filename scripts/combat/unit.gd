class_name Unit
extends Node2D
## A soldier on the battlefield. The same class is used for the player and the AI:
## a "brain" (PlayerBrain or AIBrain) writes intents (i_*), the unit executes them.
## Taking over a new body on death is simply swapping that unit's brain.
##
## Terms (Elden Ring style):
##  - HP: health. Rally: HP lost recently that you win back by hitting enemies quickly.
##  - Stamina: spent on dashes, attacks, blocking. Running out leaves you open.
##  - Poise: how many hits you can take before flinching (stagger).
##  - Stance: build-up from heavy hits. When full the enemy kneels ("stance break")
##    and can be hit with a Critical (riposte) for huge damage.
##  - Spirit: earned by fighting, spent on the weapon's skill.
##  - Bleed: build-up that bursts for a big % of max HP.

enum St { IDLE, ATTACK, DASH, GUARD, STAGGER, BROKEN, KNOCKDOWN, CRIT, DRINK, SKILL, DEAD, CLASH }

const KIND_STATS := {
	"infantry": {"hp": 42.0, "poise": 14.0, "stance": 50.0, "speed": 80.0, "xp": 12.0, "skill": 0.15, "aggro": 0.6, "windup": 2.2},
	"spear": {"hp": 44.0, "poise": 14.0, "stance": 50.0, "speed": 78.0, "xp": 12.0, "skill": 0.15, "aggro": 0.6, "windup": 2.2},
	"archer": {"hp": 32.0, "poise": 8.0, "stance": 35.0, "speed": 82.0, "xp": 14.0, "skill": 0.1, "aggro": 0.5, "windup": 4.0},
	"heavy": {"hp": 105.0, "poise": 45.0, "stance": 95.0, "speed": 66.0, "xp": 28.0, "skill": 0.25, "aggro": 0.6, "windup": 1.5},
	"cavalry": {"hp": 120.0, "poise": 60.0, "stance": 90.0, "speed": 175.0, "xp": 32.0, "skill": 0.1, "aggro": 0.8, "windup": 1.4},
	"officer": {"hp": 420.0, "poise": 95.0, "stance": 150.0, "speed": 92.0, "xp": 220.0, "skill": 0.55, "aggro": 0.95, "windup": 1.3},
	"guard": {"hp": 150.0, "poise": 70.0, "stance": 110.0, "speed": 82.0, "xp": 45.0, "skill": 0.35, "aggro": 0.8, "windup": 1.45},
	"general": {"hp": 2200.0, "poise": 120.0, "stance": 300.0, "speed": 100.0, "xp": 1500.0, "skill": 0.5, "aggro": 1.0, "windup": 1.0},
}
const KIND_LABEL := {"infantry": "INFANTRY", "spear": "SPEARMAN", "archer": "ARCHER", "heavy": "HEAVY INFANTRY",
	"cavalry": "CAVALRY", "officer": "OFFICER", "guard": "ELITE GUARD", "general": "GENERAL"}

var battle = null
var regiment := -1
var regiment_slot := 0
var formation_braced := false
var formation_ranged_weakness := 1.0
var formation_bonus := 0.0
var formation_attack := 1.0
var formation_dir := Vector2.UP
var faction := 0
var fac_key := "qin"
var kind := "infantry"
var uname := ""
var title := ""
var is_player := false
var brain = null
var radius := 6.0
var mounted := false
var is_boss := false
var is_officer := false
var in_squad := false
var xp_value := 10.0
var ai_windup := 1.6
var ai_skill := 0.2
var ai_aggro := 0.6
var spectator := false
var duelist := false
var cheer_t := 0.0

# Attributes (VIG = vigor/HP, END = endurance/stamina, STR = strength, DEX = dexterity)
var vig := 10
var endu := 10
var stren := 10
var dex := 10

var max_hp := 100.0
var hp := 100.0
var rally := 0.0
var rally_hold := 0.0
var max_stamina := 100.0
var stamina := 100.0
var stam_delay := 0.0
var stam_regen := 55.0
var spirit := 0.0
const MAX_SPIRIT := 100.0
var max_poise := 20.0
var poise := 20.0
var poise_t := 0.0
var max_stance := 60.0
var stance := 0.0
var stance_t := 0.0
var bleed := 0.0
var flasks := 2
var max_flasks := 2

var weapon: Weapon
var state := St.IDLE
var st_t := 0.0
var st_dur := 0.0
var vel := Vector2.ZERO
var move_vel := Vector2.ZERO
var sep := Vector2.ZERO
var aim := Vector2.RIGHT
var face := 1
var base_speed := 80.0
var speed_mult := 1.0
var invuln := 0.0
var hyper := false
var buff_t := 0.0
var buff_mult := 1.0
var dead := false
var lod_tick := true         # false: far from the camera, this frame is skipped (time accumulates)
var lod_acc := 0.0
var brain_tick := true       # false: this frame the AI keeps its last decision (time accumulates)
var brain_acc := 0.0
var death_t := 0.0
var hit_flash := 0.0
var show_bar_t := 0.0
var parry_t := 0.0
var parry_cd := 0.0
var guard_counter_t := 0.0
var attack_id := 0
var trample_hits := {}
# Riding: the horse takes half of the blows aimed at its rider; if it falls, so do you.
var horse_hp := 0.0
var horse_max := 140.0
var horse_fac := "qin"

# Current move
var mv: Dictionary = {}
var mv_kind := "light"
var mv_phase := 0
var mv_t := 0.0
var mv_w := 0.1
var mv_hit := {}
var mv_tick := 0
var combo := 0
var combo_reset := 0.0
var charge := 0.0
var charging := false
var ammo := 0
var reload_t := 0.0
var dash_window := 0.0
var dash_dir := Vector2.RIGHT
var crit_target: Unit = null
var crit_done := false
var crit_style := "rising"     # finisher animation: rising / overhead / thrust
var crit_exec := false         # true: an execution (the victim dies outright)
# Kicks and throws: a kicked or struck-by-thrown-weapon soldier is "flung" for a moment.
# Flung bodies bowl over their comrades and are hurt by fires and stakes they land in.
var flung_t := 0.0
var flung_by: Unit = null
var flung_hits := {}
var hazard_hit := false
var kick_cd := 0.0
var lock_target: Unit = null   # the enemy the current attack auto-targeted (player only)
# Feel: squash and stretch (springs back to 1), lean, launcher air time and death flight.
var sq := Vector2.ONE
var base_scale := Vector2(1.16, 1.16)
var lean := 0.0
var air_t := 0.0
var air_dur := 0.0
var air_hits := 0
var fly_t := 0.0
var fly_dur := 0.0
var fly_spin := 0.0

# Skill scratch
var skill_id := ""
var sk := {}
var skill_hit := {}

# Intents (written by the brain every frame)
var i_move := Vector2.ZERO
var i_aim := Vector2.RIGHT
var i_aim_pt := Vector2.ZERO
var i_light := false
var i_light_held := false
var i_heavy := false
var i_heavy_held := false
var i_dash := false
var i_guard := false
var i_guard_pressed := false
var i_skill := false
var i_flask := false
var i_kick := false
var i_throw := false
var i_goal := Vector2.INF     # where the brain is heading (used to path around walls)
var nav_pts := PackedVector2Array()
var nav_i := 0
var nav_t := 0.0
var nav_goal := Vector2.INF
var queued := ""
var queued_t := 0.0

# Visuals: baked 3D-rendered sprites (UnitArt). The body and the weapon are two layers on one
# rig; the rig carries squash / lean / hop, the sprites only swap atlas frames.
var rig: Node2D
var horse_spr: Sprite2D
var seat := Vector2.ZERO      # rider offset on horseback (rig pixels)
var body: Sprite2D
var wpn: Sprite2D
var body_sheet := ""
var wpn_sheet := ""
var aset := "1h"
var palette := "march"
var anim_t := 0.0
var anim_ofs := 0.0
var weapon_angle := 0.0
var step_acc := 0.0
var tint := Color.WHITE
var dir8 := 2
var cur_anim := ""
var cur_frame := 0
var mv_anim := "a1"
var run_phase := 0.0
var guard_hit_t := 0.0
var on_screen_vis := true
var base_body_scale := 1.0
var death_frame_t := 0.0
const MOVE_ANIMS := {
	"jian": {"combo": ["a1", "a2", "a3", "a4"], "heavy": "a2", "dash": "a3", "finisher": "a4"},
	"sword_shield": {"combo": ["a3", "a1", "a4"], "heavy": "a3", "dash": "a3", "finisher": "a4"},
	"sidearm": {"combo": ["a1", "a2", "a1"], "heavy": "a3", "dash": "a3", "finisher": "a4"},
	"daggers": {"combo": ["a1", "a2", "a1", "a2", "a1", "a2"], "heavy": "a2", "dash": "a3", "finisher": "a3"},
	"glaive": {"combo": ["a1", "a1", "a2"], "heavy": "a4", "dash": "a1", "finisher": "a4"},
	"spear": {"combo": ["a3", "a3", "a1"], "heavy": "a3", "dash": "a3", "finisher": "a4"},
	"axe": {"combo": ["a1", "a2"], "heavy": "a2", "dash": "a1", "finisher": "a2"},
	"zhanmadao": {"combo": ["a1", "a1", "a2"], "heavy": "a1", "dash": "a1", "finisher": "a4"},
	"hammer": {"combo": ["a1", "a1", "a2"], "heavy": "a2", "dash": "a1", "finisher": "a2"},
	"black_glaive": {"combo": ["a1", "a1", "a2"], "heavy": "a4", "dash": "a3", "finisher": "a4"},
	"bow": {"combo": ["shoot"], "heavy": "shoot", "dash": "shoot", "finisher": "shoot"},
	"crossbow": {"combo": ["shoot"], "heavy": "kick", "dash": "shoot", "finisher": "kick"},
}
## skill -> [animation, end of wind-up, end of the active part] (seconds); "loop" anims cycle
const SKILL_ANIMS := {
	"gale_slash": ["a1", 0.06, 0.22], "tempest": ["spin", 0.0, 99.0], "piercing_charge": ["a3", 0.14, 0.4],
	"blade_dance": ["a1", 0.0, 99.0], "earthsplitter": ["a2", 0.38, 0.5], "horse_cleaver": ["a1", 0.26, 0.36],
	"bulwark_rush": ["block", 0.0, 99.0], "arrow_rain": ["aim", 0.3, 0.4], "bolt_storm": ["shoot", 0.15, 0.25],
	"quake": ["a2", 0.42, 0.55],
}

# ------------------------------------------------------------------ setup
func setup(b, fac: int, k: String, w: Weapon) -> void:
	battle = b
	faction = fac
	fac_key = "qin" if fac == 0 else "zhao"
	kind = k
	mounted = k == "cavalry"
	is_boss = k == "general"
	is_officer = k == "officer"
	radius = 10.0 if mounted else (10.0 if is_boss else (8.0 if k in ["heavy", "officer", "guard"] else 7.0))
	var ks: Dictionary = KIND_STATS[k]
	max_hp = ks["hp"] * randf_range(0.9, 1.1)
	hp = max_hp
	max_poise = ks["poise"]
	poise = max_poise
	max_stance = ks["stance"]
	base_speed = ks["speed"] * randf_range(0.92, 1.08)
	xp_value = ks["xp"]
	ai_windup = ks["windup"]
	ai_skill = ks["skill"]
	ai_aggro = ks["aggro"]
	_roll_attributes()
	palette = "march" if fac == 0 else "crown"
	match k:
		"officer", "guard":
			palette = "march_elite" if fac == 0 else "crown_elite"
		"general":
			palette = "general"
	base_body_scale = {"general": 1.42, "officer": 1.18, "guard": 1.1, "heavy": 1.06}.get(k, 1.0)
	anim_ofs = randf() * 10.0
	_build_visuals()
	set_weapon(w)
	aim = Vector2.RIGHT if faction == 0 else Vector2.LEFT
	face = 1 if faction == 0 else -1
	uname = NameGen.make(fac)
	stamina = max_stamina

func _roll_attributes() -> void:
	var lo := 8
	var hi := 13
	match kind:
		"heavy", "guard":
			lo = 11
			hi = 16
		"officer":
			lo = 14
			hi = 18
		"general":
			lo = 20
			hi = 24
	vig = randi_range(lo, hi)
	endu = randi_range(lo, hi)
	stren = randi_range(lo, hi)
	dex = randi_range(lo, hi)
	match kind:
		"archer":
			dex += 4
			vig -= 2
		"spear":
			stren += 2
		"heavy", "guard":
			stren += 3
			dex -= 3
		"cavalry":
			vig += 2

func _build_visuals() -> void:
	base_scale = Vector2.ONE * base_body_scale
	rig = Node2D.new()
	add_child(rig)
	horse_spr = Sprite2D.new()
	horse_spr.centered = false
	horse_spr.region_enabled = true
	horse_spr.visible = false
	rig.add_child(horse_spr)
	body = Sprite2D.new()
	body.centered = false
	body.region_enabled = true
	rig.add_child(body)
	wpn = Sprite2D.new()
	wpn.centered = false
	wpn.region_enabled = true
	rig.add_child(wpn)
	_apply_palette()

func _apply_palette() -> void:
	var m: Material = UnitArt.materials.get(palette)
	body.material = m
	wpn.material = m
	horse_spr.material = m

## Body and weapon sheets: on foot by kind and weapon, on horseback the rider sheets.
func _refresh_sheets() -> void:
	if weapon == null:
		return
	if mounted:
		body_sheet = UnitArt.rider_sheet(weapon.id)
		wpn_sheet = UnitArt.rider_weapon_sheet(weapon.id)
	else:
		body_sheet = UnitArt.body_sheet(kind, weapon.id)
		wpn_sheet = UnitArt.weapon_sheet(weapon.id)
	cur_anim = ""
	_last_body = null
	_last_wpn = null
	if horse_spr:
		horse_spr.visible = mounted
	if not mounted and body:
		body.position = Vector2.ZERO
		wpn.position = Vector2.ZERO
		seat = Vector2.ZERO

func set_weapon(w: Weapon) -> void:
	weapon = w
	weapon_angle = aim.angle() + deg_to_rad(w.rest) * face
	aset = UnitArt.anim_set(w.id)
	_refresh_sheets()
	ammo = w.clip
	reload_t = 0.0
	combo = 0

## Called when the player takes control of this body.
func become_player() -> void:
	formation_bonus = 0.0
	formation_attack = 1.0
	is_player = true
	in_squad = false
	spectator = false
	var ratio := hp / max_hp
	if Game.has_perk("veteran"):
		vig += 3
		endu += 3
		stren += 3
		dex += 3
	max_hp = 55.0 + vig * 6.0
	max_stamina = (70.0 + endu * 3.0) * (1.3 if Game.has_perk("iron_lungs") else 1.0)
	stam_regen = 60.0 * (1.25 if Game.has_perk("iron_lungs") else 1.0)
	max_poise = (18.0 + vig * 0.6) * (1.6 if kind in ["heavy", "guard"] else 1.0) * (1.5 if Game.has_perk("unbroken") else 1.0)
	poise = max_poise
	max_stance = 99999.0
	stance = 0.0
	base_speed = (220.0 if mounted else 166.0) - weapon.weight * 8.0
	if Game.has_perk("second_wind"):
		hp = max_hp
		invuln = 3.0
	else:
		hp = max_hp * maxf(ratio, 0.65)
		invuln = 1.5
	stamina = max_stamina
	spirit = maxf(spirit, 30.0)
	palette = "hero"
	_apply_palette()
	if mounted:
		horse_max = 140.0
		horse_hp = horse_max
		horse_fac = fac_key
	max_flasks = 2 + (1 if Game.has_perk("field_medic") else 0)
	flasks = max_flasks
	rally = 0.0
	bleed = 0.0
	if state in [St.STAGGER, St.BROKEN, St.KNOCKDOWN, St.CRIT, St.ATTACK, St.SKILL]:
		state = St.IDLE

## Climbs onto a riderless horse (the player only): faster, tramples when galloping, and the
## dash becomes a longer charge. Kicks are not possible from the saddle.
func mount(h_fac: String) -> void:
	if mounted:
		return
	horse_fac = h_fac
	mounted = true
	radius = 10.0
	horse_max = 140.0
	horse_hp = horse_max
	base_speed = 210.0 - weapon.weight * 8.0
	_refresh_sheets()
	Sfx.play_at("dash", global_position, -2.0, 0.7)

## Gets off the horse. thrown = the horse was killed under you.
func dismount(thrown: bool) -> void:
	if not mounted:
		return
	mounted = false
	if kind == "cavalry":
		kind = "spear"
	_refresh_sheets()
	radius = 7.0
	base_speed = 150.0 - weapon.weight * 8.0
	if battle == null:
		return
	if thrown:
		battle.decals.blood_pool(global_position, 9.0)
		battle.fx.text(global_position + Vector2(0, -34), "THROWN FROM THE SADDLE", Color("#ff8c42"))
		stagger(1.0)
		state = St.KNOCKDOWN
		vel = -aim * 120.0
		battle.cam_shake(6.0)
		Sfx.play_at("death", global_position, -4.0, 0.6)
	else:
		battle.spawn_horse(horse_fac, global_position + Vector2(-6.0 * face, 3.0), Vector2.ZERO)
	horse_hp = 0.0

func kind_label() -> String:
	return KIND_LABEL.get(kind, kind.to_upper())

# ------------------------------------------------------------------ main loop
func _process(delta: float) -> void:
	if battle == null or battle.frozen:
		return
	if not lod_tick and not is_player:
		lod_acc += delta
		return
	delta = minf(delta + lod_acc, 0.1 if lod_acc > 0.0 else 1.0 / 30.0)
	lod_acc = 0.0
	if dead:
		_update_dead(delta)
		return
	var _p0 := Time.get_ticks_usec()
	if brain:
		if brain_tick or is_player:
			brain.think(self, delta + brain_acc)
			brain_acc = 0.0
		else:
			brain_acc += delta
	var _p1 := Time.get_ticks_usec()
	Prof.add("u.brain", _p1 - _p0)
	_timers(delta)
	_nav_steer(delta)
	var _p2 := Time.get_ticks_usec()
	Prof.add("u.nav", _p2 - _p1)
	_buffer(delta)
	match state:
		St.IDLE:
			_st_idle(delta)
		St.GUARD:
			_st_guard(delta)
		St.ATTACK:
			_st_attack(delta)
		St.DASH:
			_st_dash(delta)
		St.STAGGER, St.KNOCKDOWN, St.BROKEN:
			_st_stun(delta)
		St.CRIT:
			_st_crit(delta)
		St.DRINK:
			_st_drink(delta)
		St.SKILL:
			Skills.update(self, delta)
	var _pa := Time.get_ticks_usec()
	Prof.add("u.states", _pa - _p2)
	_integrate(delta)
	Prof.add("u.integrate", Time.get_ticks_usec() - _pa)
	if flung_t > 0.0:
		_fling_update(delta)
	if air_t < air_dur:
		air_t += delta
		if air_t >= air_dur:
			_land()
	if mounted and not is_player:
		_trample()
	elif mounted and is_player and (move_vel + vel).length() > 150.0:
		_trample()
	var _p3 := Time.get_ticks_usec()
	Prof.add("u.state+move", _p3 - _p2)
	_visuals(delta)
	Prof.add("u.visuals", Time.get_ticks_usec() - _p3)

func _timers(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	kick_cd -= delta
	hit_flash -= delta
	parry_t -= delta
	parry_cd -= delta
	guard_counter_t -= delta
	combo_reset -= delta
	dash_window -= delta
	show_bar_t -= delta
	cheer_t -= delta
	if combo_reset <= 0.0 and state != St.ATTACK:
		combo = 0
	if buff_t > 0.0:
		buff_t -= delta
		if buff_t <= 0.0:
			buff_mult = 1.0
			speed_mult = 1.0
	if stam_delay > 0.0:
		stam_delay -= delta
	elif state != St.ATTACK and state != St.DASH and state != St.SKILL:
		var k := 0.35 if state == St.GUARD else 1.0
		stamina = minf(max_stamina, stamina + stam_regen * k * delta)
	poise_t -= delta
	if poise_t <= 0.0:
		poise = max_poise
	stance_t -= delta
	if stance_t <= 0.0 and stance > 0.0 and state != St.BROKEN:
		stance = maxf(0.0, stance - (10.0 if is_boss else 18.0) * delta)
	if rally > 0.0:
		rally_hold -= delta
		if rally_hold <= 0.0:
			rally = maxf(0.0, rally - 24.0 * delta)
	bleed = maxf(0.0, bleed - 5.0 * delta)
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			ammo = weapon.clip

## Steering around solids: when the straight line to the brain's goal is blocked by a wall or
## a house, follow a navigation path instead (refreshed twice a second).
func _nav_steer(delta: float) -> void:
	if battle == null or battle.terrain == null or (is_player and not Game.autotest):
		return
	if i_move.length_squared() < 0.01 or i_goal == Vector2.INF:
		nav_pts = PackedVector2Array()
		return
	nav_t -= delta
	if nav_t <= 0.0 or nav_goal.distance_to(i_goal) > 48.0:
		nav_t = randf_range(0.45, 0.7)
		nav_goal = i_goal
		if battle.terrain.blocked(global_position, i_goal):
			nav_pts = battle.terrain.path(global_position, i_goal)
			nav_i = 1
		else:
			nav_pts = PackedVector2Array()
	if nav_pts.size() < 2:
		return
	while nav_i < nav_pts.size() and global_position.distance_to(nav_pts[nav_i]) < 9.0:
		nav_i += 1
	if nav_i < nav_pts.size():
		i_move = (nav_pts[nav_i] - global_position).normalized() * maxf(i_move.length(), 0.65)

## Input buffering so presses made slightly early still come out (essential for a fast feel).
func _buffer(delta: float) -> void:
	if not is_player:
		return
	queued_t -= delta
	if queued_t <= 0.0:
		queued = ""
	if i_light:
		queued = "light"
		queued_t = 0.22
	elif i_heavy:
		queued = "heavy"
		queued_t = 0.22
	elif i_skill:
		queued = "skill"
		queued_t = 0.22
	elif i_dash:
		queued = "dash"
		queued_t = 0.18
	elif i_flask:
		queued = "flask"
		queued_t = 0.15
	elif i_kick:
		queued = "kick"
		queued_t = 0.2
	elif i_throw:
		queued = "throw"
		queued_t = 0.2
	i_kick = false
	i_throw = false

func _consume(what: String) -> bool:
	if queued == what:
		queued = ""
		queued_t = 0.0
		return true
	return false

# ------------------------------------------------------------------ states
func _face_aim(rate: float = -1.0) -> void:
	var target := i_aim
	if target.length_squared() < 0.01:
		return
	if rate < 0.0:
		aim = target.normalized()
	else:
		aim = Vector2.from_angle(rotate_toward(aim.angle(), target.angle(), rate)).normalized()

func _st_idle(_delta: float) -> void:
	_face_aim(-1.0 if is_player else 9.0 * _delta)
	if not is_player:
		return
	if _consume("dash"):
		try_dash()
		return
	if queued == "light" and dash_window > 0.0 and not weapon.dash_atk.is_empty():
		_consume("light")
		start_move(weapon.dash_atk, "dash")
		return
	if queued == "light":
		_consume("light")
		if not try_crit():
			do_light()
		return
	if queued == "heavy":
		_consume("heavy")
		do_heavy()
		return
	if _consume("skill"):
		Skills.start(self)
		return
	if _consume("flask"):
		try_flask()
		return
	if _consume("kick"):
		try_kick()
		return
	if _consume("throw"):
		try_throw()
		return
	if i_guard:
		enter_guard()

func enter_guard() -> void:
	state = St.GUARD
	st_t = 0.0

func _st_guard(delta: float) -> void:
	st_t += delta
	_face_aim(-1.0 if is_player else 9.0 * delta)
	if is_player:
		if i_guard_pressed and parry_cd <= 0.0:
			open_parry()
		if not i_guard:
			state = St.IDLE
			return
		if _consume("dash"):
			try_dash()
			return
		if queued == "heavy" and guard_counter_t > 0.0:
			_consume("heavy")
			var m := weapon.heavy.duplicate()
			m["w"] = float(m["w"]) * 0.45
			m["st"] = float(m["st"]) * 1.5
			m["dmg"] = float(m["dmg"]) * 1.15
			start_move(m, "counter")
			Game.add_style("counter", 80.0, "GUARD COUNTER", Color("#ffd166"))
			return
		if queued == "light":
			_consume("light")
			if not try_crit():
				do_light()
			return
		if _consume("skill"):
			Skills.start(self)
		elif _consume("kick"):
			try_kick()
	else:
		if not i_guard:
			state = St.IDLE

func open_parry() -> void:
	var w := 0.16 + weapon.parry_bonus
	if Game.has_perk("keen_eye") and is_player:
		w *= 1.6
	if not is_player:
		w = 0.2
	parry_t = w
	parry_cd = 0.42
	if state != St.GUARD:
		enter_guard()

func do_light() -> void:
	if weapon.combo.is_empty():
		return
	if weapon.ranged:
		if weapon.clip > 0:
			if reload_t > 0.0:
				return
			if ammo <= 0:
				reload_t = weapon.reload
				return
		start_move(weapon.combo[0], "light")
		return
	var m: Dictionary = weapon.combo[combo % weapon.combo.size()]
	combo += 1
	start_move(m, "light")

func do_heavy() -> void:
	if weapon.heavy.is_empty():
		return
	if is_player and combo >= 2 and not weapon.ranged and (state == St.ATTACK or combo_reset > 0.0):
		_finisher()
		return
	start_move(weapon.heavy, "heavy")

## Light, light, heavy: a fast, unstoppable finisher. Blades launch the enemy into the air
## (keep hitting to juggle him), heavy weapons slam the ground, spears sweep all around.
func _finisher() -> void:
	var m: Dictionary = weapon.heavy.duplicate()
	m["w"] = float(m["w"]) * 0.5
	m["dmg"] = float(m["dmg"]) * 1.35
	m["st"] = float(m["st"]) * 1.4
	m["kb"] = float(m["kb"]) * 1.2
	m["hyper"] = true
	m["finisher"] = true
	match weapon.id:
		"axe", "hammer", "glaive", "black_glaive":
			m["quake"] = 54.0
		"spear":
			m["shape"] = "circle"
			m["rng"] = 1.0
			m["a0"] = 0.0
			m["a1"] = 360.0
			m["ticks"] = 2
		_:
			m["launch"] = true
			m["shape"] = "arc"
			m["arc"] = 160.0
			m["a0"] = 70.0
			m["a1"] = -150.0
	combo = 0
	Game.stats["finishers"] = int(Game.stats.get("finishers", 0)) + 1
	start_move(m, "finisher")
	if battle:
		battle.fx.text(global_position + Vector2(0, -34), "FINISHER", Color("#ffd166"))
	Game.add_style("finisher", 70.0, "FINISHER", Color("#ffd166"))

func start_move(m: Dictionary, tag: String) -> void:
	if m.is_empty():
		return
	var cost: float = float(m.get("cost", 8.0))
	if is_player:
		if stamina <= 0.0:
			Sfx.play("ui", -10.0, 0.6)
			return
		stamina -= cost * (0.5 if Game.aura_active() else 1.0)
		stam_delay = 0.55
	state = St.ATTACK
	mv = m
	mv_kind = tag
	mv_anim = _move_anim(m, tag)
	mv_phase = 0
	mv_t = 0.0
	mv_hit.clear()
	mv_tick = 0
	charge = 0.0
	attack_id += 1
	hyper = m.get("hyper", false)
	mv_w = float(m["w"]) * (1.0 if is_player else ai_windup)
	if not is_player:
		# readable telegraphs: AI wind-ups are never shorter than this
		mv_w = maxf(mv_w, 0.16 if is_boss else 0.22)
	if is_boss and battle and battle.boss_phase >= 3:
		mv_w *= 0.85
	charging = is_player and (tag == "heavy" or (weapon.id == "bow" and tag == "light"))
	if is_player:
		_face_aim()
		_auto_aim()
	elif battle:
		var perilous: bool = m.get("perilous", false)
		if mv_w > 0.12 or perilous:
			battle.fx.glint(self, perilous)

func _st_attack(delta: float) -> void:
	mv_t += delta
	var a0 := deg_to_rad(float(mv["a0"]))
	var a1 := deg_to_rad(float(mv["a1"]))
	var rest := deg_to_rad(weapon.rest)
	match mv_phase:
		0:
			if is_player and not hyper and _consume("dash"):
				try_dash()
				return
			if is_player:
				if lock_target != null and is_instance_valid(lock_target) and not lock_target.dead:
					aim = (lock_target.global_position - global_position).normalized()
				else:
					_face_aim()
			else:
				_face_aim(5.0 * delta)
			if charging:
				var held := i_heavy_held if mv_kind == "heavy" else i_light_held
				if held and charge < 1.0:
					charge = minf(1.0, charge + delta / (0.7 if weapon.id == "bow" else 0.6))
					mv_t = minf(mv_t, mv_w * 0.85)
					if charge >= 1.0 and weapon.id != "bow":
						charging = false
				elif not held:
					charging = false
			var k := clampf(mv_t / mv_w, 0.0, 1.0)
			_set_wangle(lerpf(rest, a0, _ease_out(k)) - (0.15 * charge if mv_kind == "heavy" else 0.0))
			if mv_t >= mv_w and not charging:
				mv_phase = 1
				mv_t = 0.0
				_active_start()
			elif mv_t >= mv_w and charging and weapon.id == "bow":
				mv_t = mv_w
		1:
			var act: float = mv["a"]
			var k := clampf(mv_t / act, 0.0, 1.0)
			_set_wangle(lerpf(a0, a1, _ease_out(k)))
			var ticks: int = mv.get("ticks", 1)
			if ticks > 1:
				var ti := int(k * ticks)
				if ti > mv_tick and ti < ticks:
					mv_tick = ti
					mv_hit.clear()
			if not mv.has("shot"):
				_hit_check()
			if mv_t >= act:
				mv_phase = 2
				mv_t = 0.0
				if mv.has("quake"):
					_quake(float(mv["quake"]))
		2:
			var rec: float = mv["r"] * (1.0 if is_player else 1.3)
			var k := clampf(mv_t / rec, 0.0, 1.0)
			_set_wangle(lerpf(a1, rest, k))
			if is_player:
				if _consume("dash"):
					try_dash()
					return
				if mv_t >= rec * 0.3:
					if queued == "light":
						_consume("light")
						if not try_crit():
							do_light()
						return
					if queued == "heavy":
						_consume("heavy")
						do_heavy()
						return
					if _consume("skill"):
						if Skills.start(self):
							return
					if _consume("kick"):
						if try_kick():
							return
					if _consume("throw"):
						if try_throw():
							return
				if weapon.id == "crossbow" and i_light_held and mv_t >= rec * 0.6:
					do_light()
					return
			if mv_t >= rec:
				state = St.IDLE
				hyper = false
				combo_reset = 0.45
				if is_player and i_guard:
					enter_guard()

## Which baked animation plays a move: per-weapon tables, with kicks, throws and shots special.
func _move_anim(m: Dictionary, tag: String) -> String:
	if m.has("anim"):
		return m["anim"]
	if m.get("kick", false):
		return "kick"
	if m.get("shot", "") == "throw":
		return "throw"
	var t: Dictionary = MOVE_ANIMS.get(weapon.id, MOVE_ANIMS["jian"])
	match tag:
		"light":
			var c: Array = t["combo"]
			return c[posmod(combo - 1, c.size())]
		"heavy", "counter":
			return t["heavy"]
		"dash":
			return t["dash"]
		"finisher":
			return t["finisher"]
	return "a1"

func _set_wangle(rel: float) -> void:
	weapon_angle = aim.angle() + rel * face

func _ease_out(k: float) -> float:
	return 1.0 - (1.0 - k) * (1.0 - k)

## Auto-target: the attack goes to the best enemy in the direction you point (or move).
func _auto_aim() -> void:
	lock_target = null
	if not is_player or battle == null:
		return
	var rng := 300.0 if (weapon.ranged or mv.get("shot", "") == "throw") else weapon.reach + 70.0
	var tg: Unit = battle.pick_target(self, i_aim, rng)
	if tg != null:
		lock_target = tg
		var to := tg.global_position - global_position
		if to.length() > 0.5:
			aim = to.normalized()

func _active_start() -> void:
	sq = Vector2(1.16, 0.88) if is_player else Vector2(1.08, 0.94)
	var lunge: float = mv.get("lunge", 0.0)
	# magnetism: the player's blow carries them to the auto-target (or stops short of it)
	if is_player and lock_target != null and is_instance_valid(lock_target) and not lock_target.dead and not mv.has("shot"):
		var gap := global_position.distance_to(lock_target.global_position) - lock_target.radius - weapon.reach * 0.6
		if gap > 0.0:
			lunge = maxf(lunge, minf(sqrt(2200.0 * gap), 380.0))
		else:
			lunge *= 0.45
	if not is_player:
		lunge *= 0.6
	if is_boss:
		lunge *= 1.6
	vel += aim * lunge
	var sfxn: String = mv.get("sfx", "swing")
	if mv.has("shot"):
		_fire_shot()
	else:
		Sfx.play_at(sfxn, global_position, -2.0 if is_player else -6.0)
		if battle and mv.get("kick", false):
			battle.fx.kick_streak(self)
		elif battle:
			battle.fx.swing_trail(self, mv)

func _fire_shot() -> void:
	var shot: String = mv["shot"]
	var origin := global_position + Vector2(0, -12)
	var power_k := 1.0 + charge * 1.6
	var pierce := 0
	if weapon.id == "bow" and charge >= 0.98:
		pierce = 2
		power_k = 2.8
		if is_player:
			Game.add_style("fulldraw", 30.0, "", Color.WHITE)
	var spd := weapon.proj_speed * (1.0 + charge * 0.4)
	Sfx.play_at("bow", global_position, -4.0 if is_player else -9.0, 1.3 if shot == "bolt" else 1.0)
	match shot:
		"throw":
			var h := make_hit(mv, 1.0)
			h["knockdown"] = true
			h["fling"] = true
			battle.proj.throw_weapon(self, origin, aim, weapon, h)
			Sfx.play_at("swing_heavy", global_position, -2.0, 1.2)
			set_weapon(Weapon.make("sidearm"))
			if is_player:
				base_speed = (220.0 if mounted else 166.0) - weapon.weight * 8.0
				battle.hud.alert("WEAPON THROWN  -  PICK IT UP AGAIN WITH F", Color("#ffe8a3"))
			charge = 0.0
			return
		"arrow":
			battle.proj.shoot(self, origin, aim, spd, make_hit(mv, power_k), "arrow", pierce)
		"bolt":
			var d := aim.rotated(randf_range(-0.05, 0.05))
			battle.proj.shoot(self, origin, d, spd, make_hit(mv, 1.0), "bolt", 0)
			if weapon.clip > 0:
				ammo -= 1
				if ammo <= 0:
					reload_t = weapon.reload
		"triple":
			for k in [-0.22, 0.0, 0.22]:
				battle.proj.shoot(self, origin, aim.rotated(k), spd, make_hit(mv, 1.0), "arrow", 0)
	charge = 0.0

func _hit_check() -> void:
	if battle == null:
		return
	var reach: float = weapon.reach * float(mv.get("rng", 1.0)) * (1.25 if is_boss else 1.0)
	if mv.get("kick", false):
		reach = 21.0
	var origin := global_position + Vector2(0, -8)
	var shape: String = mv.get("shape", "arc")
	var half_arc := deg_to_rad(float(mv.get("arc", 140.0)) * 0.5)
	var width: float = mv.get("width", 8.0)
	for e in battle.query(global_position, reach + 24.0):
		if e == self or e.dead or e.faction == faction or mv_hit.has(e):
			continue
		var to: Vector2 = (e.global_position + Vector2(0, -8)) - origin
		var d: float = to.length() - e.radius
		if d > reach:
			continue
		var ok := false
		match shape:
			"arc":
				ok = d < 5.0 or absf(angle_difference(aim.angle(), to.angle())) <= half_arc
			"thrust":
				var t := to.dot(aim)
				var perp := absf(to.cross(aim))
				ok = t > -6.0 and t < reach + e.radius and perp <= width + e.radius
			"circle":
				ok = true
		if ok:
			mv_hit[e] = true
			var mult := 1.0
			if mv_kind == "heavy" or mv_kind == "counter":
				mult = 1.0 + charge * 0.6
				if is_player and Game.has_perk("heavy_hand"):
					mult *= 1.35
			var h := make_hit(mv, mult)
			if mv.get("kick", false):
				h["fling"] = true
				h["guard_break"] = 4.0
				h["bleed"] = 0.0
			var res: String = e.take_hit(self, h)
			if mv.get("kick", false) and is_player and res != "dodged":
				Game.add_style("kick", 35.0, "KICK", Color("#d9e7ff"))
				Game.stats["kicks"] = int(Game.stats.get("kicks", 0)) + 1
				battle.fx.hit_star(e.global_position + Vector2(0, -8), 10.0, Color(0.85, 0.92, 1.0))
				Sfx.play_at("hit_heavy", e.global_position, -3.0, 0.8)

func _quake(r: float) -> void:
	battle.fx.ring(global_position, r, Color(0.9, 0.95, 1.0, 0.8), 0.35)
	if is_player or battle.on_screen(global_position):
		battle.cam_shake(5.0)
		Sfx.play_at("boom", global_position, -4.0)
	for e in battle.query(global_position, r + 10.0):
		if e == self or e.dead or e.faction == faction or mv_hit.has(e):
			continue
		if e.global_position.distance_to(global_position) <= r + e.radius:
			var h := make_hit(mv, 0.5)
			h["knockdown"] = true
			e.take_hit(self, h)

## Base attack power from weapon, scaling and modifiers.
func power() -> float:
	var s := 1.0 + (stren - 10) * weapon.str_k() * 0.045 + (dex - 10) * weapon.dex_k() * 0.045
	var p := weapon.base * (1.0 + weapon.level * 0.12) * maxf(0.5, s) * buff_mult
	if is_player:
		p *= Game.player_damage_mult()
	elif battle:
		p *= battle.morale_mult(faction)
		if in_squad:
			p *= 1.6 if Game.has_perk("war_drums") else 1.25
	return p

func make_hit(m: Dictionary, mult: float = 1.0) -> Dictionary:
	var bl := weapon.bleed
	if is_player and Game.has_perk("hemorrhage"):
		bl += 15.0
	var st_mult := weapon.stance_pow
	if is_player and mv_kind == "heavy" and Game.has_perk("heavy_hand"):
		st_mult *= 1.35
	return {
		"dmg": power() * float(m.get("dmg", 1.0)) * mult * formation_attack,
		"pz": float(m.get("pz", 12.0)) * weapon.stance_pow,
		"st": float(m.get("st", 10.0)) * st_mult * (1.0 + charge * 0.5),
		"kb": float(m.get("kb", 50.0)),
		"perilous": m.get("perilous", false),
		"bleed": bl,
		"anti_cav": weapon.anti_cav,
		"guard_break": weapon.guard_break,
		"src_pos": global_position,
		"ranged": false,
		"skill": false,
		"crit": false,
		"heavy": mv_kind == "heavy",
		"bash": m.get("bash", false),
		"launch": m.get("launch", false),
	}

# ------------------------------------------------------------------ dash / crit / flask
func try_dash() -> bool:
	var cost := 20.0 * (0.7 if (is_player and Game.has_perk("ghost_step")) else 1.0)
	if is_player and stamina <= 0.0:
		return false
	stamina -= cost
	stam_delay = 0.45
	state = St.DASH
	st_t = 0.0
	st_dur = 0.3 if (mounted and is_player) else 0.17
	dash_dir = i_move.normalized() if i_move.length() > 0.15 else aim
	var spd := 380.0 if mounted else 470.0
	vel = dash_dir * spd
	sq = Vector2(1.25, 0.8)
	move_vel = Vector2.ZERO
	invuln = 0.15 * (1.5 if (is_player and Game.has_perk("ghost_step")) else 1.0)
	hyper = false
	Sfx.play_at("dash", global_position, -6.0)
	if battle:
		if is_player:
			battle.cam.punch(-0.04)
			battle.cam.roll_kick(-0.02 * signf(dash_dir.x))
		battle.fx.afterimage(self)
		battle.fx.snow_kick(global_position, -dash_dir, 12 if is_player else 5)
	return true

func _st_dash(delta: float) -> void:
	st_t += delta
	if is_player and st_t > 0.05 and st_t < 0.12 and battle:
		battle.fx.afterimage(self)
	if is_player and queued == "light" and st_t > 0.06 and not weapon.dash_atk.is_empty():
		_consume("light")
		_face_aim()
		start_move(weapon.dash_atk, "dash")
		return
	if st_t >= st_dur:
		state = St.IDLE
		dash_window = 0.14
		if is_player and i_guard:
			enter_guard()

## Critical hit ("riposte" / "visceral attack") on a kneeling enemy, or an execution:
## soldiers that are knocked down, or staggered with little HP left, are finished outright
## with a weapon-specific blow (rising cut, overhead cleave or impaling thrust).
func try_crit() -> bool:
	if battle == null or weapon.ranged:
		return false
	var best: Unit = null
	var bd := 40.0
	for e in battle.query(global_position, 44.0):
		if e.dead or e.faction == faction or e.spectator:
			continue
		var ok: bool = e.state == St.BROKEN
		if not ok and is_player and not e.is_boss and e.state == St.KNOCKDOWN and e.air_t >= e.air_dur:
			ok = true
		if not ok and is_player and not e.is_boss and not e.is_officer and e.state == St.STAGGER and e.hp < e.max_hp * 0.2:
			ok = true
		if not ok:
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = e
	if best == null:
		return false
	crit_exec = is_player and not (best.is_boss or best.is_officer)
	match weapon.id:
		"axe", "hammer", "glaive", "zhanmadao", "black_glaive":
			crit_style = "overhead"
		"spear":
			crit_style = "thrust"
		_:
			crit_style = "rising"
	state = St.CRIT
	st_t = 0.0
	st_dur = 0.5 if crit_exec else 0.62
	crit_target = best
	crit_done = false
	invuln = st_dur + 0.05
	aim = (best.global_position - global_position).normalized()
	best.state = St.CRIT
	best.st_t = 0.0
	best.st_dur = 0.7
	best.vel = Vector2.ZERO
	Game.slowmo(0.3 if crit_exec else 0.35, 0.32)
	if is_player and battle:
		battle.cam.push(0.5 if crit_exec else 0.4, 0.8)
	return true

func _st_crit(delta: float) -> void:
	st_t += delta
	if crit_target != null:
		# attacker
		var k := clampf(st_t / 0.22, 0.0, 1.0)
		match crit_style:
			"overhead":
				_set_wangle(lerpf(deg_to_rad(-175.0), deg_to_rad(35.0), k * k))
			"thrust":
				_set_wangle(lerpf(deg_to_rad(-10.0), 0.0, _ease_out(k)))
			_:
				_set_wangle(lerpf(deg_to_rad(-140.0), deg_to_rad(60.0), _ease_out(k)))
		if not crit_done and st_t >= 0.22:
			crit_done = true
			var t := crit_target
			if is_instance_valid(t) and not t.dead:
				var h := make_hit({"dmg": weapon.crit_mult, "pz": 200.0, "st": 0.0, "kb": 160.0 if crit_style != "overhead" else 60.0})
				h["crit"] = true
				if crit_exec:
					h["dmg"] = maxf(float(h["dmg"]), t.hp + 60.0)
					h["execution"] = true
				if is_player and Game.has_perk("executioner"):
					h["dmg"] = float(h["dmg"]) * 1.4
					hp = minf(max_hp, hp + max_hp * 0.15)
				t.state = St.KNOCKDOWN
				t.st_t = 0.0
				t.st_dur = 0.9
				t.take_hit(self, h)
			battle.decals.splat(crit_target.global_position, aim)
			if is_player:
				battle.impact(crit_target.global_position + Vector2(0, -10), 0.1 if not crit_exec else 0.08)
				battle.hud.ink_slash(battle.hud._to_screen(global_position + Vector2(0, -10)), aim)
				if crit_exec:
					Game.add_style("exec", 140.0, "EXECUTION", Color("#ff5a5a"))
					Game.stats["executions"] = int(Game.stats.get("executions", 0)) + 1
					battle.fx.text(crit_target.global_position + Vector2(0, -34), "EXECUTED", Color("#ff4d4d"))
				else:
					Game.add_style("crit", 120.0, "CRITICAL", Color("#ff5a5a"))
				Game.stats["crits"] += 1
				spirit = minf(MAX_SPIRIT, spirit + 25.0 * _spirit_k())
				Game.hitstop(0.16)
			battle.cam_shake(12.0 if crit_style == "overhead" else 8.0)
			Sfx.play_at("crit", global_position, 0.0)
			if crit_style == "overhead":
				Sfx.play_at("boom", global_position, -6.0, 1.3)
				battle.fx.ring(crit_target.global_position, 34.0, Color(0.9, 0.95, 1.0, 0.9), 0.35)
				battle.fx.debris(crit_target.global_position, 18.0)
			battle.fx.burst(crit_target.global_position + Vector2(0, -10), Color("#ff3344"), 22)
			battle.fx.blood_arc(crit_target.global_position + Vector2(0, -10), aim, 14.0)
			battle.fx.ring(crit_target.global_position + Vector2(0, -8), 26.0, Color(1, 0.85, 0.6, 0.9), 0.25)
		if st_t >= st_dur:
			crit_target = null
			state = St.IDLE
	else:
		# victim (held in place until the attacker's blow lands)
		if st_t >= st_dur:
			state = St.IDLE
			stance = 0.0

## A front kick: little damage, but it breaks guards and sends the enemy flying
## (into his comrades, into fires, onto stakes). Kicked soldiers can be executed.
func try_kick() -> bool:
	if kick_cd > 0.0 or weapon == null or mounted:
		return false
	if is_player and stamina <= 0.0:
		return false
	var m := Weapon.mv(0.06, 0.07, 0.2, 0.35, weapon.rest, weapon.rest, {"kick": true, "lunge": 110.0, "kb": 300.0,
		"pz": 999.0, "st": 22.0, "cost": 12.0, "sfx": "swing_fast", "arc": 120.0, "trail": 0.0})
	kick_cd = 0.5
	start_move(m, "kick")
	return state == St.ATTACK

## Throws the weapon in hand. It hits hard and lands on the ground; you fight on with a
## side knife until you pick a weapon up again.
func try_throw() -> bool:
	if weapon == null or weapon.id == "sidearm":
		if is_player and battle:
			battle.hud.alert("NOTHING TO THROW  -  PICK UP A WEAPON (F)", Color("#a9a3b8"))
		return false
	var m := Weapon.mv(0.12, 0.06, 0.24, 2.4, -150, 30, {"shot": "throw", "cost": 10.0, "sfx": "swing_heavy", "trail": 0.0})
	start_move(m, "throw")
	return state == St.ATTACK

func _fling_update(delta: float) -> void:
	flung_t -= delta
	if battle == null:
		return
	var src: Unit = flung_by if (flung_by != null and is_instance_valid(flung_by) and not flung_by.dead) else null
	if not hazard_hit:
		for hz in battle.hazards:
			var hzp: Vector2 = hz["pos"]
			if global_position.distance_to(hzp) < float(hz["r"]) + radius:
				hazard_hit = true
				battle.hazard_hurt(self, hz, src)
				if dead:
					return
				break
	if vel.length() < 120.0:
		return
	for e in battle.query(global_position, 18.0):
		if e == self or e.dead or e.faction != faction or flung_hits.has(e) or e.is_boss or e.spectator or e.is_player:
			continue
		if e.global_position.distance_to(global_position) > radius + e.radius + 3.0:
			continue
		flung_hits[e] = true
		var h: Dictionary = battle.impact_hit(8.0, global_position)
		h["knockdown"] = true
		e.take_hit(src, h)
		battle.fx.sparks(e.global_position + Vector2(0, -10), Color(0.9, 0.95, 1.0), 6)
		if src != null and src.is_player:
			Game.add_style("bowl", 60.0, "BOWLED OVER", Color("#9fe8ff"))

func try_flask() -> bool:
	if flasks <= 0:
		Sfx.play("ui", -6.0, 0.5)
		return false
	flasks -= 1
	state = St.DRINK
	st_t = 0.0
	st_dur = 0.7
	sk["healed"] = false
	return true

func _st_drink(delta: float) -> void:
	st_t += delta
	if not sk.get("healed", false) and st_t >= 0.35:
		sk["healed"] = true
		hp = minf(max_hp, hp + max_hp * 0.45)
		rally = 0.0
		Sfx.play("heal", -4.0)
		battle.fx.heal(self)
	if st_t >= st_dur:
		state = St.IDLE

func _st_stun(delta: float) -> void:
	st_t += delta
	if air_t < air_dur:
		st_t = minf(st_t, 0.05)
	if st_t >= st_dur:
		if state == St.BROKEN:
			stance = 0.0
		state = St.IDLE
		hyper = false

func stagger(dur: float) -> void:
	if state == St.DEAD:
		return
	if state == St.ATTACK and is_player == false and mv_phase == 0:
		attack_id += 1
	state = St.STAGGER
	st_t = 0.0
	st_dur = dur
	charging = false
	hyper = false

func break_stance(src: Unit) -> void:
	stance = 0.0
	state = St.BROKEN
	st_t = 0.0
	st_dur = 2.4 if is_boss else (2.0 if is_officer else 1.6)
	hyper = false
	charging = false
	Sfx.play_at("break", global_position, -2.0)
	if battle:
		battle.fx.ring(global_position + Vector2(0, -10), 20.0, Color(1, 0.9, 0.3, 1), 0.3)
		# words only for the player's own fights; the rest of the field reads by its rings
		if is_player or (src != null and src.is_player):
			battle.fx.text(global_position + Vector2(0, -30), "BROKEN", Color("#ffd23f"))
	if src and src.is_player:
		Game.add_style("break", 90.0, "STANCE BREAK", Color("#ffd23f"))
		Game.hitstop(0.08)

# ------------------------------------------------------------------ receiving damage
func _spirit_k() -> float:
	return 1.5 if (is_player and Game.has_perk("spirit_well")) else 1.0

func take_hit(src: Unit, h: Dictionary) -> String:
	if dead or spectator:
		return "none"
	var src_pos: Vector2 = h["src_pos"]
	var from := (src_pos - global_position).normalized()
	var facing := aim.dot(from) > 0.15
	var perilous: bool = h.get("perilous", false)
	var ranged: bool = h.get("ranged", false)
	# Invincibility frames (dash) — a perfect dodge earns style.
	if invuln > 0.0:
		if is_player and state == St.DASH:
			Game.add_style("dodge", 55.0, "CLOSE CALL", Color("#7cf0ff"))
			Game.stats["dodges"] += 1
			spirit = minf(MAX_SPIRIT, spirit + 5.0)
		return "dodged"
	if is_player and ranged and Game.has_perk("kings_umbrella"):
		return "dodged"
	if is_player and Game.god:
		return "dodged"
	if state == St.CLASH:
		return "blocked"
	# Blade lock: in a duel, two blows that meet in mid-swing lock the duelists together.
	if battle and battle.duel and src != null and duelist and src.duelist and not ranged and not perilous and facing \
			and state == St.ATTACK and mv_phase == 1 and battle.can_clash(self, src):
		battle.start_clash(self, src)
		return "clash"
	if state == St.SKILL and sk.get("armored", false) and facing and not perilous:
		Sfx.play_at("block", global_position, -3.0)
		battle.fx.sparks(global_position + Vector2(0, -12) + from * 6.0, Color(1, 0.9, 0.6), 6)
		return "blocked"
	# Parry
	if parry_t > 0.0 and facing and not perilous and state in [St.GUARD, St.IDLE]:
		if ranged:
			if is_player:
				Game.add_style("return", 140.0, "ARROW RETURN", Color("#9fe8ff"))
			Sfx.play_at("parry", global_position, -2.0, 1.2)
			battle.fx.sparks(global_position + Vector2(0, -12), Color(0.8, 0.95, 1.0), 10)
			return "reflect"
		_on_parry_success(src)
		return "parried"
	# Guard
	if state == St.GUARD and facing and not perilous:
		var cost: float = (float(h["st"]) * 1.1 + float(h["dmg"]) * 0.7) * weapon.guard_stab * float(h.get("guard_break", 1.0))
		if is_player and Game.has_perk("unbroken"):
			cost *= 0.7
		stamina -= cost
		stam_delay = 0.6
		var chip: float = float(h["dmg"]) * (1.0 - weapon.guard_absorb)
		if not is_player and not (src and src.is_player):
			chip *= 0.45
		hp -= chip
		vel += -from * float(h["kb"]) * 0.45
		guard_counter_t = 0.5
		guard_hit_t = 0.25
		Sfx.play_at("block", global_position, -3.0)
		battle.fx.sparks(global_position + Vector2(0, -12) + from * 6.0, Color(1, 0.9, 0.6), 6)
		if stamina <= 0.0:
			stamina = 0.0
			stagger(0.85)
			if is_player or (src != null and src.is_player):
				battle.fx.text(global_position + Vector2(0, -28), "GUARD BREAK", Color("#ff8c42"))
			Sfx.play_at("break", global_position, -4.0)
			if src and src.is_player:
				Game.add_style("gbreak", 70.0, "GUARD BREAK", Color("#ff8c42"))
		if is_player:
			battle.cam_shake(2.0)
		if hp <= 0.0:
			die(src, h)
			return "killed"
		return "blocked"
	# Clean hit
	var dmg: float = h["dmg"]
	if ranged:
		dmg *= formation_ranged_weakness
	# Cohesive ranks absorb frontal blows; the unprotected rear rewards flanking.
	if formation_bonus > 0.0 and not is_boss:
		var front_dot := formation_dir.dot(from)
		if front_dot > 0.2:
			dmg *= 1.0 - formation_bonus
		elif front_dot < -0.4 and not ranged:
			dmg *= 1.2

	var src_player := src != null and src.is_player
	if not is_player and not src_player:
		dmg *= 0.36
		if is_boss or is_officer:
			dmg *= 0.25
	if is_player and not src_player:
		dmg *= battle.enemy_dmg_mult
		if Game.aura_active():
			dmg *= 0.7
	if mounted and h.get("anti_cav", false):
		dmg *= 2.0
	if state == St.BROKEN:
		dmg *= 1.3
	if air_t < air_dur:
		dmg *= 1.25
	var was_winding := state == St.ATTACK and mv_phase == 0
	if is_player and mounted and horse_hp > 0.0:
		var to_horse := dmg * 0.5
		dmg -= to_horse
		horse_hp -= to_horse
		if horse_hp <= 0.0:
			dismount(true)
	hp -= dmg
	hit_flash = 0.07
	show_bar_t = 4.0
	if src_player:
		Game.stats["dmg"] += dmg
		Game.register_hit()
		src.spirit = minf(MAX_SPIRIT, src.spirit + dmg * 0.35 * src._spirit_k())
		src.rally_recover(dmg)
		if h.get("crit", false) or dmg >= 45.0:
			battle.fx.text(global_position + Vector2(randf_range(-6, 6), -40), str(int(round(dmg))),
				Color("#ffe8a3") if not h.get("crit", false) else Color("#ff4d4d"))
	if is_player:
		rally = minf(dmg * 0.9 + rally * 0.5, max_hp)
		rally_hold = 1.0
		Game.style_hit_taken(dmg)
		battle.cam_shake(3.0 + dmg * 0.08)
		battle.on_player_hurt(dmg)
	# Poise (flinch) and knockback
	var staggered := false
	# Bosses never flinch from ordinary hits: only stance breaks, parries and criticals stop them.
	var aura_armor := is_player and Game.aura_active() and not perilous
	if not hyper and not aura_armor and not is_boss and state != St.CRIT and state != St.KNOCKDOWN:
		poise -= float(h["pz"])
		if poise <= 0.0 or h.get("knockdown", false):
			poise = max_poise
			if h.get("knockdown", false):
				stagger(0.8)
				state = St.KNOCKDOWN
			elif state != St.BROKEN:
				stagger(0.26 + float(h["pz"]) * 0.006)
			staggered = true
			if was_winding and src_player:
				Game.add_style("interrupt", 50.0, "INTERRUPT", Color("#b0ff7a"))
	poise_t = 2.0
	var kb_scale := 1.0 if staggered else 0.35
	if mounted or is_boss:
		kb_scale *= 0.3
	if air_t < air_dur:
		kb_scale *= 0.25
	vel += -from * float(h["kb"]) * kb_scale
	if hp > 0.0:
		sq = Vector2(0.84, 1.1)
	if h.get("launch", false) and not mounted and not is_boss and hp > 0.0:
		if is_officer:
			stagger(0.6)
		else:
			air_dur = 0.85
			air_t = 0.0
			air_hits = 0
			stagger(1.0)
			state = St.KNOCKDOWN
			vel *= 0.3
			if src_player:
				Game.add_style("launch", 60.0, "LAUNCHED", Color("#9fe8ff"))
	elif air_t < air_dur and src_player:
		air_t = maxf(0.0, air_t - 0.3)
		air_hits += 1
		if air_hits == 2:
			Game.add_style("air", 90.0, "AIR COMBO", Color("#9fe8ff"))
	if h.get("fling", false) and not mounted and not is_boss and hp > 0.0:
		flung_t = 0.5
		flung_by = src
		flung_hits.clear()
		hazard_hit = false
		vel += -from * 90.0
		if not is_officer:
			stagger(0.9)
			state = St.KNOCKDOWN
	# Stance
	if not is_player and state != St.BROKEN and state != St.CRIT:
		stance += float(h["st"]) * (1.0 if src_player else 0.4)
		stance_t = 2.2
		if stance >= max_stance:
			break_stance(src)
	# Bleed
	var bl: float = h.get("bleed", 0.0)
	if bl > 0.0:
		bleed += bl
		if bleed >= 100.0:
			bleed = 0.0
			var extra := max_hp * (0.08 if is_boss else 0.16) + 14.0
			hp -= extra
			battle.fx.burst(global_position + Vector2(0, -10), Color("#c3122c"), 26)
			battle.fx.text(global_position + Vector2(0, -34), "HEMORRHAGE", Color("#ff2e4d"))
			if src_player:
				Game.add_style("bleed", 70.0, "HEMORRHAGE", Color("#ff2e4d"))
	# Feedback
	var heavy_hit: bool = float(h["dmg"]) > 30.0 or h.get("crit", false)
	Sfx.play_at("hit_heavy" if heavy_hit else "hit", global_position, -1.0 if (is_player or src_player) else -8.0)
	if not ranged and (src_player or is_player):
		Sfx.play_at("clank", global_position, -9.0, randf_range(0.9, 1.2))
	battle.fx.blood(global_position + Vector2(0, -10), -from, 5 if not heavy_hit else 12)
	if src_player or is_player:
		var crit_hit: bool = h.get("crit", false)
		battle.fx.hit_star(global_position + Vector2(0, -10) + from * 4.0, 16.0 if crit_hit else (11.0 if heavy_hit else 7.0),
			Color(1.0, 0.4, 0.32) if crit_hit else Color(1.0, 0.97, 0.88))
		if heavy_hit or hp <= 0.0:
			battle.fx.blood_arc(global_position + Vector2(0, -10), -from, 11.0 if heavy_hit else 8.0)
	if src_player and not h.get("crit", false):
		Game.hitstop((0.05 if not heavy_hit else 0.085) + (0.05 if hp <= 0.0 else 0.0))
		battle.cam.kick(-from * (2.0 if not heavy_hit else 3.5))
		battle.cam.punch(0.014 if not heavy_hit else 0.026)
		if hp <= 0.0:
			battle.cam.punch(0.03)
			battle.cam.roll_kick(randf_range(-0.014, 0.014))
		if hp <= 0.0:
			battle.cam_shake(3.5)
			Sfx.play_at("hit_heavy", global_position, -3.0, 0.75)
	if is_player:
		battle.cam.kick(-from * 3.0)
		battle.cam.punch(-0.02)
	if battle.duel:
		battle.cheer()
	if hp <= 0.0:
		die(src, h)
		return "killed"
	return "hit"

func rally_recover(dmg: float) -> void:
	if rally <= 0.0:
		return
	var k := 1.2 if Game.has_perk("bloodthirst") else 0.6
	var heal := minf(rally, dmg * k)
	hp = minf(max_hp, hp + heal)
	rally -= heal

func _on_parry_success(src: Unit) -> void:
	Sfx.play_at("parry", global_position, 0.0)
	battle.fx.sparks(global_position + Vector2(0, -12) + aim * 8.0, Color(1, 0.95, 0.7), 16)
	battle.fx.ring(global_position + Vector2(0, -12) + aim * 8.0, 18.0, Color(1, 1, 1, 0.9), 0.2)
	parry_t = 0.0
	parry_cd = 0.0
	battle.fx.hit_star(global_position + Vector2(0, -12) + aim * 8.0, 15.0, Color(1.0, 0.95, 0.75), 0.16)
	if is_player:
		if src != null and (src.is_boss or src.is_officer or src.kind == "guard"):
			battle.impact(global_position + Vector2(0, -12) + aim * 8.0, 0.07)
		else:
			battle.atmos.do_flash(0.12)
			battle.atmos.aberrate(3.0)
		Game.add_style("parry", 100.0, "PARRY", Color("#ffffff"))
		Game.stats["parries"] += 1
		spirit = minf(MAX_SPIRIT, spirit + 18.0 * _spirit_k())
		Game.hitstop(0.13)
		battle.cam_shake(4.0)
	if src == null or src.dead:
		return
	if src.is_player:
		# AI parried the player: a short, fair stagger instead of a full break.
		src.stagger(0.5)
		battle.fx.text(src.global_position + Vector2(0, -28), "PARRIED", Color("#ff8c42"))
	elif src.is_boss:
		src.stance += src.max_stance * 0.3
		src.stance_t = 2.5
		if src.stance >= src.max_stance:
			src.break_stance(self)
		else:
			src.stagger(0.55)
	else:
		src.break_stance(self if is_player else null)

func die(killer: Unit, h: Dictionary) -> void:
	if dead:
		return
	dead = true
	lod_tick = true
	hp = 0.0
	state = St.DEAD
	death_t = 0.0
	death_frame_t = 0.0
	air_dur = 0.0
	rig.modulate = Color.WHITE
	Sfx.play_at("death", global_position, -6.0 if not is_player else 0.0)
	if battle and mounted and randf() < (1.0 if is_player else 0.75):
		battle.spawn_horse(fac_key if not is_player else horse_fac, global_position, vel + move_vel)
	if mounted:
		mounted = false
		_refresh_sheets()
	var by_player := killer != null and is_instance_valid(killer) and killer.is_player
	# fall away from the blow: face the killer, get knocked back, the death animation plays out
	var src_pos: Vector2 = h.get("src_pos", global_position - aim * 10.0)
	var away := (global_position - src_pos).normalized()
	if away.length_squared() < 0.01:
		away = -aim
	dir8 = UnitArt.dir_index(-away)
	var heavy: bool = h.get("heavy", false) or h.get("crit", false) or h.get("launch", false) or float(h.get("kb", 0.0)) > 120.0
	vel = away * ((330.0 if heavy else 210.0) if by_player else 90.0)
	if is_boss:
		vel *= 0.3
	fly_dur = (0.32 if heavy else 0.2) if by_player else 0.0
	fly_t = 0.0
	if battle:
		battle.on_unit_killed(self, killer, h)

func _update_dead(delta: float) -> void:
	death_t += delta
	death_frame_t += delta
	var fl := UnitArt.frames(body_sheet, "death", UnitArt.DIR8[dir8][0])
	var n := maxi(1, fl.size())
	var fi := clampi(int(death_frame_t / 0.085), 0, n - 1)
	position += vel * delta
	vel = vel.move_toward(Vector2.ZERO, 520.0 * delta)
	if battle:
		position = battle.clamp_unit(self, position)
	var hop := 0.0
	if fly_t < fly_dur:
		fly_t += delta
		hop = sin(clampf(fly_t / fly_dur, 0.0, 1.0) * PI) * 10.0
		if fly_t >= fly_dur and battle:
			battle.fx.dust(global_position, 6)
			if battle.on_screen(global_position) and fly_dur > 0.25:
				battle.cam_shake(1.0)
	if not sk.get("pooled", false) and death_t > 0.45:
		sk["pooled"] = true
		if battle:
			battle.decals.blood_pool(global_position + Vector2(0, -1), 5.0 + randf() * 4.0 + (4.0 if is_boss else 0.0))
	rig.position = Vector2(0, -hop)
	_show_frame("death", fi)
	if fi >= n - 1 and death_t > 0.8 and vel.length() < 5.0:
		# done: rest as a corpse (the battle keeps the most recent ones as sprites)
		set_process(false)
		z_index = -1
		if battle:
			battle.add_corpse(self)

## Bakes this corpse into the ground decals and removes the node.
func settle_corpse() -> void:
	if battle and is_instance_valid(body) and body.texture:
		battle.decals.stamp_sprite(body, global_position)
	queue_free()

## Lands after being launched: a thump of dust, then stays down (open to an execution).
func _land() -> void:
	sq = Vector2(1.25, 0.75)
	if battle:
		battle.fx.dust(global_position, 5)
		if battle.on_screen(global_position):
			battle.cam_shake(2.5)
		Sfx.play_at("hit_heavy", global_position, -8.0, 0.6)
	state = St.KNOCKDOWN
	st_t = 0.0
	st_dur = 0.75

# ------------------------------------------------------------------ movement
func move_speed() -> float:
	var s := base_speed * speed_mult * (1.12 if is_player and Game.aura_active() else 1.0)
	if battle != null and battle.level_ctl != null and battle.level_ctl.on_ladder(global_position):
		s *= 0.55
	match state:
		St.GUARD:
			s *= 0.45
		St.DRINK:
			s *= 0.35
		St.ATTACK:
			if is_player:
				s *= 0.3 if mv_phase < 2 else 0.55
			else:
				s *= 0.15
			if charging:
				s *= 0.6
		St.SKILL:
			s *= float(sk.get("move", 0.0))
		St.DASH, St.STAGGER, St.BROKEN, St.KNOCKDOWN, St.CRIT, St.DEAD, St.CLASH:
			s = 0.0
	return s

func _integrate(delta: float) -> void:
	var desired := i_move.limit_length(1.0) * move_speed()
	var accel := 2200.0 if is_player else 680.0
	if mounted:
		accel = 360.0
	move_vel = move_vel.move_toward(desired, accel * delta)
	var total := move_vel + vel + sep * (0.35 if is_player else 1.0)
	if vel != Vector2.ZERO:
		vel = vel.move_toward(Vector2.ZERO, (1100.0 if state != St.DASH else 200.0) * delta)
	if total.length_squared() < 0.01:
		return
	var before := position
	var np := before + total * delta
	if battle:
		np = battle.clamp_unit(self, np)
	position = np
	step_acc += (np - before).length()
	if step_acc > (14.0 if mounted else 10.0):
		step_acc = 0.0
		if battle == null or not rig.visible:
			return
		if mounted:
			battle.decals.footprint(np + Vector2(-3, 0))
			battle.decals.footprint(np + Vector2(4, 1))
			if move_vel.length() > 120.0:
				battle.fx.snow_kick(np, -move_vel.normalized(), 3)
		else:
			sk["foot"] = -int(sk.get("foot", 1))
			battle.decals.footprint(np + Vector2(randf_range(-1, 1), 1.5 * int(sk["foot"])))
			if is_player:
				Sfx.play("step_snow" if battle.level == "snow_plains" else "step", -6.0, randf_range(0.85, 1.15), 0.08)

func _trample() -> void:
	if is_player and battle != null and battle.level == "commander_city":
		return
	var mvv := move_vel + (vel if is_player else Vector2.ZERO)
	var spd := mvv.length()
	if spd < 120.0 or battle == null:
		return
	var dir := mvv / spd
	var now := Game.now()
	for e in battle.query(global_position, 20.0):
		if e == self or e.dead or e.faction == faction:
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() > 16.0 or to.dot(dir) < 0.0:
			continue
		if now - float(trample_hits.get(e, -10.0)) < 0.9:
			continue
		trample_hits[e] = now
		if e.formation_braced and e.weapon.anti_cav and e.formation_dir.dot(-dir)>0.1:
			var counter: Dictionary = e.make_hit({"dmg":1.6,"pz":90.0,"st":35.0,"kb":50.0})
			counter["anti_cav"] = true
			take_hit(e,counter)
			move_vel *= 0.12
			vel = -dir*45.0
			if not dead:stagger(0.75)
			return
		var h := make_hit({"dmg": 1.0, "pz": 80.0, "st": 25.0, "kb": 220.0})
		h["knockdown"] = true
		e.take_hit(self, h)

# ------------------------------------------------------------------ visuals
func _visuals(delta: float) -> void:
	anim_t += delta
	guard_hit_t -= delta
	if absf(aim.x) > 0.12:
		face = 1 if aim.x > 0.0 else -1
	# soldiers outside the view skip all sprite work
	var vis: bool = battle == null or battle.in_view(global_position)
	if vis != rig.visible:
		rig.visible = vis
	if not vis:
		return
	if is_player and battle and fmod(anim_t, 2.2) < delta and battle.level == "snow_plains":
		battle.fx.breath(global_position + Vector2(3.0 * face, -24.0), float(face))
	_update_dir()
	_pick_frame(delta)
	# lean into a dash or a stagger, squash on impacts, hop when launched or cheering
	var lean_goal := 0.0
	match state:
		St.DASH:
			lean_goal = 0.16 * signf(dash_dir.x) if absf(dash_dir.x) > 0.2 else 0.0
		St.STAGGER:
			lean_goal = -0.1 * face
		St.ATTACK:
			if mv_phase == 1:
				lean_goal = 0.06 * face
	lean = lerpf(lean, lean_goal, 1.0 - exp(-delta * 18.0))
	sq = sq.lerp(Vector2.ONE, 1.0 - exp(-delta * 14.0))
	if absf(rig.rotation - lean) > 0.0005:
		rig.rotation = lean
	var want_scale := base_scale * sq / UnitArt.R
	if not rig.scale.is_equal_approx(want_scale):
		rig.scale = want_scale
	var by := 0.0
	if cheer_t > 0.0 and spectator:
		by = -absf(sin(anim_t * 14.0)) * 2.5
	if air_t < air_dur:
		by -= sin(clampf(air_t / air_dur, 0.0, 1.0) * PI) * 24.0
	if rig.position.y != by:
		rig.position = Vector2(0.0, by)
	# flash / tint (values above 1 whiten in the unit shader)
	var mod := tint
	if hit_flash > 0.0:
		mod = Color(2.4, 2.4, 2.4)
	elif is_player and invuln > 0.0 and state != St.DASH and state != St.CRIT and int(anim_t * 16.0) % 2 == 0:
		mod = Color(1.45, 1.4, 1.3, 0.8)
	elif state == St.BROKEN:
		mod = Color(1.0 + 0.25 * (0.5 + 0.5 * sin(anim_t * 14.0)), 1.15, 0.85)
	elif buff_t > 0.0:
		mod = Color(1.18, 1.04, 0.96)
	if rig.modulate != mod:
		rig.modulate = mod

## The facing direction (8-way): the aim while fighting, the way you move otherwise. A little
## hysteresis keeps it from flickering between two directions.
func _update_dir() -> void:
	var look := aim
	var moving := move_vel.length() > 30.0
	match state:
		St.DASH:
			look = dash_dir
		St.IDLE, St.DRINK:
			if moving and not _combat_focus():
				look = move_vel
		St.ATTACK, St.CRIT, St.SKILL, St.CLASH, St.GUARD:
			look = aim
	if look.length_squared() < 0.0001:
		return
	var snap := state == St.ATTACK or state == St.CRIT or state == St.SKILL or state == St.DASH
	var cur := dir8 * PI * 0.25
	if snap or absf(angle_difference(look.angle(), cur)) > PI / 8.0 + 0.14:
		dir8 = UnitArt.dir_index(look)

func _combat_focus() -> bool:
	if is_player:
		return combo_reset > 0.0 or i_guard
	if brain == null or spectator:
		return false
	var tg = brain.target
	return tg != null and is_instance_valid(tg) and global_position.distance_squared_to(tg.global_position) < 8100.0

func _nf(anim: String) -> int:
	return UnitArt.frames(body_sheet, anim, UnitArt.DIR8[dir8][0]).size()

func _prog(t: float, dur: float, n: int) -> int:
	return clampi(int(clampf(t / maxf(dur, 0.001), 0.0, 0.999) * n), 0, maxi(0, n - 1))

func _pick_frame(delta: float) -> void:
	var speed := move_vel.length()
	if mounted:
		_mounted_frame(delta)
		return
	match state:
		St.ATTACK:
			_attack_frame()
			return
		St.DASH:
			_show_frame("dodge", _prog(st_t, st_dur, _nf("dodge")))
			return
		St.STAGGER:
			if air_t < air_dur:
				_show_frame("hit", 1)
			else:
				_show_frame("hit", _prog(st_t, minf(st_dur, 0.5), _nf("hit")))
			return
		St.KNOCKDOWN:
			_knockdown_frame()
			return
		St.BROKEN:
			_show_frame("hit", 2 if int(anim_t * 3.0) % 2 == 0 else 3)
			return
		St.CRIT:
			if crit_target != null:
				var a := "a1"
				if crit_style == "thrust":
					a = "a3"
				elif crit_style == "overhead":
					a = "a2" if aset == "2h" else "a4"
				_timed_attack(a, st_t, 0.22, 0.32, st_dur)
			else:
				_show_frame("hit", 2)
			return
		St.DRINK:
			_show_frame("drink", _prog(st_t, st_dur, _nf("drink")))
			return
		St.SKILL:
			_skill_frame()
			return
		St.CLASH:
			_show_frame("block", 0)
			return
		St.GUARD:
			if guard_hit_t > 0.0:
				_show_frame("blockhit", _prog(0.25 - guard_hit_t, 0.25, _nf("blockhit")))
			else:
				_show_frame("block", int(anim_t * 2.0) % maxi(1, _nf("block")))
			return
	if spectator and cheer_t > 0.0:
		_show_frame("cheer", int(anim_t * 6.0) % maxi(1, _nf("cheer")))
	elif speed > 14.0:
		var running := speed > 105.0
		var anim := "run" if running else "walk"
		var rate := (1.25 * speed / 150.0) if running else (0.95 * speed / 72.0)
		run_phase = fposmod(run_phase + delta * clampf(rate, 0.5, 2.4), 1.0)
		var n := _nf(anim)
		_show_frame(anim, int(run_phase * n) % maxi(1, n))
	elif weapon.ranged and reload_t > 0.0 and is_player:
		_show_frame("reload", _prog(weapon.reload - reload_t, weapon.reload, _nf("reload")))
	else:
		run_phase = 0.0
		_show_frame("idle", int((anim_t + anim_ofs) * 3.6) % maxi(1, _nf("idle")))

## Attack frames follow the timing of the move itself: wind-up, active and recovery each map
## to their part of the baked animation, so the blade is mid-swing exactly while the hit is live.
func _attack_frame() -> void:
	var anim := mv_anim
	if anim == "shoot":
		match mv_phase:
			0:
				_show_frame("aim", 0 if charging else int(mv_t * 6.0) % 2)
			1:
				_show_frame("shoot", 1)
			_:
				_show_frame("shoot", 2 + int(clampf(mv_t / maxf(float(mv["r"]), 0.01), 0.0, 0.99) * 2.0))
		return
	var n := _nf(anim)
	if n == 0:
		anim = "a1"
		n = _nf(anim)
	var w := 3
	var a := 2
	var info = UnitArt.anim_info.get(aset + "/" + anim)
	if info != null:
		w = int(info["windup"])
		a = int(info["active"])
	elif n == 8:
		w = 2
		a = 4
	var fi := 0
	match mv_phase:
		0:
			fi = w - 1 if charging else _prog(mv_t, mv_w, w)
		1:
			fi = w + _prog(mv_t, float(mv["a"]), a)
		_:
			var rec: float = float(mv["r"]) * (1.0 if is_player else 1.3)
			fi = w + a + _prog(mv_t, rec, maxi(1, n - w - a))
	_show_frame(anim, mini(fi, n - 1))

## Frame for a timed swing (criticals, skills): wind-up until t_w, active until t_a.
func _timed_attack(anim: String, t: float, t_w: float, t_a: float, dur: float) -> void:
	var n := _nf(anim)
	var info = UnitArt.anim_info.get(aset + "/" + anim)
	var w := int(info["windup"]) if info != null else 2
	var a := int(info["active"]) if info != null else 2
	var fi := 0
	if t < t_w:
		fi = _prog(t, t_w, w)
	elif t < t_a:
		fi = w + _prog(t - t_w, t_a - t_w, a)
	else:
		fi = w + a + _prog(t - t_a, maxf(0.01, dur - t_a), maxi(1, n - w - a))
	_show_frame(anim, mini(fi, maxi(0, n - 1)))

func _skill_frame() -> void:
	var s: Array = SKILL_ANIMS.get(skill_id, ["a1", 0.1, 0.25])
	var anim: String = s[0]
	if anim == "spin" and _nf("spin") == 0:
		anim = "a2"
	if anim == "aim" and _nf("aim") == 0:
		anim = "a1"
	var dur: float = sk.get("dur", 0.6)
	match skill_id:
		"tempest":
			_show_frame(anim, int(st_t * 12.0) % maxi(1, _nf(anim)))
		"blade_dance":
			_show_frame("a1" if int(st_t * 10.0) % 2 == 0 else "a2", 3)
		"bulwark_rush":
			_show_frame("block", 0)
		_:
			_timed_attack(anim, st_t, s[1], s[2], dur)

func _knockdown_frame() -> void:
	if air_t < air_dur:
		_show_frame("hit", 1)
		return
	var nd := _nf("death")
	var ns := _nf("standup")
	var up_t := minf(0.4, st_dur * 0.45)
	if st_t < 0.3:
		_show_frame("death", _prog(st_t, 0.3, maxi(1, nd - 1)))
	elif st_t < st_dur - up_t or ns == 0:
		_show_frame("death", maxi(0, nd - 1))
	else:
		_show_frame("standup", _prog(st_t - (st_dur - up_t), up_t, ns))

var _last_horse = null

## On horseback: the horse walks or gallops with the speed (or rears when hit); the rider sits
## on the saddle point of that horse frame and fights with the upper-body animations.
func _mounted_frame(delta: float) -> void:
	var speed := move_vel.length() + (vel.length() * 0.5 if is_player else 0.0)
	var dk: Array = UnitArt.DIR8[dir8]
	var ha := "idle"
	var hn := UnitArt.frames("horse", "idle", dk[0]).size()
	var hfi := int((anim_t + anim_ofs) * 1.2) % maxi(1, hn)
	if state == St.STAGGER or state == St.KNOCKDOWN:
		ha = "hit"
		hfi = _prog(st_t, minf(st_dur, 0.5), UnitArt.frames("horse", "hit", dk[0]).size())
	elif speed > 120.0:
		ha = "gallop"
		run_phase = fposmod(run_phase + delta * clampf(speed / 175.0 * 1.9, 0.9, 2.8), 1.0)
		hfi = int(run_phase * 6.0) % 6
	elif speed > 14.0:
		ha = "walk"
		run_phase = fposmod(run_phase + delta * clampf(speed / 80.0, 0.5, 1.6), 1.0)
		hfi = int(run_phase * 6.0) % 6
	var hl: Array = UnitArt.frames("horse", ha, dk[0])
	if not hl.is_empty():
		var hf = hl[clampi(hfi, 0, hl.size() - 1)]
		if hf != _last_horse or dk[1] != _last_flip:
			_last_horse = hf
			_set_sprite(horse_spr, hf, dk[1])
	seat = UnitArt.saddle_at(ha, dir8, hfi) * UnitArt.R
	body.position = seat
	wpn.position = seat
	match state:
		St.ATTACK:
			_attack_frame()
		St.STAGGER, St.KNOCKDOWN, St.BROKEN:
			_show_frame("hit", _prog(st_t, minf(st_dur, 0.5), _nf("hit")))
		St.SKILL:
			_skill_frame()
		St.CRIT:
			_timed_attack("a2", st_t, 0.22, 0.32, st_dur)
		_:
			_show_frame("ride", int((anim_t + anim_ofs) * 1.5) % maxi(1, _nf("ride")))

var _last_body = null
var _last_wpn = null
var _last_flip := false

func _show_frame(anim: String, fi: int) -> void:
	var dk: Array = UnitArt.DIR8[dir8]
	if mounted and anim == "a4":
		anim = "a2"
	var fl: Array = UnitArt.frames(body_sheet, anim, dk[0])
	if fl.is_empty():
		anim = "ride" if mounted else "idle"
		fl = UnitArt.frames(body_sheet, anim, dk[0])
		if fl.is_empty():
			return
		fi = 0
	fi = clampi(fi, 0, fl.size() - 1)
	cur_anim = anim
	cur_frame = fi
	var flip: bool = dk[1]
	var fb = fl[fi]
	if fb != _last_body or flip != _last_flip:
		_last_body = fb
		_set_sprite(body, fb, flip)
	var fw = null
	if not dead and weapon != null:
		var wl: Array = UnitArt.frames(wpn_sheet, anim, dk[0])
		if fi < wl.size():
			fw = wl[fi]
	if fw == null:
		if wpn.visible:
			wpn.visible = false
		_last_wpn = null
	elif fw != _last_wpn or flip != _last_flip:
		_last_wpn = fw
		wpn.visible = true
		_set_sprite(wpn, fw, flip)
	_last_flip = flip

func _set_sprite(s: Sprite2D, fr, flip: bool) -> void:
	if fr == null:
		s.visible = false
		return
	s.visible = true
	s.texture = fr["tex"]
	s.region_rect = fr["rect"]
	s.flip_h = flip
	s.offset = Vector2(-(float(fr["w"]) - float(fr["ax"])) if flip else -float(fr["ax"]), -float(fr["ay"]))

## Where swing trails are drawn from: the feet, or the saddle on horseback.
func trail_origin() -> Vector2:
	if mounted:
		return global_position + (seat / UnitArt.R + Vector2(0, 4.0)) * base_scale.x
	return global_position

## Where the weapon tip is during the current swing (for glints and trails), in world space.
func weapon_tip() -> Vector2:
	var pts := UnitArt.trail(aset, mv_anim if state == St.ATTACK else "a1", dir8)
	var s := base_scale.x
	if pts.size() > 0:
		return trail_origin() + pts[0] * s
	return trail_origin() + Vector2(8.0 * face, -26.0) * s
