class_name CommanderCityLevel
extends RefCounted
## Chapter III is assembled from eight independently generated raster paintings.
## Only invisible movement obstructions use rectangles; all visible architecture is painted.
const MAP = Rect2(0, 0, 3600, 2700)
var b
var phase = 1
var buildings: Array = []
var wall_pieces: Array = []
var points: Array = [
	{"name":"WEST GATE", "p":Vector2(900,1250), "owner":1, "capture":-1.0},
	{"name":"MARKET CROSS", "p":Vector2(1900,1260), "owner":1, "capture":-1.0},
	{"name":"GUILDHALL", "p":Vector2(2560,1840), "owner":1, "capture":-1.0}]
var secure_time = 0.0
var captured_total = 0
var route_debug_done = false

func bounds() -> Rect2: return MAP
func atmos_key() -> String: return "siege"
func cavalry_ok() -> bool: return true
func officers_ok() -> bool: return false
func boss_ready() -> bool: return false
func boss_point() -> Vector2: return Vector2(2500,1600)
func officer_point(_i:int) -> Vector2: return Vector2(2500,1600)
func elevation(_p:Vector2) -> int: return 0
func reachable(_u,_e) -> bool: return true
func falling(_u) -> bool: return false
func try_fall(_u,_p:Vector2) -> bool: return false
func on_ladder(_p:Vector2) -> bool: return false
func rout_dir(f:int) -> Vector2: return Vector2.LEFT if f==0 else Vector2.RIGHT
func march_goal(u) -> Vector2: return u.position
func markers() -> Array: return []
func objective() -> String: return "SECURE THE THREE WARDS"
func force_palace() -> void: pass
func spawn_group(_f:int,_n:int) -> void: pass
func deploy(_battle) -> void: pass

func make_ground(_rect:Rect2) -> ColorRect:
	var root=ColorRect.new()
	root.position=Vector2.ZERO
	root.size=MAP.size
	root.color=Color("#a1aa7c")
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var image=TextureRect.new()
	image.texture=load("res://assets/chapter3/terrain.png")
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.size=MAP.size
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(image)
	return root

func populate(battle) -> void:
	b=battle
	b.terrain=Terrain.new()
	b.add_child(b.terrain)
	b.terrain.setup(Rect2(35,35,3530,2630))
	# A low irregular circuit, with broad gates and a south-west postern.
	var outline=[Vector2(850,480),Vector2(1400,320),Vector2(2100,300),Vector2(2750,440),Vector2(3050,820),Vector2(3130,1500),Vector2(2800,2100),Vector2(2300,2330),Vector2(1500,2360),Vector2(900,2180),Vector2(680,1820),Vector2(620,1300),Vector2(680,800),Vector2(850,480)]
	for i in outline.size()-1:
		_wall_line(outline[i],outline[i+1])
	# Crooked blocks follow the painted roads, preserving generous public streets.
	var houses=[
		["townhouses",Vector2(1100,800),440.0], ["cottage",Vector2(1510,680),340.0],
		["townhouses",Vector2(2430,680),420.0], ["cottage",Vector2(2790,930),330.0],
		["cottage",Vector2(940,1090),340.0], ["townhouses",Vector2(1430,1070),360.0],
		["chapel",Vector2(2450,1170),600.0], ["cottage",Vector2(2860,1430),350.0],
		["townhouses",Vector2(1110,1510),390.0], ["market",Vector2(1590,1580),470.0],
		["cottage",Vector2(2280,1460),330.0], ["guildhall",Vector2(2590,1830),600.0],
		["townhouses",Vector2(1150,1850),420.0], ["cottage",Vector2(1530,1930),330.0],
		["townhouses",Vector2(2380,2190),410.0], ["cottage",Vector2(2780,1980),340.0],
		["cottage",Vector2(1020,2160),300.0], ["cottage",Vector2(3150,650),280.0],
		["market",Vector2(450,1990),340.0], ["cottage",Vector2(380,760),320.0]]
	houses.append_array([
		["cottage",Vector2(1080,590),270.0], ["townhouses",Vector2(1660,920),300.0],
		["cottage",Vector2(2140,600),260.0], ["townhouses",Vector2(2740,590),300.0],
		["cottage",Vector2(1480,430),240.0], ["townhouses",Vector2(870,1710),280.0],
		["market",Vector2(1650,1780),290.0], ["cottage",Vector2(2290,1660),260.0],
		["townhouses",Vector2(2160,2040),280.0], ["cottage",Vector2(1440,2200),280.0],
		["cottage",Vector2(2900,1650),270.0], ["cottage",Vector2(1110,980),250.0]])
	for h in houses:
		_building(h[0],h[1],h[2])
	for data in [[Vector2(860,530),260.0],[Vector2(1580,420),190.0],[Vector2(2900,490),240.0],[Vector2(3030,1840),270.0],[Vector2(2380,2440),260.0],[Vector2(1090,2350),270.0],[Vector2(370,2220),300.0],[Vector2(300,490),310.0],[Vector2(2200,830),150.0],[Vector2(2850,1180),170.0]]:
		var tree=PaintedBuilding.new()
		tree.battle=b
		tree.kind="orchard"
		tree.width=data[1]
		tree.position=data[0]
		tree.solid=false
		b.world.add_child(tree)
		buildings.append(tree)
	# The river is scenery and an obstruction, crossed by the north-east road.
	b.terrain.add(Rect2(3400,780,200,1920),"river")
	b.terrain.add(Rect2(3460,0,140,230),"river")
	for point in points:
		var banner=WardBanner.new()
		banner.point=point
		banner.position=point["p"]
		b.world.add_child(banner)

