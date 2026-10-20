extends "res://tools/bake_props.gd"
## Bakes the siege engines (built here from simple shapes in the KayKit palette, so they sit with
## the CC0 models): the siege tower (drawbridge up / down), the covered ram (three thrust
## positions) and the trebuchet (five arm angles). Same camera, sun, outline and shadow pass as
## the props. Hides are in the team key colour (red for the March in game).
##   godot --path . --script res://tools/bake_siege.gd

const WOOD := Color("#a8714a")
const WOOD_D := Color("#6e4630")
const WOOD_L := Color("#c99566")
const IRON := Color("#6d7380")
const BRONZE := Color("#c4904a")
const HIDE := Color(0.0, 0.6, 0.0)
const ROPE := Color("#d8c08a")

func _init() -> void:
	_siege_run.call_deferred()

func _m(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return _style(m, 1.0) as StandardMaterial3D

## A box mesh instance (size in metres) at a position, optionally rotated (euler degrees).
func _bx(parent: Node3D, size: Vector3, pos: Vector3, col: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _m(col)
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

func _cy(parent: Node3D, r: float, h: float, pos: Vector3, col: Color, rot: Vector3 = Vector3.ZERO, sides: int = 10) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = sides
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = _m(col)
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

func _wheel(parent: Node3D, pos: Vector3, r: float) -> void:
	_cy(parent, r, 0.3, pos, WOOD_D, Vector3(0, 0, 90), 12)
	_cy(parent, r * 0.3, 0.42, pos, IRON, Vector3(0, 0, 90), 8)
	for k in 3:
		_bx(parent, Vector3(0.12, r * 1.8, 0.14), pos + Vector3(0.05 * signf(pos.x), 0, 0), WOOD, Vector3(k * 60.0, 0, 0))

## The siege tower: tapering timber frame, hide-covered front, an open back showing the ladders,
## a parapet on top and a drawbridge hinged at the top front (north, -Z).
func _tower(open_k: float) -> Node3D:
	var n := Node3D.new()
	var h := 15.0
	var w0 := 4.8
	var w1 := 3.8
	for lv in 7:
		var y := 1.0 + lv * (h - 1.5) / 7.0
		var w := lerpf(w0, w1, float(lv) / 7.0)
		# floor beams
		_bx(n, Vector3(w + 0.3, 0.28, 0.3), Vector3(0, y, w * 0.5), WOOD_D)
		_bx(n, Vector3(w + 0.3, 0.28, 0.3), Vector3(0, y, -w * 0.5), WOOD_D)
		_bx(n, Vector3(0.3, 0.28, w + 0.3), Vector3(w * 0.5, y, 0), WOOD_D)
		_bx(n, Vector3(0.3, 0.28, w + 0.3), Vector3(-w * 0.5, y, 0), WOOD_D)
		var seg := (h - 1.5) / 7.0
		# front: wet hides; sides: planks; back: open, a ladder inside
		_bx(n, Vector3(w, seg * 0.92, 0.12), Vector3(0, y + seg * 0.5, -w * 0.5 + 0.05), HIDE)
		_bx(n, Vector3(0.12, seg * 0.92, w), Vector3(w * 0.5 - 0.05, y + seg * 0.5, 0), WOOD if lv % 2 == 0 else WOOD_L)
		_bx(n, Vector3(0.12, seg * 0.92, w), Vector3(-w * 0.5 + 0.05, y + seg * 0.5, 0), WOOD_L if lv % 2 == 0 else WOOD)
		if lv % 2 == 1:
			_bx(n, Vector3(w * 0.9, 0.18, 0.1), Vector3(0, y + seg * 0.6, w * 0.5 - 0.1), WOOD)
	# corner posts
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p0 := Vector3(sx * w0 * 0.5, 0.5, sz * w0 * 0.5)
			var p1 := Vector3(sx * w1 * 0.5, h, sz * w1 * 0.5)
			var mid := (p0 + p1) * 0.5
			var post := _bx(n, Vector3(0.38, (p1 - p0).length(), 0.38), mid, WOOD_D)
			post.look_at_from_position(mid, p1, Vector3(0, 0, 1) if absf((p1 - p0).normalized().y) > 0.99 else Vector3.UP)
			post.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	# ladder visible through the open back
	_bx(n, Vector3(0.12, h - 1.0, 0.12), Vector3(-0.5, h * 0.5, w0 * 0.35), WOOD_L)
	_bx(n, Vector3(0.12, h - 1.0, 0.12), Vector3(0.5, h * 0.5, w0 * 0.35), WOOD_L)
	for k in 14:
		_bx(n, Vector3(1.0, 0.1, 0.1), Vector3(0, 1.0 + k * 1.0, w0 * 0.35), WOOD)
	# parapet of stakes on the top platform
	_bx(n, Vector3(w1 + 0.6, 0.3, w1 + 0.6), Vector3(0, h, 0), WOOD)
	for k in 9:
		var x := lerpf(-w1 * 0.5, w1 * 0.5, k / 8.0)
		_bx(n, Vector3(0.22, 1.1, 0.22), Vector3(x, h + 0.7, w1 * 0.5), WOOD_D)
		_bx(n, Vector3(0.22, 1.1, 0.22), Vector3(-w1 * 0.5 if k < 5 else w1 * 0.5, h + 0.7, lerpf(-w1 * 0.5, w1 * 0.5, (k % 5) / 4.0)), WOOD_D)
	# a banner pole
	_cy(n, 0.07, 3.2, Vector3(-w1 * 0.5, h + 1.6, w1 * 0.5), WOOD_D)
	_bx(n, Vector3(1.4, 0.9, 0.05), Vector3(-w1 * 0.5 + 0.7, h + 2.6, w1 * 0.5), HIDE)
	# drawbridge hinged at the top front edge
	var hinge := Node3D.new()
	hinge.position = Vector3(0, h - 0.2, -w1 * 0.5 - 0.1)
	n.add_child(hinge)
	_bx(hinge, Vector3(w1 * 0.84, 4.2, 0.22), Vector3(0, 2.1, 0), WOOD_L)
	for k in 4:
		_bx(hinge, Vector3(w1 * 0.86, 0.14, 0.26), Vector3(0, 0.6 + k * 1.0, 0.02), WOOD_D)
	hinge.rotation_degrees.x = -90.0 * open_k
	# wheels
	for sx in [-1.0, 1.0]:
		for z in [-1.6, 0.0, 1.6]:
			_wheel(n, Vector3(sx * (w0 * 0.5 + 0.2), 0.9, z), 0.9)
	return n

## The covered ram: a gabled shed of hides on wheels, a bronze-headed log hanging inside.
func _ram(thrust: float) -> Node3D:
	var n := Node3D.new()
	var w := 4.4
	var l := 7.0
	var rh := 3.1
	for sx in [-1.0, 1.0]:
		# a pitched roof of wet hides over a timber side wall
		_bx(n, Vector3(w * 0.62, 0.16, l), Vector3(sx * w * 0.25, rh * 0.74, 0), HIDE, Vector3(0, 0, -sx * 36.0))
		for k in 5:
			_bx(n, Vector3(w * 0.64, 0.1, 0.14), Vector3(sx * w * 0.25, rh * 0.74 + 0.1, -l * 0.5 + 0.7 + k * 1.4), WOOD_D, Vector3(0, 0, -sx * 36.0))
		_bx(n, Vector3(0.22, 1.6, l), Vector3(sx * w * 0.47, 0.9, 0), WOOD)
	_bx(n, Vector3(0.3, 0.3, l + 0.4), Vector3(0, rh, 0), WOOD_D)
	# the log on its ropes
	var lz := -l * 0.5 - 0.6 - thrust * 1.4
	_cy(n, 0.34, l * 0.9, Vector3(0, 1.4, lz + l * 0.45), WOOD_D, Vector3(90, 0, 0), 10)
	_cy(n, 0.46, 0.9, Vector3(0, 1.4, lz - 0.1), BRONZE, Vector3(90, 0, 0), 10)
	for z in [-1.4, 1.4]:
		_bx(n, Vector3(0.06, rh - 1.4, 0.06), Vector3(0, (rh + 1.4) * 0.5, z - thrust * 0.6), ROPE, Vector3(-18.0 * thrust, 0, 0))
	for sx in [-1.0, 1.0]:
		for z in [-2.4, 0.0, 2.4]:
			_wheel(n, Vector3(sx * (w * 0.5 + 0.18), 0.7, z), 0.7)
	return n

## The trebuchet: an A-frame on a sledge, the arm swinging from cocked (k=0) to thrown (k=1).
func _treb(k: float) -> Node3D:
	var n := Node3D.new()
	var h := 5.4
	for sx in [-1.0, 1.0]:
		_bx(n, Vector3(0.4, 0.4, 6.2), Vector3(sx * 1.6, 0.3, 0), WOOD_D)
		for sz in [-1.0, 1.0]:
			var p0 := Vector3(sx * 1.6, 0.4, sz * 2.2)
			var p1 := Vector3(sx * 1.4, h, 0)
			var mid := (p0 + p1) * 0.5
			var leg := _bx(n, Vector3(0.34, (p1 - p0).length(), 0.34), mid, WOOD)
			leg.look_at_from_position(mid, p1, Vector3.FORWARD)
			leg.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	for z in [-2.8, 2.8]:
		_bx(n, Vector3(3.6, 0.36, 0.36), Vector3(0, 0.3, z), WOOD_D)
	_cy(n, 0.18, 3.4, Vector3(0, h, 0), IRON, Vector3(0, 0, 90))
	var arm := Node3D.new()
	arm.position = Vector3(0, h, 0)
	n.add_child(arm)
	var a := lerpf(-62.0, 70.0, k)
	arm.rotation_degrees.x = a
	_bx(arm, Vector3(0.36, 0.36, 9.0), Vector3(0, 0, 2.2), WOOD_L)
	_bx(arm, Vector3(1.6, 1.4, 1.6), Vector3(0, -0.9, -2.0), WOOD_D)
	_bx(arm, Vector3(1.7, 0.3, 1.7), Vector3(0, -0.2, -2.0), IRON)
	var sling := _bx(arm, Vector3(0.06, 0.06, 2.4), Vector3(0, -1.0 * (1.0 - k), 6.7 + k), ROPE, Vector3(40.0 * (1.0 - k), 0, 0))
	sling.visible = true
	if k < 0.5:
		_cy(n, 0.45, 0.9, Vector3(0, 0.6, 5.0 - k * 4.0), Color("#8a8f99"), Vector3.ZERO, 8)
	return n

func _siege_run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	meta = JSON.parse_string(FileAccess.get_file_as_string(OUT + "props.json"))
	_setup()
	var jobs: Array = []
	jobs.append(["siege_tower_0", _tower(0.0)])
	jobs.append(["siege_tower_1", _tower(1.0)])
	for i in 3:
		jobs.append(["ram_%d" % i, _ram(i / 2.0)])
	for i in 5:
		jobs.append(["treb_%d" % i, _treb(i / 4.0)])
	for j in jobs:
		await _bake_node(j[0], j[1], {"s": 1.0}, {"ol": 2.2, "origin": true})
		print("  baked ", j[0], " ", meta[j[0]].get("w", 0), "x", meta[j[0]].get("h", 0))
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT + "props.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	print("[siege] done")
	quit()
