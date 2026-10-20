class_name CombatSignals
extends Node2D
## Ground-space cues. Only threats near the controlled body are drawn, below the
## soldiers, so a large battle stays legible without giving every unit a UI panel.
var battle: Battle
var nearby: Array = []
var refresh := 0.0
var clock := 0.0

func _process(delta: float) -> void:
	if battle == null or battle.frozen:
		return
	clock += delta
	refresh -= delta
	if refresh <= 0.0 and is_instance_valid(battle.player):
		refresh = 0.05
		nearby = battle.query(battle.player.global_position, 170.0)
	queue_redraw()

func _draw() -> void:
	if battle == null or battle.player == null or not is_instance_valid(battle.player):
		return
	var p := battle.player
	if p.dead or battle.possess or Game.command_view:
		return
	var at := p.global_position
	# A quiet ivory foot ring and directional chevron identify the controlled body.
	draw_set_transform(at, 0.0, Vector2(1.0, 0.58))
	draw_circle(Vector2.ZERO, 12.0, Color(0.02, 0.07, 0.1, 0.42))
	draw_arc(Vector2.ZERO, 13.0, 0, TAU, 40, Color("#f6dfac"), 1.2, true)
	if p.riposte_t > 0.0:
		draw_arc(Vector2.ZERO, 17.0, -PI * 0.5, -PI * 0.5 + TAU * minf(1.0, p.riposte_t), 40, Color("#8fe2d1"), 1.6, true)
	draw_set_transform(at, p.aim.angle())
	draw_colored_polygon(PackedVector2Array([Vector2(21, 0), Vector2(16, -3), Vector2(16, 3)]), Color("#fff0c5"))
	draw_set_transform(Vector2.ZERO)
	for u in nearby:
		if not is_instance_valid(u) or u.dead or u.faction == p.faction or u.spectator:
			continue
		if u.state != Unit.St.ATTACK or u.mv_phase != 0 or u.mv.is_empty():
			continue
		# Hostile actions matter only if they could plausibly reach this fight.
		var distance: float = at.distance_to(u.global_position)
		var reach: float = u.weapon.reach * float(u.mv.get("rng", 1.0))
		if distance > reach + 90.0 and not u.weapon.ranged:
			continue
		var progress := clampf(u.mv_t / maxf(0.01, u.mv_w), 0.0, 1.0)
		var perilous: bool = u.mv.get("perilous", false)
		var col := Color("#ff7359") if perilous else Color("#ffc078")
		var locked: bool = progress >= 0.62
		var alpha := 0.1 + progress * 0.15
		var origin: Vector2 = u.global_position
		var shape: String = u.mv.get("shape", "arc")
		if u.weapon.ranged:
			# Bow lanes show the locked aim, not the player's future location.
			draw_line(origin, origin + u.aim * minf(170, distance + 20), Color(col, 0.45), 0.8, true)
			continue
		if shape == "thrust":
			var side: Vector2 = u.aim.orthogonal() * (float(u.mv.get("width", 8.0)) + 3.0)
			var tip: Vector2 = origin + u.aim * (reach + 6)
			draw_colored_polygon(PackedVector2Array([origin-side,tip-side,tip+side,origin+side]), Color(col,alpha))
			draw_line(tip-side,tip+side,Color(col,0.6 if locked else 0.3),1.2,true)
		else:
			var half := PI if shape == "circle" else deg_to_rad(float(u.mv.get("arc", 140.0)) * 0.5)
			var start: float = u.aim.angle() - half
			var sector := PackedVector2Array([origin])
			for i in 25:
				sector.append(origin + Vector2.from_angle(start + half * 2.0 * i / 24.0) * reach)
			draw_colored_polygon(sector, Color(col, alpha))
			draw_arc(origin, reach, start, start+half*2.0, 32, Color(col,0.65 if locked else 0.28), 1.3, true)
			draw_arc(origin, reach * progress, start, start+half*2.0, 32, Color(col,0.45), 0.8, true)
		# Red cross distinguishes unblockable attacks without relying on colour alone.
		if perilous:
			var c: Vector2 = origin + Vector2(0,-48)
			draw_line(c-Vector2(3,3),c+Vector2(3,3),col,1.5,true)
			draw_line(c-Vector2(3,-3),c+Vector2(3,-3),col,1.5,true)
