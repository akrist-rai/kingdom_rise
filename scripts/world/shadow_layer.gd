class_name ShadowLayer
extends CanvasGroup
## Long cast shadows. Every caster is drawn here as a white silhouette, sheared away from
## the sun; the group is then drawn once, tinted and translucent, so overlapping shadows
## never stack darker. The sun direction and length follow the time of day.

var mat: ShaderMaterial
var statics: Array = []        # [sprite, pos, scale]
var crowds: Array = []         # Crowd nodes whose figures cast shadows
var crowd_drawer: Node2D
var sv := Vector2(-1.0, 0.8)
var last_sv := Vector2(INF, INF)

func _ready() -> void:
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/silhouette.gdshader")
	fit_margin = 0.0
	clear_margin = 0.0
	crowd_drawer = Node2D.new()
	crowd_drawer.material = mat
	crowd_drawer.draw.connect(_draw_crowds)
	add_child(crowd_drawer)

static func proj(v: Vector2, pos: Vector2, sx: float = 1.0, sy: float = 1.0) -> Transform2D:
	return Transform2D(Vector2(sx, 0.0), -v * sy, pos)

func add_sprite(t: Texture2D, offset: Vector2, flip: bool = false) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.texture = t
	s.offset = offset
	s.flip_h = flip
	s.material = mat
	add_child(s)
	return s

## A shadow for a static prop (re-projected whenever the sun moves).
func add_static(t: Texture2D, pos: Vector2, offset: Vector2, flip: bool = false, k: float = 1.0) -> Sprite2D:
	var s := add_sprite(t, offset, flip)
	statics.append([s, pos, k])
	s.transform = proj(sv, pos, 1.0, k)
	return s

## Crowds of baked figures cast no long shadows (kept for the API).
func add_crowd(_c: Node2D) -> void:
	pass

func set_sun(v: Vector2, col: Color, alpha: float) -> void:
	sv = v
	self_modulate = Color(col.r, col.g, col.b, alpha)
	if v.distance_to(last_sv) < 0.02:
		return
	last_sv = v
	for s in statics:
		if is_instance_valid(s[0]):
			s[0].transform = proj(v, s[1], 1.0, s[2])
	crowd_drawer.queue_redraw()

func _draw_crowds() -> void:
	for c in crowds:
		if not is_instance_valid(c):
			continue
		for f in c.figs:
			var t: Texture2D = f[0]
			var p: Vector2 = f[1]
			var sx := -1.0 if f[2] else 1.0
			crowd_drawer.draw_set_transform_matrix(proj(sv, p, sx, 0.9))
			crowd_drawer.draw_texture(t, Vector2(-4, -17))
	crowd_drawer.draw_set_transform_matrix(Transform2D.IDENTITY)
