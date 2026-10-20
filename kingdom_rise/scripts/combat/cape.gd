class_name Cape
extends Node2D
## A cloth cape simulated as a Verlet chain (pinned at the shoulders) and drawn as
## two-tone shaded quads with an ink outline and a gold hem.

const N := 8
var cols: Array = []
var seg := 3.0
var width_k := 1.0
var pts := PackedVector2Array()
var old := PackedVector2Array()
var t := 0.0
var ready_pts := false

func setup(c: Array, segment: float = 3.0, wk: float = 1.0) -> void:
	cols = c
	seg = segment
	width_k = wk

func reset(anchor: Vector2, face: int) -> void:
	pts.resize(N)
	old.resize(N)
	for i in N:
		pts[i] = anchor + Vector2(-face * i * 0.8, i * seg)
		old[i] = pts[i]
	ready_pts = true

func step(delta: float, anchor: Vector2, face: int) -> void:
	if not ready_pts:
		reset(anchor, face)
	t += delta
	var dt := clampf(delta, 0.001, 1.0 / 30.0)
	var force := Vector2(-face * 30.0 + 22.0 + sin(t * 1.7) * 14.0, 80.0 + sin(t * 2.3) * 10.0)
	pts[0] = anchor
	old[0] = anchor
	for i in range(1, N):
		var v := (pts[i] - old[i]) * 0.9
		old[i] = pts[i]
		pts[i] += v + force * dt * dt
	for it in 3:
		for i in range(1, N):
			var d := pts[i] - pts[i - 1]
			var l := d.length()
			if l > 0.0001:
				pts[i] = pts[i - 1] + d / l * seg
	queue_redraw()

func _draw() -> void:
	if not ready_pts or cols.size() < 4:
		return
	var mid := PackedVector2Array()
	var nrm := PackedVector2Array()
	var wid := PackedFloat32Array()
	for i in N:
		mid.append(pts[i] - global_position)
		var dir := (pts[mini(i + 1, N - 1)] - pts[maxi(i - 1, 0)]).normalized()
		nrm.append(dir.orthogonal())
		wid.append(lerpf(1.8, 4.6, float(i) / (N - 1)) * width_k)
	var o: Color = Art.OUT
	var oc := PackedColorArray([o, o, o, o])
	for i in N - 1:
		var w0 := wid[i] + 1.0
		var w1 := wid[i + 1] + 1.0
		var ext := (mid[i + 1] - mid[i]).normalized() * (1.0 if i == N - 2 else 0.0)
		draw_primitive(PackedVector2Array([mid[i] + nrm[i] * w0, mid[i + 1] + nrm[i + 1] * w1 + ext,
			mid[i + 1] - nrm[i + 1] * w1 + ext, mid[i] - nrm[i] * w0]), oc, PackedVector2Array())
	for i in N - 1:
		var a := mid[i]
		var b := mid[i + 1]
		var la := a + nrm[i] * wid[i]
		var lb := b + nrm[i + 1] * wid[i + 1]
		var ra := a - nrm[i] * wid[i]
		var rb := b - nrm[i + 1] * wid[i + 1]
		var fold := sin(i * 1.3 + t * 3.0)
		var lc: Color = cols[0] if fold > 0.0 else cols[1]
		var rc: Color = cols[2] if fold > 0.0 else cols[1]
		draw_primitive(PackedVector2Array([la, lb, b, a]), PackedColorArray([lc, lc, lc, lc]), PackedVector2Array())
		draw_primitive(PackedVector2Array([a, b, rb, ra]), PackedColorArray([rc, rc, rc, rc]), PackedVector2Array())
	var e := N - 1
	draw_line(mid[e] + nrm[e] * wid[e], mid[e] - nrm[e] * wid[e], cols[3], 1.0)
