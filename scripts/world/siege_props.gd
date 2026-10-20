class_name SiegeProps
extends RefCounted
## Scene nodes for the Siege of Handan. The attack goes north (up the screen), so the walls run
## across the screen and show their tall south faces. Buildings are y-sorted with the soldiers by
## the south edge of their footprint, so a soldier behind a house is hidden by its roof; tall
## things fade when the player walks behind them. The siege engines roll north and animate.

## A city house: a lit facade on the south side (one or two storeys) under a tiled hip roof.
class House extends Node2D:
	var battle = null
	var rect := Rect2()
	var fh := 18.0
	var pal: Array = CityArt.ROOFS[0]
	var charred := 0.0
	var seed := 0
	var burning := false
	var glow := 1.0
	var ornate := false
	var storeys := 1

	func setup(b, r: Rect2, s: int) -> void:
		battle = b
		rect = r
		seed = s
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		pal = CityArt.ROOFS[rng.randi() % CityArt.ROOFS.size()]
		storeys = 2 if (r.size.x > 64.0 and rng.randf() < 0.45) else 1
		fh = rng.randf_range(17.0, 22.0) if storeys == 1 else 36.0
		position = Vector2(r.get_center().x, r.end.y)

	func _draw() -> void:
		var w := rect.size.x
		var d := rect.size.y
		var p := Painter.new(self)
		if storeys == 1:
			CityArt.facade(self, -w * 0.5 + 1.0, w * 0.5 - 1.0, fh, seed, glow)
		else:
			CityArt.facade(self, -w * 0.5 + 1.0, w * 0.5 - 1.0, 17.0, seed, glow)
			# a pent roof between the storeys, the upper floor set back a little
			var pr := PackedVector2Array([Vector2(-w * 0.5 - 4.0, -15.0), Vector2(w * 0.5 + 4.0, -15.0), Vector2(w * 0.5 + 1.0, -22.0), Vector2(-w * 0.5 - 1.0, -22.0)])
			p.fill(pr, pal[2] if charred < 0.3 else pal[1])
			var x := -w * 0.5 - 2.0
			while x < w * 0.5 + 2.0:
				draw_line(Vector2(x, -15.0), Vector2(x + 0.6, -21.5), Color(0, 0, 0, 0.25), 0.6)
				x += 3.2
			p.ink(pr, true, 0.7)
			draw_set_transform(Vector2(0, -21.0))
			CityArt.facade(self, -w * 0.5 + 5.0, w * 0.5 - 5.0, 15.0, seed + 7, glow)
			draw_set_transform(Vector2.ZERO)
		CityArt.roof(self, Rect2(-w * 0.5 - 5.0, -d - fh - 3.0, w + 10.0, d + 6.0), pal, charred, ornate)
		if seed % 3 == 0:
			CityArt.lantern(self, Vector2(-w * 0.5 + 6.0, -12.0), 1.0)
			CityArt.lantern(self, Vector2(w * 0.5 - 6.0, -12.0), 1.0)

	func _process(delta: float) -> void:
		_fade(self, battle, Rect2(rect.position.x - 4.0, rect.position.y - fh - 26.0, rect.size.x + 8.0, fh + 30.0), delta)

	static func _fade(n: CanvasItem, b, zone: Rect2, delta: float) -> void:
		var want := 1.0
		if b != null and b.player != null and is_instance_valid(b.player) and zone.has_point(b.player.global_position):
			want = 0.35
		n.modulate.a = move_toward(n.modulate.a, want, delta * 3.0)

## The back layer of the great wall, drawn on the ground under the soldiers: the inner parapet
## with stairs down into the city, the dark gate tunnel, ladders leaning on the face, torch
## sconces, and long banners hanging down the face (blue for Zhao, red once Qin holds that wall).
class WallBack extends Node2D:
	var lv = null

	func _draw() -> void:
		var L = lv
		var p := Painter.new(self)
		var w: float = Battle.W
		# the inner parapet: a low wall on the north side of the walk, its face toward us
		var gaps: Array = []
		for sx in L.STAIRS_X:
			gaps.append([sx - 16.0, sx + 16.0])
		gaps.append([L.GH_X0, L.GH_X1])
		gaps.sort_custom(func(a, b): return a[0] < b[0])
		gaps.append([w + 300.0, w + 300.0])
		var x := -300.0
		for g in gaps:
			if g[0] > x:
				_parapet(p, x, g[0], L.INNER_Y - 9.0, 15.0)
			x = g[1]
		# stairs down into the city
		for sx in L.STAIRS_X:
			for k in 7:
				var yy: float = L.INNER_Y + 6.0 - k * 6.0
				p.fill(Painter.rect(sx - 16.0, yy - 6.0, 32.0, 6.0), CityArt.STONE[2].lerp(CityArt.STONE[1], k / 7.0))
				draw_line(Vector2(sx - 16.0, yy - 6.0), Vector2(sx + 16.0, yy - 6.0), Color(0.05, 0.03, 0.1, 0.6), 0.8)
			for s in [-1.0, 1.0]:
				p.fill(Painter.rect(sx + s * 16.0 - (4.0 if s > 0 else 0.0), L.INNER_Y - 36.0, 4.0, 42.0), CityArt.STONE[0])
		# the gate tunnel: dark, with firelight at the far end
		var tun := Rect2(L.GATE_X0, L.WALK_Y1, L.GATE_X1 - L.GATE_X0, L.GROUND_Y - L.WALK_Y1)
		p.fill(Painter.rect(tun.position.x, tun.position.y, tun.size.x, tun.size.y), Color("#120c18"))
		for k in 8:
			var kk := k / 8.0
			draw_rect(Rect2(tun.position.x + 4.0, tun.end.y - (k + 1) * 12.0, tun.size.x - 8.0, 12.0), Color(0.3, 0.16, 0.1, 0.08 + kk * 0.12))
		# ladders leaning on the face
		for lx in L.LADDERS_X:
			_ladder(Vector2(lx, L.GROUND_Y + 26.0), Vector2(lx, L.WALK_Y1 - 14.0))
		# banners hanging from the parapet: Zhao blue, or Qin red once the stretch is taken
		for bx in L.banner_x:
			var sec: int = L.section_of(bx)
			var col := Color("#b8262c") if L.section_owner[sec] == 0 else Color("#2f4f9e")
			_banner(p, Vector2(bx, L.WALK_Y1 + 2.0), col)
		# iron torch sconces
		for tx in L.torch_x:
			var tp := Vector2(tx, L.WALK_Y1 + 30.0)
			draw_line(tp + Vector2(0, 8), tp, Color("#1a1018"), 2.0)
			p.fill(Painter.ellipse(tp + Vector2(0, -3.0), 3.0, 5.0, 10), Color("#ff9a3d"))
			p.fill(Painter.ellipse(tp + Vector2(0, -2.0), 1.6, 3.0, 8), Color("#ffe0a0"))

	func _parapet(p: Painter, x0: float, x1: float, y: float, h: float) -> void:
		p.fill(Painter.rect(x0, y, x1 - x0, h), CityArt.STONE[0])
		draw_line(Vector2(x0, y + 0.5), Vector2(x1, y + 0.5), CityArt.STONE[2], 1.0)
		var x := x0 + 8.0
		while x < x1:
			draw_line(Vector2(x, y + 2.0), Vector2(x, y + h), CityArt.STONE[1], 0.6)
			x += 16.0
		draw_line(Vector2(x0, y + h * 0.5), Vector2(x1, y + h * 0.5), CityArt.STONE[1], 0.5)
		p.ink(Painter.rect(x0, y, x1 - x0, h), true, 0.7)

	func _ladder(a: Vector2, b: Vector2) -> void:
		var l := a.distance_to(b)
		for s in [-1.0, 1.0]:
			draw_line(a + Vector2(s * 8.0, 0), b + Vector2(s * 6.0, 0), Color("#24140c"), 3.4, true)
			draw_line(a + Vector2(s * 8.0, 0), b + Vector2(s * 6.0, 0), Color("#6a4632"), 2.2, true)
		var k := 6.0
		while k < l:
			var q := a.lerp(b, k / l)
			var hw := lerpf(8.0, 6.0, k / l)
			draw_line(q + Vector2(-hw, 0), q + Vector2(hw, 0), Color("#24140c"), 2.2, true)
			draw_line(q + Vector2(-hw, -0.5), q + Vector2(hw, -0.5), Color("#8a6040"), 1.2, true)
			k += 8.0
		# grappling hooks over the parapet
		for s in [-1.0, 1.0]:
			draw_arc(b + Vector2(s * 6.0, -3.0), 3.0, PI, TAU, 6, Color("#2a2228"), 1.4)

	func _banner(p: Painter, top: Vector2, col: Color) -> void:
		var bw := 30.0
		var bh := 92.0
		draw_line(top + Vector2(-bw * 0.62, 0), top + Vector2(bw * 0.62, 0), Color("#3a2418"), 2.4)
		var cloth := PackedVector2Array([top + Vector2(-bw * 0.5, 1), top + Vector2(bw * 0.5, 1), top + Vector2(bw * 0.5, bh),
			top + Vector2(0, bh - 12.0), top + Vector2(-bw * 0.5, bh)])
		p.fill(cloth, col)
		p.fill(PackedVector2Array([top + Vector2(bw * 0.18, 1), top + Vector2(bw * 0.5, 1), top + Vector2(bw * 0.5, bh), top + Vector2(bw * 0.18, bh - 7.0)]), col.darkened(0.3))
		p.fill(Painter.circle(top + Vector2(0, 30), 9.0, 16), Color("#c9a24a"))
		p.fill(Painter.circle(top + Vector2(0, 30), 6.5, 16), col.darkened(0.15))
		draw_line(top + Vector2(-4, 26), top + Vector2(4, 34), Color("#f0cc6a"), 1.4)
		draw_line(top + Vector2(4, 26), top + Vector2(-4, 34), Color("#f0cc6a"), 1.4)
		p.ink(cloth, true, 0.8)

