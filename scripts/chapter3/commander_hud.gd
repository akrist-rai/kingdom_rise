class_name CommanderHud
extends Hud
const MAP_RECT=Rect2(537,205,91,69)
var manual=false
var toast=""
var toast_left=0.0
var intro_left=5.0
var painted_map:Texture2D
func _ready()->void:
	super._ready()
	painted_map=load("res://assets/chapter3/terrain.png")
func banner(title:String,sub:String,_col:Color=C_GOLD,_big:bool=false,dur:float=3,_seal:String="",_urgent:bool=false)->void:
	toast=title+" / "+sub
	toast_left=dur
func alert(message:String,_col:Color=C_GOLD)->void:
	toast=message
	toast_left=3.0
func _process(delta:float)->void:
	var dt=minf(delta/maxf(Engine.time_scale,0.001),0.08)
	if get_tree().paused:dt=minf(delta,0.08)
	t+=dt
	results_t+=dt
	toast_left=maxf(0,toast_left-dt)
	intro_left=maxf(0,intro_left-dt)
	if Input.is_action_just_pressed("help"):manual=not manual
	if Input.is_action_just_pressed("pause"):
		if battle.tactics.planning:battle.tactics.set_planning(false)
		else:
			pause_open=not pause_open
			get_tree().paused=pause_open
	if pause_open and Input.is_action_just_pressed("confirm"):
		pause_open=false
		get_tree().paused=false
	if results_open and results_t>1:
		if Input.is_action_just_pressed("confirm"):battle.leave(false)
		elif Input.is_action_just_pressed("flask"):battle.leave(true)
	queue_redraw()
func show_results(victory:bool)->void:
	results_open=true
	results_t=0
	results_victory=victory
	get_tree().paused=true

func _text(p:Vector2,s:String,size:int=5,col:Color=C_TEXT,align:int=0)->void:
	Game.text(self,p,s,size,col,align,0,true,Color(0.07,0.12,0.11,0.7))
