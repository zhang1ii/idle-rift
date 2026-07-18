class_name TalentTreePanel
extends Control


signal talent_requested(talent_id: String)
signal reset_requested
signal close_requested

const BRANCH_COLORS := {
	"blood": Color("b94a5a"),
	"fury": Color("d58b35"),
	"guard": Color("4b91a8"),
}

var model: TalentTreeModel
var _points_label: Label
var _lock_label: Label
var _detail_label: Label
var _reset_button: Button
var _talent_buttons: Dictionary = {}


func setup(tree_model: TalentTreeModel) -> void:
	model = tree_model
	_build_interface()
	refresh()


func refresh() -> void:
	if model == null or _points_label == null:
		return
	_points_label.text = "天赋点  %d / %d    已投入 %d / %d" % [
		model.points_remaining(),
		model.point_budget,
		model.points_spent(),
		model.maximum_points,
	]
	_lock_label.text = "战斗中锁定 · 仅可查看" if model.battle_locked else "战前可免费调整"
	_lock_label.modulate = Color("df7b67") if model.battle_locked else Color("79c8a0")
	_reset_button.disabled = model.battle_locked or model.active_talent_ids.is_empty()
	for talent_id in _talent_buttons:
		_refresh_talent_button(String(talent_id), _talent_buttons[talent_id])


func _build_interface() -> void:
	for child in get_children():
		child.queue_free()
	_talent_buttons.clear()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	content.add_theme_constant_override("separation", 5)
	frame.add_child(content)
	content.add_child(_build_header())
	content.add_child(_build_branches())
	content.add_child(_build_footer())


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 31.0
	header.add_theme_constant_override("separation", 8)
	var title := _label("狂怒战士 · 天赋树", 18, Color("edbd5b"))
	title.custom_minimum_size.x = 185.0
	header.add_child(title)
	_points_label = _label("", 11, Color("d9e1e8"))
	_points_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_points_label)
	_lock_label = _label("", 10)
	_lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_lock_label)
	var close_button := Button.new()
	close_button.text = "关闭  Tab"
	close_button.custom_minimum_size = Vector2(76, 25)
	close_button.add_theme_font_size_override("font_size", 10)
	close_button.pressed.connect(close_requested.emit)
	header.add_child(close_button)
	return header


func _build_branches() -> Control:
	var branches := HBoxContainer.new()
	branches.size_flags_vertical = Control.SIZE_EXPAND_FILL
	branches.add_theme_constant_override("separation", 7)
	for branch in model.tree_definition["branches"]:
		branches.add_child(_build_branch(branch))
	return branches


func _build_branch(branch: Dictionary) -> Control:
	var branch_id := String(branch["id"])
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	panel.add_theme_stylebox_override("panel", _branch_style(BRANCH_COLORS[branch_id]))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	var name_label := _label(String(branch["name"]), 14, BRANCH_COLORS[branch_id].lightened(0.28))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	var description := _label(String(branch["description"]), 8, Color("9eabb7"))
	description.custom_minimum_size.y = 27.0
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(description)
	for tier in range(1, 5):
		var definition := _node_for_branch_tier(branch_id, tier)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 43)
		button.add_theme_font_size_override("font_size", 10)
		button.text = "第 %d 层\n%s" % [tier, String(definition["name"])]
		button.pressed.connect(talent_requested.emit.bind(String(definition["id"])))
		button.mouse_entered.connect(_show_talent_detail.bind(String(definition["id"])))
		button.mouse_exited.connect(_show_rules_hint)
		column.add_child(button)
		_talent_buttons[String(definition["id"])] = button
	return panel


func _build_footer() -> Control:
	var footer := HBoxContainer.new()
	footer.custom_minimum_size.y = 26.0
	_detail_label = _label(
		"每条路线逐层前置；第 2/3/4 层需总投入 2/4/6 点；三系终极天赋互斥。",
		9,
		Color("9eabb7"),
	)
	_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	footer.add_child(_detail_label)
	_reset_button = Button.new()
	_reset_button.text = "免费洗点"
	_reset_button.custom_minimum_size = Vector2(82, 24)
	_reset_button.add_theme_font_size_override("font_size", 10)
	_reset_button.pressed.connect(reset_requested.emit)
	footer.add_child(_reset_button)
	return footer


func _show_talent_detail(talent_id: String) -> void:
	if _detail_label == null:
		return
	var definition := model.node_definition(talent_id)
	_detail_label.text = "%s：%s" % [definition["name"], definition["description"]]


func _show_rules_hint() -> void:
	if _detail_label != null:
		_detail_label.text = "每条路线逐层前置；第 2/3/4 层需总投入 2/4/6 点；三系终极天赋互斥。"


func _refresh_talent_button(talent_id: String, button: Button) -> void:
	var definition := model.node_definition(talent_id)
	var active := model.has_talent(talent_id)
	var available := model.can_allocate(talent_id)
	var refundable := model.can_refund(talent_id)
	button.disabled = not available and not refundable
	button.text = "第 %d 层 · %s\n%s" % [
		int(definition["tier"]),
		String(definition["name"]),
		(
			"已点亮 · 点击退还" if refundable else "已点亮 · 后续依赖"
		) if active else (_lock_reason(definition) if not available else "可点亮"),
	]
	var branch_color: Color = BRANCH_COLORS[String(definition["branch"])]
	button.add_theme_color_override(
		"font_color",
		Color("fff0c2") if active else branch_color.lightened(0.42),
	)
	button.add_theme_color_override(
		"font_disabled_color",
		Color("fff0c2") if active else Color("65717b"),
	)
	button.add_theme_stylebox_override(
		"normal",
		_button_style(branch_color, 0.42 if active else 0.13),
	)
	button.add_theme_stylebox_override(
		"hover",
		_button_style(branch_color, 0.30),
	)
	button.add_theme_stylebox_override(
		"pressed",
		_button_style(branch_color.lightened(0.12), 0.38),
	)
	button.add_theme_stylebox_override(
		"disabled",
		_button_style(branch_color, 0.42 if active else 0.04),
	)


func _lock_reason(definition: Dictionary) -> String:
	if model.battle_locked:
		return "战斗中锁定"
	if model.points_remaining() < int(definition.get("cost", 1)):
		return "天赋点不足"
	var required := int(definition.get("required_total_points", 0))
	if model.points_spent() < required:
		return "需总投入 %d 点" % required
	for prerequisite in definition.get("prerequisites", []):
		if not model.has_talent(String(prerequisite)):
			return "需先点亮上一层"
	if not String(definition.get("exclusive_group", "")).is_empty():
		return "已有其他终极天赋"
	return "后续天赋依赖中"


func _node_for_branch_tier(branch_id: String, tier: int) -> Dictionary:
	for definition in model.tree_definition["nodes"]:
		if String(definition["branch"]) == branch_id and int(definition["tier"]) == tier:
			return definition
	assert(false, "缺少天赋节点：%s tier %d" % [branch_id, tier])
	return {}


func _label(text_value: String, font_size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


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


func _branch_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.08)
	style.border_color = Color(color, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 6.0
	style.content_margin_top = 4.0
	style.content_margin_right = 6.0
	style.content_margin_bottom = 5.0
	return style


func _button_style(color: Color, alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, alpha)
	style.border_color = Color(color, minf(0.85, alpha + 0.3))
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style