## The outer parapet of the walk: a row of merlons standing in front of the soldiers on the wall
## (y-sorted at the walk's south edge, so it hides their legs), open at the ladders and docks.
class Merlons extends Node2D:
	var lv = null

	func _draw() -> void:
		var L = lv
		var p := Painter.new(self)
		var w: float = Battle.W
		var gaps: Array = []
		for lx in L.LADDERS_X:
			gaps.append([lx - 11.0, lx + 11.0])
		for i in L.DOCKS_X.size():
			if i < L.towers.size() and L.towers[i].docked:
				gaps.append([L.DOCKS_X[i] - 21.0, L.DOCKS_X[i] + 21.0])
		gaps.append([L.GH_X0, L.GH_X1])
		gaps.sort_custom(func(a, b): return a[0] < b[0])
		gaps.append([w + 300.0, w + 300.0])
		var x0 := -300.0
		for g in gaps:
			if g[0] > x0:
				_run(p, x0, g[0])
			x0 = g[1]

	func _run(p: Painter, x0: float, x1: float) -> void:
		p.fill(Painter.rect(x0, -7.0, x1 - x0, 8.0), CityArt.STONE[0])
		draw_line(Vector2(x0, -7.0), Vector2(x1, -7.0), CityArt.STONE[2], 1.0)
		var x := x0 + 3.0
		while x + 13.0 <= x1 - 2.0:
			var m := Rect2(x, -22.0, 13.0, 15.0)
			p.fill(Painter.rect(m.position.x, m.position.y, m.size.x, m.size.y), CityArt.STONE[0].lightened(0.05))
			p.fill(Painter.rect(m.position.x, m.position.y, m.size.x, 3.0), CityArt.STONE[2])
			p.fill(Painter.rect(m.end.x - 3.0, m.position.y + 3.0, 3.0, 12.0), CityArt.STONE[1])
			p.ink(Painter.rect(m.position.x, m.position.y, m.size.x, m.size.y), true, 0.7)
			x += 20.0
		p.ink(Painter.rect(x0, -7.0, x1 - x0, 8.0), true, 0.7)

## A wall tower: a stone block rising above the walk, standing proud of the face, with arrow slits,
## a crenellated top and a wooden gallery under a tiled roof. The walk runs through it.
class WallTower extends Node2D:
	var battle = null
	var lv = null
	var w := 120.0

	func _draw() -> void:
		var L = lv
		var p := Painter.new(self)
		var foot: float = L.GROUND_Y - position.y
		var top: float = L.INNER_Y - position.y - 46.0
		var body := PackedVector2Array([Vector2(-w * 0.5 - 5.0, foot), Vector2(w * 0.5 + 5.0, foot), Vector2(w * 0.5, top), Vector2(-w * 0.5, top)])
		p.fill(body, CityArt.STONE[0].lightened(0.08))
		var y := top + 13.0
		var row := 0
		while y < foot - 1.0:
			var k := (y - top) / (foot - top)
			var hw := w * 0.5 + 5.0 * k
			draw_line(Vector2(-hw, y), Vector2(hw, y), CityArt.STONE[1], 0.8)
			var x := -hw + (0.0 if row % 2 == 0 else 14.0)
			while x < hw:
				draw_line(Vector2(x, y - 13.0), Vector2(x, y), CityArt.STONE[1], 0.6)
				x += 28.0
			y += 13.0
			row += 1
		# the tower stands proud of the wall: its right side falls into shadow
		p.fill(PackedVector2Array([Vector2(w * 0.5 - 16.0, top), Vector2(w * 0.5, top), Vector2(w * 0.5 + 5.0, foot), Vector2(w * 0.5 - 11.0, foot)]), Color(0.05, 0.03, 0.12, 0.4))
		p.fill(PackedVector2Array([Vector2(-w * 0.5, top), Vector2(-w * 0.5 + 6.0, top), Vector2(-w * 0.5 + 1.0, foot), Vector2(-w * 0.5 - 5.0, foot)]), Color(1.0, 0.85, 0.7, 0.12))
		for r in 3:
			for k in 3:
				var sp := Vector2(-w * 0.3 + k * w * 0.3, top + 44.0 + r * 70.0)
				p.fill(Painter.rect(sp.x - 2.2, sp.y, 4.4, 15.0), Color("#120a14"))
				if (r + k + int(position.x)) % 4 == 0:
					draw_rect(Rect2(sp.x - 1.4, sp.y + 4.0, 2.8, 8.0), Color(1.0, 0.6, 0.25, 0.8))
		p.ink(body, true, 1.1)
		var bc := PackedVector2Array([Vector2(-16, top + 20.0), Vector2(16, top + 20.0), Vector2(16, top + 150.0), Vector2(0, top + 136.0), Vector2(-16, top + 150.0)])
		p.fill(bc, Color("#2f4f9e"))
		p.fill(Painter.circle(Vector2(0, top + 52.0), 9.0, 14), Color("#c9a24a"))
		p.fill(Painter.circle(Vector2(0, top + 52.0), 6.0, 14), Color("#24407e"))
		p.ink(bc, true, 0.8)
		# crenellations, then the gallery and its roof
		var x2 := -w * 0.5
		while x2 < w * 0.5 - 6.0:
			p.fill(Painter.rect(x2, top - 9.0, 9.0, 9.0), CityArt.STONE[0])
			p.ink(Painter.rect(x2, top - 9.0, 9.0, 9.0), true, 0.6)
			x2 += 15.0
		draw_set_transform(Vector2(0, top - 6.0))
		CityArt.facade(self, -w * 0.4, w * 0.4, 24.0, int(position.x), 1.2)
		draw_set_transform(Vector2.ZERO)
		CityArt.roof(self, Rect2(-w * 0.5 - 16.0, top - 30.0 - 74.0 - 3.0, w + 32.0, 80.0), CityArt.ROOFS[0])

	func _process(delta: float) -> void:
		var L = lv
		House._fade(self, battle, Rect2(position.x - w * 0.5 - 8.0, L.INNER_Y - 170.0, w + 16.0, L.WALK_Y1 - L.INNER_Y + 170.0), delta)

