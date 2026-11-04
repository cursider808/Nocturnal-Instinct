class_name UiIcons
extends RefCounted
## Пиксельные иконки 16x16, нарисованные кодом и кэшированные.
## Одно место сопоставления «id предмета -> иконка» — ITEM_KEY.
## Если иконки нет, UI рисует цветную плашку с буквами (make_icon_node).

const WOOD := Color(0.47, 0.33, 0.18)
const WOOD_D := Color(0.30, 0.20, 0.10)
const METAL := Color(0.62, 0.63, 0.66)
const METAL_D := Color(0.40, 0.42, 0.45)
const STONE := Color(0.52, 0.52, 0.54)
const STONE_D := Color(0.36, 0.36, 0.38)
const LEAF := Color(0.28, 0.47, 0.22)
const LEAF_D := Color(0.18, 0.32, 0.15)
const RED := Color(0.72, 0.24, 0.22)
const WATER := Color(0.42, 0.66, 0.82)
const FLESH := Color(0.78, 0.42, 0.32)
const BONE := Color(0.86, 0.83, 0.72)
const GOLD := Color(0.88, 0.68, 0.30)
const PLASTIC := Color(0.68, 0.74, 0.78)
const CLOTH := Color(0.62, 0.55, 0.38)
const COAL := Color(0.16, 0.15, 0.15)
const DARK := Color(0.10, 0.09, 0.08)

# Единое сопоставление: id предмета -> ключ иконки.
const ITEM_KEY := {
	"hook": "hook", "hook_improved": "hook",
	"axe": "axe", "warrior_axe": "axe",
	"pickaxe": "pickaxe", "hammer": "hammer", "shovel": "shovel",
	"spear": "spear", "bow": "bow", "arrow": "bow",
	"fishing_rod": "rod", "torch_item": "torch", "lantern": "torch",
	"shield": "shield", "wood_armor": "shield",
	"wood_log": "wood", "plank": "wood",
	"stone": "stone", "ore": "stone", "glass": "stone",
	"sand": "powder", "clay": "powder", "dirt": "powder", "salt": "powder",
	"scrap": "scrap", "charcoal": "coal",
	"plastic": "plastic",
	"palm_leaf": "leaf", "vine": "leaf", "seaweed": "leaf",
	"fiber": "cloth", "feather": "cloth", "hide": "cloth",
	"rope": "rope", "berry": "berry", "coconut": "berry",
	"sea_water": "water",
	"clean_water": "drink", "coconut_water": "drink", "tea": "drink",
	"raw_fish": "fish", "cooked_fish": "cooked",
	"raw_meat": "meat", "raw_crab": "meat", "raw_bird": "meat",
	"cooked_meat": "cooked", "cooked_crab": "cooked", "jerky": "cooked", "soup": "cooked",
	"foundation": "floor", "floor2": "floor", "roof": "floor",
	"wall": "wall", "window": "wall", "fence": "wall", "door": "door",
	"ladder": "ladder",
	"sail": "sail", "rudder": "sail", "oar": "sail", "anchor": "sail",
	"workbench": "station", "cooker": "station", "purifier": "station",
	"research_table": "station", "table": "station", "shelf": "station",
	"chest": "chest", "bed": "bed", "lamp": "lamp",
	"water_barrel": "water", "garden_plot": "plant",
	"trap": "trap", "spike_wall": "trap", "watchtower": "tower",
}

static var _cache: Dictionary = {}

## Иконка предмета по id (Texture2D) или null.
static func item_icon(id: String) -> Texture2D:
	var key: String = String(ITEM_KEY.get(id, ""))
	if key == "":
		return null
	return icon(key)

