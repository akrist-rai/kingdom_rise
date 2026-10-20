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
	"infantry": {"hp": 60.0, "poise": 14.0, "stance": 50.0, "speed": 80.0, "xp": 12.0, "skill": 0.15, "aggro": 0.6, "windup": 2.2},
	"spear": {"hp": 60.0, "poise": 14.0, "stance": 50.0, "speed": 78.0, "xp": 12.0, "skill": 0.15, "aggro": 0.6, "windup": 2.2},
	"archer": {"hp": 45.0, "poise": 8.0, "stance": 35.0, "speed": 82.0, "xp": 14.0, "skill": 0.1, "aggro": 0.5, "windup": 4.0},
	"heavy": {"hp": 130.0, "poise": 45.0, "stance": 95.0, "speed": 66.0, "xp": 28.0, "skill": 0.25, "aggro": 0.6, "windup": 1.5},
	"cavalry": {"hp": 140.0, "poise": 60.0, "stance": 90.0, "speed": 175.0, "xp": 32.0, "skill": 0.1, "aggro": 0.8, "windup": 1.4},
	"officer": {"hp": 420.0, "poise": 95.0, "stance": 150.0, "speed": 92.0, "xp": 220.0, "skill": 0.55, "aggro": 0.95, "windup": 1.3},
	"guard": {"hp": 170.0, "poise": 70.0, "stance": 110.0, "speed": 82.0, "xp": 45.0, "skill": 0.35, "aggro": 0.8, "windup": 1.45},
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

# Visuals
var frames: Dictionary
var body: Sprite2D
var wpn: Sprite2D
var wpn2: Sprite2D
var shield_spr: Sprite2D
var shadow: Sprite2D
var sh_body: Sprite2D
var sh_wpn: Sprite2D
var cape: Cape = null
const CAPE_SEG := 3.0
const CAPE_PLAYER := [Color("#ff6a55"), Color("#c3262f"), Color("#6e1220"), Color("#f1c35c")]
const CAPE_GENERAL := [Color("#b884f0"), Color("#6a35a8"), Color("#2f1450"), Color("#e6cf8f")]
var anim_t := 0.0
var weapon_angle := 0.0
var wpn_front := true
var step_acc := 0.0
var body_off := Vector2(-10, -22)
var tint := Color.WHITE

# ------------------------------------------------------------------ setup
func setup(b, fac: int, k: String, w: Weapon) -> void:
	battle = b
	faction = fac
	fac_key = "qin" if fac == 0 else "zhao"
	kind = k
	mounted = k == "cavalry"
	is_boss = k == "general"
	is_officer = k == "officer"
	radius = 9.0 if mounted else (8.0 if is_boss else 6.0)
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
	frames = Art.units[fac_key + "_" + k]
	if mounted:
		body_off = Vector2(-17, -31)
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
	shadow = Sprite2D.new()
	shadow.texture = Art.tex["shadow_big"] if (mounted or is_boss) else Art.tex["shadow"]
	shadow.position = Vector2(0, -1)
	add_child(shadow)
	wpn = Sprite2D.new()
	wpn.centered = false
	add_child(wpn)
	_add_fist(wpn)
	body = Sprite2D.new()
	body.centered = false
	body.offset = body_off
	body.texture = frames["idle"][0]
	add_child(body)
	if is_boss:
		base_scale = Vector2(1.35, 1.35)
		body.scale = base_scale
		shadow.scale = Vector2(1.2, 1.2)
	if battle != null and battle.shadows != null:
		sh_body = battle.shadows.add_sprite(body.texture, body_off)
		sh_wpn = battle.shadows.add_sprite(null, Vector2.ZERO)

## The soldier's fist, drawn over the weapon grip (the weapon sprite's origin is its pivot).
func _add_fist(w: Sprite2D) -> void:
	var f := Sprite2D.new()
	f.texture = Art.tex["hand"]
	w.add_child(f)

