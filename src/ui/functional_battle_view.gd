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
const HERO_ATTACK_FPS := 16.0
const HERO_ATTACK_Y_OFFSET := 3.0
const HERO_STEP_DISTANCE := 16.0
const HERO_STRONG_STEP_DISTANCE := 24.0
const ENEMY_SPAWN_OFFSET := 8.0
const MAX_FLOATING_DAMAGE_LABELS := 4

@onready var world: Node2D = %World
@onready var hero: AnimatedSprite2D = %Hero
@onready var enemy: AnimatedSprite2D = %Enemy
@onready var fx: Node2D = %BattleFx

var _hero_origin := Vector2.ZERO
var _enemy_origin := Vector2.ZERO
var _shield_visible := false
var _hero_motion_tween: Tween
var _enemy_state_tween: Tween
var _hero_pulse_tween: Tween
var _enemy_pulse_tween: Tween
var _floating_damage_labels: Array[Label] = []


func _ready() -> void:
	_setup_sprite(hero, "attack", HERO_ATTACK_FRAMES, HERO_ATTACK_FPS)
	_setup_sprite(enemy, "hurt", ENEMY_HURT_FRAMES, 14.0, ENEMY_IDLE_FRAMES)
	_hero_origin = hero.position
	_enemy_origin = enemy.position
	fx.hero_position = hero.position + Vector2(0, -4)
	_style_bar(%HeroHealth, Color("3ebf91"))
	_style_bar(%HeroRage, Color("c63b32"))
	_style_bar(%EnemyHealth, Color("d14a42"))


func spawn_enemy() -> void:
	_kill_tween(_enemy_state_tween)
	_kill_tween(_enemy_pulse_tween)
	enemy.visible = true
	enemy.rotation = 0.0
	enemy.position = _enemy_origin + Vector2(ENEMY_SPAWN_OFFSET, 0)
	enemy.modulate = Color(0.35, 0.82, 1.0, 0.0)
	enemy.play("idle")
	_enemy_state_tween = create_tween().set_parallel(true)
	_enemy_state_tween.tween_property(enemy, "position", _enemy_origin, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_enemy_state_tween.tween_property(enemy, "modulate", Color.WHITE, 0.14)


func play_skill(skill_id: String) -> void:
	if skill_id == "rage_barrier":
		fx.show_shield()
		_shield_visible = true
		_pulse(hero, Color(0.35, 0.9, 1.0))
		return
	if skill_id not in ["rage_builder", "single_spender", "aoe_spender"]:
		_pulse(hero, Color(1.0, 0.72, 0.28))
		return
	_kill_tween(_hero_motion_tween)
	hero.position = _hero_origin + Vector2(0, HERO_ATTACK_Y_OFFSET)
	hero.play("attack")
	var strong := skill_id in ["single_spender", "aoe_spender"]
	var step_distance := HERO_STRONG_STEP_DISTANCE if strong else HERO_STEP_DISTANCE
	_hero_motion_tween = create_tween()
	_hero_motion_tween.tween_property(hero, "position:x", _hero_origin.x + step_distance, 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_hero_motion_tween.tween_interval(0.08)
	_hero_motion_tween.tween_property(hero, "position", _hero_origin, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hero_motion_tween.tween_callback(hero.play.bind("idle"))


func play_enemy_damage(amount: float, strong: bool, is_dot: bool, defeated: bool) -> void:
	if is_dot:
		if not defeated:
			_pulse(enemy, Color(0.78, 0.18, 0.26))
	else:
		fx.play_contact_sparks(_enemy_origin + Vector2(-28, 10), strong)
		enemy.play("hurt")
		if not defeated:
			_pulse(enemy, Color(1.0, 0.38, 0.28))
	_spawn_damage_number(amount, _enemy_origin + Vector2(-10, -43), is_dot)
	if defeated:
		_kill_tween(_enemy_state_tween)
		_kill_tween(_enemy_pulse_tween)
		enemy.position = _enemy_origin
		enemy.modulate = Color.WHITE
		_enemy_state_tween = create_tween().set_parallel(true)
		_enemy_state_tween.tween_property(enemy, "rotation", 0.08, 0.22)
		_enemy_state_tween.tween_property(enemy, "position:y", _enemy_origin.y + 4.0, 0.22)
		_enemy_state_tween.tween_property(enemy, "modulate:a", 0.0, 0.24)


func play_hero_damage(amount: float, absorbed: float) -> void:
	if absorbed > 0.0:
		fx.show_shield()
		_shield_visible = true
	if amount <= 0.0:
		return
	_pulse(hero, Color(1.0, 0.42, 0.34))
	_spawn_damage_number(amount, _hero_origin + Vector2(-10, -43), false)


func sync_shield(value: float) -> void:
	if value > 0.0 and not _shield_visible:
		fx.show_shield()
		_shield_visible = true
	elif value <= 0.0 and _shield_visible:
		fx.break_shield()
		_shield_visible = false


func reset_presentation() -> void:
	_kill_tween(_hero_motion_tween)
	_kill_tween(_enemy_state_tween)
	_kill_tween(_hero_pulse_tween)
	_kill_tween(_enemy_pulse_tween)
	hero.position = _hero_origin
	hero.rotation = 0.0
	hero.modulate = Color.WHITE
	hero.play("idle")
	enemy.position = _enemy_origin
	enemy.rotation = 0.0
	enemy.modulate = Color.WHITE
	enemy.play("idle")
	for label in _floating_damage_labels:
		if is_instance_valid(label):
			label.queue_free()
	_floating_damage_labels.clear()
	fx.reset_effects()
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
	while _floating_damage_labels.size() >= MAX_FLOATING_DAMAGE_LABELS:
		var oldest: Label = _floating_damage_labels.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var label := Label.new()
	label.text = "-%.0f" % amount
	label.position = origin
	label.z_index = 20
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("df4c4c") if is_dot else Color.WHITE)
	world.add_child(label)
	_floating_damage_labels.append(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 10.0, 0.34)
	tween.tween_property(label, "modulate:a", 0.0, 0.26).set_delay(0.08)
	tween.chain().tween_callback(_release_damage_label.bind(label.get_instance_id()))


func _release_damage_label(instance_id: int) -> void:
	for label in _floating_damage_labels:
		if is_instance_valid(label) and label.get_instance_id() == instance_id:
			_floating_damage_labels.erase(label)
			label.queue_free()
			return


func _pulse(sprite: CanvasItem, color: Color) -> void:
	if sprite == hero:
		_kill_tween(_hero_pulse_tween)
	else:
		_kill_tween(_enemy_pulse_tween)
	sprite.modulate = Color.WHITE.lerp(color, 0.38)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	if sprite == hero:
		_hero_pulse_tween = tween
	else:
		_enemy_pulse_tween = tween


func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


func _style_bar(bar: ProgressBar, color: Color) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.015, 0.02, 0.027, 0.9)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
