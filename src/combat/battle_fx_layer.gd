extends Node2D


var shield_alpha := 0.0
var impact_alpha := 0.0
var hero_position := Vector2.ZERO
var impact_position := Vector2.ZERO
var _impact_tween: Tween
var _shield_tween: Tween


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if shield_alpha > 0.01:
		draw_circle(hero_position, 43.0, Color(0.12, 0.72, 0.92, 0.08 * shield_alpha))
		draw_arc(hero_position, 43.0, -2.4, 2.4, 32,
			Color(0.36, 0.9, 1.0, 0.92 * shield_alpha), 2.0)
		draw_arc(hero_position, 38.0, -2.2, 2.2, 24,
			Color(0.86, 0.98, 1.0, 0.48 * shield_alpha), 1.0)
	if impact_alpha > 0.01:
		for index in 6:
			var angle := TAU * float(index) / 6.0
			var start := impact_position + Vector2.from_angle(angle) * 3.0
			var finish := impact_position + Vector2.from_angle(angle) * 13.0
			draw_line(start, finish, Color(1.0, 0.76, 0.3, impact_alpha), 1.5)
		draw_circle(impact_position, 3.0, Color(1.0, 0.94, 0.72, impact_alpha))


func play_contact_sparks(position: Vector2, strong := false) -> void:
	_kill_tween(_impact_tween)
	impact_position = position
	impact_alpha = 1.0
	_impact_tween = create_tween()
	_impact_tween.tween_property(self, "impact_alpha", 0.0, 0.14 if strong else 0.10)


func show_shield() -> void:
	_kill_tween(_shield_tween)
	shield_alpha = 0.0
	_shield_tween = create_tween()
	_shield_tween.tween_property(self, "shield_alpha", 1.0, 0.12)
	_shield_tween.tween_property(self, "shield_alpha", 0.72, 0.16)


func break_shield() -> void:
	_kill_tween(_shield_tween)
	_shield_tween = create_tween()
	_shield_tween.tween_property(self, "shield_alpha", 0.0, 0.16)


func reset_effects() -> void:
	_kill_tween(_impact_tween)
	_kill_tween(_shield_tween)
	impact_alpha = 0.0
	shield_alpha = 0.0
	queue_redraw()


func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
