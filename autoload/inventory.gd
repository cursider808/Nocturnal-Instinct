extends Node
## Автозагрузка Inventory: инвентарь игрока (24 слота, первые 9 — хотбар).

signal inventory_changed
signal selection_changed(index: int)
signal item_added(id: String, count: int)

const ItemContainerScript := preload("res://scripts/item_container.gd")

const HOTBAR_SIZE: int = 9

var container: ItemContainerScript
var selected: int = 0

func _ready() -> void:
	container = ItemContainerScript.new(HOTBAR_SIZE + 15)
	container.changed.connect(func(): inventory_changed.emit())

## ---- Обёртки над контейнером ----

func add(id: String, n: int = 1) -> int:
	var leftover: int = container.add(id, n)
	var added: int = n - leftover
	if added > 0:
		item_added.emit(id, added)
	return leftover

func remove(id: String, n: int = 1) -> bool:
	return container.remove(id, n)

func has(id: String, n: int = 1) -> bool:
	return container.has(id, n)

func count(id: String) -> int:
	return container.count_amount(id)

func clear() -> void:
	container.clear()

func contents() -> Array:
	return container.contents()

## ---- Хотбар ----

func select(index: int) -> void:
	selected = clampi(index, 0, HOTBAR_SIZE - 1)
	selection_changed.emit(selected)

func selected_id() -> String:
	var s = container.slots[selected] if selected < container.slots.size() else null
	return String(s.get("id")) if s != null else ""

func selected_count() -> int:
	var s = container.slots[selected] if selected < container.slots.size() else null
	return int(s.get("count")) if s != null else 0

## Убирает 1 предмет из выбранного слота (расход при использовании).
func consume_selected(n: int = 1) -> bool:
	var id: String = selected_id()
	if id == "":
		return false
	return container.remove(id, n)

## Убирает 1 предмет из выбранного слота напрямую (по индексу слота).
func consume_slot(index: int, n: int = 1) -> bool:
	var s = container.slots[index] if index < container.slots.size() else null
	if s == null:
		return false
	var left: int = int(s.get("count")) - n
	if left <= 0:
		container.slots[index] = null
	else:
		s["count"] = left
	container.changed.emit()
	return true

## ---- Сохранение ----

func to_dict() -> Dictionary:
	return {"selected": selected, "data": container.to_dict()}

func from_dict(d: Dictionary) -> void:
	selected = int(d.get("selected", 0))
	container.from_dict(d.get("data", {}))