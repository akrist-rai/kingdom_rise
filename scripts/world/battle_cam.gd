class_name BattleCam
extends Camera2D
## Stays locked on the controlled soldier (with a small lead in the direction of movement),
## plus screen shake and a short "kick" on hits. Zoom follows the fight: close in on a few
## enemies, wide on a big crowd (base_zoom, set by the battle), with brief push-ins on top.
## Moves in real time, so slow motion and hit-stop never make the camera stutter.

var target: Node2D = null
var command_pan := Vector2.ZERO
var manual_zoom := 0.0
var look := Vector2.ZERO
var shake := 0.0
var follow_speed := 9.0
# Dynamic zoom: base_zoom is the resting level (wider in big fights, closer in duels);
# push() briefly moves in for executions, clashes, officer kills and promotions.
var base_zoom := 1.0
var push_amt := 0.0
var push_t := 0.0
var cur_zoom := 1.0
var base_cur := 1.0
var kick_v := Vector2.ZERO

## A short jolt of the view along a direction (hits, heavy landings).
func kick(v: Vector2) -> void:
	kick_v += v
	kick_v = kick_v.limit_length(7.0)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	position_smoothing_enabled = false

func snap_to(p: Vector2) -> void:
	global_position = p

func push(amount: float, dur: float) -> void:
	if push_t <= 0.0 or amount >= push_amt:
		push_amt = amount
	push_t = maxf(push_t, dur)

## World position -> position on the 640x360 UI canvas.
func world_to_screen(p: Vector2) -> Vector2:
	return (p - get_screen_center_position()) * cur_zoom + Game.VIEW * 0.5

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	var rdt := delta / maxf(Engine.time_scale, 0.0001)
	rdt = minf(rdt, 0.05)
	if target != null and is_instance_valid(target):
		if Game.command_view:
			command_pan += Input.get_vector("move_left", "move_right", "move_up", "move_down") * rdt * 470.0
		var goal := target.global_position + Vector2(0, -12) + (command_pan if Game.command_view else look)
		global_position = global_position.lerp(goal, 1.0 - exp(-rdt * follow_speed))
	push_t -= rdt
	# the crowd zoom drifts slowly so it never feels like the camera is breathing
	base_cur = lerpf(base_cur, base_zoom, 1.0 - exp(-rdt * 1.3))
	var goal := base_cur + (0.0 if Game.command_view else manual_zoom + (push_amt if push_t > 0.0 else 0.0))
	cur_zoom = lerpf(cur_zoom, goal, 1.0 - exp(-rdt * (8.0 if goal > cur_zoom else 2.6)))
	zoom = Vector2(cur_zoom, cur_zoom)
	kick_v = kick_v.lerp(Vector2.ZERO, 1.0 - exp(-rdt * 16.0))
	if shake > 0.05:
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake + kick_v
		shake = move_toward(shake, 0.0, rdt * 28.0)
	else:
		offset = kick_v
	Sfx.listener = global_position
