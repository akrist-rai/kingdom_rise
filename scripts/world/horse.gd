class_name Horse
extends Node2D
## A riderless horse. Fallen cavalry leave their mounts behind: the horse bolts, slows, then
## stands and waits. Walk up and press F to ride it (see Unit.mount). Drawn with the baked
## horse frames (UnitArt "horse"), its saddle cloth in its army's colours.

var battle = null
var fac := "zhao"
var vel := Vector2.ZERO
var life := 50.0
var anim_t := 0.0
var wander_t := 1.5
var spr: Sprite2D
var dir8 := 2
var phase := 0.0
var _last = null
var _last_flip := false

func setup(b, f: String, pos: Vector2, v: Vector2) -> void:
	battle = b
	fac = f
	position = pos
	vel = v.limit_length(160.0) + Vector2(randf_range(-40, 40), randf_range(-30, 30))
	spr = Sprite2D.new()
	spr.centered = false
	spr.region_enabled = true
	spr.scale = Vector2.ONE / UnitArt.R
	spr.material = UnitArt.materials.get("march" if fac == "qin" else "crown")
	add_child(spr)
	if vel.length() > 5.0:
		dir8 = UnitArt.dir_index(vel)

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
	var speed := vel.length()
	if speed > 8.0:
		dir8 = UnitArt.dir_index(vel)
	var anim := "idle"
	var fi := int(anim_t * 1.2) % 2
	if speed > 90.0:
		anim = "gallop"
		phase = fposmod(phase + delta * clampf(speed / 100.0, 0.8, 2.4), 1.0)
		fi = int(phase * 6.0) % 6
	elif speed > 10.0:
		anim = "walk"
		phase = fposmod(phase + delta * clampf(speed / 60.0, 0.5, 1.5), 1.0)
		fi = int(phase * 6.0) % 6
	var dk: Array = UnitArt.DIR8[dir8]
	var fl: Array = UnitArt.frames("horse", anim, dk[0])
	if not fl.is_empty():
		var fr = fl[clampi(fi, 0, fl.size() - 1)]
		if fr != null and (fr != _last or dk[1] != _last_flip):
			_last = fr
			_last_flip = dk[1]
			spr.texture = fr["tex"]
			spr.region_rect = fr["rect"]
			spr.flip_h = dk[1]
			spr.offset = Vector2(-(float(fr["w"]) - float(fr["ax"])) if dk[1] else -float(fr["ax"]), -float(fr["ay"]))
	visible = battle.in_view(global_position)
	if life < 1.5:
		modulate.a = clampf(life / 1.5, 0.0, 1.0)
	if life <= 0.0:
		remove()

func remove() -> void:
	if battle != null:
		battle.horses.erase(self)
	queue_free()