func _building(asset:String,at:Vector2,width:float) -> void:
	var building=PaintedBuilding.new()
	building.kind=asset
	building.position=at
	building.width=width
	building.battle=b
	b.world.add_child(building)
	buildings.append(building)
	# Footprints occupy the foundation, not the roofs. Units may pass behind roofs.
	var footprint=Rect2(at-Vector2(width*0.37,width*0.23),Vector2(width*0.75,width*0.23))
	if asset=="chapel": footprint=Rect2(at-Vector2(width*0.35,width*0.24),Vector2(width*0.74,width*0.24))
	b.terrain.add(footprint,"building")
	building.footprint=footprint

func _wall_line(a:Vector2,c:Vector2) -> void:
	var length=a.distance_to(c)
	var steps=ceili(length/100.0)
	for i in steps:
		var p=a.lerp(c,float(i)/steps)
		var q=a.lerp(c,float(i+1)/steps)
		var mid=(p+q)*0.5
		# West gate, south gate, north gate, east gate and smaller west postern.
		var opening=(mid.distance_to(Vector2(625,1300))<150 or mid.distance_to(Vector2(1900,2340))<170 or mid.distance_to(Vector2(1850,307))<135 or mid.distance_to(Vector2(2910,640))<140 or mid.distance_to(Vector2(680,1790))<105)
		if opening: continue
		var piece=PaintedWall.new()
		piece.position=p
		piece.heading=(q-p).angle()
		piece.length=p.distance_to(q)+4.0
		b.world.add_child(piece)
		wall_pieces.append(piece)
		# A short chain of matching physical foundations follows each visible segment.
		var sub=ceili(p.distance_to(q)/22.0)
		for j in sub:
			var v=p.lerp(q,(j+0.5)/sub)
			b.terrain.add(Rect2(v-Vector2(12,10),Vector2(24,20)),"town_wall")

func intro() -> void:
	b.hud.banner("III / THE BURGH OF BELLACOURT","YOU COMMAND THE HOST. SECURE THE THREE WARDS.",Color("#e9d69f"),true,4.5)

