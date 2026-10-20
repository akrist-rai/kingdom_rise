class_name CommanderCamera
extends BattleCam
var battle
var wanted=0.50
var follow=false
var dragging=false
var edge_enabled=false
var overview=false
var previous=Vector2.ZERO
func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	position_smoothing_enabled=false
	cur_zoom=0.50
	base_zoom=0.50
func _unhandled_input(event:InputEvent)->void:
	if battle==null or battle.hud.pause_open or battle.hud.manual:return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_MIDDLE:
			dragging=event.pressed
			follow=false
		if event.pressed:
			if event.button_index==MOUSE_BUTTON_WHEEL_UP:wanted=clampf(wanted*1.12,0.14,1.2)
			elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:wanted=clampf(wanted/1.12,0.14,1.2)
	if event is InputEventMouseMotion and dragging:
		position-=event.relative/cur_zoom
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_SPACE:
			follow=true
			wanted=0.7
		elif event.physical_keycode==KEY_M:
			overview=not overview
			wanted=0.14 if overview else 0.50
			if overview:
				position=Vector2(1800,1350)
				follow=false
func _process(delta:float)->void:
	var dt=minf(delta/maxf(Engine.time_scale,0.001),0.05)
	if get_tree().paused:dt=minf(delta,0.05)
	if battle==null:return
	var pan=Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP)))
	if pan.length_squared()>0:
		follow=false
		position+=pan.normalized()*dt*420/cur_zoom
	if follow and battle.player!=null and is_instance_valid(battle.player):
		position=position.lerp(battle.player.position,1-exp(-dt*6))
	position.x=clampf(position.x,140,3460)
	position.y=clampf(position.y,150,2540)
	cur_zoom=lerpf(cur_zoom,wanted,1-exp(-dt*7))
	zoom=Vector2(cur_zoom,cur_zoom)
	offset=Vector2.ZERO
	Sfx.listener=position
