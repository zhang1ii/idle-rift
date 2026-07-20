class_name LoopEquipmentInventoryPanel
extends "res://src/ui/equipment_inventory_panel.gd"


const Effects = preload("res://src/gameplay/legendary_loop_effects.gd")
signal exchange_requested(effect_id: String)

var _exchange_option: OptionButton
var _exchange_button: Button


func _build_inventory_section() -> Control:
	var panel := super._build_inventory_section()
	var content := panel.get_child(0) as VBoxContainer
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	content.add_child(row)
	_exchange_option = OptionButton.new()
	_exchange_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_exchange_option.add_theme_font_size_override("font_size", 8)
	row.add_child(_exchange_option)
	_exchange_button = _button("12徽记兑换弱化版", 116, 23)
	_exchange_button.pressed.connect(_request_exchange)
	row.add_child(_exchange_button)
	return panel


func refresh() -> void:
	super.refresh()
	if _exchange_option == null or model == null:
		return
	var selected_id := ""
	if _exchange_option.selected >= 0 and _exchange_option.item_count > 0:
		selected_id = String(_exchange_option.get_item_metadata(_exchange_option.selected))
	_exchange_option.clear()
	for effect_id in model.discovered_effect_ids:
		var index := _exchange_option.item_count
		_exchange_option.add_item(Effects.effect_name(effect_id))
		_exchange_option.set_item_metadata(index, effect_id)
		if effect_id == selected_id:
			_exchange_option.select(index)
	_exchange_button.disabled = locked or _exchange_option.item_count == 0 \
		or model.rift_tokens < model.WEAK_EFFECT_TOKEN_COST


func _request_exchange() -> void:
	if locked or _exchange_option.selected < 0:
		return
	var effect_id := String(_exchange_option.get_item_metadata(_exchange_option.selected))
	exchange_requested.emit(effect_id)




func _item_detail(item: Dictionary) -> String:
	var detail := super._item_detail(item)
	var effect_id := String(item.get("special_effect", ""))
	if not Effects.is_loop_effect(effect_id):
		return detail
	var power := float(item.get("effect_power", 1.0))
	var power_text := "原版" if power >= 0.999 else "兑换版 · %d%%强度" % roundi(power * 100.0)
	return "%s\n传奇特效【%s】（%s）：%s" % [
		detail,
		Effects.effect_name(effect_id),
		power_text,
		Effects.effect_description(effect_id),
	]
