class_name CommanderDirector
extends FormationDirector
## Full company command: selection, orientation, queued routes, morale and cohesion.
const COMMAND_FORMS=["LINE","COLUMN","SCHILTRON","WEDGE","LOOSE"]
var selected:Array=[]
var selection_start=Vector2.ZERO
var box_select=false
var right_start=Vector2.ZERO
var right_down=false
var right_screen=Vector2.ZERO
var order_mode="move"
var panel_hover=false
var ai_tick=1.0
var rally_cd=0.0
var planning=false
var smoke_stage=0
var smoke_clock=0.0
var test_enabled=false
var order_count=0
var reform_count=0
var routes_completed=0
var autoplay_stage=0
var arrows_ordered=0
var selections=0

func setup(b) -> void:
	battle=b
	initialized=true
	process_mode=Node.PROCESS_MODE_ALWAYS
	test_enabled=OS.get_cmdline_user_args().has("--commander-test")
func enlist(_u) -> void: pass

func add_company(name:String,kind:String,faction:int,at:Vector2,count:int,form:String="LINE") -> int:
	var id=regiments.size()
	var d=Vector2.RIGHT if faction==0 else Vector2.LEFT
	var r={"id":id,"name":name,"kind":kind,"f":faction,"at":at,"dest":at,"dir":d,"wanted_dir":d,"men":[],"initial":count,"cohesion":1.0,"morale":95.0,"form":form,"order":"hold","queue":[],"path":PackedVector2Array(),"path_i":0,"routing":false,"fire":true,"volley":0.0,"casualty_t":0.0,"ranged":kind=="archer","charge_t":0.0,"routed_logged":false}
	regiments.append(r)
	for i in count:
		var weapon="spear" if kind in ["spear","cavalry"] else "bow" if kind=="archer" else "glaive" if kind=="heavy" else "sword_shield"
		var pos=at+_local_slot(r,i,count)
		pos=battle.terrain.push_out(pos,7.0)
		var u=battle.spawn(faction,kind,pos,weapon)
		u.regiment=id
		u.regiment_slot=i
		var brain=RegimentBrain.new()
		brain.setup(u)
		u.brain=brain
		u.aim=d
		u.ai_aggro=0.72
		r["men"].append(u)
	var standard=CompanyStandard.new()
	standard.company=r
	battle.world.add_child(standard)
	return id

func _unhandled_input(event:InputEvent) -> void:
	if battle==null or battle.ended or battle.hud.pause_open or battle.hud.manual:return
	if event is InputEventKey and event.pressed and not event.echo:
		var key=event.physical_keycode
		if key==KEY_TAB:
			set_planning(not planning)
		elif key==KEY_1:set_form("LINE")
		elif key==KEY_2:set_form("COLUMN")
		elif key==KEY_3:set_form("SCHILTRON")
		elif key==KEY_4:set_form("WEDGE")
		elif key==KEY_5:set_form("LOOSE")
		elif key==KEY_X:hold_selected()
		elif key==KEY_C:order_mode="charge"; battle.hud.alert("CHARGE / RIGHT CLICK A TARGET",GOLD)
		elif key==KEY_Z:order_mode="attack"; battle.hud.alert("ATTACK MOVE / RIGHT CLICK A TARGET",GOLD)
		elif key==KEY_V:volley_at(get_global_mouse_position())
		elif key==KEY_F:toggle_fire()
		elif key==KEY_R:rally()
		elif key==KEY_G:select_all()
		elif key>=KEY_6 and key<=KEY_9:
			var index=key-KEY_6
			if index<4:select_company(index,event.shift_pressed)
	if event is InputEventMouseButton:
		var screen=get_viewport().get_mouse_position()
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _hud_click(screen):return
				if screen.y>302:return
				selection_start=screen
				box_select=true
			else:
				if box_select:
					_finish_selection(screen,event.shift_pressed)
					box_select=false
		elif event.button_index==MOUSE_BUTTON_RIGHT:
			if event.pressed and screen.y<302:
				right_down=true
				right_start=_mouse_world()
				right_screen=screen
			elif right_down:
				var vector=_mouse_world()-right_start
				var facing=vector.normalized() if screen.distance_to(right_screen)>10 else Vector2.ZERO
				issue_orders(right_start,facing,order_mode,event.shift_pressed)
				right_down=false
				order_mode="move"

