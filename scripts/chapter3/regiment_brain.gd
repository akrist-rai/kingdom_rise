class_name RegimentBrain
extends AIBrain
## Individual weapons still collide and strike; the company owns destinations and frontage.
func _march(u:Unit)->void:
	var director=u.battle.tactics
	var goal:Vector2=director.regiment_goal(u)
	var to:Vector2=goal-u.position
	u.i_goal=goal
	u.i_move=to.normalized()*clampf(to.length()/24.0,0.0,1.0) if to.length()>4 else Vector2.ZERO
	u.i_aim=u.formation_dir
func _retarget(u:Unit)->void:
	var b=u.battle
	var r=b.tactics.regiments[u.regiment]
	if r["routing"]:
		target=null
		return
	var station:Vector2=b.tactics.regiment_goal(u)
	var radius=310.0 if u.weapon.ranged else 86.0 if r["order"] in ["hold","brace","move"] else 150.0
	var best=null
	var distance=INF
	for e in b.query(u.position,radius):
		if e.dead or e.faction==u.faction or e.spectator or e.is_player:continue
		var ds=u.position.distance_squared_to(e.position)
		if ds>radius*radius:continue
		if not u.weapon.ranged and e.position.distance_to(station)>140.0:continue
		if b.terrain.blocked(u.position,e.position):continue
		if ds<distance:
			distance=ds
			best=e
	if best!=target:_release(u)
	target=best
func _cavalry(u:Unit,delta:float)->void:
	_melee(u,delta)
func think(u:Unit,delta:float)->void:
	if u.regiment<0:return
	var r=u.battle.tactics.regiments[u.regiment]
	if r["routing"]:
		u.i_move=Vector2(-1 if u.faction==0 else 1,0)
		u.i_goal=u.position+u.i_move*400
		u.i_aim=u.i_move
		u.i_guard=false
		if u.position.x<55 or u.position.x>Battle.W-55:u.battle.retire(u)
		return
	if u.weapon.ranged and not r["fire"]:
		target=null
		u.i_guard=false
		_march(u)
		return
	super.think(u,delta)
	if r["order"]=="move" and target!=null and u.position.distance_to(u.battle.tactics.regiment_goal(u))>80:
		target=null
		_march(u)

class CommanderBrain extends RefCounted:
	func think(u:Unit,_delta:float)->void:
		u.i_light=false
		u.i_light_held=false
		u.i_heavy=false
		u.i_heavy_held=false
		u.i_dash=false
		u.i_skill=false
		u.i_flask=false
		u.i_kick=false
		u.i_throw=false
		u.i_guard=false
		u.i_move=Vector2.ZERO
		if Game.autotest or u.battle.ended or get_paused(u):return
		u.i_move=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))).limit_length(1.0)
		if u.i_move.length()>0.1:u.i_aim=u.i_move.normalized()
		u.i_goal=Vector2.INF
	func get_paused(u)->bool:return u.get_tree().paused