func update(delta:float) -> void:
	if b.ended: return
	var secured=0
	for point in points:
		var counts=[0,0]
		for u in b.query(point["p"],125):
			if not u.dead and u.position.distance_to(point["p"])<125:
				counts[u.faction]+=1
		var pressure=counts[0]-counts[1]
		if abs(pressure)>=2:
			point["capture"]=clampf(point["capture"]+signf(pressure)*delta/10.0,-1.0,1.0)
		var owner=0 if point["capture"]>=1.0 else 1 if point["capture"]<=-1.0 else point["owner"]
		if owner!=point["owner"]:
			point["owner"]=owner
			if owner==0: captured_total+=1
			b.hud.alert(point["name"]+(" SECURED" if owner==0 else " LOST"),Color("#e9d69f"))
			Sfx.play("horn_short",-12)
		if point["owner"]==0: secured+=1
	if secured==3:
		secure_time+=delta
		if secure_time>18.0: b.win_command_battle()
	else: secure_time=maxf(0,secure_time-delta*0.5)
	if b.time>1.0 and not route_debug_done and OS.get_cmdline_user_args().has("--commander-test"):
		route_debug_done=true
		for route in [[Vector2(450,1300),Vector2(1900,1260)],[Vector2(1900,1260),Vector2(2560,1840)],[Vector2(450,1900),Vector2(1900,2050)]]:
			var path=b.terrain.path(route[0],route[1])
			assert(path.size()>1,"Commander city route is disconnected")
			print("[commander-nav] ",route[0]," -> ",route[1]," points=",path.size())

class PaintedBuilding extends Node2D:
	var battle
	var kind="cottage"
	var width=400.0
	var solid=true
	var footprint=Rect2()
	var sprite:Sprite2D
	var target_alpha=1.0
	var visual_size=Vector2.ZERO
	func _ready() -> void:
		sprite=Sprite2D.new()
		sprite.centered=false
		sprite.texture=load("res://assets/chapter3/"+kind+".png")
		var factor=width/sprite.texture.get_width()
		sprite.scale=Vector2(factor,factor)
		visual_size=sprite.texture.get_size()*factor
		sprite.position=Vector2(-width*0.5,-visual_size.y*0.94)
		add_child(sprite)
	func _process(delta:float) -> void:
		if battle==null or battle.player==null:return
		var screen_rect=Rect2(global_position+Vector2(-width*0.5,-visual_size.y*0.9),Vector2(width,visual_size.y*0.75))
		target_alpha=0.35 if screen_rect.has_point(battle.player.position) else 1.0
		if battle.tactics!=null:
			for id in battle.tactics.selected:
				if id<battle.tactics.regiments.size() and screen_rect.has_point(battle.tactics.regiments[id]["at"]):
					target_alpha=0.50
		modulate.a=move_toward(modulate.a,target_alpha,delta*2.5)

class PaintedWall extends Node2D:
	var heading=0.0
	var length=100.0
	func _ready() -> void:
		var sprite=Sprite2D.new()
		var atlas=AtlasTexture.new()
		atlas.atlas=load("res://assets/chapter3/wall.png")
		atlas.region=Rect2(60,204,2050,350)
		sprite.texture=atlas
		sprite.centered=false
		sprite.position=Vector2(0,-33)
		sprite.scale=Vector2(length/2050.0,0.105)
		# Wall courses turn with the ground; their modest height remains legible.
		rotation=heading
		add_child(sprite)

class WardBanner extends Node2D:
	var point
	var t=0.0
	func _process(delta:float)->void:
		t+=delta
		queue_redraw()
	func _draw()->void:
		if point==null:return
		var col=Color("#be704e") if point["owner"]==0 else Color("#477b83")
		draw_line(Vector2(0,2),Vector2(0,-51),Color("#443f2f"),1.8,true)
		var flutter=sin(t*2)*2
		draw_colored_polygon(PackedVector2Array([Vector2(0,-50),Vector2(25,-47+flutter),Vector2(22,-28+flutter),Vector2(0,-32)]),col)
		draw_line(Vector2(2,-47),Vector2(19,-45+flutter),Color("#e9d69f"),0.7,true)
