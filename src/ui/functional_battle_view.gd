class_name FunctionalBattleView
extends Control


const HERO_ATTACK_FRAMES := [
	preload("res://assets/sprites/characters/fury_barbarian/attack/attack-1.png"),
	preload("res://assets/sprites/characters/fury_barbarian/attack/attack-2.png"),
	preload("res://assets/sprites/characters/fury_barbarian/attack/attack-3.png"),
	preload("res://assets/sprites/characters/fury_barbarian/attack/attack-4.png"),
	preload("res://assets/sprites/characters/fury_barbarian/attack/attack-5.png"),
	preload("res://assets/sprites/characters/fury_barbarian/attack/attack-6.png"),
]
const ENEMY_IDLE_FRAMES := [
	preload("res://assets/sprites/enemies/rift_boar/idle/idle-1.png"),
	preload("res://assets/sprites/enemies/rift_boar/idle/idle-2.png"),
	preload("res://assets/sprites/enemies/rift_boar/idle/idle-3.png"),
	preload("res://assets/sprites/enemies/rift_boar/idle/idle-4.png"),
]
const ENEMY_HURT_FRAMES := [
	preload("res://assets/sprites/enemies/rift_boar/hurt/hurt-1.png"),
	preload("res://assets/sprites/enemies/rift_boar/hurt/hurt-2.png"),
	preload("res://assets/sprites/enemies/rift_boar/hurt/hurt-3.png"),
	preload("res://assets/sprites/enemies/rift_boar/hurt/hurt-4.png"),
]

@onready var world: Node2D = %World
@onready var hero: AnimatedSprite2D = %Hero
@onready var enemy: AnimatedSprite2D = %Enemy
@onready var fx: Node2D = %BattleFx

var _hero_origin := Vector2.ZERO
var _enemy_origin := Vector2.ZERO
var _shield_visible := false


func _ready() -> void:
	_setup_sprite(hero, "attack", HERO_ATTACK_FRAMES, 11.111)
	_setup_sprite(enemy, "hurt", ENEMY_HURT_FRAMES, 14.0, ENEMY_IDLE_FRAMES)
	_hero_origin = hero.position
	_enemy_origin = enemy.position
	fx.hero_position = hero.position + Vector2(0, -4)
	_style_bar(%HeroHealth, Color("3ebf91"))
	_style_bar(%HeroRage, Color("c63b32"))
	_style_bar(%EnemyHealth, Color("d14a42"))


func spawn_enemy() -> void:
	enemy.visible = true
	enemy.rotation = 0.0
	enemy.position = _enemy_origin + Vector2(22, 0)
	enemy.modulate = Color(0.35, 0.82, 1.0, 0.0)
	enemy.play("idle")
	var tween := create_tween().set_parallel(true)
	tween.tween_property(enemy, "position", _enemy_origin, 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(enemy, "modulate", Color.WHITE, 0.18)


func play_skill(skill_id: String) -> void:
	if skill_id == "rage_barrier":
		fx.show_shield()
		_shield_visible = true
		_pulse(hero, Color(0.35, 0.9, 1.0))
		return
	if skill_id not in ["rage_builder", "single_spender", "aoe_spender"]:
		_pulse(hero, Color(1.0, 0.72, 0.28))
		return
	hero.position = _hero_origin
	hero.play("attack")
	var strong := skill_id in ["single_spender", "aoe_spender"]
	var tween := create_tween()
	tween.tween_property(hero, "position:x", _hero_origin.x + (72.0 if strong else 55.0), 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(0.10)
	tween.tween_property(hero, "position:x", _hero_origin.x, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(hero.play.bind("idle"))


func play_enemy_damage(amount: float, strong: bool, is_dot: bool, defeated: bool) -> void:
	if is_dot:
		_pulse(enemy, Color(0.78, 0.18, 0.26))
	else:
		fx.play_contact_sparks(enemy.position + Vector2(-28, 10), strong)
		_pulse(enemy, Color(1.0, 0.38, 0.28))
		enemy.play("hurt")
	_spawn_damage_number(amount, enemy.position + Vector2(-10, -43), is_dot)
	if defeated:
		var defeat := create_tween().set_parallel(true)
		defeat.tween_property(enemy, "rotation", 0.18, 0.24)
		defeat.tween_property(enemy, "position:y", _enemy_origin.y + 8.0, 0.24)
		defeat.tween_property(enemy, "modulate:a", 0.0, 0.28)


func play_hero_damage(amount: float, absorbed: float) -> void:
	if absorbed > 0.0:
		fx.show_shield()
		_shield_visible = true
	if amount <= 0.0:
		return
	_pulse(hero, Color(1.0, 0.42, 0.34))
	_spawn_damage_number(amount, hero.position + Vector2(-10, -43), false)


func sync_shield(value: float) -> void:
	if value > 0.0 and not _shield_visible:
		fx.show_shield()
		_shield_visible = true
	elif value <= 0.0 and _shield_visible:
		fx.break_shield()
		_shield_visible = false


func _setup_sprite(
	sprite: AnimatedSprite2D,
	action_name: String,
	action_frames: Array,
	action_fps: float,
	idle_frames: Array = [],
) -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 6.0)
	frames.set_animation_loop("idle", true)
	var resolved_idle := idle_frames if not idle_frames.is_empty() else [action_frames[0]]
	for texture in resolved_idle:
		frames.add_frame("idle", texture)
	frames.add_animation(action_name)
	frames.set_animation_speed(action_name, action_fps)
	frames.set_animation_loop(action_name, false)
	for texture in action_frames:
		frames.add_frame(action_name, texture)
	sprite.sprite_frames = frames
	sprite.play("idle")


func _spawn_damage_number(amount: float, origin: Vector2, is_dot: bool) -> void:
	var label := Label.new()
	label.text = "-%.0f" % amount
	label.position = origin
	label.z_index = 20
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("df4c4c") if is_dot else Color.WHITE)
	world.add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 17.0, 0.42)
	tween.tween_property(label, "modulate:a", 0.0, 0.32).set_delay(0.12)
	tween.chain().tween_callback(label.queue_free)


func _pulse(sprite: CanvasItem, color: Color) -> void:
	sprite.modulate = color
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)


func _style_bar(bar: ProgressBar, color: Color) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.015, 0.02, 0.027, 0.9)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
