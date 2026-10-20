class_name BattleCam
extends Camera2D
## The combat camera. Everything runs in real time (hit-stop and slow motion never make it
## stutter) and is layered:
##  - follow: a critically damped spring toward the soldier, led by movement and pulled a
##    little toward the cursor (where the fight is going)
##  - framing: the battle feeds the centre of the nearby fight; the camera leans toward it and
##    picks a zoom that fits it (close on a duel, wide on a press of bodies)
##  - impulses: zoom punches, directional kicks and roll, each a damped spring with overshoot
##  - shake: trauma (0..1) that decays; offset and roll follow smooth noise scaled by trauma^2

var target: Node2D = null
var command_pan := Vector2.ZERO
var manual_zoom := 0.0
var look := Vector2.ZERO          # lead set by the battle (movement)
var aim_pull := Vector2.ZERO      # lead toward the cursor
var fight_center := Vector2.INF   # centre of the nearby fight (world), INF when calm
var fight_weight := 0.0
var follow_speed := 9.0
var base_zoom := 1.0
var push_amt := 0.0
var push_t := 0.0
var push_dur := 0.0
var cur_zoom := 1.0
var base_cur := 1.0
var trauma := 0.0
var shake := 0.0:                 # legacy API: an amplitude in pixels becomes trauma
	set(v):
		trauma = clampf(maxf(trauma, v / 14.0), 0.0, 1.0)
	get:
		return trauma * 14.0
var kick_p := Vector2.ZERO        # kick spring (position)
var kick_v := Vector2.ZERO
var zp := 0.0                     # zoom punch spring
var zv := 0.0
var roll := 0.0                   # roll spring
var roll_v := 0.0
var t := 0.0
var noise := FastNoiseLite.new()
var vel := Vector2.ZERO           # follow spring velocity
var cinematic := 0.0              # 0..1: letterboxed moments slow the follow and lift the zoom

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	position_smoothing_enabled = false
	ignore_rotation = false
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 1.0
	noise.seed = randi()

func snap_to(p: Vector2) -> void:
	global_position = p
	vel = Vector2.ZERO

## A short zoom-in that eases back (executions, clashes, officer kills, promotions).
func push(amount: float, dur: float) -> void:
	if push_t <= 0.0 or amount >= push_amt:
		push_amt = amount
		push_dur = maxf(0.05, dur)
	push_t = maxf(push_t, dur)

## A directional jolt of the view (hits, landings, blocks).
func kick(v: Vector2) -> void:
	kick_v += v * 22.0
	kick_v = kick_v.limit_length(420.0)

## A springy zoom impulse (positive = in).
func punch(amount: float) -> void:
	zv += amount * 9.0

## A springy roll impulse in radians.
func roll_kick(r: float) -> void:
	roll_v += r * 14.0

func add_trauma(a: float) -> void:
	trauma = clampf(trauma + a, 0.0, 1.0)

## World position -> position on the 640x360 UI canvas.
func world_to_screen(p: Vector2) -> Vector2:
	return ((p - get_screen_center_position()) * cur_zoom).rotated(-rotation) + Game.VIEW * 0.5

func _spring(x: float, v: float, k: float, damp: float, dt: float) -> Vector2:
	# semi-implicit damped spring toward 0: returns (x, v)
	v += (-k * x - damp * v) * dt
	x += v * dt
	return Vector2(x, v)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	var rdt := delta / maxf(Engine.time_scale, 0.0001)
	rdt = minf(rdt, 0.05)
	t += rdt
	# ---- follow
	if target != null and is_instance_valid(target):
		var goal := target.global_position + Vector2(0, -14)
		if Game.command_view:
			command_pan += Input.get_vector("move_left", "move_right", "move_up", "move_down") * rdt * 470.0
			goal += command_pan
		else:
			goal += look + aim_pull
			if fight_center != Vector2.INF and fight_weight > 0.0:
				goal = goal.lerp(fight_center + Vector2(0, -14), clampf(fight_weight, 0.0, 0.45))
		# critically damped spring (no overshoot), slower in cinematic moments
		var w := follow_speed * (1.0 - cinematic * 0.45)
		var to := goal - global_position
		vel += (to * w * w - vel * 2.0 * w) * rdt
		global_position += vel * rdt
		if to.length() > 900.0:
			global_position = goal
			vel = Vector2.ZERO
	# ---- zoom: slow drift of the framing zoom, quick push-ins, springy punches
	push_t -= rdt
	var pk := 0.0
	if push_t > 0.0:
		var k := 1.0 - push_t / push_dur
		pk = push_amt * smoothstep(0.0, 0.2, k) * (1.0 - smoothstep(0.65, 1.0, k))
	var zs := _spring(zp, zv, 140.0, 13.0, rdt)
	zp = zs.x
	zv = zs.y
	base_cur = lerpf(base_cur, base_zoom, 1.0 - exp(-rdt * 1.6))
	var goal_z := base_cur + (0.0 if Game.command_view else manual_zoom + pk + cinematic * 0.08)
	cur_zoom = lerpf(cur_zoom, goal_z, 1.0 - exp(-rdt * (7.0 if goal_z > cur_zoom else 2.4)))
	var z := maxf(0.2, cur_zoom * (1.0 + zp))
	zoom = Vector2(z, z)
	# ---- kicks and roll
	kick_v += (-kick_p * 260.0 - kick_v * 22.0) * rdt
	kick_p += kick_v * rdt
	var rs := _spring(roll, roll_v, 120.0, 11.0, rdt)
	roll = rs.x
	roll_v = rs.y
	# ---- trauma shake: smooth noise, squared falloff
	trauma = maxf(0.0, trauma - rdt * 1.25)
	var tr2 := trauma * trauma
	var sh := Vector2(noise.get_noise_2d(t * 24.0, 0.0), noise.get_noise_2d(0.0, t * 24.0 + 50.0)) * 16.0 * tr2
	var sr := noise.get_noise_2d(t * 18.0 + 100.0, 7.0) * 0.045 * tr2
	if Game.low_gfx:
		sr = 0.0
	offset = sh + kick_p
	# a breath of drift when nothing happens, so the frame never feels frozen
	var drift := Vector2(sin(t * 0.37), cos(t * 0.29)) * 1.2
	offset += drift
	rotation = sr + roll
	Sfx.listener = global_position