## The great gatehouse: a battered stone block with an arched gate (studded doors until the ram
## breaks them) rising above the walls, crowned by a two-tier pagoda gate tower. Soldiers in the
## gate tunnel are hidden by the stone above the arch; it fades when the player is inside.
class GateHouse extends Node2D:
	var battle = null
	var lv = null
	var t := 0.0
	const HW := 150.0
	const AW := 40.0
	const AH := 100.0

	func _process(delta: float) -> void:
		t += delta
		var L = lv
		if L.gate_shake > 0.0:
			queue_redraw()
		# see-through only while the player is in the tunnel or in the street behind the gatehouse
		var want := 1.0
		if battle != null and battle.player != null and is_instance_valid(battle.player):
			var pp: Vector2 = battle.player.global_position
			var tunnel := Rect2(L.GATE_X0 - 6.0, L.INNER_Y - 4.0, L.GATE_X1 - L.GATE_X0 + 12.0, L.GROUND_Y - L.INNER_Y + 2.0)
			var behind := Rect2(position.x - HW - 20.0, L.INNER_Y - 300.0, HW * 2.0 + 40.0, 300.0)
			if tunnel.has_point(pp) or behind.has_point(pp):
				want = 0.35
		modulate.a = move_toward(modulate.a, want, delta * 3.0)

	func _arch_hw(y: float) -> float:
		# half width of the arch opening at height y (y < 0 above the ground)
		if y > -AH + AW:
			return AW
		var dy := y - (-AH + AW)
		return sqrt(maxf(0.0, AW * AW - dy * dy))

	func _draw() -> void:
		var L = lv
		var p := Painter.new(self)
		var top: float = L.INNER_Y - position.y - 54.0
		var tw := HW - 12.0
		var stone: Color = CityArt.STONE[0].lightened(0.1)
		var arch := PackedVector2Array()
		for i in 17:
			var a := PI * i / 16.0
			arch.append(Vector2(cos(a) * AW, -AH + AW - sin(a) * AW))
		var body := PackedVector2Array([Vector2(-HW, 0), Vector2(-tw, top), Vector2(tw, top), Vector2(HW, 0), Vector2(AW, 0)])
		body.append_array(arch)
		body.append(Vector2(-AW, 0))
		p.fill(body, stone)
		# courses of stone, interrupted by the arch
		var y := top + 14.0
		var row := 0
		while y < -1.0:
			var k := (y - top) / -top
			var hw := lerpf(tw, HW, k)
			var ah := _arch_hw(y) if y > -AH else -1.0
			if ah > 0.0:
				draw_line(Vector2(-hw, y), Vector2(-ah - 6.0, y), CityArt.STONE[1], 0.8)
				draw_line(Vector2(ah + 6.0, y), Vector2(hw, y), CityArt.STONE[1], 0.8)
			else:
				draw_line(Vector2(-hw, y), Vector2(hw, y), CityArt.STONE[1], 0.8)
			var x := -hw + (0.0 if row % 2 == 0 else 15.0)
			while x < hw:
				if ah < 0.0 or absf(x) > ah + 6.0:
					draw_line(Vector2(x, y - 14.0), Vector2(x, y), CityArt.STONE[1], 0.6)
				x += 30.0
			y += 14.0
			row += 1
		# voussoirs and keystone around the arch
		for i in 13:
			var a := PI * i / 12.0
			var c := Vector2(0, -AH + AW)
			draw_line(c + Vector2(cos(a), -sin(a)) * AW, c + Vector2(cos(a), -sin(a)) * (AW + 13.0), CityArt.STONE[1], 1.0)
		var arc := PackedVector2Array()
		for i in 17:
			var a := PI * i / 16.0
			arc.append(Vector2(0, -AH + AW) + Vector2(cos(a), -sin(a)) * (AW + 13.0))
		draw_polyline(arc, CityArt.INK, 1.0, true)
		p.fill(PackedVector2Array([Vector2(-6, -AH - 1), Vector2(6, -AH - 1), Vector2(8, -AH - 15), Vector2(-8, -AH - 15)]), CityArt.STONE[2])
		# shading: lit left edge, shadowed right flank, dark plinth
		p.fill(PackedVector2Array([Vector2(tw - 18.0, top), Vector2(tw, top), Vector2(HW, 0), Vector2(HW - 18.0, 0)]), Color(0.05, 0.03, 0.12, 0.38))
		p.fill(Painter.rect(-HW, -10.0, HW - AW, 10.0), CityArt.STONE[1])
		p.fill(Painter.rect(AW, -10.0, HW - AW, 10.0), CityArt.STONE[1])
		p.ink(body, true, 1.4)
		# rows of arrow-slit windows, some lit from inside
		for r in 3:
			var wy := top + 30.0 + r * 52.0
			if wy > -AH - 40.0:
				break
			var k := (wy - top) / -top
			var hw := lerpf(tw, HW, k) - 26.0
			var nw := 6
			for i in nw:
				var wx := -hw + i * hw * 2.0 / (nw - 1)
				p.fill(Painter.rect(wx - 3.0, wy, 6.0, 16.0), Color("#120a14"))
				if (i + r) % 3 != 1:
					draw_rect(Rect2(wx - 2.0, wy + 4.0, 4.0, 10.0), Color(1.0, 0.62, 0.28, 0.85))
		# a carved plaque over the arch with the city's name
		var pq := Rect2(-34.0, -AH - 44.0, 68.0, 22.0)
		p.fill(Painter.rect(pq.position.x - 3.0, pq.position.y - 3.0, pq.size.x + 6.0, pq.size.y + 6.0), Color("#3a2a1e"))
		p.fill(Painter.rect(pq.position.x, pq.position.y, pq.size.x, pq.size.y), Color("#1a1430"))
		draw_rect(pq.grow(-2.5), Color("#c9a24a"), false, 1.0)
		for i in 2:
			var cx := -12.0 + i * 24.0
			draw_line(Vector2(cx - 6, pq.position.y + 6), Vector2(cx + 6, pq.position.y + 6), Color("#e8c46a"), 1.4)
			draw_line(Vector2(cx, pq.position.y + 4), Vector2(cx, pq.end.y - 4), Color("#e8c46a"), 1.4)
			draw_line(Vector2(cx - 6, pq.end.y - 6), Vector2(cx + 6, pq.end.y - 6), Color("#e8c46a"), 1.4)
		# long banners either side of the arch, and torches
		for s in [-1.0, 1.0]:
			var bx: float = s * (AW + 46.0)
			var cloth := PackedVector2Array([Vector2(bx - 14.0, -AH - 30.0), Vector2(bx + 14.0, -AH - 30.0), Vector2(bx + 14.0, -16.0), Vector2(bx, -26.0), Vector2(bx - 14.0, -16.0)])
			p.fill(cloth, Color("#2f4f9e"))
			p.fill(Painter.circle(Vector2(bx, -AH + 4.0), 8.0, 14), Color("#c9a24a"))
			p.fill(Painter.circle(Vector2(bx, -AH + 4.0), 5.5, 14), Color("#24407e"))
			p.ink(cloth, true, 0.8)
			var tp: Vector2 = Vector2(s * (AW + 16.0), -60.0)
			draw_line(tp + Vector2(0, 10), tp, Color("#1a1018"), 2.4)
			p.fill(Painter.ellipse(tp + Vector2(0, -4.0), 3.6, 6.0, 10), Color("#ff9a3d"))
			p.fill(Painter.ellipse(tp + Vector2(0, -3.0), 2.0, 3.6, 8), Color("#ffe0a0"))
		# the doors, or what is left of them
		var shake: float = L.gate_shake
		if not L.gate_broken:
			var door := PackedVector2Array([Vector2(AW, 0)])
			door.append_array(arch)
			door.append(Vector2(-AW, 0))
			var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
			door = Painter.shift(door, off)
			p.fill(door, Color("#5a3220"))
			for k in 7:
				var xx := -AW + 6.0 + k * 11.3
				draw_line(Vector2(xx, -_arch_top(xx) + 2.0) + off, Vector2(xx, 0) + off, Color("#3a1e12"), 1.0)
			draw_line(Vector2(0, -AH) + off, Vector2(0, 0) + off, Color("#24120a"), 2.0)
			for by in [-18.0, -48.0, -76.0]:
				var hw2 := _arch_hw(by) - 1.0
				draw_line(Vector2(-hw2, by) + off, Vector2(hw2, by) + off, Color("#2a2228"), 3.0)
				for s in 6:
					var sx := -hw2 + 4.0 + s * (hw2 * 2.0 - 8.0) / 5.0
					draw_circle(Vector2(sx, by) + off, 1.6, Color("#d9b04a"))
			if shake > 0.0:
				p.fill(door, Color(1.0, 0.8, 0.5, 0.2))
			p.ink(door, true, 1.0)
		else:
			var rng := RandomNumberGenerator.new()
			rng.seed = 99
			for k in 9:
				var c := Vector2(rng.randf_range(-AW, AW), rng.randf_range(-14.0, 18.0))
				var plank := Painter.rotated(Painter.rect(c.x - 12, c.y - 2, 24, 4), c, rng.randf_range(-1.3, 1.3))
				p.fill(plank, Color("#5a3220"))
				p.ink(plank, true, 0.5)
			var leaf := Painter.rotated(Painter.rect(-AW - 2.0, -AH * 0.8, 12.0, AH * 0.8), Vector2(-AW, 0), -0.15)
			p.fill(leaf, Color("#4a2818"))
			p.ink(leaf, true, 0.6)
		# crenellated top, then the two-tier gate tower
		var x2 := -tw
		while x2 < tw - 8.0:
			p.fill(Painter.rect(x2, top - 11.0, 11.0, 11.0), CityArt.STONE[0])
			p.ink(Painter.rect(x2, top - 11.0, 11.0, 11.0), true, 0.6)
			x2 += 18.0
		var b1 := top - 4.0
		draw_set_transform(Vector2(0, b1))
		CityArt.facade(self, -tw + 14.0, tw - 14.0, 54.0, 77, 1.4)
		draw_set_transform(Vector2.ZERO)
		# a red-railed balcony and big lanterns across the front of the tower
		p.fill(Painter.rect(-tw + 6.0, b1 - 20.0, tw * 2.0 - 12.0, 4.0), CityArt.LACQUER[0])
		var rx := -tw + 10.0
		while rx < tw - 8.0:
			draw_line(Vector2(rx, b1 - 16.0), Vector2(rx, b1 - 6.0), CityArt.LACQUER[1], 1.6)
			rx += 12.0
		for s in [-1.0, -0.33, 0.33, 1.0]:
			CityArt.lantern(self, Vector2(s * (tw - 30.0), b1 - 30.0), 2.0)
		var d1 := 110.0
		CityArt.roof(self, Rect2(-tw - 40.0, b1 - 54.0 - d1 - 3.0, tw * 2.0 + 80.0, d1 + 6.0), CityArt.ROOFS[0])
		var b2 := b1 - 54.0 - d1 * 0.52
		draw_set_transform(Vector2(0, b2))
		CityArt.facade(self, -tw * 0.6, tw * 0.6, 40.0, 78, 1.4)
		draw_set_transform(Vector2.ZERO)
		var d2 := 76.0
		CityArt.roof(self, Rect2(-tw * 0.86, b2 - 40.0 - d2 - 3.0, tw * 1.72, d2 + 6.0), CityArt.ROOFS[0])

	func _arch_top(x: float) -> float:
		# height of the arch opening above the ground at x
		if absf(x) >= AW:
			return 0.0
		return AH - AW + sqrt(maxf(0.0, AW * AW - x * x))

