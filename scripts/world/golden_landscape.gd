class_name GoldenLandscape
extends Node2D
## Flat ink shapes and painterly clusters. Static decoration is built once.
var battle
var rng = RandomNumberGenerator.new()

func setup(b) -> void:
	battle = b
	rng.seed = 9218
	if b.level_ctl == null:
		return
	# Trees flank three distinct approaches; the paths remain clear for formations.
	for side in [-1.0, 1.0]:
		for i in 15:
			var tree = CopseTree.new()
			tree.position = Vector2((70.0 if side < 0 else 2110.0) + rng.randf_range(-60,60), 2070.0 + i * 34.0)
			tree.factor = rng.randf_range(0.8,1.7)
			tree.seed_value = rng.randi()
			b.world.add_child(tree)
	for pos in [Vector2(380,2300), Vector2(690,2420), Vector2(1480,2390), Vector2(1840,2290),Vector2(280,2200),Vector2(1930,2450)]:
		var tree = CopseTree.new()
		tree.position = pos
		tree.factor = rng.randf_range(1.1,1.7)
		tree.seed_value = rng.randi()
		b.world.add_child(tree)
	for i in 26:
		var tree = CopseTree.new()
		tree.position = Vector2(rng.randf_range(50,2150), rng.randf_range(850,1720))
		if b.terrain.solid_at(tree.position,32):
			tree.queue_free()
			continue
		tree.factor = rng.randf_range(0.65,1.0)
		tree.seed_value = rng.randi()
		b.world.add_child(tree)
	queue_redraw()

func _draw() -> void:
	if battle == null or battle.level_ctl == null:
		return
	rng.seed = 9218
	# Wheat, flowers and short etched grass, distributed without screen-sized repeats.
	for i in 2300:
		var p = Vector2(rng.randf_range(-180,2380),rng.randf_range(2100,2660))
		if absf(p.x-1100.0-sin(p.y*0.007)*32.0)<70.0 or absf(p.y-2310.0-sin(p.x*0.007)*28.0)<30.0:
			continue
		var c = Color("#ead79b") if i % 3 else Color("#777c48")
		var h = rng.randf_range(2,6)
		draw_line(p,p+Vector2(1.5,-h),Color(c,0.55),0.6,true)
		if i%9==0:
			draw_line(p+Vector2(0,-h*0.6),p+Vector2(3,-h),c,1.0,true)
		if i%17==0:
			draw_circle(p+Vector2(0,-3),rng.randf_range(1.2,2),Color("#be553c"))
	# Broken dry-stone field boundaries, with openings where the armies cross.
	for x in [310.0, 1900.0]:
		for i in 20:
			var y = 2160.0+i*15.0
			if absf(y-2310)<40:
				continue
			var p = Vector2(x+sin(y*0.02)*10,y)
			draw_style_box(_stone_box(),Rect2(p,Vector2(rng.randf_range(7,12),5)))

func _stone_box() -> StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=Color("#8e9176")
	s.border_color=Color("#4d5a4b")
	s.set_border_width_all(1)
	return s

class CopseTree extends Node2D:
	var factor = 1.0
	var seed_value = 0
	func _draw() -> void:
		var r=RandomNumberGenerator.new()
		r.seed=seed_value
		var s=factor
		var shadow=PackedVector2Array([Vector2(-12,-3)*s,Vector2(8,-5)*s,Vector2(55,22)*s,Vector2(36,27)*s])
		draw_colored_polygon(shadow,Color(0.18,0.28,0.24,0.17))
		draw_line(Vector2.ZERO,Vector2(-2,-28)*s,Color("#39463a"),4*s,true)
		for k in 15:
			var p=Vector2(r.randf_range(-20,20),r.randf_range(-42,-23))*s
			var radius=r.randf_range(9,16)*s
			var col=[Color("#344f46"),Color("#4d6950"),Color("#7e894b"),Color("#a09d59")][k%4]
			var pts=PackedVector2Array()
			for j in 9:
				var a=j*TAU/9
				pts.append(p+Vector2(cos(a),sin(a)*0.75)*radius*r.randf_range(0.85,1.1))
			draw_colored_polygon(pts,col)
			pts.append(pts[0])
			draw_polyline(pts,Color(0.16,0.25,0.22,0.5),0.65*s,true)
			if k%3==0:
				draw_line(p+Vector2(-4,-5)*s,p+Vector2(5,-7)*s,Color("#bdba77"),1.3*s,true)