func _mouse_world()->Vector2:
	var screen=get_viewport().get_mouse_position()
	if CommanderHud.MAP_RECT.has_point(screen):return (screen-CommanderHud.MAP_RECT.position)/CommanderHud.MAP_RECT.size*Vector2(Battle.W,Battle.H)
	return get_global_mouse_position()
func _hud_click(p:Vector2)->bool:
	if CommanderHud.MAP_RECT.has_point(p):
		battle.cam.follow=false
		battle.cam.position=(p-CommanderHud.MAP_RECT.position)/CommanderHud.MAP_RECT.size*Vector2(Battle.W,Battle.H)
		return true
	if p.y>309 and p.y<347:
		for id in 8:
			if Rect2(13+id*58,310,55,35).has_point(p):
				select_company(id,Input.is_physical_key_pressed(KEY_SHIFT))
				return true
	if p.y>277 and p.y<302:
		for i in 5:
			if Rect2(177+i*68,278,65,23).has_point(p):
				set_form(COMMAND_FORMS[i])
				return true
	if Rect2(545,12,80,25).has_point(p):
		set_planning(not planning)
		return true
	return false

func select_company(id:int,additive:bool=false)->void:
	if id<0 or id>=regiments.size() or regiments[id]["f"]!=0:return
	if not additive:selected.clear()
	if selected.has(id):
		if additive:selected.erase(id)
	else:selected.append(id)
	selections+=1
	Sfx.play("ui",-17)
func select_all()->void:
	selected.clear()
	for r in regiments:
		if r["f"]==0 and not r["men"].is_empty() and not r["routing"]:selected.append(r["id"])
func _finish_selection(end:Vector2,additive:bool)->void:
	if not additive:selected.clear()
	if end.distance_to(selection_start)<5:
		var best=-1
		var dist=34.0
		for r in regiments:
			if r["f"]!=0 or r["men"].is_empty():continue
			for u in r["men"]:
				if not is_instance_valid(u) or u.dead:continue
				var screen=battle.cam.world_to_screen(u.position+Vector2(0,-9))
				var distance=screen.distance_to(end)
				if distance<dist:
					dist=distance
					best=r["id"]
		if best>=0:select_company(best,additive)
	else:
		var box=Rect2(selection_start,end-selection_start).abs()
		for r in regiments:
			if r["f"]!=0 or r["men"].is_empty():continue
			var hits=0
			for u in r["men"]:
				if is_instance_valid(u) and not u.dead and box.has_point(battle.cam.world_to_screen(u.position)):hits+=1
			if hits>0 and not selected.has(r["id"]):selected.append(r["id"])
		selections+=1

func set_planning(on:bool)->void:
	planning=on
	get_tree().paused=on
	battle.hud.pause_open=false
	Sfx.play("drum",-15)
func set_form(form:String)->void:
	var changed=0
	for id in selected:
		var r=regiments[id]
		if not compatible(r,form):continue
		r["form"]=form
		changed+=1
		reform_count+=1
	if changed==0:
		battle.hud.alert("SELECT SPEARS FOR SCHILTRON, HORSE FOR WEDGE, BOWS FOR LOOSE",GOLD)
	else:
		battle.hud.alert("%s / %d COMPANIES REFORM" % [form,changed],GOLD)
		Sfx.play("drum",-12)
func compatible(r:Dictionary,form:String)->bool:
	if form=="SCHILTRON":return r["kind"]=="spear"
	if form=="WEDGE":return r["kind"]=="cavalry"
	if form=="LOOSE":return r["kind"]=="archer"
	return true
func hold_selected()->void:
	for id in selected:
		var r=regiments[id]
		r["order"]="brace" if r["kind"]=="spear" and r["form"]=="SCHILTRON" else "hold"
		r["dest"]=r["at"]
		r["queue"].clear()
		r["path"]=PackedVector2Array()
	battle.hud.alert("HOLD / FACE THE ENEMY",GOLD)

func issue_orders(point:Vector2,facing:Vector2=Vector2.ZERO,order:String="move",queued:bool=false)->void:
	if selected.is_empty():return
	var center=Vector2.ZERO
	for id in selected:center+=regiments[id]["at"]
	center/=selected.size()
	if facing.length_squared()<0.1:facing=(point-center).normalized()
	if facing.length_squared()<0.1:facing=Vector2.RIGHT
	var side=facing.orthogonal()
	for i in selected.size():
		var r=regiments[selected[i]]
		if r["routing"]:continue
		var goal=point+side*(i-(selected.size()-1)*0.5)*178.0
		goal.x=clampf(goal.x,60,Battle.W-80)
		goal.y=clampf(goal.y,60,Battle.BOT-60)
		goal=battle.terrain.push_out(goal,18)
		var command={"point":goal,"dir":facing,"order":order}
		if queued:r["queue"].append(command)
		else:
			r["queue"].clear()
			_begin_order(r,command)
	order_count+=1
	battle.hud.alert(("QUEUED / " if queued else "ORDER / ")+order.to_upper(),GOLD)
	Sfx.play("horn_short",-15)
