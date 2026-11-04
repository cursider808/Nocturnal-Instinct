extends CanvasLayer
## Меню крафта (Tab): центр экрана, категории-иконки, сетка рецептов,
## панель деталей с ингредиентами, выбор количества и прогресс изготовления.

const CAT_ICON := {"tools": "axe", "food": "cooked", "raft": "floor", "furniture": "station", "defense": "shield"}

enum RState { LOCKED, NO_STATION, NO_RES, OK }

var panel: Control
var _title: Label
var _grid: GridContainer
var _search: LineEdit
var _tabs: Array = []          # {id, button}
var _category: String = "tools"
var _selected: Dictionary = {}
var _crafting: bool = false
var _open: bool = false

# Панель деталей
var _d_icon: Control
var _d_name: Label
var _d_desc: Label
var _d_ing: VBoxContainer
var _d_station: Label
var _d_time: Label
var _craft_btn: Button
var _reason: Label
var _qty: int = 1
var _qty_buttons: Dictionary = {}
var _progress: ProgressBar

func _ready() -> void:
	add_to_group("crafting_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Recipes.recipes_changed.connect(_refresh)
	Inventory.inventory_changed.connect(_refresh_if_open)

func _build() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	panel = Panel.new()
	panel.add_theme_stylebox_override("panel", Ui.panel_style(Ui.BG, Ui.BORDER, 2, 6))
	panel.size = Vector2(410, 256)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.position = Ui.center_pos(panel.size)
	add_child(panel)

	_title = Ui.label("КРАФТ", 14, Ui.ACCENT)
	_title.position = Vector2(8, 4)
	panel.add_child(_title)
	var hint := Ui.label("Tab/Esc — закрыть", 9, Ui.TEXT_DIM)
	hint.position = Vector2(300, 8)
	panel.add_child(hint)

	# Вкладки категорий одинаковой ширины.
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(8, 22)
	tabs.add_theme_constant_override("separation", 2)
	panel.add_child(tabs)
	for cat in Recipes.CATEGORY_ORDER:
		var b := Button.new()
		b.custom_minimum_size = Vector2(46, 20)
		b.icon = UiIcons.icon(String(CAT_ICON.get(cat, "station")))
		b.expand_icon = true
		b.tooltip_text = String(Recipes.CATEGORY_NAMES.get(cat, cat))
		b.pressed.connect(func(): _set_category(cat))
		tabs.add_child(b)
		_tabs.append({"id": cat, "button": b})

	# Левая колонка: поиск + сетка.
	var left := VBoxContainer.new()
	left.position = Vector2(8, 48)
	left.size = Vector2(214, 202)
	left.add_theme_constant_override("separation", 3)
	panel.add_child(left)
	_search = LineEdit.new()
	_search.placeholder_text = "Поиск..."
	_search.custom_minimum_size = Vector2(214, 20)
	_search.add_theme_font_size_override("font_size", 10)
	_search.text_changed.connect(func(_t): _rebuild_grid())
	left.add_child(_search)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(214, 178)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 3)
	_grid.add_theme_constant_override("v_separation", 3)
	scroll.add_child(_grid)

	# Правая колонка: детали.
	var right := VBoxContainer.new()
	right.position = Vector2(230, 48)
	right.size = Vector2(172, 202)
	right.add_theme_constant_override("separation", 3)
	panel.add_child(right)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	right.add_child(head)
	var icon_holder := CenterContainer.new()
	icon_holder.custom_minimum_size = Vector2(36, 36)
	head.add_child(icon_holder)
	_d_icon = icon_holder
	_d_name = Ui.label("", 13, Ui.ACCENT)
	_d_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_name.custom_minimum_size = Vector2(122, 0)
	head.add_child(_d_name)
	_d_desc = Ui.label("", 9, Ui.TEXT_DIM)
	_d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_desc.custom_minimum_size = Vector2(164, 0)
	right.add_child(_d_desc)
	_d_ing = VBoxContainer.new()
	_d_ing.add_theme_constant_override("separation", 1)
	right.add_child(_d_ing)
	_d_station = Ui.label("", 9, Ui.TEXT_DIM)
	right.add_child(_d_station)
	_d_time = Ui.label("", 9, Ui.TEXT_DIM)
	right.add_child(_d_time)

	# Количество.
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", 3)
	right.add_child(qrow)
	var qlbl := Ui.label("Кол-во:", 9, Ui.TEXT_DIM)
	qrow.add_child(qlbl)
	for q in [["1", 1], ["5", 5], ["Макс", -1]]:
		var b := Button.new()
		b.text = String(q[0])
		b.custom_minimum_size = Vector2(0, 18)
		b.add_theme_font_size_override("font_size", 9)
		b.pressed.connect(func(): _set_qty(int(q[1])))
		qrow.add_child(b)
		_qty_buttons[int(q[1])] = b

	_craft_btn = Button.new()
	_craft_btn.text = "Изготовить"
	_craft_btn.custom_minimum_size = Vector2(164, 22)
	_craft_btn.pressed.connect(func(): _craft(_qty))
	right.add_child(_craft_btn)
	_reason = Ui.label("", 9, Ui.DANGER)
	_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason.custom_minimum_size = Vector2(164, 0)
	right.add_child(_reason)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(164, 8)
	_progress.max_value = 100.0
	_progress.value = 0.0
	_progress.visible = false
	right.add_child(_progress)

	panel.visible = false
	set_process_unhandled_input(false)

