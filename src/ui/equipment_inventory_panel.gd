class_name EquipmentInventoryPanel
extends Control


signal equip_requested(inventory_index: int)
signal dismantle_requested(inventory_index: int)
signal dismantle_non_upgrades_requested
signal close_requested

const Rules = preload("res://src/gameplay/equipment_rules.gd")

const SLOT_NAMES := {
	"weapon": "武器", "head": "头盔", "shoulders": "肩甲", "chest": "胸甲",
	"wrists": "护腕", "hands": "手套", "waist": "腰带", "legs": "腿甲",
	"feet": "鞋子", "ring_1": "戒指 1", "ring_2": "戒指 2",
	"trinket_1": "饰品 1", "trinket_2": "饰品 2",
}
const AFFIX_NAMES := {
	"mastery": "精通", "haste": "急速",
	"critical_strike": "暴击", "versatility": "全能",
}
const QUALITY_COLORS := {
	"common": Color("d3d6d8"), "uncommon": Color("72cf78"),
	"rare": Color("5ca8e8"), "epic": Color("b57ae8"),
	"legendary": Color("e89b45"),
}

var model: EquipmentInventory
var locked := false
var _selected_inventory_index := -1
var _summary_label: Label
var _lock_label: Label
var _equipped_grid: GridContainer
var _inventory_list: VBoxContainer
var _detail_label: Label
var _equip_button: Button
var _dismantle_button: Button
var _cleanup_button: Button
var _equipped_buttons: Dictionary = {}
var _inventory_buttons: Array[Button] = []


func setup(inventory_model: EquipmentInventory) -> void:
	model = inventory_model
	_build_interface()
	refresh()


func set_locked(value: bool) -> void:
	locked = value
	refresh()


func refresh() -> void:
	if model == null or _summary_label == null:
		return
	_selected_inventory_index = mini(_selected_inventory_index, model.inventory.size() - 1)
	_summary_label.text = "已穿戴 %d / 13    背包 %d    材料 %d" % [
		model.equipped.size(), model.inventory.size(), model.materials,
	]
	_lock_label.text = "战斗中只读" if locked else "战前可管理"
	_lock_label.modulate = Color("df7b67") if locked else Color("79c8a0")
	_rebuild_equipped_buttons()
	_rebuild_inventory_buttons()
	_refresh_selection()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.01, 0.015, 0.022, 0.96)
	add_child(dimmer)
	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 18.0
	frame.offset_top = 12.0
	frame.offset_right = -18.0
	frame.offset_bottom = -12.0
	frame.add_theme_stylebox_override("panel", _panel_style())
	add_child(frame)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	frame.add_child(content)
	content.add_child(_build_header())
	content.add_child(_build_body())


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 29.0
	header.add_theme_constant_override("separation", 8)
	var title := _label("背包与配装", 17, Color("edbd5b"))
	title.custom_minimum_size.x = 140.0
	header.add_child(title)
	_summary_label = _label("", 10, Color("d9e1e8"))
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_summary_label)
	_lock_label = _label("", 10)
	_lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_lock_label)
	var close_button := _button("关闭  B", 66, 24)
	close_button.pressed.connect(close_requested.emit)
	header.add_child(close_button)
	return header


func _build_body() -> Control:
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 7)
	body.add_child(_build_equipped_section())
	body.add_child(_build_inventory_section())
	return body


