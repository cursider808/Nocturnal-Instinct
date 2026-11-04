extends CanvasLayer
## Окно инвентаря (I) и сундука: сетка слотов, перетаскивание мышью,
## разделение стека (ПКМ), быстрый перенос (Shift+ЛКМ), выброс (Q / за окно).

const HOTBAR := 9

var panel: Panel
var _root: Control
var _held: Dictionary = {}          # {"id":..., "count":...} или пусто
var _held_vis: Control
var _held_icon: Control
var _held_count: Label
var _chest: Variant = null          # ItemContainer сундука
var _open: bool = false
var _title: Label
var _content: Control
var _tooltip: Label

func _ready() -> void:
	add_to_group("inventory_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	panel = Panel.new()
	panel.add_theme_stylebox_override("panel", Ui.panel_style(Ui.BG, Ui.BORDER, 2, 6))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_root.add_child(panel)
	_title = Ui.label("ИНВЕНТАРЬ", 13, Ui.ACCENT)
	_title.position = Vector2(8, 4)
	panel.add_child(_title)
	_content = Control.new()
	_content.position = Vector2(6, 22)
	panel.add_child(_content)

	# Плашка «в руке».
	_held_vis = Panel.new()
	_held_vis.add_theme_stylebox_override("panel", Ui.panel_style(Color(0, 0, 0, 0.85), Ui.ACCENT, 1, 0))
	_held_vis.custom_minimum_size = Vector2(24, 24)
	_held_vis.size = Vector2(24, 24)
	_held_vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_vis.visible = false
	_held_vis.z_index = 10
	_root.add_child(_held_vis)
	_held_icon = Control.new()
	_held_icon.set_anchors_preset(Control.PRESET_CENTER)
	_held_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_vis.add_child(_held_icon)
	_held_count = Ui.label("", 9, Ui.TEXT)
	_held_count.position = Vector2(10, 12)
	_held_vis.add_child(_held_count)

	Inventory.inventory_changed.connect(_render_if_open)
	Inventory.selection_changed.connect(func(_i): _render_if_open())

	_tooltip = Ui.label("", 9, Ui.TEXT_DIM)
	_tooltip.z_index = 11
	_tooltip.visible = false
	_root.add_child(_tooltip)

func _process(_delta: float) -> void:
	if _held_vis.visible:
		_held_vis.position = get_viewport().get_mouse_position() - Vector2(12, 12)

func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		if event.is_action_pressed("inventory"):
			open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	# Клик вне окна при «предмете в руке» — выбросить.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _held.is_empty():
		if not panel.get_global_rect().has_point(get_viewport().get_mouse_position()):
			_drop_held()
			get_viewport().set_input_as_handled()

# --- Открытие ---

func toggle() -> void:
	if _open:
		close()
	else:
		open()

func open() -> void:
	_chest = null
	_open = true
	panel.visible = true
	panel.size = Vector2(266, 150)
	panel.position = Ui.center_pos(panel.size)
	_title.text = "ИНВЕНТАРЬ  (I — закрыть)"
	GameState.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_render()

func open_container(container: Variant) -> void:
	_chest = container
	_open = true
	panel.visible = true
	panel.size = Vector2(300, 168)
	panel.position = Ui.center_pos(panel.size)
	_title.text = "СУНДУК  (I/Esc — закрыть)"
	GameState.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_render()

func close() -> void:
	if not _held.is_empty():
		_drop_held()
	_open = false
	_chest = null
	panel.visible = false
	_tooltip.visible = false
	GameState.ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# --- Отрисовка ---

func _render_if_open() -> void:
	if _open:
		_render()

func _render() -> void:
	for c in _content.get_children():
		c.queue_free()
	if _chest != null:
		_build_chest()
	else:
		_build_inventory()
	_update_held_visual()

func _build_inventory() -> void:
	var hot_lbl := Ui.label("Быстрый доступ", 9, Ui.TEXT_DIM)
	hot_lbl.position = Vector2(2, 0)
	_content.add_child(hot_lbl)
	for i in HOTBAR:
		_content.add_child(_make_slot(Inventory.container, i, Vector2(2 + i * 28, 12), i == Inventory.selected))
	var bp_lbl := Ui.label("Рюкзак", 9, Ui.TEXT_DIM)
	bp_lbl.position = Vector2(2, 44)
	_content.add_child(bp_lbl)
	for i in range(HOTBAR, Inventory.container.slots.size()):
		var n: int = i - HOTBAR
		_content.add_child(_make_slot(Inventory.container, i, Vector2(2 + (n % 5) * 28, 56 + int(float(n) / 5.0) * 28), false))

func _build_chest() -> void:
	var ch_lbl := Ui.label("Сундук", 9, Ui.TEXT_DIM)
	ch_lbl.position = Vector2(2, 0)
	_content.add_child(ch_lbl)
	for i in _chest.slots.size():
		var n: int = i
		_content.add_child(_make_slot(_chest, i, Vector2(2 + (n % 3) * 28, 12 + int(float(n) / 3.0) * 28), false))
	var pl_lbl := Ui.label("Инвентарь", 9, Ui.TEXT_DIM)
	pl_lbl.position = Vector2(96, 0)
	_content.add_child(pl_lbl)
	for i in Inventory.container.slots.size():
		var n: int = i
		_content.add_child(_make_slot(Inventory.container, i, Vector2(96 + (n % 5) * 28, 12 + int(float(n) / 5.0) * 28), i == Inventory.selected and i < HOTBAR))

func _make_slot(container: Variant, index: int, pos: Vector2, selected: bool) -> Control:
	var slot := Panel.new()
	slot.position = pos
	slot.size = Vector2(26, 26)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	var border: Color = Ui.ACCENT if selected else Ui.BORDER
	slot.add_theme_stylebox_override("panel", Ui.cell_style(Ui.BG_SOFT, border, 2 if selected else 1))
	slot.set_meta("container", container)
	slot.set_meta("index", index)

	var s = container.slots[index]
	if s != null:
		var holder := Control.new()
		holder.set_anchors_preset(Control.PRESET_CENTER)
		holder.grow_horizontal = Control.GROW_DIRECTION_BOTH
		holder.grow_vertical = Control.GROW_DIRECTION_BOTH
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(UiIcons.make_icon_node(String(s.get("id"))))
		slot.add_child(holder)
		if int(s.get("count")) > 1:
			var cnt := Ui.label(str(int(s.get("count"))), 9, Ui.TEXT)
			cnt.position = Vector2(0, 13)
			cnt.size = Vector2(24, 12)
			cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			slot.add_child(cnt)
		slot.tooltip_text = _slot_tooltip(String(s.get("id")))

	slot.gui_input.connect(func(ev): _on_slot_input(ev, container, index))
	slot.mouse_entered.connect(func(): _show_tooltip(slot))
	slot.mouse_exited.connect(func(): _tooltip.visible = false)
	return slot

func _slot_tooltip(id: String) -> String:
	var info: Dictionary = Recipes.get_item(id)
	return "%s\n%s\nТип: %s" % [Recipes.item_name(id), String(info.get("desc", "")), _cat_name(String(info.get("cat", "")))]

func _cat_name(cat: String) -> String:
	match cat:
		"resource": return "ресурс"
		"food": return "еда/питьё"
		"tool": return "инструмент"
		"build": return "постройка"
		"station": return "станция"
		"defense": return "оборона"
	return cat

func _show_tooltip(slot: Control) -> void:
	var id: String = ""
	var cont = slot.get_meta("container")
	var idx: int = int(slot.get_meta("index"))
	var s = cont.slots[idx]
	if s != null:
		id = String(s.get("id"))
	if id == "":
		_tooltip.visible = false
		return
	_tooltip.text = _slot_tooltip(id)
	_tooltip.position = slot.global_position + Vector2(28, 0)
	_tooltip.visible = true

# --- Логика слотов ---

func _on_slot_input(ev: InputEvent, container: Variant, index: int) -> void:
	if not (ev is InputEventMouseButton) or not ev.pressed:
		return
	if ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.double_click:
			_quick_move(container, index)
		elif ev.shift_pressed:
			_quick_move(container, index)
		else:
			_pick_or_place(container, index)
	elif ev.button_index == MOUSE_BUTTON_RIGHT:
		_split_or_one(container, index)

func _set_slot(container: Variant, index: int, value: Variant) -> void:
	container.slots[index] = value
	container.changed.emit()

func _pick_or_place(container: Variant, index: int) -> void:
	var cur = container.slots[index]
	if _held.is_empty():
		if cur == null:
			return
		_held = {"id": String(cur.get("id")), "count": int(cur.get("count"))}
		_set_slot(container, index, null)
		return
	# Несём предмет.
	if cur == null:
		_set_slot(container, index, _held.duplicate())
		_held = {}
	elif String(cur.get("id")) == String(_held.get("id")):
		var maxs: int = int(Recipes.get_item(String(_held.get("id"))).get("stack", 50))
		var space: int = maxs - int(cur.get("count"))
		var put: int = mini(space, int(_held.get("count")))
		cur["count"] = int(cur.get("count")) + put
		_held["count"] = int(_held.get("count")) - put
		if int(_held.get("count")) <= 0:
			_held = {}
		container.changed.emit()
	else:
		# Обмен.
		_set_slot(container, index, _held.duplicate())
		_held = {"id": String(cur.get("id")), "count": int(cur.get("count"))}
	_update_held_visual()

func _split_or_one(container: Variant, index: int) -> void:
	var cur = container.slots[index]
	if _held.is_empty():
		if cur == null:
			return
		var half: int = int(ceil(float(cur.get("count")) / 2.0))
		_held = {"id": String(cur.get("id")), "count": half}
		var left: int = int(cur.get("count")) - half
		if left > 0:
			_set_slot(container, index, {"id": String(cur.get("id")), "count": left})
		else:
			_set_slot(container, index, null)
	else:
		if cur == null:
			_set_slot(container, index, {"id": String(_held.get("id")), "count": 1})
			_held["count"] = int(_held.get("count")) - 1
		elif String(cur.get("id")) == String(_held.get("id")):
			var maxs: int = int(Recipes.get_item(String(_held.get("id"))).get("stack", 50))
			if int(cur.get("count")) < maxs:
				cur["count"] = int(cur.get("count")) + 1
				_held["count"] = int(_held.get("count")) - 1
				container.changed.emit()
		if not _held.is_empty() and int(_held.get("count")) <= 0:
			_held = {}
	_update_held_visual()

## Shift/двойной клик — перенос между хотбаром и рюкзаком (или сундуком и игроком).
func _quick_move(container: Variant, index: int) -> void:
	var cur = container.slots[index]
	if cur == null:
		return
	var id: String = String(cur.get("id"))
	var count: int = int(cur.get("count"))
	# Целевой контейнер.
	var target: Variant
	if container == Inventory.container:
		if _chest != null:
			target = _chest
		else:
			# Хотбар <-> рюкзак: переносим в другую половину.
			target = Inventory.container
	elif _chest != null and container == _chest:
		target = Inventory.container
	if target == null:
		return
	# Пробуем добавить, минуя исходный слот.
	var placed: int = 0
	var maxs: int = int(Recipes.get_item(id).get("stack", 50))
	for i in target.slots.size():
		if i == index and target == container:
			continue
		var s = target.slots[i]
		if s != null and String(s.get("id")) == id and int(s.get("count")) < maxs:
			var put: int = mini(maxs - int(s.get("count")), count - placed)
			s["count"] = int(s.get("count")) + put
			placed += put
		if placed >= count:
			break
	for i in target.slots.size():
		if placed >= count:
			break
		if i == index and target == container:
			continue
		if target.slots[i] == null:
			var put2: int = mini(maxs, count - placed)
			target.slots[i] = {"id": id, "count": put2}
			placed += put2
	if placed > 0:
		var left: int = count - placed
		if left > 0:
			_set_slot(container, index, {"id": id, "count": left})
		else:
			_set_slot(container, index, null)
		target.changed.emit()

func _drop_held() -> void:
	if _held.is_empty():
		return
	GameState.show_toast("Выброшено: " + Recipes.item_name(String(_held.get("id"))) + " x" + str(int(_held.get("count"))))
	_held = {}
	_update_held_visual()

func _update_held_visual() -> void:
	for c in _held_icon.get_children():
		c.queue_free()
	if _held.is_empty():
		_held_vis.visible = false
		return
	_held_vis.visible = true
	_held_icon.add_child(UiIcons.make_icon_node(String(_held.get("id"))))
	_held_count.text = str(int(_held.get("count"))) if int(_held.get("count")) > 1 else ""