extends Control


const FuryBattleModel = preload("res://src/combat/fury_battle_model.gd")

const HERO_FRAMES := [
	preload("res://assets/sprites/characters/iron_vow/idle/frame_01.png"),
	preload("res://assets/sprites/characters/iron_vow/idle/frame_02.png"),
	preload("res://assets/sprites/characters/iron_vow/idle/frame_03.png"),
	preload("res://assets/sprites/characters/iron_vow/idle/frame_04.png"),
]
const ENEMY_FRAMES := [
	preload("res://assets/sprites/enemies/rift_hound/idle/idle-1.png"),
	preload("res://assets/sprites/enemies/rift_hound/idle/idle-2.png"),
	preload("res://assets/sprites/enemies/rift_hound/idle/idle-3.png"),
	preload("res://assets/sprites/enemies/rift_hound/idle/idle-4.png"),
]

@onready var world: Node2D = %World
@onready var hero: AnimatedSprite2D = %Hero
@onready var enemy: AnimatedSprite2D = %Enemy
@onready var fx: Node2D = %BattleFx
@onready var hero_health: ProgressBar = %HeroHealth
@onready var hero_rage: ProgressBar = %HeroRage
@onready var enemy_health: ProgressBar = %EnemyHealth
@onready var enemy_name: Label = %EnemyName
@onready var skill_name: Label = %SkillName
@onready var skill_detail: Label = %SkillDetail
@onready var floor_label: Label = %FloorLabel
@onready var kill_label: Label = %KillLabel
@onready var loot_label: Label = %LootLabel

var model = FuryBattleModel.new()
var _hit_stop := 0.0
var _hero_origin := Vector2.ZERO
var _enemy_origin := Vector2.ZERO
var _world_origin := Vector2.ZERO
var _shake_tween: Tween


func _ready() -> void:
	_setup_sprite(hero, HERO_FRAMES, "idle", 7.0)
	_setup_sprite(enemy, ENEMY_FRAMES, "idle", 6.0)
	_hero_origin = hero.position
	_enemy_origin = enemy.position
	_world_origin = world.position
	fx.hero_position = hero.position + Vector2(0, -8)
	fx.enemy_position = enemy.position + Vector2(0, -8)
	_style_bars()
	model.event_emitted.connect(_on_battle_event)
	model.start(1)
	_refresh_hud()


func _process(delta: float) -> void:
	if _hit_stop > 0.0:
		_hit_stop -= delta
		return
	model.tick(delta)
	_refresh_hud()


func _setup_sprite(
	sprite: AnimatedSprite2D,
	textures: Array,
	animation_name: String,
	fps: float,
) -> void:
	var frames := SpriteFrames.new()
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, true)
	for texture in textures:
		frames.add_frame(animation_name, texture)
	sprite.sprite_frames = frames
	sprite.play(animation_name)


func _on_battle_event(event: Dictionary) -> void:
	match event.type:
		"enemy_spawned":
			_enemy_spawn(event)
		"skill_cast_started":
			_play_skill_cast(event)
		"enemy_damaged":
			_play_enemy_hit(event)
		"bleed_applied":
			skill_detail.text = "裂伤撕开 · %d 次流血" % event.ticks
		"rage_changed":
			_play_rage_change(event)
		"shield_changed":
			if event.value > 0.0:
				fx.show_shield()
			else:
				fx.break_shield()
		"hero_damaged":
			_play_hero_hit(event)
		"enemy_defeated":
			_play_enemy_defeat(event)


func _play_skill_cast(event: Dictionary) -> void:
	skill_name.text = event.skill_name
	match event.skill_id:
		"rage_builder":
			skill_detail.text = "撕裂 · 积攒怒意"
			_lunge_hero(125.0, 0.11)
		"single_spender":
			skill_detail.text = "倾泻 50 怒意 · 重击"
			_lunge_hero(145.0, 0.15)
		"rage_barrier":
			skill_detail.text = "怒意凝聚为护盾"
			_pulse_sprite(hero, Color(0.35, 0.9, 1.0))
	var banner := create_tween()
	skill_name.modulate.a = 0.0
	banner.tween_property(skill_name, "modulate:a", 1.0, 0.08)
	banner.tween_interval(0.72)
	banner.tween_property(skill_name, "modulate:a", 0.35, 0.28)