func _draw()->void:
	if battle==null or battle.tactics==null:return
	var director=battle.tactics
	# Quiet top margin, with capture ownership and command state.
	draw_style_box(_minimal_plate(Color(0.07,0.16,0.15,0.78)),Rect2(12,10,137,29))
	_text(Vector2(20,22),"III / BELLACOURT",7,C_TEXT)
	_text(Vector2(20,32),"MOUNTED COMMAND / THE MARCH",4,C_DIM)
	for i in battle.level_ctl.points.size():
		var point=battle.level_ctl.points[i]
		var x=225+i*94
		var col=Color("#efc17f") if point["owner"]==0 else Color("#acd2cf")
		_text(Vector2(x,20),point["name"],4,col,1)
		draw_rect(Rect2(x-31,25,62,1.3),Color(0.07,0.16,0.15,0.8))
		var fraction=(point["capture"]+1)*0.5
		draw_rect(Rect2(x-31,25,62*fraction,1.3),Color("#d8ab70"))
	var planned=director.planning
	draw_style_box(_minimal_plate(Color(0.07,0.16,0.15,0.88)),Rect2(545,10,83,29))
	_text(Vector2(586,22),"TAB / "+("RESUME" if planned else "PLAN"),5,C_GOLD if planned else C_TEXT,1)
	_text(Vector2(586,32),"%02d:%02d" % [int(battle.time)/60,int(battle.time)%60],4,C_DIM,1)
	# The selected companies and their independent morale are the primary interface.
	draw_rect(Rect2(0,303,640,57),Color(0.055,0.13,0.13,0.95))
	for id in mini(8,director.regiments.size()):
		var r=director.regiments[id]
		var rect=Rect2(13+id*58,310,55,35)
		var chosen=director.selected.has(id)
		if chosen:draw_rect(rect,Color(0.29,0.38,0.29,0.85))
		draw_line(rect.position,rect.position+Vector2(rect.size.x,0),C_GOLD if chosen else Color(0.36,0.44,0.38,0.7),1.1 if chosen else 0.5)
		_text(rect.position+Vector2(4,9),str(id+1)+" / "+_role_name(r["kind"]),4,C_GOLD if chosen else C_TEXT)
		_text(rect.position+Vector2(4,19),str(r["men"].size())+" / "+str(r["initial"]),5,C_TEXT)
		_line_bar(rect.position.x+4,rect.position.y+25,46,r["morale"]/100,Color("#c7c99b"),1.1)
		_line_bar(rect.position.x+4,rect.position.y+29,46,r["cohesion"],Color("#8fb6ac"),0.8)
	_text(Vector2(16,355),"LEFT DRAG SELECT  /  RIGHT CLICK MOVE  /  RIGHT DRAG FACE  /  SHIFT QUEUE",4,C_DIM)
	# Contextual formation strip; troop-specific options visibly dim when unavailable.
	if not director.selected.is_empty():
		var first=director.regiments[director.selected[0]]
		for i in 5:
			var rect=Rect2(177+i*68,278,65,22)
			var form=director.COMMAND_FORMS[i]
			var enabled=director.compatible(first,form)
			var current=first["form"]==form
			draw_style_box(_minimal_plate(Color(0.07,0.16,0.15,0.90)),rect)
			_text(rect.position+Vector2(32.5,14),str(i+1)+" "+form,4,C_GOLD if current else C_TEXT if enabled else Color("#707e72"),1)
			if current:draw_line(rect.position+Vector2(4,20),rect.end-Vector2(4,2),C_GOLD,0.7)
		_text(Vector2(508,319),"%d SELECTED" % director.selected.size(),4,C_DIM)
		_text(Vector2(508,330),first["order"].to_upper(),5,C_GOLD)
		_text(Vector2(508,342),"MORALE %d" % int(first["morale"]),4,C_TEXT)
	else:_text(Vector2(506,326),"SELECT A COMPANY",4,C_DIM)
	if battle.player!=null:
		_text(Vector2(628,342),"MARSHAL %d%%" % int(100*battle.player.hp/battle.player.max_hp),4,C_TEXT,2)
		_text(Vector2(628,355),"RALLY "+("READY" if director.rally_cd<=0 else "%ds" % ceili(director.rally_cd)),4,C_GOLD,2)
	_draw_city_minimap()
	_draw_regiment_labels()
	if director.box_select:
		var rect=Rect2(director.selection_start,get_viewport().get_mouse_position()-director.selection_start).abs()
		draw_rect(rect,Color(0.91,0.84,0.60,0.08))
		draw_rect(rect,C_GOLD,false,0.7)
	if toast_left>0 and not manual:
		_text(Vector2(320,60),toast,4,C_TEXT,1)
	if planned:
		draw_style_box(_minimal_plate(Color(0.07,0.16,0.15,0.92)),Rect2(229,77,182,33))
		_text(Vector2(320,91),"THE FIELD IS PAUSED",7,C_GOLD,1)
		_text(Vector2(320,102),"PLACE YOUR ORDERS / TAB TO RESUME",4,C_TEXT,1)
	if manual:_draw_manual()
	if pause_open:_draw_pause_menu()
	if results_open:_draw_command_result()
	_draw_commander_cursor()

func _role_name(kind:String)->String:
	return {"spear":"SPEARS","infantry":"FOOT","heavy":"BILLS","archer":"BOWS","cavalry":"HORSE"}.get(kind,"FOOT")
func _draw_city_minimap()->void:
	draw_style_box(_minimal_plate(Color(0.07,0.16,0.15,0.95)),MAP_RECT.grow(3))
	draw_texture_rect(painted_map,MAP_RECT,false)
	var k=MAP_RECT.size/Vector2(Battle.W,Battle.H)
	for point in battle.level_ctl.points:
		draw_rect(Rect2(MAP_RECT.position+point["p"]*k-Vector2(1,1),Vector2(2,2)),Color("#ffde95") if point["owner"]==0 else Color("#335b66"))
	for r in battle.tactics.regiments:
		if r["men"].is_empty():continue
		var p=MAP_RECT.position+r["at"]*k
		draw_line(p-Vector2(1.5,0),p+Vector2(1.5,0),Color("#f6ca8a") if r["f"]==0 else Color("#254e5a"),1.5)
	var camera=Rect2(battle.cam.get_screen_center_position()-Game.VIEW*0.5/battle.cam.cur_zoom,Game.VIEW/battle.cam.cur_zoom)
	var rect=Rect2(MAP_RECT.position+camera.position*k,camera.size*k).intersection(MAP_RECT)
	draw_rect(rect,Color("#faf0c9"),false,0.55)
	_text(Vector2(MAP_RECT.end.x,MAP_RECT.position.y-5),"M / FIELD OVERVIEW",4,C_TEXT,2)
