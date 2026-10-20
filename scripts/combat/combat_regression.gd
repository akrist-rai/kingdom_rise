class_name CombatRegression
extends RefCounted
## Engine integration checks. Run with --autotest --combat-test. The live battle
## is frozen, but these call the exact production states, damage and prop paths.
var failures := 0
var checks := 0
func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("[combat-test] FAIL " + label)
	else:
		print("[combat-test] PASS " + label)
func run(b: Battle) -> void:
	b.frozen = true
	b.input_lock = 0
	Game.god = false
	var p := b.player
	p.position = Vector2(1100,2410)
	p.invuln = 0
	p.state = Unit.St.IDLE
	p.aim = Vector2.RIGHT
	p.i_aim = Vector2.RIGHT
	p.i_guard = true
	p.i_guard_pressed = true
	p.parry_cd = 0
	p.queued = ""
	p._st_idle(0.016)
	expect(p.state==Unit.St.GUARD and p.parry_t>0.1,"first guard frame opens parry window")
	var foe := b.spawn(1,"infantry",p.position+Vector2(25,0),"jian")
	foe.invuln = 0
	foe.aim = Vector2.LEFT
	var hit := foe.make_hit(foe.weapon.combo[0])
	var hp := p.hp
	expect(p.take_hit(foe,hit)=="parried" and p.hp==hp,"timed guard deflects a real melee hit")
	expect(p.riposte_t>0,"parry primes the counterattack")
	p.state = Unit.St.IDLE
	p.i_guard = false
	p.i_guard_pressed = false
	p.stamina = 0.5
	p.start_move(p.weapon.heavy,"heavy")
	expect(p.state==Unit.St.IDLE and p.stamina>=0,"unaffordable attacks never overdraft stamina")
	p.stamina = 0
	p.dash_charges = 2
	expect(p.try_dash() and p.dash_charges==1,"dodge works at zero stamina")
	expect(p.try_dash() and p.dash_charges==0,"second dodge charge works")
	expect(not p.try_dash(),"third dodge waits for a recharge")
	p._timers(Unit.DASH_RECHARGE+0.01)
	expect(p.dash_charges==1,"dodge charges recover on the production timer")
	p.invuln = 0.2
	p.state = Unit.St.DASH
	p.dash_rewarded = false
	var before: int = Game.stats["dodges"]
	p.take_hit(foe,hit)
	p.take_hit(foe,hit)
	expect(Game.stats["dodges"]==before+1,"one perfect dodge reward per evade")
	p.state = Unit.St.IDLE
	p.stamina = p.max_stamina
	p.invuln = 0
	var original: Dictionary = p.weapon.combo[0].duplicate(true)
	p.start_move(p.weapon.combo[0],"light")
	expect(p.mv.get("riposte",false) and p.mv["dmg"]>original["dmg"],"perfect dodge empowers the next strike")
	expect(p.weapon.combo[0]==original,"counterattacks leave shared weapon data immutable")
	p.i_dash = true
	p.i_light = true
	p._buffer(0.016)
	expect(p.queued=="dash","simultaneous defence takes priority over attacks")
	p.i_dash = false
	p.i_light = false
	p.state = Unit.St.IDLE
	p.queued = ""
	p.combo = 2
	p.combo_reset = 0.45
	p.stamina = 0
	var finishers_before: int = Game.stats.get("finishers",0)
	p.do_heavy()
	expect(p.state==Unit.St.IDLE and p.combo==2 and int(Game.stats.get("finishers",0))==finishers_before,"unaffordable finisher preserves combo and grants no reward")
	p.stamina = p.max_stamina
	p.do_heavy()
	expect(p.state==Unit.St.ATTACK and p.mv_kind=="finisher" and p.combo==0 and int(Game.stats.get("finishers",0))==finishers_before+1,"two lights into heavy starts and rewards a real finisher")
	# A temporary wall lies between two actual actors, not a mocked query.
	p.state = Unit.St.IDLE
	p.queued = ""
	p.position = Vector2(1100,2410)
	foe.position = p.position+Vector2(25,0)
	foe.state = Unit.St.IDLE
	foe.hp = foe.max_hp
	foe.invuln = 0
	b.terrain.add(Rect2(1110,2390,5,40),"combat_test_wall")
	b._rebuild_grid()
	p.start_move(p.weapon.combo[0],"light")
	var enemy_hp := foe.hp
	p._hit_check()
	expect(foe.hp==enemy_hp,"solid walls block melee damage")
	Skills._hit(p,foe,1.0,{})
	expect(foe.hp==enemy_hp,"solid walls also block melee skills")
	b.level = "combat_yard"
	b.proj.shots.clear()
	b.proj.shoot(p,p.global_position+Vector2(0,-9),Vector2.RIGHT,400,p.make_hit(p.mv),"arrow",0)
	b.proj._update_shots(0.08)
	expect(foe.hp==enemy_hp and b.proj.shots.is_empty(),"direct city and yard arrows stop at solid walls")
	b.level = "siege"
	expect(b.pick_target(p,Vector2.RIGHT,35)==null,"aim assist rejects enemies behind walls")
	b.terrain.set_active("combat_test_wall",false)
	p.mv_hit.clear()
	p._hit_check()
	expect(foe.hp<enemy_hp,"same attack connects after the obstruction is removed")
	var after_hit := foe.hp
	p._hit_check()
	expect(foe.hp==after_hit,"one hit per victim per active swing")
	# Real supply prop: the strike path pays its reward exactly once.
	var crate_at := Vector2(1200,2480)
	b.interactables.spawn_prop(crate_at,false)
	var crate = b.interactables.props.back()
	p.position = crate_at-Vector2(24,0)
	p.aim = Vector2.RIGHT
	p.i_aim = Vector2.RIGHT
	p.stamina = 50
	p.riposte_t = 0
	p.start_move(p.weapon.combo[0],"light")
	b.interactables.strike(p,30,p.mv)
	var supplied := p.stamina
	b.interactables.strike(p,30,p.mv)
	expect(crate.broken and supplied>50 and p.stamina==supplied,"supply cache breaks and pays out only once")
	expect(not b.terrain.is_active(crate.tag),"broken supply footprint is removed from navigation")
	# Every loadout uses the same production attack phases, including shots and
	# reloads. This catches a broken weapon definition before a pickup reaches play.
	for id in ["jian","glaive","spear","hammer","daggers","bow","crossbow","axe","zhanmadao","sword_shield","black_glaive","sidearm"]:
		p.set_weapon(Weapon.make(id))
		p.state = Unit.St.IDLE
		p.stamina = p.max_stamina
		p.riposte_t = 0
		p.queued = ""
		p.i_light_held = false
		p.i_heavy_held = false
		p.i_guard = false
		p.do_light()
		var started := p.state==Unit.St.ATTACK
		p._st_attack(p.mv_w+0.01)
		p._st_attack(float(p.mv["a"])+0.01)
		p._st_attack(float(p.mv["r"])+0.01)
		expect(started and p.state==Unit.St.IDLE and p.stamina>=0,"loadout phases / "+id)
	p.set_weapon(Weapon.make("jian"))
	p.stamina = p.max_stamina
	var oil_at := Vector2(1280,2490)
	b.interactables.spawn_prop(oil_at,true)
	var oil = b.interactables.props.back()
	var victim := b.spawn(1,"heavy",oil_at+Vector2(25,0),"hammer")
	victim.invuln = 0
	victim.state = Unit.St.IDLE
	p.position = oil_at-Vector2(24,0)
	p.aim = Vector2.RIGHT
	p.i_aim = Vector2.RIGHT
	p.start_move(p.weapon.combo[0],"light")
	b._rebuild_grid()
	var victim_hp := victim.hp
	b.interactables.strike(p,30,p.mv)
	expect(oil.broken and victim.hp<victim_hp,"marked oil barrel deals real area damage")
	# A resting cursor remains the aim source while WASD changes direction.
	p.state = Unit.St.IDLE
	p.queued = ""
	var brain := PlayerBrain.new()
	brain.mouse_used = true
	brain.last_mouse = p.get_viewport().get_mouse_position()
	Game.autotest = false
	Input.action_press("move_left")
	brain.think(p,0.016)
	var to_cursor := p.get_global_mouse_position()-(p.global_position+Vector2(0,-10))
	expect(p.i_aim.dot(to_cursor.normalized())>0.999,"mouse aim stays authoritative after five seconds at rest")
	Input.action_release("move_left")
	Game.autotest = true
	Game._hitstop_ready = 0
	Game.hitstop(0.03)
	var stop := Game._hitstop_until
	Game.hitstop(0.15)
	expect(Game._hitstop_until==stop,"crowd impacts cannot extend the current hit stop")
	print("[combat-test] RESULT ",checks-failures,"/",checks," passed")
	b.get_tree().quit(0 if failures==0 else 1)
