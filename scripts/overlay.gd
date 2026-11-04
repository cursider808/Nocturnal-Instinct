extends CanvasLayer
## Экраны поверх игры: пауза, настройки, управление (F1), смерть, победа.
## Всё в едином стиле, с мягкими появлениями.

var _dim: ColorRect
var pause_panel: Panel
var settings_panel: Panel
var controls_panel: Panel
var death_panel: Panel
var win_panel: Panel
var _paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	add_child(_dim)
	pause_panel = _make_screen("ПАУЗА", 220, 212)
	_build_pause()
	settings_panel = _make_screen("НАСТРОЙКИ", 300, 250)
	_build_settings()
	controls_panel = _make_screen("УПРАВЛЕНИЕ", 320, 226)
	_build_controls()
	death_panel = _make_screen("ВЫ ПОГИБЛИ", 240, 150)
	_build_death()
	win_panel = _make_screen("ВЫ ВЫЖИЛИ!", 260, 130)
	_build_win()
	GameState.died.connect(func(): _show(death_panel))
	GameState.won.connect(func(): _show(win_panel))

# --- Вспомогательное ---

func _make_screen(title: String, w: float, h: float) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", Ui.panel_style(Ui.BG, Ui.BORDER, 2, 8))
	p.size = Vector2(w, h)
	p.set_anchors_preset(Control.PRESET_TOP_LEFT)
	p.position = Ui.center_pos(p.size)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.visible = false
	add_child(p)
	var t := Ui.label(title, 16, Ui.ACCENT)
	t.position = Vector2(10, 8)
	p.add_child(t)
	return p

func _show(p: Panel) -> void:
	_dim.visible = true
	p.visible = true
	p.modulate.a = 0.0
	p.position.y += 6.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(p, "modulate:a", 1.0, 0.18)
	tw.tween_property(p, "position:y", p.position.y - 6.0, 0.18)

func _hide_all() -> void:
	for p in [pause_panel, settings_panel, controls_panel, death_panel, win_panel]:
		p.visible = false
	_dim.visible = false