## The grand stairs up the palace terrace: marble steps between carved cheeks, with a dragon
## ramp of relief carving up the middle (drawn over the terrace face).
class TerraceStairs extends Node2D:
	var lv = null

	func _draw() -> void:
		var L = lv
		var p := Painter.new(self)
		var r: Rect2 = L.GRAND_STAIRS
		var n := 16
		var sh := r.size.y / n
		for k in n:
			var y := r.end.y - (k + 1) * sh
			var lit := Color("#d6cfd8").lerp(Color("#a59cb0"), float(k) / n)
			p.fill(Painter.rect(r.position.x, y, r.size.x, sh * 0.62), lit)
			p.fill(Painter.rect(r.position.x, y + sh * 0.62, r.size.x, sh * 0.38), Color("#6c6480"))
		# the dragon ramp
		var dr := Rect2(r.get_center().x - 22.0, r.position.y, 44.0, r.size.y)
		p.fill(Painter.rect(dr.position.x, dr.position.y, dr.size.x, dr.size.y), Color("#c4bccb"))
		var pts := PackedVector2Array()
		for i in 40:
			var k := i / 39.0
			pts.append(Vector2(dr.get_center().x + sin(k * 14.0) * 13.0, dr.position.y + k * dr.size.y))
		draw_polyline(pts, Color("#c9a24a"), 2.2, true)
		draw_polyline(pts, Color("#8a6a2a"), 0.8, true)
		p.ink(Painter.rect(dr.position.x, dr.position.y, dr.size.x, dr.size.y), true, 0.8)
		for s in [r.position.x, r.end.x - 14.0]:
			p.fill(Painter.rect(s, r.position.y - 6.0, 14.0, r.size.y + 6.0), Color("#ddd6e0"))
			draw_line(Vector2(s + 14.0 if s == r.position.x else s, r.position.y), Vector2(s + 14.0 if s == r.position.x else s, r.end.y), Color("#6c6480"), 1.2)
			p.ink(Painter.rect(s, r.position.y - 6.0, 14.0, r.size.y + 6.0), true, 0.8)

## The white marble balustrade along the edge of the palace terrace (in front of the soldiers up
## there), open at the grand stairs.
class Balustrade extends Node2D:
	var lv = null

	func _draw() -> void:
		var L = lv
		var p := Painter.new(self)
		var r: Rect2 = L.GRAND_STAIRS
		for seg in [[-300.0, r.position.x], [r.end.x, Battle.W + 300.0]]:
			var x0: float = seg[0]
			var x1: float = seg[1]
			p.fill(Painter.rect(x0, -4.0, x1 - x0, 5.0), Color("#cfc7d4"))
			draw_line(Vector2(x0, -11.0), Vector2(x1, -11.0), Color("#e8e2ec"), 2.0)
			draw_line(Vector2(x0, -11.0), Vector2(x1, -11.0), Color("#6c6480"), 0.5)
			var x := x0 + 4.0
			while x < x1 - 4.0:
				p.fill(Painter.rect(x - 2.5, -16.0, 5.0, 16.0), Color("#e6e0ea"))
				p.fill(Painter.circle(Vector2(x, -17.0), 3.2, 10), Color("#f2eef4"))
				p.ink(Painter.rect(x - 2.5, -16.0, 5.0, 16.0), true, 0.5)
				x += 26.0
			p.ink(Painter.rect(x0, -4.0, x1 - x0, 5.0), true, 0.6)

