class_name CombatYard
extends Battle
## A compact playable combat loop: test six weapons against curated mixed groups
## without waiting for a siege to reach the interesting part of its combat.
const ARMOURY := ["jian","glaive","spear","hammer","daggers","bow"]
var round_number := 0
var round_delay := 2.0
var round_active := false
var yard_ui: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Engine.time_scale = 1
	Game.command_view = false
	Game.possess_slow = false
	W = 1200
	H = 900
	TOP = 40
	BOT = 860
	level = "combat_yard"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kill="):
			debug_kill_at = float(arg.substr(7))
	reserves = [0,0]
	caps = [8,8]
	level_ctl = YardLayout.new()
	_build()
	fg_grass.set_process(false)
	fg_grass.visible = false
	var p := spawn(0,"infantry",Vector2(570,580),"jian")
	take_control(p,true)
	cam.snap_to(p.position)
	interactables = BattleInteractables.new()
	add_child(interactables)
	interactables.battle = self
	interactables.spawn_prop(Vector2(390,490),false)
	interactables.spawn_prop(Vector2(800,410),true)
	_rebuild_grid()
	Sfx.boss_mode = false
	Sfx.start_music()
	hud.banner("THE COMBAT YARD","1-6 CHANGE WEAPON / LIGHT, LIGHT, HEAVY TO FINISH",Color("#e6c48b"),true,3.0)
	yard_ui = Control.new()
	yard_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	yard_ui.draw.connect(_draw_yard_ui)
	hud.get_parent().add_child(yard_ui)

func _process(delta: float) -> void:
	var dt := minf(delta,0.1)
	time += dt
	if debug_kill_at>=0 and time>=debug_kill_at and player!=null:
		debug_kill_at = -1
		player.die(null,{})
	_update_view_rect()
	_rebuild_grid()
	_separation()
	_pickups_update(dt)
	_aura_update(dt)
	_camera_shaders(dt)
	_commands()
	if round_active and alive[1]==0:
		round_active = false
		round_delay = 2
		if player != null:
			player.hp = minf(player.max_hp,player.hp+player.max_hp*0.25)
			player.flasks = player.max_flasks
			hud.banner("GROUND HELD","+25% HEALTH / FLASKS REFILLED",Color("#acd6ba"),false,2)
	if not round_active and not ended:
		round_delay -= dt
		if round_delay<=0:
			_start_round()
	yard_ui.queue_redraw()

func _commands() -> void:
	if input_locked() or Game.command_view or player==null:
		return
	if Input.is_action_just_pressed("interact"):
		_try_pickup()
	if Input.is_action_just_pressed("aura") and Game.aura_ready():
		activate_aura()
	for i in 6:
		if Input.is_physical_key_pressed(KEY_1+i) and player.weapon.id!=ARMOURY[i] and player.state==Unit.St.IDLE:
			player.set_weapon(Weapon.make(ARMOURY[i]))
			player.base_speed = 166-player.weapon.weight*8
			player.spirit = maxf(player.spirit,player.weapon.skill_cost)
			hud.alert(player.weapon.display_name(),Color("#e6c48b"))

func _start_round() -> void:
	round_number += 1
	round_active = true
	var wave := (round_number-1)%3
	var kinds: Array = [["infantry","infantry"],["spear","heavy","archer"],["officer","infantry","spear"]][wave]
	for i in kinds.size():
		var at := Vector2(430+i*135,280+(i%2)*35)
		var u := spawn(1,kinds[i],at,"jian" if kinds[i]=="infantry" else "glaive" if kinds[i]=="officer" else "")
		u.ai_aggro = 0.8
		if u.is_officer:
			u.max_hp = 200
			u.hp = 200
			u.is_officer = false # no campaign cut-in in the practice loop
		(u.brain as AIBrain).atk_cd = 0.5+i*0.3
	var lessons: Array = ["DODGE THROUGH A SWING / COUNTER WHILE THE RING IS GREEN", "KICK GUARDS / HEAVY ATTACKS BREAK STANCE", "MIX YOUR TOOLS / KEEP MOVING / FINISH THE OFFICER"]
	hud.banner("EXCHANGE %02d" % round_number,lessons[wave],Color("#e6c48b"),false,3)

func _on_player_death(_u: Unit) -> void:
	Game.stats["deaths"] += 1
	player = null
	_respawn.call_deferred()
func _respawn() -> void:
	var p := spawn(0,"infantry",Vector2(570,680),"jian")
	take_control(p,true)
	cam.snap_to(p.position)
	hud.alert("A FRESH START / TRY SHIFT JUST BEFORE THE HIT",Color("#e6c48b"))
	Game.event_log("yard respawn / controlled body restored")
func _draw_yard_ui() -> void:
	Game.text(yard_ui,Vector2(18,21),"COMBAT YARD",6,Color("#e6c48b"))
	Game.text(yard_ui,Vector2(622,21),"1 SWORD / 2 GLAIVE / 3 SPEAR / 4 HAMMER / 5 DAGGERS / 6 BOW",4,Color("#f2e8d3"),2)

class YardLayout extends RefCounted:
	var phase := 1
	func march_goal(u: Unit) -> Vector2:
		return u.battle.player.position if is_instance_valid(u.battle.player) else Vector2(600,480)
	func rout_dir(f: int) -> Vector2: return Vector2.LEFT if f==0 else Vector2.RIGHT
	func make_ground(rect: Rect2) -> ColorRect:
		var g := WorldBuilder.shader_rect("res://shaders/courtyard_ground.gdshader",rect)
		return g
	func populate(b: Battle) -> void:
		b.terrain = Terrain.new()
		b.add_child(b.terrain)
		b.terrain.setup(Rect2(65,65,1070,770))
		var rng := RandomNumberGenerator.new()
		rng.seed = 722
		# A walled court, an open sparring floor, a chapel and an armoury.
		for side in [90.0,1110.0]:
			for i in 12:
				b.scenery.prop("fence_stone",Vector2(side,140+i*55),{"scale":1.2})
			for i in 8:
				b.scenery.prop("oak_%d" % (i%4+1),Vector2(side+( -55 if side<600 else 55),200+i*80),{"scale":1.4,"sway":"tree"})
		b.scenery.prop("church_blue",Vector2(600,160),{"scale":1.8,"solid":true})
		b.scenery.prop("barracks_red",Vector2(260,230),{"scale":1.3,"solid":true})
		b.scenery.prop("smithy_blue",Vector2(960,230),{"scale":1.2,"solid":true})
		for i in 4:
			b.scenery.prop("target",Vector2(230+i*240,750),{"scale":1.6})
			b.scenery.prop("weaponrack",Vector2(250+i*240,780),{"scale":1.7})
		for at in [Vector2(210,360),Vector2(970,360)]:
			b.scenery.banner(at,Color("#a94837"),80)
		b.scenery.scatter_clumps(Rect2(110,120,980,620),35,Vector2i(3,6),18,["clover_1","grass_1","petals_1"],rng,func(p: Vector2):return p.distance_to(Vector2(600,480))<260,Vector2(0.7,1.1),Color(0.8,0.9,0.75))
	func atmos_key() -> String: return "siege"
	func on_ladder(_p: Vector2) -> bool: return false
	func reachable(_a,_b) -> bool: return true
	func falling(_u) -> bool: return false
	func try_fall(_u,_p: Vector2) -> bool: return false
	func elevation(_p: Vector2) -> int: return 0
	func markers() -> Array: return []
	func objective() -> String: return "KEEP THE INITIATIVE / PERFECT DODGES PRIME A COUNTER"
