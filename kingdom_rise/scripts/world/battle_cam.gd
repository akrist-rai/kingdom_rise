class_name BattleCam
extends Camera2D
## Follows the controlled soldier with look-ahead toward the aim, plus screen shake.
## Moves in real time, so slow motion and hit-stop never make the camera stutter.

var target: Node2D = null
var look := Vector2.ZERO
var shake := 0.0
var follow_speed := 9.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	position_smoothing_enabled = false

func snap_to(p: Vector2) -> void:
	global_position = p

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	var rdt := delta / maxf(Engine.time_scale, 0.0001)
	rdt = minf(rdt, 0.05)
	if target != null and is_instance_valid(target):
		var goal := target.global_position + Vector2(0, -12) + look
		global_position = global_position.lerp(goal, 1.0 - exp(-rdt * follow_speed))
	if shake > 0.05:
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
		shake = move_toward(shake, 0.0, rdt * 28.0)
	else:
		offset = Vector2.ZERO
	Sfx.listener = global_position