## The gate pavilion at the head of the grand stairs: red pillars, studded doors, golden roof.
class PalaceGate extends Node2D:
	var battle = null
	var lv = null

	func _draw() -> void:
		var L = lv
		var p := Painter.new(self)
		var hw := 100.0
		var h := 50.0
		p.fill(Painter.rect(-hw - 6.0, -6.0, hw * 2.0 + 12.0, 6.0), Color("#cfc7d4"))
		p.fill(Painter.rect(-hw, -h, hw * 2.0, h - 6.0), CityArt.PLASTER[0])
		if not L.palace_open:
			p.fill(Painter.rect(-38.0, -h + 4.0, 76.0, h - 10.0), Color("#b0281e"))
			draw_line(Vector2(0, -h + 4.0), Vector2(0, -6.0), Color("#5a1410"), 1.6)
			for i in 5:
				for j in 6:
					draw_circle(Vector2(-33.0 + j * 13.2, -h + 9.0 + i * 8.0), 1.2, Color("#f0cc6a"))
		else:
			p.fill(Painter.rect(-38.0, -h + 4.0, 76.0, h - 10.0), Color("#1a1018"))
			for s in [-1.0, 1.0]:
				p.fill(Painter.rect(s * 38.0 - (8.0 if s > 0 else 0.0), -h + 4.0, 8.0, h - 10.0), Color("#8a2018"))
		for px in [-hw + 4.0, -44.0, 44.0, hw - 4.0]:
			p.fill(Painter.rect(px - 4.0, -h, 8.0, h - 6.0), CityArt.LACQUER[0])
			draw_line(Vector2(px + 4.0, -h), Vector2(px + 4.0, -6.0), CityArt.LACQUER[1], 1.2)
		p.ink(Painter.rect(-hw, -h, hw * 2.0, h - 6.0), true, 0.9)
		CityArt.roof(self, Rect2(-hw - 22.0, -h - 66.0 - 3.0, hw * 2.0 + 44.0, 72.0), CityArt.ROOFS[0], 0.0, true)

	func _process(delta: float) -> void:
		House._fade(self, battle, Rect2(position.x - 130.0, position.y - 130.0, 260.0, 130.0), delta)

## A stone bridge over the canal: a flagged deck with low parapets, and its arch over the water.
class Bridge extends Node2D:
	var r := Rect2()

	func _draw() -> void:
		var p := Painter.new(self)
		p.fill(Painter.rect(r.position.x, r.position.y, r.size.x, r.size.y - 14.0), Color("#8e8698"))
		var y := r.position.y + 10.0
		while y < r.end.y - 14.0:
			draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0.2, 0.17, 0.26, 0.6), 0.6)
			y += 10.0
		# the south face with its arch over the water
		var fy := r.end.y - 14.0
		p.fill(Painter.rect(r.position.x, fy, r.size.x, 14.0), Color("#6c6480"))
		p.fill(Painter.ellipse(Vector2(r.get_center().x, r.end.y), r.size.x * 0.32, 10.0, 20, PI, TAU), Color("#0e1222"))
		for s in [r.position.x, r.end.x - 6.0]:
			p.fill(Painter.rect(s, r.position.y - 6.0, 6.0, r.size.y), Color("#b0a8ba"))
			var yy := r.position.y
			while yy < r.end.y - 8.0:
				p.fill(Painter.rect(s - 1.0, yy - 8.0, 8.0, 8.0), Color("#c8c0d0"))
				p.ink(Painter.rect(s - 1.0, yy - 8.0, 8.0, 8.0), true, 0.4)
				yy += 18.0
		p.ink(Painter.rect(r.position.x, r.position.y, r.size.x, r.size.y), true, 0.8)

## A five-storey temple pagoda.
class Pagoda extends Node2D:
	var battle = null
	var w := 92.0

	func _draw() -> void:
		var p := Painter.new(self)
		p.fill(Painter.rect(-w * 0.62, -12.0, w * 1.24, 12.0), CityArt.STONE[0])
		p.ink(Painter.rect(-w * 0.62, -12.0, w * 1.24, 12.0), true, 0.8)
		var y := -12.0
		for tier in 5:
			var fw := w * (1.0 - tier * 0.13)
			var fhh := 26.0 if tier == 0 else 19.0
			draw_set_transform(Vector2(0, y))
			CityArt.facade(self, -fw * 0.42, fw * 0.42, fhh, 300 + tier, 1.3)
			draw_set_transform(Vector2.ZERO)
			y -= fhh
			var rd := 36.0 - tier * 3.0
			CityArt.roof(self, Rect2(-fw * 0.64, y - rd * 0.6, fw * 1.28, rd), CityArt.ROOFS[2], 0.0, tier == 4)
			y -= rd * 0.42
		var gold := Color("#d9a845")
		draw_line(Vector2(0, y), Vector2(0, y - 44.0), Color("#2a1810"), 3.4)
		draw_line(Vector2(0, y), Vector2(0, y - 44.0), gold, 2.0)
		for k in 6:
			p.fill(Painter.ellipse(Vector2(0, y - 8.0 - k * 5.5), 4.5 - k * 0.4, 1.6, 10), gold)
		p.fill(Painter.circle(Vector2(0, y - 46.0), 3.2, 10), Color("#f6d886"))

	func _process(delta: float) -> void:
		House._fade(self, battle, Rect2(position.x - w * 0.7, position.y - 270.0, w * 1.4, 270.0), delta)

## A Qin siege tower rolling north to the wall. When it docks, its drawbridge drops onto the walk
## and soldiers climb up inside it.
class SiegeTowerV extends Node2D:
	var x := 0.0
	var y := 0.0
	var dock_y := 2000.0
	var speed := 9.0
	var docked := false
	var started := false
	var delay := 0.0
	var t := 0.0
	var bridge := 0.0
	const TH := 160.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var p := Painter.new(self)
		var moving := started and not docked
		var wob := sin(t * 3.0) * 0.8 if moving else 0.0
		var wb := 60.0
		var wt := 46.0
		var body := PackedVector2Array([Vector2(-wb * 0.5, -8.0), Vector2(wb * 0.5, -8.0), Vector2(wt * 0.5 + wob, -TH), Vector2(-wt * 0.5 + wob, -TH)])
		p.fill(body, Color("#4a3426"))
		var n := 8
		for k in n:
			var y0 := -8.0 - k * (TH - 8.0) / n
			var y1 := y0 - (TH - 8.0) / n
			var hw0 := lerpf(wb, wt, float(k) / n) * 0.5
			var hw1 := lerpf(wb, wt, float(k + 1) / n) * 0.5
			var band := PackedVector2Array([Vector2(-hw0 + 1.5, y0 - 1.5), Vector2(hw0 - 1.5, y0 - 1.5), Vector2(hw1 - 1.5 + wob * (k + 1) / n, y1 + 1.5), Vector2(-hw1 + 1.5 + wob * (k + 1) / n, y1 + 1.5)])
			p.fill(band, Color("#6e4a34") if k % 2 == 0 else Color("#5e3e2c"))
			draw_line(Vector2(-hw0, y0), Vector2(hw0, y0), Color("#2a1810"), 1.4)
			if k % 3 == 1:
				p.fill(Painter.rect(-5.0 + wob * k / n, y0 - 12.0, 10.0, 6.0), Color("#140c10"))
		draw_line(Vector2(-wb * 0.5, -8.0), Vector2(wt * 0.5 + wob, -TH), Color("#2a1810"), 1.2)
		draw_line(Vector2(wb * 0.5, -8.0), Vector2(-wt * 0.5 + wob, -TH), Color("#2a1810"), 1.2)
		p.fill(PackedVector2Array([Vector2(wb * 0.5 - 10.0, -8.0), Vector2(wb * 0.5, -8.0), Vector2(wt * 0.5 + wob, -TH), Vector2(wt * 0.5 - 8.0 + wob, -TH)]), Color(0.05, 0.03, 0.08, 0.35))
		p.ink(body, true, 1.2)
		for s in [-1.0, 1.0]:
			var c := Vector2(s * 26.0, -6.0)
			p.fill(Painter.ellipse(c, 6.0, 8.0, 14), Color("#3a2418"))
			var spin := t * 2.0 if moving else 0.0
			for k in 3:
				var a := spin + k * PI / 3.0
				draw_line(c - Vector2(cos(a) * 5.0, sin(a) * 7.0), c + Vector2(cos(a) * 5.0, sin(a) * 7.0), Color("#6a4632"), 1.0)
			p.ink(Painter.ellipse(c, 6.0, 8.0, 14), true, 0.7)
		# top platform with a wicker parapet and a Qin banner
		var top := Vector2(wob, -TH)
		p.fill(Painter.rect(top.x - wt * 0.6, top.y - 10.0, wt * 1.2, 10.0), Color("#7a5434"))
		for k in 7:
			draw_line(Vector2(top.x - wt * 0.6 + k * wt * 0.2, top.y - 10.0), Vector2(top.x - wt * 0.6 + k * wt * 0.2, top.y), Color("#3a2418"), 0.9)
		p.ink(Painter.rect(top.x - wt * 0.6, top.y - 10.0, wt * 1.2, 10.0), true, 0.8)
		CityArt.pennant(self, top + Vector2(-wt * 0.5, -10.0), 30.0, 15.0, Color("#b8262c"), x * 0.01, t)
		# the drawbridge: standing up while it rolls, dropped flat onto the walk when docked
		var bh := lerpf(34.0, 26.0, bridge)
		var plank := Painter.rect(top.x - wt * 0.42, top.y - 10.0 - bh, wt * 0.84, bh)
		p.fill(plank, Color("#3e2a1e").lerp(Color("#9a6c46"), bridge))
		for k in 5:
			var yy := top.y - 10.0 - bh + (k + 0.5) * bh / 5.0
			draw_line(Vector2(top.x - wt * 0.42, yy), Vector2(top.x + wt * 0.42, yy), Color("#2a1810"), 0.8)
		p.ink(plank, true, 0.9)

