class_name Terrain
extends Node2D
## Solid obstacles of a level (walls, gates, towers, houses). Units are pushed out of them, AI
## soldiers walk around them along paths from Godot's navigation server, and the navigation
## mesh is rebuilt whenever the level changes (a gate breaks, a siege tower docks).

const CELL := 80.0

var rects: Array = []        # [Rect2, tag: String, active: bool]
var grid := {}               # cell key -> [rect indices]
var region: NavigationRegion2D
var bounds := Rect2()
var nav_dirty := false
var check_t := 0.5

func setup(b: Rect2) -> void:
	bounds = b
	region = NavigationRegion2D.new()
	add_child(region)
	# synchronous map updates: a polygon changed during a background update could be lost,
	# leaving the soldiers with no paths at all
	NavigationServer2D.map_set_use_async_iterations(get_world_2d().navigation_map, false)

func add(r: Rect2, tag: String = "") -> int:
	rects.append([r, tag, true])
	_index(rects.size() - 1)
	nav_dirty = true
	return rects.size() - 1

## Turns every rect with this tag on or off (e.g. "gate" when it breaks).
func set_active(tag: String, on: bool) -> void:
	for e in rects:
		if e[1] == tag:
			e[2] = on
	grid.clear()
	for i in rects.size():
		if rects[i][2]:
			_index(i)
	nav_dirty = true

func is_active(tag: String) -> bool:
	for e in rects:
		if e[1] == tag and e[2]:
			return true
	return false

static func _key(cx: int, cy: int) -> int:
	return cx * 4096 + cy

func _index(i: int) -> void:
	var r: Rect2 = rects[i][0]
	for cx in range(int(floor(r.position.x / CELL)), int(floor(r.end.x / CELL)) + 1):
		for cy in range(int(floor(r.position.y / CELL)), int(floor(r.end.y / CELL)) + 1):
			var k := _key(cx, cy)
			if grid.has(k):
				grid[k].append(i)
			else:
				grid[k] = [i]

func _near(p: Vector2) -> Array:
	var out: Array = []
	var cx := int(floor(p.x / CELL))
	var cy := int(floor(p.y / CELL))
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var k := _key(cx + dx, cy + dy)
			if grid.has(k):
				out.append_array(grid[k])
	return out

## Pushes a circle of radius `rad` at `p` out of any solid it overlaps.
func push_out(p: Vector2, rad: float) -> Vector2:
	for i in _near(p):
		var r: Rect2 = (rects[i][0] as Rect2).grow(rad)
		if not r.has_point(p):
			continue
		var dl := p.x - r.position.x
		var dr := r.end.x - p.x
		var dt := p.y - r.position.y
		var db := r.end.y - p.y
		var m := minf(minf(dl, dr), minf(dt, db))
		if m == dl:
			p.x = r.position.x
		elif m == dr:
			p.x = r.end.x
		elif m == dt:
			p.y = r.position.y
		else:
			p.y = r.end.y
	return p

func solid_at(p: Vector2, rad: float = 0.0) -> bool:
	for i in _near(p):
		if (rects[i][0] as Rect2).grow(rad).has_point(p):
			return true
	return false

## Does the straight line a -> b cross a solid?
func blocked(a: Vector2, b: Vector2) -> bool:
	var seen := {}
	var l := a.distance_to(b)
	var steps := int(ceil(l / (CELL * 0.5))) + 1
	for s in steps + 1:
		var q := a.lerp(b, float(s) / steps)
		for i in _near(q):
			if seen.has(i):
				continue
			seen[i] = true
			if _seg_rect(a, b, (rects[i][0] as Rect2).grow(5.0)):
				return true
	return false

static func _seg_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	if r.has_point(a) or r.has_point(b):
		return true
	var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for k in 4:
		if Geometry2D.segment_intersects_segment(a, b, c[k], c[(k + 1) % 4]) != null:
			return true
	return false

static func _pts(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])

func bake() -> void:
	var poly := NavigationPolygon.new()
	poly.agent_radius = 6.0
	var src := NavigationMeshSourceGeometryData2D.new()
	src.add_traversable_outline(_pts(bounds))
	for e in rects:
		if e[2]:
			src.add_obstruction_outline(_pts(e[0]))
	NavigationServer2D.bake_from_source_geometry_data(poly, src)
	region.navigation_polygon = poly
	nav_dirty = false
	check_t = 0.5

func _process(delta: float) -> void:
	if nav_dirty:
		bake()
		return
	# safety net: if the map still has no mesh after an update, hand it the polygon again
	check_t -= delta
	if check_t <= 0.0:
		check_t = 1.0
		var map := get_world_2d().navigation_map
		if NavigationServer2D.map_get_iteration_id(map) > 0 and region.navigation_polygon != null and region.navigation_polygon.get_polygon_count() > 0:
			if NavigationServer2D.map_get_closest_point(map, bounds.position + Vector2(30, 30)) == Vector2.ZERO:
				var poly := region.navigation_polygon
				region.navigation_polygon = null
				region.navigation_polygon = poly

## A path around the solids (empty until the navigation map is ready).
func path(a: Vector2, b: Vector2) -> PackedVector2Array:
	var map := get_world_2d().navigation_map
	if NavigationServer2D.map_get_iteration_id(map) == 0:
		return PackedVector2Array()
	return NavigationServer2D.map_get_path(map, a, b, true)