# --- Открытие/закрытие ---

func toggle() -> void:
	if _open:
		close()
	else:
		open()

func open() -> void:
	_open = true
	panel.visible = true
	GameState.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_process_unhandled_input(true)
	_refresh()
	_search.grab_focus()

func close() -> void:
	_open = false
	panel.visible = false
	GameState.ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_process_unhandled_input(false)

func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("toggle_craft") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_category(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_category(-1)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Q:
			_cycle_category(-1)
		elif event.physical_keycode == KEY_E:
			_cycle_category(1)
		elif event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER:
			_craft(_qty)

func _cycle_category(dir: int) -> void:
	var idx: int = Recipes.CATEGORY_ORDER.find(_category)
	idx = wrapi(idx + dir, 0, Recipes.CATEGORY_ORDER.size())
	_set_category(Recipes.CATEGORY_ORDER[idx])

func _set_category(cat: String) -> void:
	_category = cat
	if _title != null:
		_title.text = "КРАФТ — " + String(Recipes.CATEGORY_NAMES.get(cat, cat))
	_refresh()

func _set_qty(q: int) -> void:
	_qty = q
	_update_qty_buttons()
	_update_detail()

func _update_qty_buttons() -> void:
	for q in _qty_buttons:
		_qty_buttons[q].modulate = Ui.ACCENT if q == _qty else Color.WHITE

# --- Обновление ---

func _refresh_if_open() -> void:
	if _open:
		_refresh()

func _refresh() -> void:
	if not _open:
		return
	if _title != null:
		_title.text = "КРАФТ — " + String(Recipes.CATEGORY_NAMES.get(_category, _category))
	for t in _tabs:
		t["button"].modulate = Ui.ACCENT if String(t["id"]) == _category else Color.WHITE
	_rebuild_grid()
	_update_detail()

func _recipes_to_show() -> Array:
	var q: String = _search.text.strip_edges().to_lower()
	var out: Array = []
	for r in Recipes.recipes:
		if q != "":
			if Recipes.item_name(String(r.get("out"))).to_lower().findn(q) >= 0:
				out.append(r)
		elif String(r.get("cat")) == _category:
			out.append(r)
	return out

func _rebuild_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	for r in _recipes_to_show():
		_grid.add_child(_make_cell(r))

func _recipe_state(r: Dictionary) -> int:
	if not Recipes.is_unlocked(r):
		return RState.LOCKED
	if not _station_ok(r):
		return RState.NO_STATION
	if Recipes.missing(r).size() > 0:
		return RState.NO_RES
	return RState.OK

func _cell_border(state: int) -> Color:
	match state:
		RState.OK: return Ui.ACCENT
		RState.NO_RES: return Ui.BORDER
		RState.NO_STATION: return Color(0.45, 0.35, 0.5)
		_: return Color(0.25, 0.24, 0.22)

func _make_cell(r: Dictionary) -> Control:
	var state: int = _recipe_state(r)
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(65, 58)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := Ui.panel_style(Ui.BG_SOFT, _cell_border(state), 1, 2)
	var sel_id: String = "" if _selected.is_empty() else str(_selected.get("id", ""))
	if sel_id != "" and str(r.get("id", "")) == sel_id:
		style = Ui.panel_style(Color(0.18, 0.14, 0.08, 0.95), Ui.ACCENT, 2, 2)
	cell.add_theme_stylebox_override("panel", style)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(vb)
	var icon_center := CenterContainer.new()
	icon_center.custom_minimum_size = Vector2(0, 26)
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(icon_center)
	if state == RState.LOCKED:
		icon_center.add_child(_tex_node("lock"))
	else:
		icon_center.add_child(UiIcons.make_icon_node(String(r.get("out"))))
	var nm := Ui.label("???" if state == RState.LOCKED else Recipes.item_name(String(r.get("out"))), 9,
		Ui.TEXT if state != RState.LOCKED else Ui.TEXT_DIM)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(61, 0)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nm)
	cell.tooltip_text = _tooltip_for(r, state)
	cell.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_select(r))
	return cell