## The covered ram rolling north on the avenue to the gate: a gabled roof of wet hides seen from
## behind and above, wheels along both sides, and a bronze-headed log that swings into the doors.
class RamV extends Node2D:
	var y := 0.0
	var swing := 0.0
	var moving := false
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		swing = maxf(0.0, swing - delta * 3.0)
		queue_redraw()

	func _draw() -> void:
		var p := Painter.new(self)
		var thrust := sin(minf(1.0, 1.0 - swing) * PI) * 14.0 if swing > 0.0 else 0.0
		for s in [-1.0, 1.0]:
			for k in 3:
				var c := Vector2(s * 27.0, -10.0 - k * 27.0)
				p.fill(Painter.ellipse(c, 3.6, 7.5, 10), Color("#2a1810"))
				p.ink(Painter.ellipse(c, 3.6, 7.5, 10), true, 0.5)
		var ly := -88.0 - thrust
		draw_line(Vector2(0, -60.0), Vector2(0, ly), Color("#2a1810"), 9.0, true)
		draw_line(Vector2(0, -60.0), Vector2(0, ly), Color("#6e4a34"), 6.4, true)
		var head := Painter.blob(PackedVector2Array([Vector2(-8, ly + 3), Vector2(-6, ly - 9), Vector2(6, ly - 9), Vector2(8, ly + 3)]), 2)
		p.fill(head, Color("#b8862e"))
		p.ink(head, true, 0.7)
		var lroof := PackedVector2Array([Vector2(-29, -2), Vector2(0, -8), Vector2(0, -80), Vector2(-25, -74)])
		var rroof := PackedVector2Array([Vector2(0, -8), Vector2(29, -2), Vector2(25, -74), Vector2(0, -80)])
		p.fill(lroof, Color("#6a4834"))
		p.fill(rroof, Color("#3e2a22"))
		for k in 7:
			var yy := -10.0 - k * 10.0
			draw_line(Vector2(-27.0 + k * 0.5, yy + 1.5), Vector2(0, yy - 4.0), Color("#4a3224"), 1.0)
			draw_line(Vector2(0, yy - 4.0), Vector2(27.0 - k * 0.5, yy + 1.5), Color("#2a1a14"), 1.0)
		draw_line(Vector2(0, -8), Vector2(0, -80), Color("#8a6044"), 1.4)
		p.ink(lroof, true, 0.9)
		p.ink(rroof, true, 0.9)
		# the open rear end with the crew's legs
		p.fill(Painter.rect(-22.0, -4.0, 44.0, 6.0), Color("#1a1018"))
		if moving:
			for i in 4:
				var fx := -16.0 + i * 10.6
				var ph := sin(t * 9.0 + i)
				draw_line(Vector2(fx, -4.0), Vector2(fx + ph * 2.0, 3.0), Color("#3a2a30"), 2.0)

## Strings of red lanterns hung across a street, swaying a little (drawn above the soldiers).
class LanternLine extends Node2D:
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var n := 5
	var ph := 0.0
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var sag := a.distance_to(b) * 0.12
		var pts := PackedVector2Array()
		for i in 13:
			var k := i / 12.0
			pts.append(a.lerp(b, k) + Vector2(0, sin(k * PI) * sag))
		draw_polyline(pts, Color(0.05, 0.04, 0.08, 0.9), 0.8, true)
		for i in n:
			var k := (i + 1.0) / (n + 1.0)
			var c := a.lerp(b, k) + Vector2(sin(t * 1.4 + ph + i) * 0.8, sin(k * PI) * sag + 5.0)
			CityArt.lantern(self, c, 1.1)

## A market stall: a cloth awning on poles over a counter of goods.
class Stall extends Node2D:
	var w := 30.0
	var col := Color("#b8322a")
	var seed := 0

	func _draw() -> void:
		var p := Painter.new(self)
		p.fill(Painter.rect(-w * 0.5, -10.0, w, 10.0), CityArt.WOOD[0])
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		for i in int(w / 5.0):
			var c := Vector2(-w * 0.5 + 3.0 + i * 5.0, -11.0)
			p.fill(Painter.circle(c, 1.8, 8), [Color("#d9a23a"), Color("#8fb36a"), Color("#c95a3a"), Color("#e8d6b0")][rng.randi() % 4])
		for s in [-1.0, 1.0]:
			draw_line(Vector2(s * w * 0.48, 0), Vector2(s * w * 0.48, -24.0), CityArt.WOOD[1], 1.2)
		var aw := PackedVector2Array([Vector2(-w * 0.58, -20.0), Vector2(w * 0.58, -20.0), Vector2(w * 0.5, -28.0), Vector2(-w * 0.5, -28.0)])
		p.fill(aw, col)
		for i in 4:
			var x := -w * 0.58 + i * w * 0.39
			p.fill(Painter.rect(x, -20.0, w * 0.18, 3.0), col.lightened(0.3))
		p.ink(aw, true, 0.6)