func _begin_order(r:Dictionary,command:Dictionary)->void:
	r["dest"]=command["point"]
	r["wanted_dir"]=command["dir"]
	r["order"]=command["order"]
	r["path"]=battle.terrain.path(r["at"],r["dest"])
	r["path_i"]=1 if r["path"].size()>1 else 0
	r["charge_t"]=8.0 if r["order"]=="charge" else 0.0
	if r["order"]=="charge" and r["kind"]=="cavalry":r["form"]="WEDGE"

func _local_slot(r:Dictionary,i:int,n:int)->Vector2:
	var form=r["form"]
	var mounted=r["kind"]=="cavalry"
	var space=25.0 if mounted else 14.5
	var depth=30.0 if mounted else 19.0
	var columns=6 if mounted else 8
	if form=="COLUMN":columns=2 if mounted else 3
	elif form=="SCHILTRON":columns=maxi(4,ceili(sqrt(n)))
	elif form=="LOOSE":columns=8;space=24.0;depth=27.0
	var x=0.0
	var y=0.0
	if form=="WEDGE":
		var row=floori(sqrt(i))
		x=(i-row*row-row)*25.0
		y=(row-1.8)*32.0
	else:
		var rows=ceili(float(n)/columns)
		x=(i%columns-(columns-1)*0.5)*space
		y=(i/columns-(rows-1)*0.5)*depth
	var d:Vector2=r["dir"]
	return d.orthogonal()*x-d*y
func regiment_goal(u)->Vector2:
	if u.regiment<0 or u.regiment>=regiments.size():return u.position
	var r=regiments[u.regiment]
	return r["at"]+_local_slot(r,u.regiment_slot,r["men"].size())
func squad_goal(u)->Vector2:return regiment_goal(u)

func _process(delta:float)->void:
	if not initialized:return
	if get_tree().paused or battle.ended:
		queue_redraw()
		return
	delta=minf(delta,1.0/30.0)
	rally_cd=maxf(0,rally_cd-delta)
	tick-=delta
	if tick<=0:
		tick=0.25
		for r in regiments:_update_company(r,0.25)
	ai_tick-=delta
	if ai_tick<=0:
		ai_tick=2.0
		_enemy_orders()
	if test_enabled:_smoke_test(delta)
	if OS.get_cmdline_user_args().has("--commander-autoplay"):_autoplay()
	queue_redraw()

