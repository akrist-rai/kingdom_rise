class_name CityDetails
extends Node2D
## Small foreground-scale CC0 props make the painted chapter feel inhabited.
## Foundations remain clear; props are clustered at block corners, not on routes.
var battle: Battle
var lanterns: Array[Vector2] = []
var banners: Array = []
var clock := 0.0
func setup(b: Battle) -> void:
	battle = b
	var rng := RandomNumberGenerator.new()
	rng.seed = 12078
	for spec in [["cart",Vector2(1220,1545),1.8],["well_blue",Vector2(2010,1130),0.8],
		["weaponrack",Vector2(840,1130),1.6],["crate_a",Vector2(1450,1640),1.7],
		["barrel",Vector2(1480,1650),1.8],["sack",Vector2(1464,1661),1.9],
		["cart",Vector2(2490,2050),1.7],["lumber",Vector2(2430,2080),1.7],
		["crate_open",Vector2(2785,1460),1.8],["barrel",Vector2(2802,1470),1.9],
		["tent",Vector2(170,1710),1.5],["tent_b",Vector2(220,1830),1.5]]:
		_add_prop(spec[0],spec[1],spec[2])
	for p in [Vector2(832,1180),Vector2(842,1420),Vector2(1750,1320),Vector2(2085,1300),Vector2(2435,1810),Vector2(2670,1980)]:
		lanterns.append(p)
		var post := StreetLamp.new()
		post.position = p
		battle.world.add_child(post)
	for p in [Vector2(860,1170),Vector2(860,1440),Vector2(1820,1320),Vector2(2490,1940)]:
		var standard := Scenery.WarBanner.new()
		standard.position = p
		standard.col = Color("#377482")
		standard.height = 72
		battle.world.add_child(standard)
	for i in 55:
		var at := Vector2(rng.randf_range(800,3000),rng.randf_range(500,2250))
		if battle.terrain.solid_at(at,14):
			continue
		_add_prop(["pebble_1","petals_1","clover_1"][i%3],at,rng.randf_range(0.8,1.4))
func _add_prop(id: String, at: Vector2, s: float) -> void:
	var spr := Sprite2D.new()
	spr.texture = PropArt.tex(id)
	spr.centered = false
	spr.offset = -PropArt.anchor(id)
	spr.scale = Vector2.ONE * s / PropArt.R
	spr.position = at
	spr.modulate = Color(0.92,0.92,0.85)
	battle.world.add_child(spr)
func _process(delta: float) -> void:
	clock += delta
	queue_redraw()
func _draw() -> void:
	if battle == null:
		return
	# Warm lantern pools and windborne dust are painted below the soldiers.
	for p in lanterns:
		if not battle.in_view(p):
			continue
		var alpha := 0.045+sin(clock*3+p.x)*0.007
		for i in 3:
			draw_circle(p+Vector2(0,-2),20+i*10,Color(1,0.75,0.37,alpha*(1.0-i*0.25)))

class StreetLamp extends Node2D:
	func _draw() -> void:
		draw_set_transform(Vector2(8,4),0,Vector2(1,0.4))
		draw_circle(Vector2.ZERO,7,Color(0.05,0.09,0.1,0.2))
		draw_set_transform(Vector2.ZERO)
		draw_line(Vector2(0,0),Vector2(0,-46),Color("#334347"),2,true)
		draw_line(Vector2(0,-46),Vector2(9,-46),Color("#334347"),1.4,true)
		draw_rect(Rect2(5,-45,7,9),Color("#2d3c3e"))
		draw_rect(Rect2(7,-43,3,5),Color("#efc785"))
		draw_line(Vector2(4,-46),Vector2(13,-46),Color("#d6af75"),1,true)