func _lunge_hero(distance: float, duration: float) -> void:
	hero.position = _hero_origin
	var tween := create_tween()
	tween.tween_property(hero, "position:x", _hero_origin.x + distance, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(hero, "position:x", _hero_origin.x, duration * 1.8) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_enemy_hit(event: Dictionary) -> void:
	var strong: bool = event.source == "single_spender"
	if event.is_dot:
		_spawn_blood_drop()
		_spawn_damage_number(event.amount, event.critical, true, false)
	else:
		# Damage is resolved by the model immediately; presentation waits for the
		# warrior to cross the arena so contact and impact read as one action.
		var contact := create_tween()
		contact.tween_interval(0.12 if strong else 0.085)
		contact.tween_callback(_resolve_attack_impact.bind(event.duplicate(true), strong))
	enemy_health.value = event.health


func _resolve_attack_impact(event: Dictionary, strong: bool) -> void:
	fx.play_slash(strong)
	_hit_stop = 0.085 if strong else 0.045
	_shake_world(5.0 if strong else 2.5)
	_pulse_sprite(enemy, Color(1.0, 0.38, 0.28))
	var recoil := create_tween()
	recoil.tween_property(enemy, "position:x", _enemy_origin.x + (15.0 if strong else 7.0), 0.06)
	recoil.tween_property(enemy, "position:x", _enemy_origin.x, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_damage_number(event.amount, event.critical, false, false)


func _play_hero_hit(event: Dictionary) -> void:
	if event.amount > 0.0:
		_pulse_sprite(hero, Color(1.0, 0.42, 0.34))
		_spawn_damage_number(event.amount, false, false, true)
		_shake_world(1.8)
	if event.absorbed > 0.0:
		skill_detail.text = "壁垒吸收 %.0f 伤害" % event.absorbed


func _play_rage_change(event: Dictionary) -> void:
	if event.delta > 0.0:
		skill_detail.text += "  +%.0f 怒意" % event.delta


func _enemy_spawn(event: Dictionary) -> void:
	enemy.visible = true
	enemy.position = _enemy_origin + Vector2(35, 0)
	enemy.modulate = Color(0.25, 0.8, 1.0, 0.0)
	enemy_name.text = event.name
	enemy_health.max_value = event.max_health
	enemy_health.value = event.health
	var tween := create_tween().set_parallel(true)
	tween.tween_property(enemy, "position", _enemy_origin, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(enemy, "modulate", Color.WHITE, 0.22)


func _play_enemy_defeat(event: Dictionary) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(enemy, "rotation", 0.18, 0.24)
	tween.tween_property(enemy, "position:y", _enemy_origin.y + 10.0, 0.24)
	tween.tween_property(enemy, "modulate:a", 0.0, 0.30)
	_spawn_loot_beam(event.loot_quality)
	loot_label.text = "%s装备坠落" % event.loot_quality
	loot_label.modulate.a = 1.0
	var fade := create_tween()
	fade.tween_interval(0.65)
	fade.tween_property(loot_label, "modulate:a", 0.0, 0.42)


func _spawn_damage_number(
	amount: float,
	critical: bool,
	is_dot: bool,
	on_hero: bool,
) -> void:
	var label := Label.new()
	label.text = "-%.0f" % amount
	label.z_index = 20
	label.add_theme_font_size_override("font_size", 18 if critical else 13)
	label.add_theme_color_override("font_color",
		Color("ffd36a") if critical else (Color("df4c4c") if is_dot else Color.WHITE))
	label.position = (hero.position if on_hero else enemy.position) + Vector2(-10, -58)
	world.add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 24.0, 0.52) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.52).set_delay(0.18)
	tween.chain().tween_callback(label.queue_free)


func _spawn_blood_drop() -> void:
	for index in 3:
		var drop := Polygon2D.new()
		drop.polygon = PackedVector2Array([
			Vector2(-2, -3), Vector2(2, -3), Vector2(1, 3), Vector2(-1, 3)])
		drop.color = Color("b92736")
		drop.position = enemy.position + Vector2(index * 5 - 5, -22)
		world.add_child(drop)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(drop, "position:y", _enemy_origin.y + 18.0, 0.38 + index * 0.05)
		tween.tween_property(drop, "modulate:a", 0.0, 0.24).set_delay(0.20)
		tween.chain().tween_callback(drop.queue_free)


func _spawn_loot_beam(quality: String) -> void:
	var beam := ColorRect.new()
	beam.color = Color("4aa7ff") if quality == "稀有" else Color("d9d6c8")
	beam.color.a = 0.72
	beam.position = _enemy_origin + Vector2(-3, -70)
	beam.size = Vector2(6, 84)
	world.add_child(beam)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(beam, "size:x", 2.0, 0.55)
	tween.tween_property(beam, "modulate:a", 0.0, 0.55).set_delay(0.30)
	tween.chain().tween_callback(beam.queue_free)


func _pulse_sprite(sprite: CanvasItem, color: Color) -> void:
	sprite.modulate = color
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)


func _shake_world(strength: float) -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	_shake_tween.tween_property(world, "position", _world_origin + Vector2(strength, -strength), 0.025)
	_shake_tween.tween_property(world, "position", _world_origin + Vector2(-strength, strength), 0.04)
	_shake_tween.tween_property(world, "position", _world_origin, 0.055)


func _refresh_hud() -> void:
	var state := model.snapshot()
	hero_health.max_value = state.hero_max_health
	hero_health.value = state.hero_health
	hero_rage.value = state.hero_rage
	enemy_health.max_value = maxf(1.0, state.enemy_max_health)
	enemy_health.value = state.enemy_health
	floor_label.text = "裂隙 %02d" % state.floor
	kill_label.text = "讨伐 %d" % state.kills


func _style_bars() -> void:
	_style_bar(hero_health, Color("3ebf91"))
	_style_bar(hero_rage, Color("c63b32"))
	_style_bar(enemy_health, Color("d14a42"))


func _style_bar(bar: ProgressBar, color: Color) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.015, 0.02, 0.027, 0.9)
	background.corner_radius_top_left = 2
	background.corner_radius_top_right = 2
	background.corner_radius_bottom_left = 2
	background.corner_radius_bottom_right = 2
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left = 2
	fill.corner_radius_top_right = 2
	fill.corner_radius_bottom_left = 2
	fill.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
