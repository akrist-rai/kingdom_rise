class_name Horse
extends Node2D
## A riderless horse. Fallen cavalry leave their mounts behind: the horse bolts, slows, then
## stands and waits. Walk up and press F to ride it (see Unit.mount).

var battle = null
var fac := "zhao"
var vel := Vector2.ZERO
var life := 50.0
var anim_t := 0.0
var wander_t := 1.5
var spr: Sprite2D
var shadow: Sprite2D
var sh: Sprite2D

func setup(b, f: String, pos: Vector2, v: Vector2) -> void:
	battle = b
	fac = f
	position = pos
	vel = v.limit_length(160.0) + Vector2(randf_range(-40, 40), randf_range(-30, 30))
	shadow = Sprite2D.new()
	shadow.texture = Art.tex["shadow_big"]
	shadow.position = Vector2(0, -1)
	add_child(shadow)
	spr = Sprite2D.new()
	spr.centered = false
	spr.offset = Vector2(-17, -31)
	spr.texture = Art.tex["horse_%s_idle0" % fac]
	add_child(spr)
	if battle.shadows != null:
		sh = battle.shadows.add_sprite(spr.texture, spr.offset)

func _process(delta: float) -> void:
	if battle == null or battle.frozen:
		return
	delta = minf(delta, 1.0 / 30.0)
	anim_t += delta
	life -= delta
	wander_t -= delta
	if wander_t <= 0.0:
		wander_t = randf_range(2.0, 4.5)
		if randf() < 0.45:
			vel += Vector2.from_angle(randf() * TAU) * randf_range(20.0, 45.0)
	vel = vel.move_toward(Vector2.ZERO, 70.0 * delta)
	position += vel * delta
	position = Vector2(clampf(position.x, 40.0, Battle.W - 40.0), clampf(position.y, Battle.TOP, Battle.BOT))
	var moving := vel.length() > 12.0
	if absf(vel.x) > 4.0:
		spr.flip_h = vel.x < 0.0
	if moving:
		spr.texture = Art.tex["horse_%s_walk%d" % [fac, int(anim_t * 9.0) % 4]]
	else:
		spr.texture = Art.tex["horse_%s_idle%d" % [fac, int(anim_t * 1.5) % 2]]
	if sh != null:
		var sv: Vector2 = battle.shadow_vec
		sh.texture = spr.texture
		sh.flip_h = spr.flip_h
		sh.transform = Transform2D(Vector2(1.0, 0.0), -sv, global_position)
	if life < 1.5:
		modulate.a = clampf(life / 1.5, 0.0, 1.0)
	if life <= 0.0:
		remove()

func remove() -> void:
	if battle != null:
		battle.horses.erase(self)
	if sh != null and is_instance_valid(sh):
		sh.queue_free()
	queue_free()
