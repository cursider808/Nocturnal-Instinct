extends CanvasLayer
## HUD в едином мрачном пиксельном стиле: показатели, часы, тревога, хотбар,
## прицел с подсказкой действия, уведомления и эффекты состояния.

var root: Control
var _stats: Dictionary = {}        # key -> {bar, fill, num, row, color}
var _clock_icon: TextureRect
var _clock_label: Label
var _alarm_fill: ColorRect
var _alarm_label: Label
var _alarm_row: Control
var _hotbar: Array = []
var _item_name: Label
var _item_name_timer: float = 0.0
var _crosshair: Control
var _prompt: Control
var _prompt_key: Label
var _prompt_text: Label
var _prompt_icon: TextureRect
var _loot_box: VBoxContainer
var _warn_box: VBoxContainer
var _vignette: TextureRect
var _player: Node

var _shown: Dictionary = {"health": 100.0, "hunger": 100.0, "thirst": 100.0, "stamina": 100.0, "oxygen": 100.0}
var _last_phase: String = ""
var _last_minute: int = -1
var _last_alarm_pct: int = -1

func _ready() -> void:
	add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_stats()
	_build_clock()
	_build_hotbar()
	_build_crosshair()
	_build_notifications()
	_build_vignette()
	Inventory.inventory_changed.connect(_refresh_hotbar)
	Inventory.selection_changed.connect(func(_i): _refresh_hotbar(); _show_item_name())
	Inventory.item_added.connect(_on_item_added)
	GameState.warn.connect(_on_warning)
	_refresh_hotbar()
	_show_item_name()

# --- Показатели ---

func _build_stats() -> void:
	var defs := [
		["health", "heart", Ui.DANGER],
		["hunger", "hunger", Color(0.78, 0.5, 0.2)],
		["thirst", "thirst", Color(0.35, 0.6, 0.85)],
		["stamina", "stamina", Color(0.75, 0.7, 0.3)],
		["oxygen", "oxygen", Color(0.5, 0.8, 0.9)],
	]
	var y: float = 6.0
	for d in defs:
		var row := HBoxContainer.new()
		row.position = Vector2(6, y)
		row.add_theme_constant_override("separation", 3)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := TextureRect.new()
		ic.texture = UiIcons.icon(String(d[1]))
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.custom_minimum_size = Vector2(16, 16)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(ic)
		var bar_bg := Panel.new()
		bar_bg.custom_minimum_size = Vector2(64, 7)
		bar_bg.add_theme_stylebox_override("panel", Ui.cell_style(Color(0.02, 0.02, 0.02, 0.85), Ui.BORDER, 1))
		row.add_child(bar_bg)
		var fill := ColorRect.new()
		fill.color = d[2]
		fill.position = Vector2(1, 1)
		fill.size = Vector2(62, 5)
		bar_bg.add_child(fill)
		var num := Ui.label("100", 9, Ui.TEXT)
		num.custom_minimum_size = Vector2(34, 0)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(num)
		root.add_child(row)
		_stats[d[0]] = {"row": row, "bar": bar_bg, "fill": fill, "num": num, "color": d[2]}
		y += 12.0

# --- Часы и тревога ---

func _build_clock() -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_icon = TextureRect.new()
	_clock_icon.texture = UiIcons.icon("sun")
	_clock_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_clock_icon.custom_minimum_size = Vector2(16, 16)
	_clock_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	box.add_child(_clock_icon)
	_clock_label = Ui.label("День 1, 08:00", 12, Ui.TEXT)
	box.add_child(_clock_label)
	box.position = Vector2(320, 4)
	root.add_child(box)

	_alarm_row = Control.new()
	_alarm_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alarm_row.position = Vector2(320, 22)
	root.add_child(_alarm_row)
	_alarm_label = Ui.label("Тревога 0%", 9, Ui.TEXT_DIM)
	_alarm_label.position = Vector2(0, 0)
	_alarm_label.size = Vector2(154, 10)
	_alarm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_alarm_row.add_child(_alarm_label)
	var bg := Panel.new()
	bg.size = Vector2(96, 8)
	bg.position = Vector2(58, 11)
	bg.add_theme_stylebox_override("panel", Ui.cell_style(Color(0.02, 0.02, 0.02, 0.85), Ui.BORDER, 1))
	_alarm_row.add_child(bg)
	_alarm_fill = ColorRect.new()
	_alarm_fill.color = Ui.GOOD
	_alarm_fill.position = Vector2(1, 1)
	_alarm_fill.size = Vector2(94, 6)
	bg.add_child(_alarm_fill)
	_alarm_row.pivot_offset = Vector2(106, 14)

# --- Хотбар ---

