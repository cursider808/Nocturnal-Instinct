class_name Ui
extends RefCounted
## Единая палитра и мелкие хелперы для всего интерфейса.
## Цвета заданы здесь один раз (Theme использует те же значения).

## Базовое разрешение UI (stretch=viewport, поэтому координаты неизменны).
const VIEW := Vector2(480, 270)

## Позиция для центрирования панели заданного размера.
static func center_pos(size: Vector2) -> Vector2:
	return ((VIEW - size) / 2.0).floor()

const BG := Color(0.06, 0.055, 0.05, 0.94)
const BG_SOFT := Color(0.10, 0.09, 0.07, 0.92)
const BORDER := Color(0.34, 0.29, 0.20, 1.0)
const ACCENT := Color(0.87, 0.66, 0.28, 1.0)
const ACCENT_DIM := Color(0.55, 0.42, 0.18, 1.0)
const TEXT := Color(0.86, 0.83, 0.74, 1.0)
const TEXT_DIM := Color(0.52, 0.50, 0.44, 1.0)
const DANGER := Color(0.80, 0.25, 0.20, 1.0)
const GOOD := Color(0.45, 0.72, 0.38, 1.0)
const WARN := Color(0.85, 0.6, 0.2, 1.0)

## Полупрозрачная панель с рамкой.
static func panel_style(bg: Color = BG, border_col: Color = BORDER, bw: int = 1, margin: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border_col
	s.set_border_width_all(bw)
	s.set_corner_radius_all(0)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	return s

## Ровная плитка-панель (для слотов/карточек).
static func cell_style(bg: Color, border_col: Color, bw: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border_col
	s.set_border_width_all(bw)
	s.set_corner_radius_all(0)
	return s

## Простой Label с целым размером шрифта и заданным цветом.
static func label(text: String, size: int = 12, col: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

## Панель-подложка на весь родительский rect.
static func full_panel(parent: Control, bg: Color = BG) -> Panel:
	var p := Panel.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_theme_stylebox_override("panel", panel_style(bg))
	parent.add_child(p)
	return p

## Иконка предмета с подписью (для наград/подсказок).
static func item_row(id: String, count: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.add_child(UiIcons.make_icon_node(id))
	h.add_child(label(("+%d " % count) + Recipes.item_name(id), 12, TEXT))
	return h