## Иконка по ключу (с кэшем).
static func icon(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var img: Image = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_draw(key, img)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	tex.set_meta("ui_icon", true)
	_cache[key] = tex
	return tex

# --- Примитивы рисования ---
static func _r(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and xx < 16 and yy >= 0 and yy < 16:
				img.set_pixel(xx, yy, c)

static func _p(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < 16 and y >= 0 and y < 16:
		img.set_pixel(x, y, c)

static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	while true:
		_p(img, x0, y0, c)
		if x0 == x1 and y0 == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy

static func _draw(key: String, img: Image) -> void:
	match key:
		# --- Статус ---
		"heart":
			_r(img, 2, 4, 5, 3, RED); _r(img, 9, 4, 5, 3, RED)
			_r(img, 2, 6, 12, 3, RED); _r(img, 4, 9, 8, 2, RED); _r(img, 6, 11, 4, 2, RED)
			_r(img, 3, 4, 2, 2, Color(0.95, 0.5, 0.45))
		"hunger":
			_r(img, 3, 3, 8, 8, FLESH); _r(img, 4, 4, 4, 3, Color(0.9, 0.55, 0.4))
			_r(img, 10, 9, 3, 3, BONE); _r(img, 12, 11, 2, 3, BONE)
		"thirst":
			_r(img, 7, 2, 2, 2, WATER); _r(img, 6, 4, 4, 3, WATER)
			_r(img, 5, 7, 6, 4, WATER); _r(img, 6, 11, 4, 2, WATER); _p(img, 6, 6, Color(0.8, 0.9, 1.0))
		"stamina":
			_r(img, 8, 2, 4, 5, GOLD); _r(img, 5, 6, 6, 2, GOLD)
			_r(img, 6, 8, 4, 5, GOLD); _r(img, 5, 11, 5, 2, GOLD)
		"oxygen":
			_r(img, 4, 4, 8, 8, WATER); _r(img, 6, 6, 4, 4, Color(0, 0, 0, 0))
			_p(img, 6, 6, Color(0.85, 0.95, 1.0))
		"sun":
			_r(img, 5, 5, 6, 6, GOLD)
			_p(img, 7, 1, GOLD); _p(img, 7, 14, GOLD); _p(img, 1, 7, GOLD); _p(img, 14, 7, GOLD)
			_r(img, 7, 7, 2, 2, Color(1, 0.9, 0.6))
		"moon":
			_r(img, 4, 3, 9, 10, BONE); _r(img, 8, 3, 6, 10, Color(0, 0, 0, 0))
		"dawn":
			_r(img, 4, 6, 8, 6, Color(0.95, 0.6, 0.35)); _r(img, 2, 12, 12, 2, Color(0.3, 0.25, 0.2))
			_p(img, 7, 2, Color(0.95, 0.75, 0.4))
		"dusk":
			_r(img, 4, 6, 8, 6, Color(0.6, 0.35, 0.5)); _r(img, 2, 12, 12, 2, Color(0.25, 0.2, 0.25))
			_p(img, 7, 2, Color(0.8, 0.6, 0.7))
		"skull":
			_r(img, 4, 3, 8, 7, BONE); _r(img, 5, 2, 6, 2, BONE)
			_r(img, 5, 5, 2, 2, DARK); _r(img, 9, 5, 2, 2, DARK)
			_r(img, 6, 10, 4, 3, BONE); _r(img, 5, 10, 1, 2, BONE); _r(img, 10, 10, 1, 2, BONE)
		"hand":
			_p(img, 7, 2, BONE); _r(img, 7, 3, 2, 9, BONE)
			_r(img, 5, 6, 2, 3, BONE); _r(img, 4, 7, 1, 2, BONE); _r(img, 9, 6, 2, 3, BONE)
			_r(img, 6, 9, 2, 3, BONE)
		"lock":
			_r(img, 4, 7, 8, 7, METAL_D); _r(img, 3, 6, 10, 2, METAL)
			_r(img, 6, 3, 4, 4, Color(0, 0, 0, 0)); _r(img, 5, 3, 6, 2, METAL)
			_r(img, 7, 9, 2, 3, DARK)
		# --- Инструменты ---
		"axe":
			_line(img, 6, 4, 5, 13, WOOD); _r(img, 8, 3, 5, 4, METAL)
			_r(img, 11, 3, 2, 5, METAL_D); _r(img, 5, 13, 2, 2, WOOD_D)
		"pickaxe":
			_line(img, 8, 4, 8, 13, WOOD); _r(img, 4, 3, 8, 2, METAL)
			_p(img, 3, 4, METAL); _p(img, 12, 4, METAL); _r(img, 7, 13, 2, 2, WOOD_D)
		"hammer":
			_line(img, 7, 4, 7, 13, WOOD); _r(img, 4, 2, 7, 4, METAL); _r(img, 4, 5, 7, 1, METAL_D)
		"shovel":
			_line(img, 8, 2, 8, 10, WOOD); _r(img, 5, 10, 6, 4, METAL); _r(img, 6, 14, 4, 1, METAL_D)
		"spear":
			_line(img, 7, 3, 7, 14, WOOD); _r(img, 6, 1, 4, 3, METAL); _p(img, 7, 0, METAL)
		"bow":
			_line(img, 5, 2, 3, 7, WOOD); _line(img, 3, 7, 5, 13, WOOD)
			_line(img, 5, 2, 5, 13, BONE); _line(img, 5, 7, 12, 7, WOOD)
		"rod":
			_line(img, 3, 12, 11, 3, WOOD); _line(img, 11, 3, 12, 7, BONE)
			_r(img, 11, 7, 2, 2, METAL)
		"torch":
			_line(img, 7, 7, 7, 14, WOOD_D); _r(img, 5, 3, 6, 4, Color(0.95, 0.5, 0.15))
			_r(img, 6, 2, 4, 3, GOLD); _p(img, 7, 1, Color(1, 0.95, 0.6))
		"hook":
			_line(img, 8, 2, 8, 6, BONE); _line(img, 8, 6, 6, 11, BONE)
			_line(img, 6, 11, 5, 10, BONE); _line(img, 8, 6, 11, 9, BONE); _line(img, 11, 9, 10, 10, BONE)
		"shield":
			_r(img, 3, 2, 10, 9, WOOD); _r(img, 3, 2, 10, 2, WOOD_D); _r(img, 5, 11, 6, 3, WOOD)
			_r(img, 7, 5, 3, 3, METAL)
		# --- Материалы ---
		"wood":
			_r(img, 2, 5, 12, 6, WOOD); _r(img, 2, 5, 12, 1, Color(0.6, 0.44, 0.25))
			_r(img, 2, 10, 12, 1, WOOD_D); _p(img, 4, 7, WOOD_D); _p(img, 11, 8, WOOD_D)
		"stone":
			_r(img, 3, 6, 10, 7, STONE); _r(img, 5, 4, 6, 2, STONE)
			_r(img, 5, 7, 3, 2, STONE_D); _r(img, 9, 8, 2, 2, STONE_D)
		"scrap":
			_r(img, 3, 4, 5, 8, METAL); _r(img, 9, 7, 4, 5, METAL_D)
			_r(img, 4, 5, 3, 1, Color(0.8, 0.8, 0.85)); _p(img, 11, 5, METAL)
		"coal":
			_r(img, 4, 5, 8, 7, COAL); _r(img, 6, 3, 4, 2, COAL)
			_p(img, 6, 7, Color(0.3, 0.3, 0.32)); _p(img, 9, 9, Color(0.3, 0.3, 0.32))
		"plastic":
			_r(img, 6, 2, 4, 2, PLASTIC); _r(img, 5, 4, 6, 10, PLASTIC)
			_r(img, 6, 5, 1, 8, Color(0.85, 0.9, 0.95)); _r(img, 5, 13, 6, 1, Color(0.5, 0.55, 0.6))
		"leaf":
			_r(img, 4, 4, 8, 8, LEAF); _r(img, 6, 3, 4, 2, LEAF)
			_line(img, 8, 3, 8, 13, LEAF_D); _r(img, 5, 11, 3, 3, LEAF_D)
		"cloth":
			_r(img, 4, 4, 8, 8, CLOTH); _r(img, 4, 4, 8, 1, Color(0.75, 0.68, 0.5))
			_r(img, 4, 11, 8, 1, Color(0.45, 0.4, 0.28)); _line(img, 6, 5, 6, 10, Color(0.45, 0.4, 0.28))
			_line(img, 10, 5, 10, 10, Color(0.45, 0.4, 0.28))
		"rope":
			_r(img, 3, 5, 10, 2, CLOTH); _r(img, 3, 9, 10, 2, CLOTH)
			_r(img, 5, 7, 6, 2, Color(0.45, 0.4, 0.28)); _r(img, 4, 4, 2, 1, Color(0.75, 0.68, 0.5))
		"powder":
			_r(img, 4, 9, 8, 4, STONE); _r(img, 5, 7, 6, 2, STONE)
			_p(img, 6, 6, Color(0.8, 0.78, 0.7)); _p(img, 9, 6, Color(0.8, 0.78, 0.7))
		"berry":
			_r(img, 3, 5, 5, 5, RED); _r(img, 8, 4, 5, 5, Color(0.6, 0.15, 0.2))
			_r(img, 8, 9, 4, 4, Color(0.65, 0.2, 0.25)); _p(img, 4, 6, Color(0.95, 0.5, 0.5))
		"water":
			_r(img, 6, 2, 4, 3, WATER); _r(img, 5, 5, 6, 9, WATER)
			_r(img, 6, 3, 1, 8, Color(0.8, 0.9, 1.0)); _r(img, 5, 13, 6, 1, Color(0.3, 0.5, 0.65))
		"plant":
			_line(img, 8, 4, 8, 13, LEAF_D); _r(img, 5, 5, 3, 3, LEAF); _r(img, 9, 7, 3, 3, LEAF)
			_r(img, 6, 9, 3, 3, Color(0.35, 0.55, 0.25))
		# --- Еда ---
		"fish":
			_r(img, 3, 6, 8, 5, Color(0.5, 0.6, 0.66)); _r(img, 2, 7, 1, 3, Color(0.4, 0.5, 0.56))
			_r(img, 11, 5, 3, 3, Color(0.42, 0.52, 0.58)); _r(img, 11, 9, 3, 3, Color(0.42, 0.52, 0.58))
			_p(img, 4, 7, DARK)
		"meat":
			_r(img, 3, 4, 9, 8, FLESH); _r(img, 4, 5, 4, 3, Color(0.9, 0.55, 0.45))
			_r(img, 11, 6, 4, 3, BONE); _r(img, 13, 9, 2, 3, BONE)
		"cooked":
			_r(img, 2, 5, 12, 8, Color(0.55, 0.5, 0.45)); _r(img, 3, 6, 10, 6, Color(0.7, 0.45, 0.22))
			_r(img, 5, 7, 4, 3, Color(0.85, 0.6, 0.3)); _r(img, 2, 13, 12, 1, Color(0.4, 0.36, 0.32))
		"drink":
			_r(img, 6, 2, 4, 2, METAL); _r(img, 5, 4, 6, 10, WATER)
			_r(img, 6, 5, 1, 8, Color(0.85, 0.95, 1.0)); _r(img, 5, 13, 6, 1, Color(0.3, 0.5, 0.65))
		# --- Постройки ---
		"wall":
			_r(img, 2, 3, 12, 11, WOOD); _r(img, 2, 3, 12, 1, WOOD_D); _r(img, 2, 13, 12, 1, WOOD_D)
			_r(img, 2, 8, 12, 1, WOOD_D); _line(img, 8, 3, 8, 8, WOOD_D); _line(img, 5, 8, 5, 13, WOOD_D)
			_line(img, 12, 8, 12, 13, WOOD_D)
		"floor":
			_r(img, 1, 5, 14, 7, WOOD); _r(img, 1, 5, 14, 1, Color(0.6, 0.44, 0.25))
			_line(img, 1, 8, 14, 8, WOOD_D); _line(img, 1, 11, 14, 11, WOOD_D)
		"door":
			_r(img, 4, 2, 8, 13, WOOD_D); _r(img, 5, 3, 6, 11, WOOD)
			_r(img, 5, 7, 6, 1, WOOD_D); _p(img, 9, 9, GOLD)
		"ladder":
			_line(img, 5, 1, 5, 15, WOOD); _line(img, 11, 1, 11, 15, WOOD)
			for yy in [4, 8, 12]:
				_line(img, 5, yy, 11, yy, WOOD_D)
		"sail":
			_r(img, 2, 2, 2, 13, WOOD_D); _r(img, 4, 3, 9, 9, BONE)
			_r(img, 4, 3, 9, 1, Color(0.7, 0.67, 0.58)); _r(img, 12, 3, 1, 9, Color(0.7, 0.67, 0.58))
		"station":
			_r(img, 1, 4, 14, 4, WOOD); _r(img, 2, 8, 2, 6, WOOD_D); _r(img, 12, 8, 2, 6, WOOD_D)
			_r(img, 4, 2, 5, 2, METAL); _r(img, 9, 1, 2, 3, WOOD_D)
		"chest":
			_r(img, 2, 6, 12, 8, WOOD_D); _r(img, 2, 4, 12, 3, WOOD)
			_r(img, 2, 7, 12, 1, WOOD_D); _r(img, 7, 8, 2, 3, GOLD); _r(img, 6, 8, 4, 1, GOLD)
		"bed":
			_r(img, 2, 6, 12, 7, WOOD_D); _r(img, 3, 4, 10, 3, Color(0.8, 0.78, 0.7))
			_r(img, 3, 7, 10, 4, Color(0.5, 0.4, 0.35)); _r(img, 2, 4, 1, 9, WOOD)
		"lamp":
			_line(img, 8, 8, 8, 14, METAL_D); _r(img, 4, 3, 8, 5, Color(0.95, 0.85, 0.5))
			_r(img, 6, 2, 4, 1, METAL_D); _r(img, 5, 8, 6, 1, METAL_D)
		"trap":
			_r(img, 2, 11, 12, 3, WOOD_D)
			for xx in [3, 6, 9, 12]:
				_line(img, xx, 11, xx, 6, METAL)
			_p(img, 3, 6, METAL); _p(img, 6, 6, METAL); _p(img, 9, 6, METAL); _p(img, 12, 6, METAL)
		"tower":
			_r(img, 5, 3, 6, 12, WOOD); _r(img, 4, 2, 8, 2, WOOD_D)
			_r(img, 6, 5, 4, 2, DARK); _r(img, 6, 9, 4, 3, DARK)
			_r(img, 4, 14, 8, 1, WOOD_D)
		_:
			_r(img, 3, 3, 10, 10, STONE); _r(img, 4, 4, 8, 8, STONE_D)

## Узел-иконка для UI: TextureRect (если иконка есть) либо цветная плашка с буквами.
static func make_icon_node(id: String) -> Control:
	var tex: Texture2D = item_icon(id)
	if tex != null:
		var node := TextureRect.new()
		node.texture = tex
		node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		node.custom_minimum_size = Vector2(20, 20)
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return node
	# Плашка с первыми буквами и цветом предмета.
	var plate := Panel.new()
	plate.custom_minimum_size = Vector2(20, 20)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := Recipes.item_color(id)
	plate.add_theme_stylebox_override("panel", _plate_style(col))
	var lbl := Label.new()
	lbl.text = _initials(Recipes.item_name(id))
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(lbl)
	return plate

static func _plate_style(col: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, 0.95)
	s.border_color = col
	s.set_border_width_all(1)
	s.set_corner_radius_all(0)
	return s

static func _initials(name: String) -> String:
	var parts := name.split(" ", false)
	if parts.is_empty():
		return "?"
	if parts.size() == 1:
		return name.substr(0, 2).to_upper()
	return (parts[0].substr(0, 1) + parts[1].substr(0, 1)).to_upper()