func _update_company(r:Dictionary,dt:float)->void:
	r["men"]=r["men"].filter(func(u):return is_instance_valid(u) and not u.dead)
	var men:Array=r["men"]
	if men.is_empty():return
	var count=men.size()
	r["volley"]=maxf(0,r["volley"]-dt)
	r["charge_t"]=maxf(0,r["charge_t"]-dt)
	r["casualty_t"]=maxf(0,r["casualty_t"]-dt)
	var center=Vector2.ZERO
	var together=0
	for i in count:
		var u=men[i]
		u.regiment_slot=i
		center+=u.position
		if u.position.distance_to(regiment_goal(u))<42:together+=1
	center/=count
	r["cohesion"]=float(together)/count
	if r["at"].distance_to(center)>180:r["at"]=r["at"].lerp(center,0.06)
	if count<r["initial"]*0.24 or r["morale"]<18:
		r["routing"]=true
		if not r["routed_logged"]:
			r["routed_logged"]=true
			battle.hud.alert(r["name"]+" / ROUTING",GOLD)
	if r["routing"]:return
	if battle.player!=null and r["f"]==0 and center.distance_to(battle.player.position)<370 and r["casualty_t"]<=0:
		r["morale"]=minf(100,r["morale"]+dt*0.7)
	var path:PackedVector2Array=r["path"]
	var index:int=r["path_i"]
	var moving=r["order"] in ["move","attack","charge"]
	if moving:
		if path.is_empty():
			path=battle.terrain.path(r["at"],r["dest"])
			r["path"]=path
			r["path_i"]=1 if path.size()>1 else 0
			index=r["path_i"]
		if index<path.size():
			var goal=path[index]
			var to:Vector2=goal-r["at"]
			var speed=105.0 if r["kind"]=="cavalry" else 54.0 if r["kind"]=="heavy" else 64.0
			if r["form"]=="COLUMN":speed*=1.10
			if r["form"]=="SCHILTRON":speed*=0.70
			if r["charge_t"]>0:speed*=1.3
			if r["cohesion"]<0.35:speed*=0.45
			r["at"]=r["at"].move_toward(goal,speed*dt)
			if to.length()>6:
				r["dir"]=r["dir"].slerp(to.normalized(),minf(1,dt*1.8)).normalized()
			if r["at"].distance_to(goal)<12:r["path_i"]+=1
		elif r["at"].distance_to(r["dest"])<28 or path.size()>0:
			routes_completed+=1
			if not r["queue"].is_empty():_begin_order(r,r["queue"].pop_front())
			else:r["order"]="hold";r["path"]=PackedVector2Array()
	else:
		r["dir"]=r["dir"].slerp(r["wanted_dir"],minf(1,dt*1.8)).normalized()
	for u in men:
		u.formation_attack=1.0+(0.24*r["cohesion"] if r["form"]=="WEDGE" and r["charge_t"]>0 else 0.0)
		u.formation_bonus=(0.28 if r["form"]=="SCHILTRON" and not moving else 0.16 if r["form"]=="LINE" else 0.0)*r["cohesion"]
		u.formation_dir=r["dir"]
		u.formation_braced=r["form"]=="SCHILTRON" and not moving and r["cohesion"]>0.50
		u.formation_ranged_weakness=1.18 if r["form"]=="SCHILTRON" else 1.0
		u.speed_mult=1.30 if r["charge_t"]>0 and u.mounted else 1.1 if r["form"]=="COLUMN" else 0.85 if r["form"]=="SCHILTRON" else 1.0
		if u.formation_braced:
			var away:Vector2=u.position-r["at"]
			if away.length()>32:u.formation_dir=away.normalized()
		if not r["fire"] and u.weapon.ranged and u.brain is RegimentBrain:u.brain.target=null

func _enemy_orders()->void:
	if battle.ended:return
	for r in regiments:
		if r["f"]!=1 or r["routing"] or r["men"].is_empty():continue
		var nearest=null
		var distance=INF
		for ally in regiments:
			if ally["f"]!=0 or ally["routing"] or ally["men"].is_empty():continue
			var ds=r["at"].distance_to(ally["at"])
			if ds<distance:distance=ds;nearest=ally
		if nearest==null:continue
		if r["kind"]=="cavalry" and (battle.time>60 or distance<500):
			var aim=nearest["at"]
			for ally in regiments:
				if ally["f"]==0 and ally["kind"]=="archer" and not ally["men"].is_empty():aim=ally["at"];break
			_begin_order(r,{"point":aim,"dir":(aim-r["at"]).normalized(),"order":"charge"})
		elif r["ranged"]:
			if distance<150:
				var goal=r["at"]+(r["at"]-nearest["at"]).normalized()*110
				goal=battle.terrain.push_out(goal,18)
				_begin_order(r,{"point":goal,"dir":(nearest["at"]-r["at"]).normalized(),"order":"move"})
		elif distance<450 and r["at"].distance_to(r["dest"])<60:
			var aim=nearest["at"]
			_begin_order(r,{"point":aim,"dir":(aim-r["at"]).normalized(),"order":"attack"})

func casualty(id:int)->void:
	if id<0 or id>=regiments.size():return
	var r=regiments[id]
	r["morale"]=maxf(0,r["morale"]-2.3)
	r["casualty_t"]=6.0
func volley_at(point:Vector2)->void:
	var fired=0
	for id in selected:
		var r=regiments[id]
		if not r["ranged"] or r["men"].is_empty() or r["volley"]>0 or r["routing"]:continue
		if r["at"].distance_to(point)>345 or battle.terrain.blocked(r["at"],point):continue
		var archer=r["men"][0]
		var hit=archer.make_hit({"dmg":0.7,"pz":10,"st":8,"kb":12})
		hit["ranged"]=true
		battle.proj.rain(archer,point,55,r["men"].size(),0.7,hit)
		r["volley"]=18.0
		fired+=1
		arrows_ordered+=1
	battle.hud.alert("VOLLEY / %d COMPANIES" % fired if fired>0 else "SELECT READY BOWS WITHIN RANGE AND LINE OF SIGHT",GOLD)
