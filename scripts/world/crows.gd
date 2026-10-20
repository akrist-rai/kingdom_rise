class_name Crows
extends Node2D
## A loose flock of crows circling over the battlefield, with shadows on the snow.

var birds: Array = []
var bounds := Rect2()
var shadow_vec := Vector2(-1.0, 0.8)
var t := 0.0

func setup(area: Rect2, n: int) -> void:
	bounds = area
	var c := area.position + area.size * Vector2(randf_range(0.3, 0.7), randf_range(0.3, 0.6))
	for i in n:
		birds.append({"c": c + Vector2(randf_range(-160, 160), randf_range(-60, 60)), "r": randf_range(40, 110),
			"a": randf() * TAU, "w": randf_range(0.35, 0.6) * (1.0 if randf() < 0.7 else -1.0),
			"h": randf_range(60, 120), "ph": randf() * 10.0, "drift": Vector2(randf_range(6, 14), randf_range(-3, 3))})

func _process(delta: float) -> void:
	t += delta
	for b in birds:
		b["a"] = float(b["a"]) + float(b["w"]) * delta
		b["c"] = b["c"] + b["drift"] * delta
		var c: Vector2 = b["c"]
		if c.x > bounds.end.x + 200.0:
			c.x = bounds.position.x - 200.0
		b["c"] = c
	queue_redraw()

func _draw() -> void:
	for b in birds:
		var p: Vector2 = b["c"] + Vector2.from_angle(float(b["a"])) * float(b["r"]) * Vector2(1.0, 0.55)
		var h: float = b["h"]
		var flap := int((t * 7.0 + float(b["ph"])) ) % 3
		var ground := p + Vector2(0, h)
		# shadow on the snow (projected away from the sun)
		var sp := ground + shadow_vec * h * 0.25
		draw_rect(Rect2(sp.floor() - Vector2(2, 0), Vector2(5, 1)), Color(0.1, 0.1, 0.25, 0.22))
		var col := Color(0.07, 0.05, 0.09)
		var q := p.floor()
		match flap:
			0:
				draw_rect(Rect2(q + Vector2(-3, -1), Vector2(2, 1)), col)
				draw_rect(Rect2(q + Vector2(2, -1), Vector2(2, 1)), col)
				draw_rect(Rect2(q + Vector2(-1, 0), Vector2(3, 1)), col)
			1:
				draw_rect(Rect2(q + Vector2(-3, 0), Vector2(7, 1)), col)
			2:
				draw_rect(Rect2(q + Vector2(-3, 1), Vector2(2, 1)), col)
				draw_rect(Rect2(q + Vector2(2, 1), Vector2(2, 1)), col)
				draw_rect(Rect2(q + Vector2(-1, 0), Vector2(3, 1)), col)