## The palace hall: a white marble terrace, red pillars, glowing doors and a double golden roof.
class PalaceHall extends Node2D:
	var battle = null
	var rect := Rect2()

	func setup(b, r: Rect2) -> void:
		battle = b
		rect = r
		position = Vector2(r.get_center().x, r.end.y)

	func _draw() -> void:
		var w := rect.size.x
		var d := rect.size.y
		var p := Painter.new(self)
		# terrace face
		p.fill(Painter.rect(-w * 0.5 - 8.0, -12.0, w + 16.0, 12.0), Color("#c9c2cf"))
		for k in 12:
			var x := -w * 0.5 - 8.0 + k * (w + 16.0) / 12.0
			draw_line(Vector2(x, -12.0), Vector2(x, 0), Color("#8a8296"), 0.6)
		p.ink(Painter.rect(-w * 0.5 - 8.0, -12.0, w + 16.0, 12.0), true, 0.8)
		# hall facade
		var fh := 34.0
		draw_set_transform(Vector2(0, -12.0))
		CityArt.facade(self, -w * 0.46, w * 0.46, fh, 99, 1.4)
		for k in 9:
			var x := -w * 0.46 + k * w * 0.92 / 8.0
			p.fill(Painter.rect(x - 2.4, -fh, 4.8, fh), CityArt.LACQUER[0])
			draw_line(Vector2(x + 2.4, -fh), Vector2(x + 2.4, 0), CityArt.LACQUER[1], 1.0)
		draw_set_transform(Vector2.ZERO)
		var top := -12.0 - fh
		# lower and upper golden roofs
		CityArt.roof(self, Rect2(-w * 0.5 - 14.0, top - d - 6.0, w + 28.0, d + 12.0), CityArt.ROOFS[0], 0.0, true)
		var w2 := w * 0.66
		var d2 := d * 0.5
		var uy := top - d * 0.55
		draw_set_transform(Vector2(0, uy))
		CityArt.facade(self, -w2 * 0.46, w2 * 0.46, 14.0, 98, 1.4)
		draw_set_transform(Vector2.ZERO)
		CityArt.roof(self, Rect2(-w2 * 0.5 - 10.0, uy - 14.0 - d2 - 4.0, w2 + 20.0, d2 + 8.0), CityArt.ROOFS[0], 0.0, true)
		# plaque
		p.fill(Painter.rect(-14.0, uy - 6.0, 28.0, 10.0), Color("#1a1430"))
		draw_rect(Rect2(-12.0, uy - 4.5, 24.0, 7.0), Color("#c9a24a"), false, 0.8)

	func _process(delta: float) -> void:
		House._fade(self, battle, Rect2(rect.position.x - 14.0, rect.position.y - 120.0, rect.size.x + 28.0, rect.size.y + 110.0), delta)

## The drum tower in the plaza: a stone base, two wooden storeys and a great war drum.
class DrumTower extends Node2D:
	var battle = null
	var rect := Rect2()

	func setup(b, r: Rect2) -> void:
		battle = b
		rect = r
		position = Vector2(r.get_center().x, r.end.y)

	func _draw() -> void:
		var w := rect.size.x
		var d := rect.size.y
		var p := Painter.new(self)
		p.fill(Painter.rect(-w * 0.5, -22.0, w, 22.0), CityArt.STONE[0])
		p.fill(Painter.rect(-9.0, -18.0, 18.0, 18.0), Color("#140c12"))
		p.ink(Painter.rect(-w * 0.5, -22.0, w, 22.0), true, 0.8)
		draw_set_transform(Vector2(0, -22.0))
		CityArt.facade(self, -w * 0.42, w * 0.42, 18.0, 31, 1.2)
		draw_set_transform(Vector2.ZERO)
		var dc := Vector2(0, -34.0)
		p.fill(Painter.ellipse(dc, 9.0, 7.0, 16), Color("#8e2a20"))
		p.fill(Painter.ellipse(dc, 6.0, 4.6, 14), Color("#e8d6b0"))
		var top := -40.0
		CityArt.roof(self, Rect2(-w * 0.5 - 8.0, top - d - 4.0, w + 16.0, d + 8.0), CityArt.ROOFS[2])
		draw_set_transform(Vector2(0, top - d * 0.35))
		CityArt.facade(self, -w * 0.3, w * 0.3, 10.0, 32, 1.2)
		draw_set_transform(Vector2.ZERO)
		CityArt.roof(self, Rect2(-w * 0.36, top - d * 0.35 - 10.0 - d * 0.55, w * 0.72, d * 0.6), CityArt.ROOFS[2])

	func _process(delta: float) -> void:
		House._fade(self, battle, Rect2(rect.position.x - 8.0, rect.position.y - 110.0, rect.size.x + 16.0, rect.size.y + 100.0), delta)

## A trebuchet in the Qin camp. Its arm snaps over when it throws.
class Trebuchet extends Node2D:
	var t := 0.0
	var fire_t := 9.0

	func throw() -> void:
		fire_t = 0.0

	func _process(delta: float) -> void:
		t += delta
		fire_t += delta
		queue_redraw()

	func _draw() -> void:
		var p := Painter.new(self)
		# A-frame
		for s in [-1.0, 1.0]:
			draw_line(Vector2(s * 22.0, 0), Vector2(0, -52.0), Color("#2a1810"), 4.0, true)
			draw_line(Vector2(s * 22.0, 0), Vector2(0, -52.0), Color("#6a4632"), 2.6, true)
		draw_line(Vector2(-26, 0), Vector2(26, 0), Color("#4a2c1c"), 4.0)
		# arm: cocked back, then whipping forward
		var k := clampf(fire_t / 0.35, 0.0, 1.0)
		var reload := clampf((fire_t - 1.2) / 3.0, 0.0, 1.0)
		var ang := lerpf(deg_to_rad(150.0), deg_to_rad(-60.0), 1.0 - (1.0 - k) * (1.0 - k))
		if fire_t > 1.2:
			ang = lerpf(deg_to_rad(-60.0), deg_to_rad(150.0), reload)
		var piv := Vector2(0, -50.0)
		var tip := piv + Vector2.from_angle(ang) * 62.0
		var cw := piv - Vector2.from_angle(ang) * 16.0
		draw_line(piv, tip, Color("#1e120c"), 3.6, true)
		draw_line(piv, tip, Color("#7a5434"), 2.2, true)
		p.fill(Painter.rect(cw.x - 8.0, cw.y - 2.0, 16.0, 14.0), Color("#3a2a24"))
		p.ink(Painter.rect(cw.x - 8.0, cw.y - 2.0, 16.0, 14.0), true, 0.8)
		var sling := tip + Vector2(0, 14.0).rotated(ang * 0.3)
		draw_line(tip, sling, Color("#1e120c"), 0.8)
		if fire_t > 1.2 and reload > 0.9:
			draw_circle(sling, 4.0, Color("#ff8a3a"))
		p.fill(Painter.circle(piv, 3.0, 10), Color("#c9a24a"))

## Flaming trebuchet stones in flight, and pools of burning oil poured from the gatehouse.
class SiegeFx extends Node2D:
	var lv = null
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var gl: Texture2D = Art.tex["glow"]
		for s in lv.stones:
			var k: float = float(s["t"]) / float(s["dur"])
			var a: Vector2 = s["a"]
			var b: Vector2 = s["b"]
			var ground := a.lerp(b, k)
			var hgt := sin(k * PI) * float(s["h"])
			var pos := ground - Vector2(0, hgt)
			# shadow on the ground, growing as it falls
			draw_set_transform(ground, 0.0, Vector2(1.0, 0.45))
			draw_circle(Vector2.ZERO, 3.0 + k * 6.0, Color(0, 0, 0, 0.25 + k * 0.25))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# fire trail
			for i in 6:
				var kk := maxf(0.0, k - i * 0.025)
				var q := a.lerp(b, kk) - Vector2(0, sin(kk * PI) * float(s["h"]))
				var r := 7.0 - i
				draw_texture_rect(gl, Rect2(q - Vector2(r, r) * 1.6, Vector2(r, r) * 3.2), false, Color(1.0, 0.5, 0.18, 0.55 - i * 0.08))
			draw_circle(pos, 4.6, Color("#2a1c18"))
			draw_circle(pos + Vector2(-1, -1), 3.0, Color("#ffb04a"))
			if s.get("zhao", false):
				# where a Zhao stone will land: a pulsing red mark on the ground
				draw_set_transform(b, 0.0, Vector2(1.0, 0.55))
				var pulse := 0.5 + 0.5 * sin(t * 14.0)
				draw_arc(Vector2.ZERO, 38.0, 0.0, TAU, 40, Color(1.0, 0.3, 0.2, 0.35 + 0.45 * k), 1.6, true)
				draw_arc(Vector2.ZERO, 38.0 * (1.0 - k), 0.0, TAU, 32, Color(1.0, 0.45, 0.25, 0.25 + 0.3 * pulse), 1.0, true)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for o in lv.oil:
			var c: Vector2 = o["pos"]
			var r: float = o["r"]
			var st: String = o["state"]
			draw_set_transform(c, 0.0, Vector2(1.0, 0.6))
			if st == "warn":
				var pulse := 0.5 + 0.5 * sin(t * 18.0)
				draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, Color(1.0, 0.55, 0.15, 0.4 + 0.5 * pulse), 2.0, true)
				draw_arc(Vector2.ZERO, r * 0.5, 0.0, TAU, 24, Color(1.0, 0.55, 0.15, 0.3 * pulse), 1.0, true)
			else:
				draw_circle(Vector2.ZERO, r, Color(0.12, 0.05, 0.03, 0.75))
				for i in 7:
					var q := Vector2.from_angle(i * 0.9 + t) * r * 0.55 * (0.4 + 0.6 * fmod(i * 0.37, 1.0))
					draw_texture_rect(gl, Rect2(q - Vector2(9, 9), Vector2(18, 18)), false, Color(1.0, 0.45, 0.12, 0.5))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## A row of swallow-tail banners on poles, flapping in the hot wind of the fires.