func toggle_fire()->void:
	for id in selected:
		var r=regiments[id]
		if r["ranged"]:r["fire"]=not r["fire"]
func rally()->void:
	if rally_cd>0:return
	rally_cd=35.0
	for r in regiments:
		if r["f"]==0 and r["at"].distance_to(battle.player.position)<420:
			r["morale"]=minf(100,r["morale"]+15)
			if r["men"].size()>r["initial"]*0.3:r["routing"]=false;r["routed_logged"]=false
	Sfx.play("horn",-8)
	battle.hud.alert("THE COMMANDER RALLIES THE NEARBY COMPANIES",GOLD)

func _smoke_test(delta:float)->void:
	smoke_clock+=delta
	if smoke_clock>0.8 and smoke_stage==0:
		select_company(0)
		set_form("COLUMN")
		issue_orders(Vector2(1050,1240),Vector2.RIGHT,"move")
		issue_orders(Vector2(1400,1230),Vector2.RIGHT,"attack",true)
		assert(regiments[0]["queue"].size()==1,"Queued order missing")
		assert(regiments[0]["path"].size()>1,"Company path missing")
		assert(battle.player.mounted,"Commander must be mounted")
		assert(not compatible(regiments[0],"WEDGE"),"Infantry accepted cavalry wedge")
		set_form("SCHILTRON")
		assert(regiments[0]["form"]=="SCHILTRON","Spear schiltron failed")
		select_company(5)
		set_form("WEDGE")
		assert(regiments[5]["form"]=="WEDGE","Cavalry wedge failed")
		smoke_stage=1
	elif smoke_clock>1.6 and smoke_stage==1:
		select_company(3)
		set_form("LOOSE")
		assert(regiments[3]["form"]=="LOOSE","Archer loose order failed")
		assert(_hud_click(Vector2(75,320)),"Company card did not receive the click")
		assert(selected==[1],"Company card selected the wrong company")
		var soldier=regiments[1]["men"][0]
		var screen=battle.cam.world_to_screen(soldier.position+Vector2(0,-9))
		selection_start=screen
		_finish_selection(screen,false)
		assert(selected==[1],"Clicking a soldier did not select its company")
		select_company(0)
		for i in regiments[0]["men"].size():assert(regiment_goal(regiments[0]["men"][i]).is_finite(),"Invalid slot")
		hold_selected()
		rally()
		assert(regiments[0]["order"]=="brace","Spear brace order failed")
		# Exercise the actual mounted collision against a braced spear, then restore actors.
		var spear=regiments[0]["men"][0]
		var horse=regiments[15]["men"][0]
		var saved=[spear.position,spear.hp,spear.formation_braced,spear.formation_dir,horse.position,horse.hp,horse.horse_hp,horse.move_vel,horse.vel,horse.state]
		spear.position=Vector2(305,2450)
		spear.formation_braced=true
		spear.formation_dir=Vector2.LEFT
		horse.position=Vector2(290,2450)
		horse.move_vel=Vector2(175,0)
		horse.aim=Vector2.RIGHT
		horse.invuln=0
		battle._rebuild_grid()
		horse._trample()
		assert(spear.hp==saved[1],"Braced spears took charge trample damage")
		assert(horse.move_vel.length()<30,"Braced spears did not arrest the charge")
		assert(horse.hp<saved[5] or horse.horse_hp<saved[6],"Charge counter did not damage cavalry")
		spear.position=saved[0];spear.hp=saved[1];spear.formation_braced=saved[2];spear.formation_dir=saved[3]
		horse.position=saved[4];horse.hp=saved[5];horse.horse_hp=saved[6];horse.move_vel=saved[7];horse.vel=saved[8];horse.state=saved[9]
		battle._rebuild_grid()
		smoke_stage=2
		_test_planning.call_deferred()
		print("[commander-test] PASS mounted commander, selection, queued movement, navigation, troop-specific formations, brace and rally; companies=",regiments.size()," soldiers=",battle.units.size())