func _draw_regiment_labels()->void:
	for r in battle.tactics.regiments:
		if r["men"].is_empty():continue
		var p=battle.cam.world_to_screen(r["at"]+Vector2(0,-86))
		if p.x<10 or p.x>630 or p.y<40 or p.y>260:continue
		var chosen=battle.tactics.selected.has(r["id"])
		if not chosen and (battle.cam.cur_zoom>0.9 or battle.cam.cur_zoom<0.25):continue
		var w=30.0
		var c=Color("#d4aa70") if r["f"]==0 else Color("#77a9b3")
		draw_line(p-Vector2(w/2,0),p+Vector2(w/2,0),Color(0.06,0.13,0.13,0.75),3)
		draw_line(p-Vector2(w/2,0),p-Vector2(w/2,0)+Vector2(w*r["men"].size()/r["initial"],0),c,1.5)
		_text(p+Vector2(0,-5),"ROUTING" if r["routing"] else r["name"] if chosen else str(r["men"].size()),4,C_GOLD if chosen else C_TEXT,1)
func _draw_manual()->void:
	draw_rect(Rect2(0,0,640,360),Color(0.03,0.10,0.10,0.78))
	draw_style_box(_minimal_plate(Color(0.06,0.14,0.14,0.97)),Rect2(73,41,494,262))
	_text(Vector2(96,68),"THE COMMANDER'S FIELD BOOK",11,C_GOLD)
	var rows=[
		["SELECT","Click a soldier or company card; drag a selection box."],
		["MULTIPLE","Shift adds companies; G selects the entire host."],
		["ORDERS","Right click moves; right drag fixes the final facing."],
		["WAYPOINTS","Shift + right click queues the next destination."],
		["FORMATIONS","1 line / 2 column / 3 schiltron / 4 wedge / 5 loose."],
		["TROOP ROLES","Schiltron: spears. Wedge: cavalry. Loose: archers."],
		["ENGAGEMENT","Z then right click attack-moves. C orders a charge."],
		["HOLD / FIRE","X holds and braces spears. F toggles fire at will."],
		["VOLLEY / RALLY","V targets a bow volley; R rallies near your horse."],
		["CAMERA","Arrows pan / middle drag / wheel zoom / M overview."],
		["YOUR HORSE","WASD rides the commander. Space follows your horse."],
		["PLAN","Tab pauses the battle while you place orders."],
		["WIN","Secure all three wards and hold them for 18 seconds."]]
	for i in rows.size():
		var y=88+i*15
		_text(Vector2(96,y),rows[i][0],4,C_GOLD)
		Game.text(self,Vector2(211,y),rows[i][1],5,C_TEXT,0,2,false)
	_text(Vector2(544,291),"H / CLOSE",4,C_DIM,2)
func _draw_pause_menu()->void:
	draw_rect(Rect2(0,0,640,360),Color(0.03,0.10,0.10,0.83))
	_text(Vector2(320,150),"BELLACOURT / PAUSED",13,C_GOLD,1)
	_text(Vector2(320,178),"ENTER OR ESC / RESUME",6,C_TEXT,1)
	_text(Vector2(320,198),"H / FIELD BOOK",5,C_DIM,1)
func _draw_command_result()->void:
	draw_rect(Rect2(0,0,640,360),Color(0.03,0.10,0.10,0.87))
	_text(Vector2(320,125),"THE BURGH IS OURS" if results_victory else "THE HOST IS BROKEN",17,C_GOLD,1)
	_text(Vector2(320,151),"BELLACOURT / CHAPTER III",6,C_TEXT,1)
	_text(Vector2(320,179),"%d ORDERS / %d REFORMATIONS" % [battle.tactics.order_count,battle.tactics.reform_count],6,C_DIM,1)
	_text(Vector2(320,205),"ENTER / CAMPAIGN ATLAS     R / TRY AGAIN",6,C_TEXT,1)
func _draw_commander_cursor()->void:
	var p=get_viewport().get_mouse_position()
	draw_line(p+Vector2(-3,0),p+Vector2(3,0),C_GOLD,0.65,true)
	draw_line(p+Vector2(0,-3),p+Vector2(0,3),C_GOLD,0.65,true)
