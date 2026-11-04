class_name ItemContainer
extends RefCounted
## Универсальный контейнер предметов (инвентарь игрока, сундуки, бочки).

signal changed

var slots: Array = []

func _init(size: int = 24) -> void:
	resize(size)

func resize(size: int) -> void:
	slots.resize(size)

## Максимальный размер стопки для предмета.
func _max_stack(id: String) -> int:
	var info: Dictionary = Recipes.get_item(id)
	return int(info.get("stack", 50))

## Добавляет предмет, возвращает остаток, который не поместился.
func add(id: String, count: int) -> int:
	if count <= 0:
		return 0
	var leftover: int = count
	var max_stack: int = _max_stack(id)
	for i in slots.size():
		if leftover <= 0:
			break
		var s = slots[i]
		if s != null and s.get("id") == id and int(s.get("count")) < max_stack:
			var space: int = max_stack - int(s.get("count"))
			var put: int = mini(space, leftover)
			s["count"] = int(s.get("count")) + put
			leftover -= put
	for i in slots.size():
		if leftover <= 0:
			break
		if slots[i] == null:
			var put: int = mini(max_stack, leftover)
			slots[i] = {"id": id, "count": put}
			leftover -= put
	if leftover != count:
		changed.emit()
	return leftover

## Убирает предмет, если его достаточно.
func remove(id: String, count: int) -> bool:
	if count_amount(id) < count:
		return false
	var left: int = count
	for i in slots.size():
		if left <= 0:
			break
		var s = slots[i]
		if s != null and s.get("id") == id:
			var take: int = mini(int(s.get("count")), left)
			s["count"] = int(s.get("count")) - take
			left -= take
			if int(s.get("count")) <= 0:
				slots[i] = null
	changed.emit()
	return true

## Сколько предметов данного типа в контейнере.
func count_amount(id: String) -> int:
	var total: int = 0
	for s in slots:
		if s != null and s.get("id") == id:
			total += int(s.get("count"))
	return total

func has(id: String, count: int = 1) -> bool:
	return count_amount(id) >= count

## Полностью очищает контейнер.
func clear() -> void:
	for i in slots.size():
		slots[i] = null
	changed.emit()

## Список предметов в виде [{"id":..., "count":...}] без пустых слотов.
func contents() -> Array:
	var out: Array = []
	for s in slots:
		if s != null:
			out.append({"id": s.get("id"), "count": int(s.get("count"))})
	return out

func to_dict() -> Dictionary:
	return {"size": slots.size(), "slots": slots.duplicate(true)}

func from_dict(data: Dictionary) -> void:
	resize(int(data.get("size", 24)))
	var saved: Array = data.get("slots", [])
	for i in slots.size():
		slots[i] = saved[i] if i < saved.size() else null
	changed.emit()