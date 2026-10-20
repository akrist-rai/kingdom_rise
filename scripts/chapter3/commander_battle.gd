class_name CommanderBattle
extends Battle
## A separate third chapter: commander-led companies and capture objectives, no personal duel loop.
var result_delay=0.0
var death_reason=""
func _ready()->void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	Engine.time_scale=1.0
	Game.command_view=false
	get_tree().paused=false
	Game.rank=4
	Game.xp=6500
	level="commander_city"
	W=3600.0
	H=2700.0
	TOP=35.0
	BOT=2665.0
	reserves=[0,0]
	reserves_max=[0,0]
	caps=[300,320]
	level_ctl=CommanderCityLevel.new()
	_build()
	tactics=CommanderDirector.new()
	add_child(tactics)
	tactics.setup(self)
	_deploy()
	_rebuild_grid()
	Sfx.boss_mode=false
	Sfx.start_music()
	Sfx.play("horn",-9)
	Input.mouse_mode=Input.MOUSE_MODE_HIDDEN
	level_ctl.intro()
	if OS.get_cmdline_user_args().has("--objective-test"):configure_objective_test()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--export-city-art="):
			export_city_art.call_deferred(arg.substr(18))
func _build()->void:
	visibility_layer=3
	ground=level_ctl.make_ground(Rect2(0,0,W,H))
	add_child(ground)
	decals=Decals.new()
	add_child(decals)
	decals.RES=1.0
	decals.setup(Vector2(W,H))
	shadows=ShadowLayer.new()
	add_child(shadows)
	unit_shadows=UnitShadows.new()
	unit_shadows.battle=self
	add_child(unit_shadows)
	world=Node2D.new()
	world.y_sort_enabled=true
	add_child(world)
	glowfx=Node2D.new()
	add_child(glowfx)
	proj=Projectiles.new()
	proj.battle=self
	add_child(proj)
	fx=Fx.new()
	fx.battle=self
	add_child(fx)
	high=Node2D.new()
	add_child(high)
	var camera=CommanderCamera.new()
	camera.battle=self
	cam=camera
	add_child(cam)
	cam.position=Vector2(680,1330)
	cam.make_current()
	for arg in OS.get_cmdline_user_args():
		if arg=="--city-view=overview":
			cam.position=Vector2(1800,1350)
			camera.wanted=0.14
			camera.cur_zoom=0.14
		elif arg=="--city-view=market":
			cam.position=Vector2(1950,1370)
			camera.wanted=0.48
			camera.cur_zoom=0.48
		elif arg=="--city-view=chapel":
			cam.position=Vector2(2440,1000)
			camera.wanted=0.52
			camera.cur_zoom=0.52
	atmos=Atmos.new()
	add_child(atmos)
	# Keep the generated paintings' own lighting. No terrain recolouring pass in this chapter.
	atmos.set_process(false)
	atmos.cam=cam
	var layer=CanvasLayer.new()
	layer.layer=10
	add_child(layer)
	hud=CommanderHud.new()
	hud.battle=self
	layer.add_child(hud)
	level_ctl.populate(self)
	shadows.set_sun(Vector2(0.7,0.4),Color("#243d36"),0.18)
func _deploy()->void:
	var d=tactics as CommanderDirector
	d.add_company("I / ASH SPEARS","spear",0,Vector2(380,1050),36,"SCHILTRON")
	d.add_company("II / IRON FOOT","infantry",0,Vector2(350,1330),36)
	d.add_company("III / REED SPEARS","spear",0,Vector2(360,1600),36,"LINE")
	d.add_company("IV / ASH BOWS","archer",0,Vector2(180,1110),24,"LOOSE")
	d.add_company("V / REED BOWS","archer",0,Vector2(180,1520),24,"LOOSE")
	d.add_company("VI / RED LANCES","cavalry",0,Vector2(370,1900),18,"WEDGE")
	d.add_company("VII / GREY HORSE","cavalry",0,Vector2(320,2180),18,"COLUMN")
	d.add_company("VIII / BILLMEN","heavy",0,Vector2(380,780),28,"LINE")
	d.add_company("GATE WATCH","infantry",1,Vector2(980,1270),32)
	d.add_company("CROWN SPEARS","spear",1,Vector2(1330,1240),32,"SCHILTRON")
	d.add_company("HIGH BOWS","archer",1,Vector2(1420,880),24,"LOOSE")
	d.add_company("MARKET SPEARS","spear",1,Vector2(1950,1240),36,"SCHILTRON")
	d.add_company("GUILD FOOT","infantry",1,Vector2(2140,1670),32)
	d.add_company("GREEN BOWS","archer",1,Vector2(2520,1320),24,"LOOSE")
	d.add_company("WARD SPEARS","spear",1,Vector2(2540,1910),32)
	d.add_company("CROWN LANCES","cavalry",1,Vector2(2800,2080),18,"WEDGE")
	d.add_company("EAST HORSE","cavalry",1,Vector2(2930,900),18,"COLUMN")
	var commander=spawn(0,"cavalry",Vector2(560,1440),"spear")
	take_control(commander,true)
	commander.uname="MARSHAL ROWAN"
	commander.max_hp=300
	commander.hp=300
	commander.base_speed=185
	commander.brain=RegimentBrain.CommanderBrain.new()
	d.select_company(0)