func _tex_node(icon_key: String) -> TextureRect:
	var node := TextureRect.new()
	node.texture = UiIcons.icon(icon_key)
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.custom_minimum_size = Vector2(20, 20)
	node.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _tooltip_for(r: Dictionary, state: int) -> String:
	match state:
		RState.LOCKED: return "Рецепт не открыт (стол исследователя)"
		RState.NO_STATION: return "Нужна станция: " + _station_name(String(r.get("station")))
		RState.NO_RES: return "Не хватает ресурсов"
		_: return "Можно изготовить"

func _select(r: Dictionary) -> void:
	_selected = r
	_rebuild_grid()
	_update_detail()

func _update_detail() -> void:
	for c in _d_icon.get_children():
		c.queue_free()
	if _selected.is_empty():
		_d_name.text = "Выберите рецепт"
		_d_desc.text = "Кликните рецепт слева, чтобы увидеть ингредиенты."
		for c in _d_ing.get_children():
			c.queue_free()
		_d_station.text = ""
		_d_time.text = ""
		_craft_btn.disabled = true
		_reason.text = ""
		return
	var out_id: String = String(_selected.get("out"))
	_d_icon.add_child(UiIcons.make_icon_node(out_id))
	_d_name.text = Recipes.item_name(out_id)
	_d_desc.text = String(_selected.get("desc", ""))
	# Ингредиенты с иконками и счётчиком есть/нужно.
	for c in _d_ing.get_children():
		c.queue_free()
	var need: Dictionary = _selected.get("need", {})
	var qty: int = _effective_qty()
	for id in need:
		var have: int = Inventory.count(id)
		var want: int = int(need[id]) * qty
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		row.add_child(UiIcons.make_icon_node(id))
		row.add_child(Ui.label(Recipes.item_name(id), 9, Ui.TEXT))
		var cnt := Ui.label("%d/%d" % [have, want], 9, Ui.GOOD if have >= want else Ui.DANGER)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cnt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cnt)
		_d_ing.add_child(row)
	# Станция и время.
	var st: String = String(_selected.get("station", ""))
	_d_station.text = ("Станция: " + _station_name(st)) if st != "" else "Без станции"
	_d_time.text = "Время: %.1f с" % _craft_time(_selected)
	_reason.text = _reason_text()
	_craft_btn.disabled = _crafting or _recipe_state(_selected) != RState.OK
	_update_qty_buttons()

func _effective_qty() -> int:
	var need: Dictionary = _selected.get("need", {})
	if _qty != -1:
		return maxi(1, _qty)
	# Максимум по ресурсам.
	var best: int = 99
	for id in need:
		best = mini(best, int(float(Inventory.count(id)) / float(maxi(1, int(need[id])))))
	return maxi(1, best)

func _reason_text() -> String:
	if _selected.is_empty():
		return ""
	match _recipe_state(_selected):
		RState.LOCKED: return "Рецепт не открыт"
		RState.NO_STATION: return "Нужна станция: " + _station_name(String(_selected.get("station")))
		RState.NO_RES: return "Не хватает ресурсов"
		_: return "Enter — быстрый крафт"

func _craft_time(r: Dictionary) -> float:
	return 0.4 + float(r.get("tier", 1)) * 0.2

# --- Изготовление ---

func _craft(qty_sel: int) -> void:
	if _crafting or _selected.is_empty():
		return
	if _recipe_state(_selected) != RState.OK:
		GameState.show_toast(_reason_text())
		return
	var qty: int = _effective_qty() if qty_sel == -1 else maxi(1, qty_sel)
	# Проверяем ресурсы на всё количество.
	var need: Dictionary = _selected.get("need", {})
	for id in need:
		if Inventory.count(id) < int(need[id]) * qty:
			GameState.show_toast("Не хватает ресурсов на x%d" % qty)
			return
	for id in need:
		Inventory.remove(id, int(need[id]) * qty)
	var out_id: String = String(_selected.get("out"))
	var out_n: int = int(_selected.get("n", 1)) * qty
	_crafting = true
	_craft_btn.disabled = true
	_progress.visible = true
	_progress.value = 0.0
	AudioManager.play("craft", null, -6.0)
	var dur: float = _craft_time(_selected)
	var t := create_tween()
	t.tween_property(_progress, "value", 100.0, dur)
	await t.finished
	_progress.visible = false
	_crafting = false
	var leftover: int = Inventory.add(out_id, out_n)
	if leftover < out_n:
		GameState.show_toast("Изготовлено: " + Recipes.item_name(out_id))
	else:
		GameState.show_toast("Инвентарь полон!")
	Recipes.recipes_changed.emit()
	_refresh()

func _station_ok(r: Dictionary) -> bool:
	var st: String = String(r.get("station", ""))
	if st == "":
		return true
	for n in get_tree().get_nodes_in_group("station"):
		if String(n.get("station_id")) == st:
			return true
	return false

func _station_name(st: String) -> String:
	match st:
		"workbench": return "Верстак"
		"cooker": return "Плита"
		"purifier": return "Очиститель воды"
		"research": return "Стол исследователя"
	return st