class PennantRow extends Node2D:
	var flags: Array = []     # [base, colour, phase]
	var t := 0.0

	func add(p: Vector2, col: Color, ph: float) -> void:
		flags.append([p, col, ph])

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		for f in flags:
			CityArt.pennant(self, f[0], 36.0, 18.0, f[1], f[2], t)

## The far skyline of Handan against the burning horizon: pagodas, roof ridges and smoke.
class Skyline extends Node2D:
	var t := 0.0
	var base := 34.0
	var x0 := 1000.0
	var x1 := 3600.0

	func _process(delta: float) -> void:
		t += delta
		if Engine.get_process_frames() % 3 == 0:
			queue_redraw()

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		var gl: Texture2D = Art.tex["glow"]
		# fire glow along the horizon
		var x := x0
		while x < x1:
			var r := rng.randf_range(60.0, 130.0)
			var fl := 0.8 + 0.2 * sin(t * 2.0 + x * 0.01)
			draw_texture_rect(gl, Rect2(x - r, base - r * 0.7, r * 2.0, r * 0.9), false, Color(1.0, 0.42, 0.18, 0.32 * fl))
			x += rng.randf_range(80.0, 160.0)
		var far := Color("#1a1430")
		var near := Color("#120d22")
		x = x0 + 50.0
		while x < x1:
			var w := rng.randf_range(40.0, 90.0)
			var h := rng.randf_range(10.0, 22.0)
			var k := rng.randf()
			var top := base - h
			var col := far if k < 0.5 else near
			draw_rect(Rect2(x, top, w, h + 8.0), col)
			# a curled ridge roof
			var roof := PackedVector2Array([Vector2(x - 6, top + 2), Vector2(x + 4, top - 6), Vector2(x + w - 4, top - 6), Vector2(x + w + 6, top + 2)])
			draw_colored_polygon(roof, col)
			if k > 0.82:
				# a pagoda of stacked roofs
				var px := x + w * 0.5
				var ph := rng.randf_range(40.0, 70.0)
				for tier in 5:
					var ty := top - 6.0 - tier * ph / 5.0
					var tw := 22.0 - tier * 3.0
					draw_colored_polygon(PackedVector2Array([Vector2(px - tw, ty), Vector2(px - tw * 0.6, ty - 6.0), Vector2(px + tw * 0.6, ty - 6.0), Vector2(px + tw, ty)]), col)
					draw_rect(Rect2(px - tw * 0.45, ty - 6.0 - ph / 5.0 + 6.0, tw * 0.9, ph / 5.0 - 6.0), col)
				draw_line(Vector2(px, top - 6.0 - ph), Vector2(px, top - 14.0 - ph), col, 1.4)
			# lit windows
			for i in int(w / 12.0):
				if rng.randf() < 0.35:
					draw_rect(Rect2(x + 4.0 + i * 12.0, top + 4.0, 3.0, 2.0), Color(1.0, 0.7, 0.35, 0.8))
			x += w + rng.randf_range(-10.0, 16.0)
		# smoke columns leaning with the wind
		for i in 9:
			var sx := x0 + 200.0 + i * (x1 - x0) / 9.0 + rng.randf_range(-60, 60)
			for j in 8:
				var k := j / 8.0
				var c := Vector2(sx + k * 90.0 + sin(t * 0.4 + i + k * 3.0) * 8.0, base - 10.0 - k * 120.0)
				var r := 16.0 + k * 34.0
				draw_texture_rect(gl, Rect2(c - Vector2(r, r * 0.8), Vector2(r * 2.0, r * 1.6)), false, Color(0.22, 0.14, 0.24, 0.35 * (1.0 - k * 0.6)))

## A bronze ding cauldron on three legs, burning incense and fire.
class Ding extends Node2D:
	func _draw() -> void:
		var p := Painter.new(self)
		var bronze := Color("#5f6a4a")
		var dark := Color("#33392a")
		var hi := Color("#b8a45a")
		for s in [-1.0, 0.0, 1.0]:
			p.fill(Painter.limb(Vector2(s * 10.0, -8.0), Vector2(s * 13.0, 0.0), 3.0, 2.2), dark)
		var body := Painter.ellipse(Vector2(0, -14.0), 16.0, 10.0, 20)
		p.fill(body, bronze)
		p.fill(Painter.ellipse(Vector2(-4, -16.0), 8.0, 5.0, 14), hi.darkened(0.2))
		for k in 5:
			var x := -12.0 + k * 6.0
			draw_line(Vector2(x, -18.0), Vector2(x, -10.0), dark, 0.8)
		p.ink(body, true, 1.0)
		p.fill(Painter.ellipse(Vector2(0, -23.0), 15.0, 4.0, 18), dark)
		p.fill(Painter.ellipse(Vector2(0, -23.0), 12.0, 2.8, 16), Color("#ff9a3d"))
		for s in [-1.0, 1.0]:
			var hd := PackedVector2Array([Vector2(s * 9.0, -24.0), Vector2(s * 9.0, -31.0), Vector2(s * 14.0, -31.0), Vector2(s * 14.0, -24.0)])
			p.ink(hd, false, 1.6)

## A stone guardian lion on a plinth, flanking the steps of the palace hall.
class Lion extends Node2D:
	var flip := false

	func _draw() -> void:
		var p := Painter.new(self)
		var f := -1.0 if flip else 1.0
		var st := Color("#b7aebf")
		var sh := Color("#6e6680")
		p.fill(Painter.rect(-11.0, -8.0, 22.0, 8.0), Color("#8a8296"))
		p.ink(Painter.rect(-11.0, -8.0, 22.0, 8.0), true, 0.7)
		var body := PackedVector2Array([Vector2(-8 * f, -8), Vector2(7 * f, -8), Vector2(6 * f, -20), Vector2(2 * f, -27), Vector2(-5 * f, -24), Vector2(-8 * f, -15)])
		p.fill(body, st)
		p.fill(PackedVector2Array([Vector2(1 * f, -8), Vector2(7 * f, -8), Vector2(6 * f, -20), Vector2(3 * f, -14)]), sh)
		p.ink(body, true, 0.8)
		# curly mane and the face
		p.fill(Painter.circle(Vector2(3 * f, -27), 6.0, 12), st.lightened(0.1))
		for k in 5:
			draw_circle(Vector2(3 * f, -27) + Vector2.from_angle(k * 1.25) * 4.5, 1.4, sh)
		p.fill(Painter.circle(Vector2(5 * f, -26), 2.6, 10), st)
		draw_circle(Vector2(6 * f, -27.5), 0.7, Color("#1a1420"))
		p.ink(Painter.circle(Vector2(3 * f, -27), 6.0, 12), true, 0.7)
		# one paw on a ball
		p.fill(Painter.circle(Vector2(-4 * f, -10), 3.0, 10), Color("#c9a24a"))
		p.ink(Painter.circle(Vector2(-4 * f, -10), 3.0, 10), true, 0.5)