func _draw()->void:
	if not initialized:return
	# Formation previews and selection are restrained ink strokes, never terrain symbols.
	for r in regiments:
		if r["men"].is_empty():continue
		var selected_now=selected.has(r["id"])
		if selected_now:
			for u in r["men"]:
				if not is_instance_valid(u) or u.dead:continue
				var p:Vector2=u.position
				draw_line(p+Vector2(-3,2),p+Vector2(0,4),Color("#f6de9d"),1.0,true)
				draw_line(p+Vector2(0,4),p+Vector2(3,2),Color("#f6de9d"),1.0,true)
			if r["order"] in ["move","attack","charge"]:
				var p:Vector2=r["dest"]
				var d:Vector2=r["wanted_dir"]
				draw_line(p-d.orthogonal()*48,p+d.orthogonal()*48,Color(0.96,0.86,0.61,0.65),1.1,true)
				# Display the actual route around buildings, then queued waypoints.
				var route: PackedVector2Array=r["path"]
				var previous: Vector2=r["at"]
				for k in range(int(r["path_i"]),route.size()):
					draw_dashed_line(previous,route[k],Color(0.96,0.86,0.61,0.4),1.0,10,true)
					previous=route[k]
				for command in r["queue"]:
					draw_dashed_line(previous,command["point"],Color(0.65,0.86,0.81,0.35),0.8,9,true)
					previous=command["point"]
					draw_arc(previous,5,0,TAU,16,Color(0.65,0.86,0.81,0.8),1.0,true)
	if right_down:
		var end=_mouse_world()
		var d=(end-right_start).normalized()
		if d.length_squared()<0.1:d=Vector2.RIGHT
		draw_line(right_start,end,Color("#f7dfa2"),1.2,true)
		for index in selected.size():
			var r=regiments[selected[index]].duplicate(false)
			r["dir"]=d
			var at=right_start+d.orthogonal()*(index-(selected.size()-1)*0.5)*178
			for i in r["men"].size():
				var pos=at+_local_slot(r,i,r["men"].size())
				var col=Color(0.94,0.85,0.61,0.65) if not battle.terrain.solid_at(pos,7) else Color(0.82,0.38,0.27,0.8)
				draw_line(pos-d*2-d.orthogonal()*2,pos+d*2,col,0.8,true)
				draw_line(pos+d*2,pos-d*2+d.orthogonal()*2,col,0.8,true)

func _autoplay()->void:
	if battle.time>1 and autoplay_stage==0:
		selected=[0,1,2]
		set_form("COLUMN")
		issue_orders(Vector2(950,1290),Vector2.RIGHT,"attack")
		selected=[3,4]
		issue_orders(Vector2(770,1240),Vector2.RIGHT,"move")
		selected=[5,6]
		set_form("COLUMN")
		issue_orders(Vector2(1000,1900),Vector2.RIGHT,"move")
		autoplay_stage=1
	elif battle.time>16 and autoplay_stage==1:
		selected=[0,1,2]
		set_form("LINE")
		issue_orders(Vector2(1220,1270),Vector2.RIGHT,"attack")
		selected=[5,6]
		issue_orders(Vector2(1760,1740),Vector2.UP,"charge")
		autoplay_stage=2
	elif battle.time>38 and autoplay_stage==2:
		selected=[0,2]
		set_form("SCHILTRON")
		issue_orders(Vector2(1740,1290),Vector2.RIGHT,"attack")
		selected=[3,4]
		issue_orders(Vector2(1320,1260),Vector2.RIGHT,"attack")
		autoplay_stage=3

class CompanyStandard extends Node2D:
	var company:Dictionary
	var sprite:Sprite2D
	var t=0.0
	func _ready()->void:
		sprite=Sprite2D.new()
		sprite.centered=false
		sprite.offset=Vector2(-3,-43)
		add_child(sprite)
	func _process(delta:float)->void:
		if company.is_empty():return
		visible=not company["men"].is_empty()
		if not visible:return
		t+=delta
		position=company["at"]+company["dir"].orthogonal()*-44
		var faction="qin" if company["f"]==0 else "zhao"
		sprite.texture=Art.tex["banner_"+faction+"_"+str(int(t*5)%3)]

func _test_planning()->void:
	var before=battle.time
	set_planning(true)
	select_company(1)
	issue_orders(Vector2(750,1300),Vector2.RIGHT,"move")
	await get_tree().create_timer(0.25,true,false,true).timeout
	assert(is_equal_approx(battle.time,before),"Battle advanced during planning pause")
	assert(regiments[1]["dest"].distance_to(Vector2(750,1300))<1,"Paused orders were not applied")
	set_planning(false)
	print("[planning-test] PASS battle paused while company orders remained active")