func _build_hotbar() -> void:
	var total: float = 9 * 28
	var x0: float = (480 - total) / 2.0
	for i in 9:
		var panel := Panel.new()
		panel.position = Vector2(x0 + i * 28, 244)
		panel.size = Vector2(26, 26)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", Ui.cell_style(Ui.BG_SOFT, Ui.BORDER, 1))
		root.add_child(panel)
		var num := Ui.label(str(i + 1), 8, Ui.TEXT_DIM)
		num.position = Vector2(2, 0)
		panel.add_child(num)
		var icon_holder := Control.new()
		icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_holder.set_anchors_preset(Control.PRESET_CENTER)
		icon_holder.grow_horizontal = Control.GROW_DIRECTION_BOTH
		icon_holder.grow_vertical = Control.GROW_DIRECTION_BOTH
		panel.add_child(icon_holder)
		var cnt := Ui.label("", 9, Ui.TEXT)
		cnt.position = Vector2(0, 13)
		cnt.size = Vector2(24, 12)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		panel.add_child(cnt)
		_hotbar.append({"panel": panel, "icon": icon_holder, "count": cnt})

	_item_name = Ui.label("", 12, Ui.ACCENT)
	_item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_name.position = Vector2(0, 226)
	_item_name.size = Vector2(480, 14)
	_item_name.modulate.a = 0.0
	root.add_child(_item_name)

func _refresh_hotbar() -> void:
	for i in 9:
		var s = Inventory.container.slots[i] if i < Inventory.container.slots.size() else null
		var slot: Dictionary = _hotbar[i]
		for c in slot["icon"].get_children():
			c.queue_free()
		var sel: bool = (i == Inventory.selected)
		var style: StyleBoxFlat = Ui.cell_style(Color(0.18, 0.14, 0.08, 0.95), Ui.ACCENT, 2) if sel else Ui.cell_style(Ui.BG_SOFT, Ui.BORDER, 1)
		slot["panel"].add_theme_stylebox_override("panel", style)
		if s == null:
			slot["count"].text = ""
			continue
		slot["icon"].add_child(UiIcons.make_icon_node(String(s.get("id"))))
		var n: int = int(s.get("count"))
		slot["count"].text = str(n) if n > 1 else ""

func _show_item_name() -> void:
	var id: String = Inventory.selected_id()
	_item_name.text = Recipes.item_name(id) if id != "" else ""
	_item_name.modulate.a = 1.0 if id != "" else 0.0
	_item_name_timer = 2.0

# --- Прицел и подсказка ---

func _build_crosshair() -> void:
	_crosshair = Control.new()
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.position = Vector2(239, 134)
	root.add_child(_crosshair)
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.85)
	dot.size = Vector2(2, 2)
	dot.position = Vector2(0, 0)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.add_child(dot)

	_prompt = HBoxContainer.new()
	_prompt.position = Vector2(0, 148)
	_prompt.size = Vector2(480, 18)
	_prompt.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt.add_theme_constant_override("separation", 4)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_prompt)
	_prompt_icon = TextureRect.new()
	_prompt_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_prompt_icon.custom_minimum_size = Vector2(16, 16)
	_prompt_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_prompt.add_child(_prompt_icon)
	var key_panel := Panel.new()
	key_panel.custom_minimum_size = Vector2(0, 16)
	key_panel.add_theme_stylebox_override("panel", Ui.panel_style(Color(0, 0, 0, 0.7), Ui.ACCENT_DIM, 1, 3))
	_prompt.add_child(key_panel)
	_prompt_key = Ui.label("E", 10, Ui.ACCENT)
	key_panel.add_child(_prompt_key)
	_prompt_text = Ui.label("", 11, Ui.TEXT)
	_prompt.add_child(_prompt_text)
	_prompt.visible = false

# --- Уведомления ---

func _build_notifications() -> void:
	_loot_box = VBoxContainer.new()
	_loot_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_loot_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_loot_box.position = Vector2(6, -6)
	_loot_box.add_theme_constant_override("separation", 1)
	_loot_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_loot_box)
	_warn_box = VBoxContainer.new()
	_warn_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_warn_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_warn_box.position = Vector2(-6, 42)
	_warn_box.add_theme_constant_override("separation", 1)
	_warn_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_warn_box)

func _on_item_added(id: String, count: int) -> void:
	_push_notification(_loot_box, id, ("+%d " % count) + Recipes.item_name(id), Ui.TEXT)
	while _loot_box.get_child_count() > 4:
		var c := _loot_box.get_child(0)
		_loot_box.remove_child(c)
		c.queue_free()

func _on_warning(text: String) -> void:
	_push_notification(_warn_box, "", text, Ui.WARN)
	while _warn_box.get_child_count() > 3:
		var c := _warn_box.get_child(0)
		_warn_box.remove_child(c)
		c.queue_free()