func _process(delta:float)->void:
	delta=minf(delta,1.0/30.0)
	if not ended:time+=delta
	Game.stats["time"]=time
	_update_view_rect()
	_rebuild_grid()
	_separation()
	if not ended:
		if OS.get_cmdline_user_args().has("--commander-death-test") and time>1.5 and player!=null:player.die(null,{})
		level_ctl.update(delta)
		if alive[0]<=10:_defeat("THE HOST IS BROKEN")
		elif alive[1]<=8 and time>8:win_command_battle()
	if ended:
		result_delay+=delta
		if result_delay>2.0 and not hud.results_open:hud.show_results(victory)
	_camera_shaders(delta)
func _commands()->void:pass
func _refresh_squad()->void:pass
func _squad_update(_delta:float)->void:pass
func _spawning(_delta:float)->void:pass
func _events(_delta:float)->void:pass
func _officer_boss_checks()->void:pass
func _camera_shaders(_delta:float)->void:
	if shadows!=null:shadows.visible=not Game.low_gfx
	if cam!=null:Sfx.listener=cam.position
func _crowd_zoom(_dt:float)->void:pass
func impact(_pos:Vector2,_dur:float=0.1)->void:pass
func on_player_hurt(_damage:float)->void:pass
func on_unit_killed(u:Unit,killer:Unit,_hit:Dictionary)->void:
	units.erase(u)
	tokens.erase(u)
	if tactics!=null:(tactics as CommanderDirector).casualty(u.regiment)
	if u.faction==1 and killer!=null and killer.faction==0:Game.stats["kills"]+=1
	if u==player:
		player=null
		_defeat("THE COMMANDER HAS FALLEN")
func spawn_horse(_fac:String,_pos:Vector2,_v:Vector2)->void:pass
func win_command_battle()->void:
	if ended:return
	ended=true
	victory=true
	Game.campaign["bellacourt"]=true
	if OS.get_cmdline_user_args().has("--objective-test"):
		assert(level_ctl.captured_total==3,"Not all wards were captured")
		print("[objective-test] PASS three wards captured and hold victory reached")
	Sfx.play("gong",-8)
	for u in units:
		if u.brain is RegimentBrain:u.brain.target=null
func _defeat(reason:String)->void:
	if ended:return
	ended=true
	victory=false
	death_reason=reason
	Sfx.play("horn",-9,0.7)

func export_city_art(path:String)->void:
	# Render the actual assembled scene, using its depth sorting and source alpha.
	frozen=true
	set_process(false)
	tactics.set_process(false)
	tactics.visible=false
	for u in units:u.visible=false
	for child in world.get_children():
		if child is CommanderDirector.CompanyStandard or child is CommanderCityLevel.WardBanner:child.visible=false
	shadows.visible=false
	var view=SubViewport.new()
	view.size=Vector2i(2160,1620)
	view.disable_3d=true
	view.canvas_cull_mask=1
	view.world_2d=get_viewport().world_2d
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(view)
	await get_tree().process_frame
	view.canvas_transform=Transform2D.IDENTITY.scaled(Vector2(0.6,0.6))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var rendered=view.get_texture().get_image()
	var status=rendered.save_png(path)
	assert(status==OK,"Could not export composed city painting")
	print("[city-art] saved composed 2160x1620 scene to ",path)
	get_tree().quit()

func configure_objective_test()->void:
	# An arranged integration state: troops hold the wards while enemy reserves are remote.
	var director=tactics as CommanderDirector
	for r in director.regiments:
		if r["f"]==1:
			r["at"]=Vector2(3220+(r["id"]%2)*80,180+(r["id"]%4)*60)
			r["dest"]=r["at"]
			r["order"]="hold"
			r["path"]=PackedVector2Array()
			for u in r["men"]:u.position=r["at"]+director._local_slot(r,u.regiment_slot,r["men"].size())
	for i in 3:
		var r=director.regiments[i]
		r["at"]=level_ctl.points[i]["p"]
		r["dest"]=r["at"]
		r["order"]="hold"
		for u in r["men"]:
			u.position=terrain.push_out(r["at"]+director._local_slot(r,u.regiment_slot,r["men"].size()),7)
		level_ctl.points[i]["capture"]=0.98
	level_ctl.secure_time=17.8