func set_weapon(w: Weapon) -> void:
	weapon = w
	var wd: Dictionary = Art.weapons[w.tex_key]
	wpn.texture = wd["tex"]
	weapon_angle = aim.angle() + deg_to_rad(w.rest) * face
	if wpn2:
		wpn2.queue_free()
		wpn2 = null
	if w.id == "daggers":
		wpn2 = Sprite2D.new()
		wpn2.centered = false
		wpn2.texture = wd["tex"]
		add_child(wpn2)
		move_child(wpn2, 1)
		_add_fist(wpn2)
	if shield_spr:
		shield_spr.queue_free()
		shield_spr = null
	if w.shield:
		shield_spr = Sprite2D.new()
		shield_spr.texture = Art.tex["shield_" + fac_key]
		add_child(shield_spr)
	ammo = w.clip
	reload_t = 0.0
	combo = 0
	if is_boss:
		wpn.scale = Vector2(1.2, 1.2)

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
	enable_cape(CAPE_PLAYER)
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
	var key := "qin_%s_m" % kind
	frames = Art.units[key] if Art.units.has(key) else Art.units["qin_cavalry"]
	body_off = Vector2(-17, -31)
	body.offset = body_off
	radius = 9.0
	horse_max = 140.0
	horse_hp = horse_max
	base_speed = 210.0 - weapon.weight * 8.0
	shadow.texture = Art.tex["shadow_big"]
	if cape != null:
		cape.reset(_cape_anchor(), face)
	Sfx.play_at("dash", global_position, -2.0, 0.7)