func _push_notification(box: VBoxContainer, id: String, text: String, col: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if id != "":
		row.add_child(UiIcons.make_icon_node(id))
	row.add_child(Ui.label(text, 11, col))
	row.modulate.a = 0.0
	box.add_child(row)
	var t := create_tween()
	t.tween_property(row, "modulate:a", 1.0, 0.15)
	t.tween_interval(2.6)
	t.tween_property(row, "modulate:a", 0.0, 0.5)
	t.tween_callback(row.queue_free)

# --- Виньетка ---

func _build_vignette() -> void:
	_vignette = TextureRect.new()
	_vignette.texture = _make_vignette_texture()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate = Color(1, 1, 1, 0)
	root.add_child(_vignette)
	root.move_child(_vignette, 0)

func _make_vignette_texture() -> Texture2D:
	var w := 64
	var h := 36
	var img: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var nx: float = absf((float(x) / w) * 2.0 - 1.0)
			var ny: float = absf((float(y) / h) * 2.0 - 1.0)
			var d: float = clampf((maxf(nx, ny) - 0.5) / 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, d * d))
	return ImageTexture.create_from_image(img)

# --- Кадровое обновление ---

func _process(delta: float) -> void:
	_update_stat("health", GameState.health, delta)
	_update_stat("hunger", GameState.hunger, delta)
	_update_stat("thirst", GameState.thirst, delta)
	_update_stat("stamina", GameState.stamina, delta)
	_update_stat("oxygen", GameState.oxygen, delta)
	_update_clock()
	_update_alarm(delta)
	_update_crosshair()
	if _item_name_timer > 0.0:
		_item_name_timer -= delta
		if _item_name_timer <= 0.0:
			var t := create_tween()
			t.tween_property(_item_name, "modulate:a", 0.0, 0.3)
	_update_vignette(delta)

func _update_stat(key: String, value: float, delta: float) -> void:
	var d: Dictionary = _stats[key]
	_shown[key] = lerpf(_shown[key], value, clampf(delta * 8.0, 0.0, 1.0))
	var v: float = _shown[key]
	d["fill"].size.x = 62.0 * clampf(v / 100.0, 0.0, 1.0)
	d["num"].text = str(int(round(value)))
	if key == "stamina":
		d["row"].visible = value < 99.5
	if value < 25.0:
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		d["fill"].color = d["color"].lerp(Ui.DANGER, pulse)
	else:
		d["fill"].color = d["color"]

func _update_clock() -> void:
	var t: float = GameState.time_of_day
	var hh: int = int(t)
	var mm: int = int((t - hh) * 60.0)
	var phase: String = GameState.day_phase()
	if phase != _last_phase:
		_last_phase = phase
		_clock_icon.texture = UiIcons.icon(_phase_icon(phase))
	if mm != _last_minute:
		_last_minute = mm
		_clock_label.text = "День %d, %02d:%02d" % [GameState.day, hh, mm]

func _phase_icon(phase: String) -> String:
	match phase:
		"dawn": return "dawn"
		"day": return "sun"
		"dusk": return "dusk"
		_: return "moon"

func _update_alarm(_delta: float) -> void:
	var a: float = GameState.alarm
	_alarm_fill.size.x = 94.0 * clampf(a / 100.0, 0.0, 1.0)
	_alarm_fill.color = Ui.GOOD.lerp(Ui.DANGER, clampf(a / 100.0, 0.0, 1.0))
	var pct: int = int(round(a))
	if pct != _last_alarm_pct:
		_last_alarm_pct = pct
		_alarm_label.text = "Тревога %d%%" % pct
		if pct > 0:
			var tw := create_tween()
			_alarm_row.scale = Vector2(1.12, 1.12)
			tw.tween_property(_alarm_row, "scale", Vector2.ONE, 0.2)

func _update_crosshair() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	var info: Dictionary = {}
	if _player != null and _player.has_method("get_hover_info"):
		info = _player.call("get_hover_info")
	if info.is_empty() or String(info.get("text", "")) == "":
		_prompt.visible = false
		return
	_prompt.visible = true
	_prompt_key.text = String(info.get("key", ""))
	_prompt_text.text = String(info.get("text", ""))
	var icon_key: String = String(info.get("icon", ""))
	if icon_key != "":
		_prompt_icon.texture = UiIcons.icon(icon_key)
		_prompt_icon.visible = true
	else:
		_prompt_icon.visible = false

func _update_vignette(delta: float) -> void:
	var target := Color(0, 0, 0, 0)
	if GameState.state == GameState.State.DEAD:
		target = Color(0, 0, 0, 1)
	elif GameState.health < 35.0:
		target = Color(Ui.DANGER.r, Ui.DANGER.g, Ui.DANGER.b, clampf((35.0 - GameState.health) / 35.0, 0.0, 0.8))
	else:
		var need: float = maxf(1.0 - GameState.hunger / 100.0, 1.0 - GameState.thirst / 100.0)
		if need > 0.5:
			target = Color(0.0, 0.0, 0.0, (need - 0.5) * 0.5)
	_vignette.modulate = _vignette.modulate.lerp(target, clampf(delta * 4.0, 0.0, 1.0))