func _build_equipped_section() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.95
	panel.add_theme_stylebox_override("panel", _section_style(Color("527e90")))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	panel.add_child(content)
	var title := _label("当前穿戴 · 13 槽", 12, Color("8ec8d9"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	_equipped_grid = GridContainer.new()
	_equipped_grid.columns = 2
	_equipped_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_equipped_grid.add_theme_constant_override("h_separation", 4)
	_equipped_grid.add_theme_constant_override("v_separation", 3)
	content.add_child(_equipped_grid)
	return panel


func _build_inventory_section() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.05
	panel.add_theme_stylebox_override("panel", _section_style(Color("a67543")))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	panel.add_child(content)
	var title := _label("背包掉落 · 先比较再处理", 12, Color("e5b66f"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_inventory_list = VBoxContainer.new()
	_inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_list.add_theme_constant_override("separation", 3)
	scroll.add_child(_inventory_list)
	_detail_label = _label("选择一件背包物品查看属性与提升目标。", 8, Color("b7c1ca"))
	_detail_label.custom_minimum_size.y = 43.0
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_detail_label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	content.add_child(actions)
	_equip_button = _button("装备到较弱槽", 0, 23)
	_equip_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equip_button.pressed.connect(_request_equip)
	actions.add_child(_equip_button)
	_dismantle_button = _button("分解", 50, 23)
	_dismantle_button.pressed.connect(_request_dismantle)
	actions.add_child(_dismantle_button)
	_cleanup_button = _button("清理非提升", 76, 23)
	_cleanup_button.pressed.connect(dismantle_non_upgrades_requested.emit)
	actions.add_child(_cleanup_button)
	return panel


func _rebuild_equipped_buttons() -> void:
	for child in _equipped_grid.get_children():
		_equipped_grid.remove_child(child)
		child.queue_free()
	_equipped_buttons.clear()
	for target in Rules.EQUIPMENT_TARGETS:
		var button := _button("", 0, 27)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.x = 126.0
		button.pressed.connect(_show_equipped_detail.bind(target))
		var item: Dictionary = model.equipped.get(target, {})
		if item.is_empty():
			button.text = "%s · 空" % SLOT_NAMES[target]
			button.add_theme_color_override("font_color", Color("65717b"))
		else:
			button.text = "%s · %s T%d · %.1f" % [
				SLOT_NAMES[target], Rules.QUALITY_DATA[item.quality].name,
				int(item.item_tier), Rules.item_score(item),
			]
			button.add_theme_color_override("font_color", QUALITY_COLORS[item.quality])
		_equipped_grid.add_child(button)
		_equipped_buttons[target] = button


func _rebuild_inventory_buttons() -> void:
	for child in _inventory_list.get_children():
		_inventory_list.remove_child(child)
		child.queue_free()
	_inventory_buttons.clear()
	if model.inventory.is_empty():
		var empty := _label("背包为空；普通敌人每次击杀有 3% 装备掉落率。", 8, Color("7f8b95"))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_inventory_list.add_child(empty)
		return
	for index in model.inventory.size():
		var item: Dictionary = model.inventory[index]
		var button := _button("", 0, 27)
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s  T%d %s  · 评分 %.1f%s" % [
			Rules.QUALITY_DATA[item.quality].name,
			int(item.item_tier), _slot_name_for_item(item), Rules.item_score(item),
			" · 可能提升" if model.is_potential_upgrade(item) else "",
		]
		button.add_theme_color_override("font_color", QUALITY_COLORS[item.quality])
		button.pressed.connect(_select_inventory_item.bind(index))
		_inventory_list.add_child(button)
		_inventory_buttons.append(button)


func _select_inventory_item(index: int) -> void:
	_selected_inventory_index = index
	_refresh_selection()


func _show_equipped_detail(target: String) -> void:
	_selected_inventory_index = -1
	var item: Dictionary = model.equipped.get(target, {})
	_detail_label.text = "%s：空槽" % SLOT_NAMES[target] if item.is_empty() \
		else "%s：%s" % [SLOT_NAMES[target], _item_detail(item)]
	_refresh_action_buttons()


func _refresh_selection() -> void:
	if _selected_inventory_index < 0 or _selected_inventory_index >= model.inventory.size():
		_detail_label.text = "选择一件背包物品查看属性与提升目标。"
		_refresh_action_buttons()
		return
	var item: Dictionary = model.inventory[_selected_inventory_index]
	var targets := model.potential_upgrade_targets(item)
	_detail_label.text = "%s\n提升目标：%s" % [
		_item_detail(item),
		_target_names(targets) \
			if not targets.is_empty() else "无（仍可手动替换较弱槽）",
	]
	for index in _inventory_buttons.size():
		_inventory_buttons[index].button_pressed = index == _selected_inventory_index
	_refresh_action_buttons()


func _refresh_action_buttons() -> void:
	var has_selection := (
		_selected_inventory_index >= 0
		and _selected_inventory_index < model.inventory.size()
	)
	_equip_button.disabled = locked or not has_selection
	_dismantle_button.disabled = locked or not has_selection
	_cleanup_button.disabled = locked or model.inventory.is_empty()


func _request_equip() -> void:
	if not locked and _selected_inventory_index >= 0:
		equip_requested.emit(_selected_inventory_index)


func _request_dismantle() -> void:
	if not locked and _selected_inventory_index >= 0:
		dismantle_requested.emit(_selected_inventory_index)


func _item_detail(item: Dictionary) -> String:
	var affixes := PackedStringArray()
	for affix_id in item.affixes:
		affixes.append("%s %.1f" % [AFFIX_NAMES[affix_id], float(item.affixes[affix_id])])
	var set_text := ""
	if not String(item.set_id).is_empty():
		set_text = " · %s%s" % [
			Rules.SET_DEFINITIONS[item.set_id].name,
			"（打造 70%）" if bool(item.crafted) else "",
		]
	return "%s T%d · 主属性 %.1f · 耐力 %.1f · %s%s" % [
		Rules.QUALITY_DATA[item.quality].name, int(item.item_tier),
		float(item.primary), float(item.stamina),
		" / ".join(affixes) if not affixes.is_empty() else "无词缀",
		set_text,
	]


func _slot_name_for_item(item: Dictionary) -> String:
	var targets := Rules.valid_targets(item.slot)
	if targets.size() == 1:
		return SLOT_NAMES[targets[0]]
	return "戒指" if Rules.canonical_slot(item.slot) == "ring" else "饰品"


func _target_names(targets: Array[String]) -> String:
	var names := PackedStringArray()
	for target in targets:
		names.append(SLOT_NAMES[target])
	return "、".join(names)


func _label(text_value: String, font_size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text_value: String, width: float, height: float) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(width, height)
	button.add_theme_font_size_override("font_size", 8)
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111820")
	style.border_color = Color("5a4930")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10.0
	style.content_margin_top = 7.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 7.0
	return style


func _section_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.07)
	style.border_color = Color(color, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 6.0
	style.content_margin_top = 5.0
	style.content_margin_right = 6.0
	style.content_margin_bottom = 5.0
	return style
