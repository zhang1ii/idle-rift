extends Control

const Combat = preload("res://src/combat/combat_simulation.gd")
const Equipment = preload("res://src/equipment/equipment_item.gd")
const IRON_VOW_IDLE_FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/characters/iron_vow/idle/frame_01.png"),
	preload("res://assets/sprites/characters/iron_vow/idle/frame_02.png"),
	preload("res://assets/sprites/characters/iron_vow/idle/frame_03.png"),
	preload("res://assets/sprites/characters/iron_vow/idle/frame_04.png"),
]
const RIFT_HOUND_IDLE_FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/enemies/rift_hound/idle/idle-1.png"),
	preload("res://assets/sprites/enemies/rift_hound/idle/idle-2.png"),
	preload("res://assets/sprites/enemies/rift_hound/idle/idle-3.png"),
	preload("res://assets/sprites/enemies/rift_hound/idle/idle-4.png"),
]

enum InterfaceMode {
	COMPACT,
	MANAGEMENT,
	SETTLEMENT,
}

@onready var rift_label: Label = %RiftLabel
@onready var gold_label: Label = %GoldLabel
@onready var hero_health: ProgressBar = %HeroHealth
@onready var class_name_label: Label = %ClassName
@onready var class_resource: ProgressBar = %ClassResource
@onready var hero_sprite: TextureRect = %HeroSprite
@onready var enemy_sprite: TextureRect = %EnemySprite
@onready var hero_stats: Label = %HeroStats
@onready var enemy_name: Label = %EnemyName
@onready var enemy_health: ProgressBar = %EnemyHealth
@onready var enemy_stats: Label = %EnemyStats
@onready var efficiency_label: Label = %EfficiencyLabel
@onready var battle_log: RichTextLabel = %BattleLog
@onready var inventory_list: ItemList = %InventoryList
@onready var item_detail: Label = %ItemDetail
@onready var equip_button: Button = %EquipButton
@onready var equipped_label: Label = %EquippedLabel
@onready var pause_button: Button = %PauseButton
@onready var speed_button: Button = %SpeedButton
@onready var settlement_shade: ColorRect = %SettlementShade
@onready var settlement_panel: PanelContainer = %SettlementPanel
@onready var management_panel: PanelContainer = %ManagementPanel
@onready var battle_dock: PanelContainer = %BattleDock
@onready var loot_button: Button = %LootButton
@onready var manage_button: Button = %ManageButton
@onready var compact_button: Button = %CompactButton
@onready var keep_farming_button: Button = %KeepFarmingButton
@onready var best_drop_button: Button = %BestDropButton

var simulation: CombatSimulation
var log_lines: Array[String] = []
var idle_frame_index := 0
var idle_frame_elapsed := 0.0
var interface_mode := InterfaceMode.SETTLEMENT
var expanded_window_size := Vector2i(1280, 720)


