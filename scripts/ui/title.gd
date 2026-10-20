class_name TitleScreen
extends Node2D
## A live illustrated cover: gold fields, a limestone citadel, columns on the march.
signal start_game
signal open_map
signal start_commander
var t=0.0
var stage=0
var help=false
const CREAM=Color("#f5e5bd")
const INK=Color("#283f40")
func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	Engine.time_scale=1.0
	Game.command_view=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	Sfx.play("horn",-12.0,0.8)
func _process(delta:float)->void:
	t+=delta
	queue_redraw()
	if OS.get_cmdline_user_args().has("--test-chapter3-entry") and t>0.8 and not has_meta("entry_test"):
		set_meta("entry_test",true)
		var key=InputEventKey.new()
		key.physical_keycode=KEY_3
		key.pressed=true
		Input.parse_input_event(key)
	if Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("attack"):
		if t>0.5:
			if Input.is_action_just_pressed("attack") and Rect2(27,254,250,29).has_point(get_viewport().get_mouse_position()):start_commander.emit()
			else:start_game.emit()
	if Input.is_action_just_pressed("help"):
		help=not help
	if OS.get_cmdline_user_args().has("--autostart") and t>1 and not has_meta("started"):
		set_meta("started",true)
		start_game.emit()
func _unhandled_input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_M:open_map.emit()
		elif event.physical_keycode==KEY_3:start_commander.emit()
func _draw()->void:
	draw_rect(Rect2(Vector2.ZERO,Game.VIEW),Color("#a8c6bb"))
	var rng=RandomNumberGenerator.new()
	rng.seed=412
	# Wind-sculpted cloud silhouettes.
	for i in 13:
		var p=Vector2(fmod(i*71.0+t*1.0,760.0)-60,30+(i%3)*19)
		draw_colored_polygon(Painter.ellipse(p,43+i%4*10,5+i%3*2,14),Color("#dddcc0"))
	for row in 3:
		var pts=PackedVector2Array([Vector2(-10,160+row*32)])
		for i in 18:
			pts.append(Vector2(i*42-20,125+row*40+sin(i*0.55+row*2)*20))
		pts.append(Vector2(700,370));pts.append(Vector2(-10,370))
		draw_colored_polygon(pts,[Color("#789b86"),Color("#8f9c65"),Color("#c5ac63")][row])
	# Veyre, above the valley. The silhouettes echo the actual playable keep.
	for i in 17:
		var x=315+i*18
		var y=157+sin(i*0.6)*10
		draw_rect(Rect2(x,y-15,17,22),Color("#9d9979"))
		draw_colored_polygon(PackedVector2Array([Vector2(x-2,y-15),Vector2(x+8,y-28),Vector2(x+19,y-15)]),Color("#45646a"))
	var keep=Vector2(493,145)
	draw_rect(Rect2(keep-Vector2(50,41),Vector2(100,56)),Color("#d4cca7"))
	for x in [-49,37]:
		draw_rect(Rect2(keep+Vector2(x,-67),Vector2(18,82)),Color("#b5b697"))
		draw_colored_polygon(PackedVector2Array([keep+Vector2(x-3,-67),keep+Vector2(x+9,-95),keep+Vector2(x+21,-67)]),Color("#385860"))
	for i in 10:
		draw_rect(Rect2(441+i*11,97,7,10),Color("#ded2ad"))
	for i in 25:
		var x=310+i*14
		var y=175+sin(i*0.2)*6
		draw_rect(Rect2(x,y,15,19),Color("#a1aa8b"))
		draw_rect(Rect2(x,y-4,8,6),Color("#d3ccaa"))
	# Golden sweep across the foreground, with a pale road towards the citadel.
	draw_colored_polygon(PackedVector2Array([Vector2(0,290),Vector2(310,203),Vector2(640,241),Vector2(640,360),Vector2(0,360)]),Color("#dcc07a"))
	draw_colored_polygon(PackedVector2Array([Vector2(220,360),Vector2(397,210),Vector2(412,198),Vector2(418,210),Vector2(297,360)]),Color("#eaddb0"))
	for i in 500:
		var p=Vector2(rng.randf_range(0,640),rng.randf_range(210,370))
		if p.x<300 and p.y<295:continue
		var c=Color("#b29855") if i%3 else Color("#f4dda0")
		draw_line(p,p+Vector2(4,-2),c,0.7,true)
	# Distant marching files, not a single sparse ribbon.
	for row in 7:
		for col in 6:
			var p=Vector2(360+col*8-row*3,243+row*10)
			var tex:Texture2D=Art.units["qin_spear"]["walk"][int(t*7+row)%8]
			draw_texture_rect(tex,Rect2(p-Vector2(5,14),Vector2(11,14)),false,Color("#bc9b72"))
			if col==2:
				draw_line(p+Vector2(4,-6),p+Vector2(9,-28),INK,0.6,true)
	for p in [Vector2(377,251),Vector2(371,276),Vector2(359,302)]:
		draw_line(p,p+Vector2(0,-36),INK,1.0,true)
		var wave=sin(t*2+p.y)*2
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-36),p+Vector2(18,-34+wave),p+Vector2(15,-20+wave),p+Vector2(0,-23)]),Color("#ab4f3b"))
	# Flat foreground oak silhouettes frame the painting.
	for i in 14:
		var p=Vector2(610+rng.randf_range(-40,65),280+rng.randf_range(-30,80))
		draw_colored_polygon(Painter.ellipse(p,rng.randf_range(14,42),rng.randf_range(12,27),9),INK)
	draw_line(Vector2(619,360),Vector2(627,275),INK,13)
	# A restrained editorial title, room for the painting to breathe.
	Game.text(self,Vector2(30,42),"A FIELD CHRONICLE / I",6,INK,0,0,false)
	Game.text(self,Vector2(29,102),"GOLDEN",30,INK,0,1,false)
	Game.text(self,Vector2(29,151),"MARCH",30,INK,0,1,false)
	draw_line(Vector2(32,169),Vector2(182,169),INK,0.8)
	Game.text(self,Vector2(32,187),"THE SIEGE OF VEYRE",7,INK,0,0,false)
	Game.text(self,Vector2(32,205),"Lead the line. Break the crown.",6,INK,0,2,false)
	draw_style_box(_plate(),Rect2(27,254,230,28))
	Game.text(self,Vector2(38,272),"3 / COMMAND BELLACOURT",7,CREAM,0,0,false)
	draw_style_box(_plate(),Rect2(27,286,213,41))
	Game.text(self,Vector2(40,302),"ENTER / MARCH TO BATTLE",7,CREAM,0,0,false)
	Game.text(self,Vector2(40,316),"M / CAMPAIGN ATLAS",5,Color("#bec7aa"),0,0,false)
	Game.text(self,Vector2(30,345),"H CONTROLS   /   F11 FULLSCREEN",4,INK,0,0,false)
	if help:
		draw_rect(Rect2(22,218,290,62),Color(INK,0.94))
		Game.text(self,Vector2(34,232),"WASD MOVE / CLICK ATTACK / SPACE DASH",5,CREAM)
		Game.text(self,Vector2(34,244),"TAB COMMAND / RIGHT CLICK PLACE / Q FORMATION",5,CREAM)
		Game.text(self,Vector2(34,256),"1 FOLLOW / 2 ADVANCE / 3 HOLD",5,CREAM)
		Game.text(self,Vector2(34,269),"E SKILL / R HEAL / F INTERACT / H IN-GAME HELP",5,CREAM)
func _plate()->StyleBoxFlat:
	var p=StyleBoxFlat.new()
	p.bg_color=INK
	p.set_corner_radius_all(2)
	return p
