class_name UnitShadows
extends Node2D
## Soft contact shadows under every soldier and horse in view, drawn by one canvas item
## (so hundreds of them batch into a single draw call). A second, fainter ellipse leans away
## from the sun. The controlled soldier gets a thin golden ring on the ground.

var battle = null
var tex: Texture2D
var t := 0.0

func _ready() -> void:
	tex = Art.tex["blob"]

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	if battle == null:
		return
	var sv: Vector2 = battle.shadow_vec.limit_length(2.0)
	var dark := Color(0.05, 0.06, 0.12, 0.42)
	var soft := Color(0.05, 0.06, 0.12, 0.2)
	for u in battle.units:
		if u.dead or not battle.in_view(u.global_position):
			continue
		var p: Vector2 = u.global_position
		var s: float = u.base_scale.x
		var rx := (17.0 if u.mounted else 9.5) * s
		var ry := rx * 0.42
		var lift := 0.0
		if u.air_t < u.air_dur:
			lift = sin(clampf(u.air_t / u.air_dur, 0.0, 1.0) * PI)
		var k := 1.0 - lift * 0.5
		draw_texture_rect(tex, Rect2(p + sv * 3.0 * s - Vector2(rx * 1.25, ry * 1.15), Vector2(rx * 2.5, ry * 2.3)), false, Color(soft.r, soft.g, soft.b, soft.a * k))
		draw_texture_rect(tex, Rect2(p - Vector2(rx, ry) * k, Vector2(rx, ry) * 2.0 * k), false, Color(dark.r, dark.g, dark.b, dark.a * k))
	for h in battle.horses:
		if is_instance_valid(h) and battle.in_view(h.global_position):
			var p: Vector2 = h.global_position
			draw_texture_rect(tex, Rect2(p - Vector2(17, 7), Vector2(34, 14)), false, dark)
	var pl = battle.player
	if pl != null and is_instance_valid(pl) and not pl.dead and not battle.possess:
		var pulse := 0.5 + 0.5 * sin(t * 3.0)
		var r: float = (14.0 if pl.mounted else 11.0) * pl.base_scale.x
		draw_set_transform(pl.global_position, 0.0, Vector2(1.0, 0.42))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1.0, 0.8, 0.4, 0.35 + 0.15 * pulse), 1.4, true)
		draw_arc(Vector2.ZERO, r + 3.0, -0.6, 0.6, 12, Color(1.0, 0.85, 0.5, 0.5), 1.0, true)
		draw_arc(Vector2.ZERO, r + 3.0, PI - 0.6, PI + 0.6, 12, Color(1.0, 0.85, 0.5, 0.5), 1.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