func _ready() -> void:
	simulation = Combat.new()
	simulation.battle_event.connect(_on_battle_event)
	simulation.equipment_dropped.connect(_on_equipment_dropped)
	simulation.inventory_changed.connect(_refresh_inventory)
	simulation.equipment_changed.connect(_refresh_equipment)
	inventory_list.item_selected.connect(_on_inventory_selected)
	equip_button.pressed.connect(_on_equip_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	speed_button.pressed.connect(_on_speed_pressed)
	loot_button.pressed.connect(func() -> void: _set_interface_mode(InterfaceMode.SETTLEMENT))
	manage_button.pressed.connect(func() -> void: _set_interface_mode(InterfaceMode.MANAGEMENT))
	compact_button.pressed.connect(func() -> void: _set_interface_mode(InterfaceMode.COMPACT))
	keep_farming_button.pressed.connect(func() -> void: _set_interface_mode(InterfaceMode.COMPACT))
	best_drop_button.pressed.connect(func() -> void: _set_interface_mode(InterfaceMode.MANAGEMENT))
	_configure_desktop_window()
	_set_interface_mode(InterfaceMode.SETTLEMENT)
	_on_battle_event("远征开始。英雄将自动战斗并收集装备。")
	_refresh_inventory()
	_refresh_equipment()
	_refresh_runtime_ui()


func _process(delta: float) -> void:
	simulation.tick(delta)
	_update_sprite_animation(delta)
	_refresh_runtime_ui()


func _update_sprite_animation(delta: float) -> void:
	if simulation.paused:
		return
	idle_frame_elapsed += delta * simulation.speed_multiplier
	if idle_frame_elapsed < 0.22:
		return
	idle_frame_elapsed = fmod(idle_frame_elapsed, 0.22)
	idle_frame_index = (idle_frame_index + 1) % IRON_VOW_IDLE_FRAMES.size()
	hero_sprite.texture = IRON_VOW_IDLE_FRAMES[idle_frame_index]
	enemy_sprite.texture = RIFT_HOUND_IDLE_FRAMES[idle_frame_index]


func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	match event.keycode:
		KEY_TAB:
			_set_interface_mode(InterfaceMode.MANAGEMENT if interface_mode == InterfaceMode.COMPACT else InterfaceMode.COMPACT)
			get_viewport().set_input_as_handled()
		KEY_R:
			_set_interface_mode(InterfaceMode.SETTLEMENT)
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_set_interface_mode(InterfaceMode.COMPACT)
			get_viewport().set_input_as_handled()


func _configure_desktop_window() -> void:
	get_window().borderless = true
	get_window().always_on_top = true
	get_window().unresizable = false
	get_window().transparent = false
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS


func _set_interface_mode(mode: InterfaceMode) -> void:
	interface_mode = mode
	var compact := mode == InterfaceMode.COMPACT
	settlement_shade.visible = not compact
	settlement_panel.visible = mode == InterfaceMode.SETTLEMENT
	management_panel.visible = mode == InterfaceMode.MANAGEMENT
	%TopChrome.visible = not compact
	compact_button.text = "收起" if not compact else "展开"

	if compact:
		get_window().content_scale_size = Vector2i(1120, 180)
		get_window().size = Vector2i(1120, 180)
		_anchor_window_to_work_area()
	else:
		get_window().content_scale_size = Vector2i(960, 540)
		get_window().size = expanded_window_size
		_center_window_in_work_area()


func _anchor_window_to_work_area() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	get_window().position = Vector2i(
		usable.position.x + usable.size.x - get_window().size.x - 16,
		usable.position.y + usable.size.y - get_window().size.y - 8
	)


func _center_window_in_work_area() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	get_window().position = usable.position + (usable.size - get_window().size) / 2


func _refresh_runtime_ui() -> void:
	rift_label.text = "裂隙 %02d" % simulation.current_rift_level()
	gold_label.text = "%d 金币" % simulation.gold
	hero_health.max_value = simulation.hero_max_health()
	hero_health.value = simulation.hero_health
	(hero_health.get_node("Value") as Label).text = "%d / %d" % [roundi(simulation.hero_health), roundi(simulation.hero_max_health())]
	class_name_label.text = simulation.class_definition()["name"]
	class_resource.value = simulation.class_resource
	(class_resource.get_node("Value") as Label).text = "守势 %d / 100" % roundi(simulation.class_resource)
	hero_stats.text = "伤害 %.0f  ·  攻速 %.2f\n护甲 %.0f  ·  格挡 %d%%" % [
		simulation.hero_damage(),
		simulation.hero_attack_speed(),
		simulation.hero_armor(),
		roundi(simulation.hero_block_chance() * 100.0),
	]
	enemy_name.text = simulation.enemy_name
	enemy_health.max_value = simulation.enemy_max_health
	enemy_health.value = simulation.enemy_health
	(enemy_health.get_node("Value") as Label).text = "%d / %d" % [roundi(simulation.enemy_health), roundi(simulation.enemy_max_health)]
	enemy_stats.text = "等级 %d  ·  已击杀 %d" % [simulation.enemy_level, simulation.kill_count]
	efficiency_label.text = "%.1f 击杀/分钟" % simulation.kills_per_minute()
	loot_button.text = "战利品  %d" % simulation.inventory.size()


func _refresh_inventory() -> void:
	var selected_item: EquipmentItem = _selected_item()
	inventory_list.clear()
	for item in simulation.inventory:
		var index := inventory_list.item_count
		inventory_list.add_item("[%d] %s  ·  %d" % [item.item_level, item.display_name(), item.power_score()])
		inventory_list.set_item_metadata(index, item)
		inventory_list.set_item_custom_fg_color(index, Equipment.rarity_color(item.rarity))

	if selected_item != null:
		var new_index := simulation.inventory.find(selected_item)
		if new_index >= 0:
			inventory_list.select(new_index)
			_show_item(selected_item)
			return
	if inventory_list.item_count > 0:
		inventory_list.select(0)
		_show_item(inventory_list.get_item_metadata(0) as EquipmentItem)
		return
	item_detail.text = "等待装备掉落……"
	equip_button.disabled = true


func _refresh_equipment() -> void:
	var lines: Array[String] = []
	for slot in Equipment.Slot.values():
		var item := simulation.equipped_item(slot)
		var value := "空"
		if item != null:
			value = "%s · %d" % [item.display_name(), item.power_score()]
		lines.append("%s：%s" % [Equipment.slot_name(slot), value])
	equipped_label.text = "   ".join(lines)


func _on_inventory_selected(index: int) -> void:
	_show_item(inventory_list.get_item_metadata(index) as EquipmentItem)


func _show_item(item: EquipmentItem) -> void:
	if item == null:
		return
	var comparison := ""
	var current := simulation.equipped_item(item.slot)
	if current == null:
		comparison = "当前部位为空"
	else:
		var delta := item.power_score() - current.power_score()
		comparison = "相对当前 %+d 战力" % delta
	item_detail.text = "%s\n%s\n%s" % [item.display_name(), item.short_description(), comparison]
	item_detail.modulate = Equipment.rarity_color(item.rarity)
	equip_button.disabled = false


func _on_equip_pressed() -> void:
	var item := _selected_item()
	if item != null:
		simulation.equip_item(item)


func _on_pause_pressed() -> void:
	simulation.paused = not simulation.paused
	pause_button.text = "继续" if simulation.paused else "暂停"


func _on_speed_pressed() -> void:
	simulation.speed_multiplier = 2.0 if simulation.speed_multiplier == 1.0 else 1.0
	speed_button.text = "%.0f×" % simulation.speed_multiplier


func _on_battle_event(message: String) -> void:
	log_lines.append(message)
	if log_lines.size() > 6:
		log_lines.pop_front()
	battle_log.text = "\n".join(log_lines)


func _on_equipment_dropped(item: EquipmentItem) -> void:
	_on_battle_event("掉落：%s（战力 %d）" % [item.display_name(), item.power_score()])


func _selected_item() -> EquipmentItem:
	var selected := inventory_list.get_selected_items()
	if selected.is_empty():
		return null
	return inventory_list.get_item_metadata(selected[0]) as EquipmentItem
