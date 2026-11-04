extends Node
## Автозагрузка Recipes: база предметов и рецептов из JSON.

signal recipes_changed

const ITEMS_PATH: String = "res://resources/recipes/items.json"
const RECIPES_PATH: String = "res://resources/recipes/recipes.json"

# Порядок и русские названия категорий рецептов.
const CATEGORY_ORDER: Array[String] = ["tools", "food", "raft", "furniture", "defense"]
const CATEGORY_NAMES: Dictionary = {
	"tools": "Инструменты",
	"food": "Еда и вода",
	"raft": "Плот",
	"furniture": "Мебель и станции",
	"defense": "Оборона",
}

var items: Dictionary = {}
var recipes: Array = []

func _ready() -> void:
	_load_items()
	_load_recipes()

func _load_items() -> void:
	var txt: String = _read(ITEMS_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		items = parsed
	else:
		push_error("Не удалось прочитать items.json")

func _load_recipes() -> void:
	var txt: String = _read(RECIPES_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Array:
		recipes = parsed
	else:
		push_error("Не удалось прочитать recipes.json")

func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		push_error("Нет файла: " + path)
		return "{}"
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f != null else "{}"

## Информация о предмете (пустой словарь, если предмет неизвестен).
func get_item(id: String) -> Dictionary:
	return items.get(id, {})

func item_name(id: String) -> String:
	return String(get_item(id).get("name", id))

func item_color(id: String) -> Color:
	var c: Array = get_item(id).get("color", [0.5, 0.5, 0.5])
	return Color(c[0], c[1], c[2])

func get_recipe(id: String) -> Dictionary:
	for r in recipes:
		if r.get("id") == id:
			return r
	return {}

func recipes_in(cat: String) -> Array:
	var out: Array = []
	for r in recipes:
		if r.get("cat") == cat:
			out.append(r)
	return out

## Открыт ли рецепт (исследовательский стол открывает "research" рецепты).
func is_unlocked(recipe: Dictionary) -> bool:
	if not bool(recipe.get("research", false)):
		return true
	return GameState.unlocked_recipes.has(String(recipe.get("id")))

## Разница между требуемым и имеющимся по каждому ресурсу.
func missing(recipe: Dictionary) -> Dictionary:
	var need: Dictionary = recipe.get("need", {})
	var out: Dictionary = {}
	for id in need:
		var have: int = Inventory.count(id)
		var want: int = int(need[id])
		if have < want:
			out[id] = want - have
	return out

func can_craft(recipe: Dictionary) -> bool:
	if not is_unlocked(recipe):
		return false
	if missing(recipe).size() > 0:
		return false
	# Требуется ли станция рядом — проверяется отдельно, здесь только ресурсы.
	return true

## Изготавливает предмет: списывает ресурсы и выдаёт результат.
## Возвращает остаток непоместившегося результата (0 при успехе).
func craft(recipe: Dictionary) -> int:
	if not can_craft(recipe):
		return -1
	var need: Dictionary = recipe.get("need", {})
	for id in need:
		Inventory.remove(id, int(need[id]))
	var out_id: String = String(recipe.get("out"))
	var out_n: int = int(recipe.get("n", 1))
	var leftover: int = Inventory.add(out_id, out_n)
	recipes_changed.emit()
	return leftover