## Gets off the horse. thrown = the horse was killed under you.
func dismount(thrown: bool) -> void:
	if not mounted:
		return
	mounted = false
	if kind == "cavalry":
		kind = "spear"
	frames = Art.units[fac_key + "_" + kind]
	body_off = Vector2(-10, -22)
	body.offset = body_off
	radius = 6.0
	base_speed = 150.0 - weapon.weight * 8.0
	shadow.texture = Art.tex["shadow"]
	if cape != null:
		cape.reset(_cape_anchor(), face)
	if battle == null:
		return
	if thrown:
		battle.decals.stamp(Art.units["qin_cavalry"]["dead"], global_position + Vector2(-17, -16), face < 0)
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
	delta = minf(delta, 1.0 / 30.0)
	if dead:
		_update_dead(delta)
		return
	var _p0 := Time.get_ticks_usec()
	if brain:
		brain.think(self, delta)
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
	_integrate(delta)
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
		Sfx.play_at("block", global_position, -3.0)
		battle.fx.sparks(global_position + Vector2(0, -12) + from * 6.0, Color(1, 0.9, 0.6), 6)
		if stamina <= 0.0:
			stamina = 0.0
			stagger(0.85)
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
		dmg *= 0.45
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
		battle.fx.text(global_position + Vector2(randf_range(-6, 6), -26), str(int(round(dmg))),
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
		if hp <= 0.0:
			battle.cam_shake(3.5)
			Sfx.play_at("hit_heavy", global_position, -3.0, 0.75)
	if is_player:
		battle.cam.kick(-from * 3.0)
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
	hp = 0.0
	state = St.DEAD
	death_t = 0.0
	air_dur = 0.0
	body.self_modulate = Color.WHITE
	body.flip_h = face < 0
	wpn.visible = false
	if wpn2:
		wpn2.visible = false
	if shield_spr:
		shield_spr.visible = false
	shadow.visible = false
	if sh_body:
		sh_body.visible = false
		sh_wpn.visible = false
	Sfx.play_at("death", global_position, -6.0 if not is_player else 0.0)
	if battle and mounted and randf() < (1.0 if is_player else 0.75):
		battle.spawn_horse(fac_key if not is_player else horse_fac, global_position, vel + move_vel)
	var by_player := killer != null and is_instance_valid(killer) and killer.is_player
	if not mounted and not is_boss:
		# knocked off their feet: the body spins through the air and lands a few steps away
		var src_pos: Vector2 = h.get("src_pos", global_position - aim * 10.0)
		var away := (global_position - src_pos).normalized()
		if away.length_squared() < 0.01:
			away = -aim
		fly_dur = 0.42 if by_player else 0.3
		fly_t = 0.0
		fly_spin = randf_range(7.0, 11.0) * (1.0 if away.x >= 0.0 else -1.0)
		vel = away * (240.0 if by_player else 110.0)
		body.texture = frames["hurt"]
		body.offset = body_off
	else:
		_lie_down()
		if battle:
			battle.decals.blood_pool(global_position + Vector2(0, -2), 5.0 + randf() * 4.0 + (6.0 if mounted else 0.0))
	if battle:
		battle.on_unit_killed(self, killer, h)

func _lie_down() -> void:
	body.rotation = 0.0
	body.position = Vector2.ZERO
	body.scale = base_scale
	body.texture = frames["dead"]
	var ts: Vector2 = frames["dead"].get_size()
	body.offset = Vector2(-ts.x * 0.5, -ts.y + 6.0)

func _update_dead(delta: float) -> void:
	death_t += delta
	if fly_t < fly_dur:
		fly_t += delta
		var k := clampf(fly_t / fly_dur, 0.0, 1.0)
		body.position.y = -sin(k * PI) * 13.0
		body.rotation += fly_spin * delta
		position += vel * delta
		if fly_t >= fly_dur:
			_lie_down()
			vel *= 0.35
			if battle:
				battle.fx.snow_puff(global_position)
				battle.decals.blood_pool(global_position + Vector2(0, -2), 5.0 + randf() * 4.0)
		return
	position += vel * delta
	vel = vel.move_toward(Vector2.ZERO, 600.0 * delta)
	if death_t > 1.4:
		body.modulate.a = clampf(1.0 - (death_t - 1.4) / 0.4, 0.0, 1.0)
	if death_t > 1.0 and not sk.get("stamped", false):
		sk["stamped"] = true
		if battle:
			battle.decals.stamp(body.texture, global_position + body.offset, body.flip_h)
	if death_t > 1.8:
		queue_free()

## Lands after being launched: a thump of snow, then stays down (open to an execution).
func _land() -> void:
	sq = Vector2(1.25, 0.75)
	if battle:
		battle.fx.snow_puff(global_position)
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
	var before := position
	position += total * delta
	vel = vel.move_toward(Vector2.ZERO, (1100.0 if state != St.DASH else 200.0) * delta)
	if battle:
		position = battle.clamp_unit(self, position)
	var moved := (position - before).length()
	step_acc += moved
	if step_acc > 9.0 and not mounted:
		step_acc = 0.0
		if battle:
			sk["foot"] = -int(sk.get("foot", 1))
			battle.decals.footprint(global_position + Vector2(randf_range(-1, 1), 1.5 * int(sk["foot"])))
		if is_player:
			Sfx.play("step", -14.0, randf_range(0.8, 1.2), 0.08)
	elif step_acc > 14.0 and mounted:
		step_acc = 0.0
		if battle:
			battle.decals.footprint(global_position + Vector2(-3, 0))
			battle.decals.footprint(global_position + Vector2(4, 1))
			if move_vel.length() > 120.0:
				battle.fx.snow_kick(global_position, -move_vel.normalized(), 3)

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
	if is_player and battle and fmod(anim_t, 2.2) < delta and not dead:
		battle.fx.breath(global_position + Vector2(3.0 * face, -17.0 if not mounted else -26.0), float(face))
	if absf(aim.x) > 0.12:
		var nf := 1 if aim.x > 0.0 else -1
		if nf != face:
			sq = Vector2(0.72, 1.06)
		face = nf
	var moving := move_vel.length() > 14.0
	var t: Texture2D
	match state:
		St.STAGGER, St.KNOCKDOWN:
			t = frames["hurt"]
		St.BROKEN:
			t = frames["broken"]
		St.CRIT:
			t = frames["broken"] if crit_target == null else frames["idle"][0]
		_:
			if moving:
				var rate := 10.0 * clampf(move_vel.length() / 90.0, 0.6, 1.6)
				t = frames["walk"][int(anim_t * rate) % frames["walk"].size()]
			else:
				t = frames["idle"][int(anim_t * 2.2) % 2]
	body.texture = t
	body.flip_h = face < 0
	body.offset = body_off
	# lean into a run, pull back in the wind-up, throw the weight into the swing
	var lean_goal := 0.0
	match state:
		St.ATTACK:
			lean_goal = (-0.1 if mv_phase == 0 else (0.16 if mv_phase == 1 else 0.04)) * face
		St.DASH:
			lean_goal = 0.22 * signf(dash_dir.x) if absf(dash_dir.x) > 0.2 else 0.0
		St.STAGGER, St.KNOCKDOWN:
			lean_goal = -0.18 * face
		_:
			if moving:
				lean_goal = clampf(move_vel.x / maxf(base_speed, 1.0), -1.0, 1.0) * 0.1
	lean = lerpf(lean, lean_goal, 1.0 - exp(-delta * 18.0))
	body.rotation = lean
	sq = sq.lerp(Vector2.ONE, 1.0 - exp(-delta * 12.0))
	body.scale = base_scale * sq
	var bx := 0.0
	if state == St.ATTACK:
		if mv_phase == 0:
			bx = -1.0 * face
		elif mv_phase == 1:
			bx = face * (3.0 if mv.get("kick", false) else 2.0)
		else:
			bx = face * 1.0
	body.position.x = bx
	var by := 0.0
	if moving and (state == St.IDLE or state == St.GUARD) and not mounted:
		var rate := 10.0 * clampf(move_vel.length() / 90.0, 0.6, 1.6)
		by = -absf(sin(anim_t * rate * PI * 0.5)) * 1.1
	if cheer_t > 0.0 and spectator:
		by = -1.0 if int(anim_t * 8.0) % 2 == 0 else 0.0
	if air_t < air_dur:
		by -= sin(clampf(air_t / air_dur, 0.0, 1.0) * PI) * 22.0
	body.position.y = by
	# flash / tint
	if hit_flash > 0.0:
		body.self_modulate = Color(3.2, 3.0, 3.0)
	elif is_player and invuln > 0.0 and state != St.DASH and state != St.CRIT and int(anim_t * 16.0) % 2 == 0:
		body.self_modulate = Color(1.6, 1.5, 1.2, 0.75)
	elif state == St.BROKEN:
		body.self_modulate = Color(1.25, 1.15, 0.8)
	elif buff_t > 0.0:
		body.self_modulate = Color(1.25, 1.05, 0.95)
	else:
		body.self_modulate = tint
	_weapon_visual()
	_update_shadow()
	_update_cape(delta)

# ------------------------------------------------------------------ cape (Verlet cloth)
func enable_cape(cols: Array) -> void:
	if cape == null:
		cape = Cape.new()
		add_child(cape)
		move_child(cape, body.get_index())
	cape.setup(cols, CAPE_SEG * (1.35 if is_boss else 1.0), 1.4 if is_boss else 1.0)
	cape.reset(_cape_anchor(), face)

func _cape_anchor() -> Vector2:
	var y := -21.0 if mounted else (-18.0 if is_boss else -13.0)
	return global_position + Vector2(-1.5 * face, y + body.position.y)

func _update_cape(delta: float) -> void:
	if cape != null:
		cape.step(delta, _cape_anchor(), face)

## Long shadow cast away from the sun (body and weapon), see ShadowLayer.
func _update_shadow() -> void:
	if sh_body == null:
		return
	var sv: Vector2 = battle.shadow_vec
	var o := global_position
	sh_body.texture = body.texture
	sh_body.flip_h = body.flip_h
	sh_body.offset = body.offset
	sh_body.transform = Transform2D(Vector2(body.scale.x, 0.0), -sv * body.scale.y, o + Vector2(body.position.x, 0.0))
	sh_wpn.visible = wpn.visible
	if wpn.visible:
		sh_wpn.texture = wpn.texture
		sh_wpn.flip_v = wpn.flip_v
		sh_wpn.offset = wpn.offset
		sh_wpn.transform = Transform2D(0.0, o) * Transform2D(Vector2(1.0, 0.0), -sv, Vector2.ZERO) * wpn.transform

func _exit_tree() -> void:
	if sh_body and is_instance_valid(sh_body):
		sh_body.queue_free()
	if sh_wpn and is_instance_valid(sh_wpn):
		sh_wpn.queue_free()

func _weapon_visual() -> void:
	if state == St.IDLE or state == St.GUARD or state == St.DASH or state == St.DRINK:
		var rest_rel := deg_to_rad(weapon.rest)
		if state == St.GUARD and not weapon.shield and not weapon.ranged:
			rest_rel = deg_to_rad(-60.0)
		if state == St.DRINK:
			rest_rel = deg_to_rad(80.0)
		if cheer_t > 0.0 and spectator:
			rest_rel = deg_to_rad(-80.0)
		var target := aim.angle() + rest_rel * face
		weapon_angle = rotate_toward(weapon_angle, target, 0.35)
	elif state == St.STAGGER or state == St.KNOCKDOWN or state == St.BROKEN:
		weapon_angle = rotate_toward(weapon_angle, PI * 0.5, 0.2)
	elif state == St.CLASH:
		weapon_angle = aim.angle() - deg_to_rad(38.0 + sin(anim_t * 40.0) * 3.0) * face
	var wd: Dictionary = Art.weapons[weapon.tex_key]
	var pivot: Vector2 = wd["pivot"]
	var tex_h := float(wd["tex"].get_height())
	var flip := face < 0
	var shoulder := Vector2(2.0 * face, -22.0 if mounted else -13.0)
	if is_boss:
		shoulder = Vector2(3.0 * face, -17.0)
	var hand := shoulder + Vector2.from_angle(weapon_angle) * 3.0 + Vector2(body.position.x * 0.6, body.position.y)
	if state == St.ATTACK and mv_phase == 1 and mv.get("shape", "arc") == "thrust":
		hand += Vector2.from_angle(weapon_angle) * float(mv.get("ext", 0.0)) * clampf(mv_t / float(mv["a"]) * 2.0, 0.0, 1.0)
	elif state == St.CRIT and crit_target != null and crit_style == "thrust":
		hand += Vector2.from_angle(weapon_angle) * 10.0 * clampf(st_t / 0.22, 0.0, 1.0)
	wpn.position = hand
	wpn.rotation = weapon_angle
	wpn.flip_v = flip
	wpn.offset = Vector2(-pivot.x, -(tex_h - 1.0 - pivot.y) if flip else -pivot.y)
	# draw weapon behind the body when it points upward
	var front := sin(weapon_angle) > -0.25
	if front != wpn_front:
		wpn_front = front
		move_child(wpn, get_child_count() - 1 if front else 1)
	if wpn2:
		wpn2.position = Vector2(-2.0 * face, -12.0) + Vector2.from_angle(weapon_angle + PI * 0.8 * face) * 3.0
		wpn2.rotation = weapon_angle + PI * 0.8 * face
		wpn2.flip_v = flip
		wpn2.offset = wpn.offset
	if shield_spr:
		shield_spr.flip_h = flip
		var raised: bool = state == St.GUARD or (state == St.ATTACK and mv.get("bash", false)) or (state == St.SKILL and skill_id == "bulwark_rush")
		if raised:
			shield_spr.position = Vector2(6.0 * face, -11.0)
			if shield_spr.get_index() != get_child_count() - 1:
				move_child(shield_spr, get_child_count() - 1)
		else:
			shield_spr.position = Vector2(-4.0 * face, -11.0)
			if shield_spr.get_index() != 1:
				move_child(shield_spr, 1)
