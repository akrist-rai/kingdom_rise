class_name BattleInteractables
extends Node
## CC0 supply props with actual combat consequences. All art ships with the game.
## A prop can be hit once per swing; explosion damage cannot recursively detonate
## other props. Navigation is updated only when a solid cache is destroyed.
var battle: Battle
var props: Array = []
var sequence := 0

func setup(b: Battle) -> void:
	battle = b
	if b.level == "siege":
		for spec in [[Vector2(920,2290),false],[Vector2(1240,2310),true],[Vector2(760,2170),true],[Vector2(1440,2130),false],
			[Vector2(420,2250),false],[Vector2(1770,2240),true],[Vector2(1180,1660),true],[Vector2(940,1500),false],
			[Vector2(1270,1390),true],[Vector2(1100,1020),false],[Vector2(970,650),false]]:
			spawn_prop(spec[0],spec[1])
	elif b.level == "commander_city":
		for spec in [[Vector2(840,1350),true],[Vector2(1000,1160),false],[Vector2(1810,1340),true],
			[Vector2(2000,1420),false],[Vector2(2450,1770),true],[Vector2(2670,1930),false]]:
			spawn_prop(spec[0],spec[1])
	else:
		for i in 9:
			spawn_prop(Vector2(1200+i*88,300+(i%3)*155),i%3==1)

func spawn_prop(at: Vector2, oil: bool) -> void:
	if battle.terrain != null and battle.terrain.solid_at(at,14):
		return
	var p := SupplyProp.new()
	p.battle = battle
	p.oil = oil
	p.position = at
	p.tag = "supply_%d" % sequence
	sequence += 1
	battle.world.add_child(p)
	props.append(p)
	if battle.terrain != null:
		battle.terrain.add(Rect2(at-Vector2(5,4),Vector2(10,8)),p.tag)

func strike(u: Unit, reach: float, move: Dictionary) -> void:
	if not u.is_player:
		return
	for p in props:
		if not is_instance_valid(p) or p.broken or p.last_attack == u.attack_id:
			continue
		var to: Vector2 = p.global_position-u.global_position
		if to.length()>reach+6:
			continue
		var shape: String = move.get("shape","arc")
		if shape=="thrust":
			if to.dot(u.aim)<-4 or absf(to.cross(u.aim))>float(move.get("width",8))+6:
				continue
		elif shape!="circle" and absf(angle_difference(u.aim.angle(),to.angle()))>deg_to_rad(float(move.get("arc",140))*0.5):
			continue
		# The cache's own small footprint is ignored; a wall between it and the
		# soldier is checked up to the near edge instead.
		if battle.terrain != null and battle.terrain.blocked(u.global_position,p.global_position-to.normalized()*13):
			continue
		p.last_attack = u.attack_id
		p.smash(u)

class SupplyProp extends Node2D:
	var battle: Battle
	var oil := false
	var broken := false
	var last_attack := -1
	var tag := ""
	var sprite: Sprite2D
	var clock := 0.0
	func _ready() -> void:
		sprite = Sprite2D.new()
		var id := "barrel" if oil else "crate_a"
		sprite.texture = PropArt.tex(id)
		sprite.centered = false
		sprite.offset = -PropArt.anchor(id)
		sprite.scale = Vector2.ONE / PropArt.R * 1.35
		sprite.modulate = Color("#c37c63") if oil else Color("#e0cfaa")
		add_child(sprite)
	func _process(delta: float) -> void:
		clock += delta
		visible = battle.in_view(global_position)
		if visible:
			queue_redraw()
	func _draw() -> void:
		if broken:
			return
		draw_set_transform(Vector2(0,1),0,Vector2(1,0.45))
		draw_circle(Vector2.ZERO,10,Color(0.03,0.08,0.1,0.22))
		draw_set_transform(Vector2.ZERO)
		if oil:
			# Red hazard ring + three rays are a visible cue before the first hit.
			draw_arc(Vector2.ZERO,11,0,TAU,24,Color(0.9,0.3,0.16,0.4),0.8,true)
			for i in 3:
				var a := -PI*0.5+(i-1)*0.4
				var p := Vector2(0,-22)
				draw_line(p+Vector2.from_angle(a)*2,p+Vector2.from_angle(a)*5,Color("#f8a15e"),1,true)
		elif battle.player != null and global_position.distance_to(battle.player.global_position)<90:
			Game.text(self,Vector2(0,-25),"SUPPLY",4,Color("#e7cf99"),1)
	func smash(u: Unit) -> void:
		broken = true
		sprite.visible = false
		if battle.terrain != null:
			battle.terrain.set_active(tag,false)
		battle.fx.debris(global_position,12)
		Sfx.play_at("break",global_position,-8,1.1)
		if oil:
			battle.fx.burst(global_position+Vector2(0,-10),Color("#ffad61"),22)
			battle.fx.ring(global_position,64,Color("#ffbd78"),0.32)
			battle.cam.add_trauma(0.16)
			Sfx.play_at("boom",global_position,-8)
			for enemy in battle.query(global_position,70):
				if enemy.dead or enemy.faction==u.faction or global_position.distance_to(enemy.global_position)>64+enemy.radius:
					continue
				if battle.terrain != null and battle.terrain.blocked(global_position,enemy.global_position):
					continue
				var h := u.make_hit(Weapon.mv(0,0,0,2,0,0))
				h["src_pos"] = global_position
				h["knockdown"] = true
				h["kb"] = 180.0
				enemy.take_hit(u,h)
		else:
			u.stamina = minf(u.max_stamina,u.stamina+24)
			u.spirit = minf(Unit.MAX_SPIRIT,u.spirit+10)
			battle.fx.text(global_position+Vector2(0,-24),"SUPPLIED",Color("#b6dfbc"))
			battle.fx.heal(u)
		if not oil:
			battle.fx.dust(global_position,6)
		queue_redraw()
