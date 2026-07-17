extends Node2D


var shield_alpha := 0.0
var impact_alpha := 0.0
var slash_alpha := 0.0
var hero_position := Vector2.ZERO
var enemy_position := Vector2.ZERO


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if shield_alpha > 0.01:
		draw_circle(hero_position, 43.0, Color(0.12, 0.72, 0.92, 0.08 * shield_alpha))
		draw_arc(hero_position, 43.0, -2.4, 2.4, 32,
			Color(0.36, 0.9, 1.0, 0.92 * shield_alpha), 2.0)
		draw_arc(hero_position, 38.0, -2.2, 2.2, 24,
			Color(0.86, 0.98, 1.0, 0.48 * shield_alpha), 1.0)
	if slash_alpha > 0.01:
		draw_arc(enemy_position + Vector2(-5, -6), 36.0, -2.3, 0.55, 18,
			Color(1.0, 0.25, 0.12, slash_alpha), 6.0)
		draw_arc(enemy_position + Vector2(-5, -6), 31.0, -2.3, 0.55, 18,
			Color(1.0, 0.86, 0.52, slash_alpha), 2.0)
	if impact_alpha > 0.01:
		for index in 8:
			var angle := TAU * float(index) / 8.0
			var start := enemy_position + Vector2.from_angle(angle) * 15.0
			var finish := enemy_position + Vector2.from_angle(angle) * 35.0
			draw_line(start, finish, Color(1.0, 0.72, 0.28, impact_alpha), 2.0)


func play_slash(strong := false) -> void:
	slash_alpha = 1.0
	impact_alpha = 1.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "slash_alpha", 0.0, 0.22 if strong else 0.16)
	tween.tween_property(self, "impact_alpha", 0.0, 0.18)


func show_shield() -> void:
	shield_alpha = 0.0
	var tween := create_tween()
	tween.tween_property(self, "shield_alpha", 1.0, 0.14)
	tween.tween_property(self, "shield_alpha", 0.72, 0.18)


func break_shield() -> void:
	var tween := create_tween()
	tween.tween_property(self, "shield_alpha", 0.0, 0.18)
