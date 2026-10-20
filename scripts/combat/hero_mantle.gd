class_name HeroMantle
extends Node2D
## A small live cloth accent over the shared CC0 soldier rig. It remains in world
## units, behind the baked body, and reacts to velocity instead of looping rigidly.
var unit: Unit
var t := 0.0
func _process(delta: float) -> void:
	if not is_instance_valid(unit):
		return
	visible = unit.rig.visible and not unit.dead and unit.is_player
	if not visible:
		return
	t += delta
	queue_redraw()
func _draw() -> void:
	if not is_instance_valid(unit) or unit.dead:
		return
	var sc := unit.base_scale.x
	var sway := sin(t * 5.0 + unit.anim_ofs) * 1.3
	var drag := (unit.move_vel + unit.vel).limit_length(180.0) / 180.0
	var top := unit.rig.transform * (unit.body.position + Vector2(unit.body.offset.x+unit.body.region_rect.size.x*0.5,unit.body.offset.y+unit.body.region_rect.size.y*0.28))
	var tail := top + Vector2(-unit.face * 6.0 + sway, 17.0) * sc - drag * 6.0
	var edge := PackedVector2Array([top+Vector2(-5,0)*sc,top+Vector2(5,0)*sc,tail+Vector2(7,0)*sc,tail+Vector2(0,3)*sc,tail+Vector2(-6,1)*sc])
	var col := Color("#a73431") if unit.faction == 0 else Color("#234852")
	draw_colored_polygon(edge, col)
	draw_line(top+Vector2(-4,1)*sc,tail+Vector2(-5,0)*sc,Color("#f1c574"),0.8,true)
	draw_line(top+Vector2(1,1)*sc,tail+Vector2(2,1)*sc,Color(col.lightened(0.15),0.8),1.2,true)