func _button(parent: Control, text: String, x: float, y: float, w: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = Vector2(x, y)
	b.size = Vector2(w, 22)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

# --- Пауза ---

func _build_pause() -> void:
	var b := 220
	_button(pause_panel, "Продолжить", (b - 180) / 2.0, 44, 180, resume)
	_button(pause_panel, "Сохранить", (b - 180) / 2.0, 70, 180, func(): SaveManager.save_game())
	_button(pause_panel, "Настройки", (b - 180) / 2.0, 96, 180, func():
		_dim.visible = true
		settings_panel.visible = true
		_settings_refresh())
	_button(pause_panel, "Управление (F1)", (b - 180) / 2.0, 122, 180, func():
		_dim.visible = true
		controls_panel.visible = true)
	_button(pause_panel, "В главное меню", (b - 180) / 2.0, 148, 180, _goto_menu)
	_button(pause_panel, "Выход", (b - 180) / 2.0, 174, 180, func(): get_tree().quit())

func toggle_pause() -> void:
	if _paused:
		resume()
	else:
		pause()

func pause() -> void:
	_paused = true
	_show(pause_panel)
	GameState.ui_open = true
	GameState.set_state(GameState.State.PAUSED)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func resume() -> void:
	_paused = false
	_hide_all()
	GameState.ui_open = false
	GameState.set_state(GameState.State.PLAYING)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	# Esc закрывает верхний открытый экран.
	if event.is_action_pressed("pause"):
		if settings_panel.visible:
			settings_panel.visible = false
			get_viewport().set_input_as_handled()
			return
		if controls_panel.visible:
			controls_panel.visible = false
			if not pause_panel.visible and not settings_panel.visible:
				_dim.visible = false
			get_viewport().set_input_as_handled()
			return
		if pause_panel.visible:
			resume()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1:
		if controls_panel.visible:
			controls_panel.visible = false
			if not pause_panel.visible and not settings_panel.visible:
				_dim.visible = false
		else:
			_dim.visible = true
			controls_panel.visible = true
		get_viewport().set_input_as_handled()

# --- Настройки ---

var _vol_sliders: Dictionary = {}
var _sens_slider: HSlider
var _bright_slider: HSlider
var _win_mode: OptionButton

func _build_settings() -> void:
	var y: float = 34.0
	_vol_sliders["Master"] = _add_slider(settings_panel, "Общая громкость", y, 0.0, 1.0, func(v): GameState.vol_master = linear_to_db(maxf(0.001, v)); AudioManager.apply_volumes())
	y += 26
	_vol_sliders["SFX"] = _add_slider(settings_panel, "Звуки", y, 0.0, 1.0, func(v): GameState.vol_sfx = linear_to_db(maxf(0.001, v)); AudioManager.apply_volumes())
	y += 26
	_vol_sliders["Ambient"] = _add_slider(settings_panel, "Эмбиент", y, 0.0, 1.0, func(v): GameState.vol_ambient = linear_to_db(maxf(0.001, v)); AudioManager.apply_volumes())
	y += 26
	_vol_sliders["Music"] = _add_slider(settings_panel, "Музыка", y, 0.0, 1.0, func(v): GameState.vol_music = linear_to_db(maxf(0.001, v)); AudioManager.apply_volumes())
	y += 26
	_sens_slider = _add_slider(settings_panel, "Чувствительность мыши", y, 0.3, 3.0, func(v): GameState.mouse_sensitivity = 0.003 * v)
	y += 26
	_bright_slider = _add_slider(settings_panel, "Яркость", y, 0.5, 1.6, func(v): GameState.brightness = v)
	y += 26
	# Режим окна.
	var lbl := Ui.label("Режим окна", 11, Ui.TEXT)
	lbl.position = Vector2(16, y + 2)
	settings_panel.add_child(lbl)
	_win_mode = OptionButton.new()
	_win_mode.position = Vector2(170, y)
	_win_mode.size = Vector2(114, 20)
	_win_mode.add_theme_font_size_override("font_size", 10)
	_win_mode.add_item("Оконный", 0)
	_win_mode.add_item("Полный экран", 1)
	_win_mode.add_item("Без рамки", 2)
	_win_mode.item_selected.connect(func(i): _apply_window_mode(i))
	settings_panel.add_child(_win_mode)
	_button(settings_panel, "Назад", 110, y + 30, 100, func():
		settings_panel.visible = false
		if not pause_panel.visible:
			_dim.visible = false
	)

func _add_slider(parent: Control, text: String, y: float, mn: float, mx: float, cb: Callable) -> HSlider:
	var l := Ui.label(text, 11, Ui.TEXT)
	l.position = Vector2(16, y + 2)
	l.custom_minimum_size = Vector2(150, 0)
	parent.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = (mx - mn) / 100.0
	s.position = Vector2(170, y)
	s.size = Vector2(96, 16)
	s.value_changed.connect(cb)
	parent.add_child(s)
	return s

func _settings_refresh() -> void:
	if _vol_sliders.has("Master"):
		_vol_sliders["Master"].value = db_to_linear(GameState.vol_master)
		_vol_sliders["SFX"].value = db_to_linear(GameState.vol_sfx)
		_vol_sliders["Ambient"].value = db_to_linear(GameState.vol_ambient)
		_vol_sliders["Music"].value = db_to_linear(GameState.vol_music)
	_sens_slider.value = GameState.mouse_sensitivity / 0.003
	_bright_slider.value = GameState.brightness
	_win_mode.selected = int(GameState.window_mode)

func _apply_window_mode(mode: int) -> void:
	GameState.window_mode = mode
	match mode:
		1: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

# --- Управление (F1) ---

func _build_controls() -> void:
	var lines: Array[String] = [
		"WASD — движение, Shift — бег/нырок",
		"Space — прыжок, F — фонарь",
		"ЛКМ — использовать, ПКМ — крюк",
		"E — взаимодействие, Q — якорь/выброс",
		"B — стройка, R — поворот постройки",
		"Tab — крафт, I — инвентарь",
		"1-9 — слоты, F1 — справка, Esc — пауза",
	]
	var y := 34.0
	for line in lines:
		var l := Ui.label(line, 10, Ui.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.position = Vector2(14, y)
		l.custom_minimum_size = Vector2(292, 0)
		l.size = Vector2(292, 20)
		controls_panel.add_child(l)
		y += 24
	_button(controls_panel, "Закрыть", 110, y + 4, 100, func():
		controls_panel.visible = false
		if not pause_panel.visible:
			_dim.visible = false)

# --- Смерть и победа ---

func _build_death() -> void:
	_button(death_panel, "Начать заново", 30, 56, 180, func():
		GameState.new_game()
		get_tree().reload_current_scene())
	_button(death_panel, "Загрузить сохранение", 30, 84, 180, func():
		if SaveManager.has_save():
			SaveManager.load_game()
			get_tree().reload_current_scene()
		else:
			GameState.show_toast("Сохранения нет"))
	_button(death_panel, "В главное меню", 30, 112, 180, _goto_menu)

func _build_win() -> void:
	var l := Ui.label("Вы пережили %d суток на острове" % GameState.GOAL_DAYS, 11, Ui.TEXT)
	l.position = Vector2(24, 44)
	win_panel.add_child(l)
	_button(win_panel, "В главное меню", 40, 74, 180, _goto_menu)

func _goto_menu() -> void:
	GameState.set_state(GameState.State.MENU)
	GameState.ui_open = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")