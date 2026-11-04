extends Control
## Главное меню в едином мрачном пиксельном стиле.

var menu_panel: Panel
var settings_panel: Panel
var _vol_sliders: Dictionary = {}

func _ready() -> void:
	GameState.set_state(GameState.State.MENU)
	GameState.ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.loop_play("menu_music", "Music", -12.0)
	AudioManager.apply_volumes()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	menu_panel = _make_panel("ОСТРОВ ВЫЖИВАНИЯ", 240, 200)
	_build_menu()
	settings_panel = _make_panel("НАСТРОЙКИ", 300, 190)
	_build_settings()
	settings_panel.visible = false

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.05, 0.07)
	add_child(bg)
	# Лёгкая вертикальная тень для атмосферы.
	var v := TextureRect.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var sub := Ui.label("Переживите %d суток в океане" % GameState.GOAL_DAYS, 11, Ui.TEXT_DIM)
	sub.position = Vector2(0, 40)
	sub.size = Vector2(480, 14)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

func _make_panel(title: String, w: float, h: float) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", Ui.panel_style(Ui.BG, Ui.BORDER, 2, 8))
	p.size = Vector2(w, h)
	p.set_anchors_preset(Control.PRESET_TOP_LEFT)
	p.position = Ui.center_pos(p.size)
	add_child(p)
	var t := Ui.label(title, 16, Ui.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.position = Vector2(0, 10)
	t.size = Vector2(w, 18)
	p.add_child(t)
	return p

func _button(parent: Control, text: String, x: float, y: float, w: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = Vector2(x, y)
	b.size = Vector2(w, 24)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _build_menu() -> void:
	var w: float = 240
	_button(menu_panel, "Новая игра", 30, 54, 180, _new_game)
	var cont := _button(menu_panel, "Продолжить", 30, 84, 180, _continue)
	cont.disabled = not SaveManager.has_save()
	_button(menu_panel, "Настройки", 30, 114, 180, func(): settings_panel.visible = true)
	_button(menu_panel, "Выход", 30, 144, 180, func(): get_tree().quit())
	var hint := Ui.label("F1 — управление в игре", 10, Ui.TEXT_DIM)
	hint.position = Vector2(30, 174)
	menu_panel.add_child(hint)

func _build_settings() -> void:
	var y: float = 36.0
	_vol_sliders["Master"] = _slider(settings_panel, "Общая громкость", y, 0.0, 1.0, func(v): GameState.vol_master = linear_to_db(maxf(0.001, v)); AudioManager.apply_volumes())
	y += 24
	_vol_sliders["SFX"] = _slider(settings_panel, "Звуки", y, 0.0, 1.0, func(v): GameState.vol_sfx = linear_to_db(maxf(0.001, v)); AudioManager.apply_volumes())
	y += 24
	_vol_sliders["Ambient"] = _slider(settings_panel, "Эмбиент", y, 0.0, 1.0, func(v): GameState.vol_ambient = linear_to_db(maxf(0.001, v)); AudioManager.apply_volumes())
	y += 24
	_vol_sliders["Music"] = _slider(settings_panel, "Музыка", y, 0.0, 1.0, func(v): GameState.vol_music = linear_to_db(maxf(0.001, v)); AudioManager.apply_volumes())
	y += 24
	_slider(settings_panel, "Яркость", y, 0.5, 1.6, func(v): GameState.brightness = v)
	y += 30
	_button(settings_panel, "Назад", 100, y, 100, func(): settings_panel.visible = false)

func _slider(parent: Control, text: String, y: float, mn: float, mx: float, cb: Callable) -> HSlider:
	var l := Ui.label(text, 11, Ui.TEXT)
	l.position = Vector2(16, y + 2)
	parent.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = (mx - mn) / 100.0
	s.position = Vector2(180, y)
	s.size = Vector2(104, 16)
	s.value_changed.connect(cb)
	parent.add_child(s)
	return s

func _new_game() -> void:
	GameState.new_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _continue() -> void:
	if SaveManager.load_game():
		get_tree().change_scene_to_file("res://scenes/main.tscn")