class_name Campaign
extends RefCounted
## Hand-authored room layouts. Every coordinate is a map tile, not a world unit.

static func build(index: int) -> Dictionary:
	var d = {"grid": [], "enemies": [], "pickups": [], "props": [], "doors": [], "lamps": [], "index": index}
	var size = [Vector2i(29, 27), Vector2i(35, 31), Vector2i(35, 33)][index]
	d["size"] = size
	for y in range(size.y):
		var row: Array = []
		row.resize(size.x)
		row.fill("#")
		d.grid.append(row)
	match index:
		0: _facility(d)
		1: _cathedral(d)
		2: _heart(d)
	return d

static func room(d: Dictionary, x: int, y: int, w: int, h: int, floor_type: String = ".") -> void:
	for py in range(y, y + h):
		for px in range(x, x + w):
			d.grid[py][px] = floor_type

static func door(d: Dictionary, x: int, y: int, key: String = "", secret: bool = false) -> void:
	d.grid[y][x] = "D"
	d.doors.append({"tile": Vector2i(x, y), "key": key, "secret": secret})

static func enemy(d: Dictionary, kind: String, x: int, y: int) -> void:
	d.enemies.append({"kind": kind, "tile": Vector2i(x, y)})

static func item(d: Dictionary, kind: String, x: int, y: int) -> void:
	d.pickups.append({"kind": kind, "tile": Vector2i(x, y)})

static func prop(d: Dictionary, kind: String, x: int, y: int) -> void:
	d.props.append({"kind": kind, "tile": Vector2i(x, y)})
	if kind in ["lamp", "torch"]:
		d.lamps.append(Vector2i(x, y))

static func _facility(d: Dictionary) -> void:
	d.merge({"name": "THE SILENT FOUNDRY", "subtitle": "FACILITY 09 / SURFACE ACCESS", "spawn": Vector2i(14, 24), "exit": Vector2i(14, 2), "height": 3.5, "wall": "metal", "ceiling": true, "par": 180}, true)
	room(d, 11, 20, 7, 6)
	room(d, 8, 11, 13, 8)
	door(d, 14, 19)
	room(d, 1, 10, 6, 8, "g")
	door(d, 7, 14)
	room(d, 22, 11, 6, 8)
	door(d, 21, 15)
	room(d, 9, 2, 11, 8, "g")
	door(d, 14, 10, "blue")
	room(d, 1, 19, 6, 4)
	door(d, 3, 18, "", true)
	for p in [Vector2i(11, 14), Vector2i(17, 14), Vector2i(12, 5), Vector2i(16, 5)]:
		d.grid[p.y][p.x] = "C"
	room(d, 10, 7, 3, 2, "a")
	room(d, 17, 7, 2, 2, "a")
	for p in [Vector2i(11, 22), Vector2i(17, 22), Vector2i(8, 11), Vector2i(20, 11), Vector2i(2, 10), Vector2i(27, 11), Vector2i(9, 2), Vector2i(19, 2)]:
		prop(d, "lamp", p.x, p.y)
	for p in [Vector2i(10, 16), Vector2i(19, 13), Vector2i(25, 16), Vector2i(5, 15)]:
		prop(d, "barrel", p.x, p.y)
	prop(d, "gore", 15, 22)
	enemy(d, "thrall", 12, 16)
	enemy(d, "thrall", 17, 12)
	enemy(d, "thrall", 19, 16)
	enemy(d, "ember", 3, 11)
	enemy(d, "thrall", 5, 16)
	enemy(d, "thrall", 25, 12)
	enemy(d, "ember", 26, 17)
	enemy(d, "ember", 11, 3)
	enemy(d, "ember", 18, 3)
	enemy(d, "brute", 14, 6)
	item(d, "bluekey", 2, 12)
	item(d, "shotgun", 24, 14)
	item(d, "shells", 26, 14)
	item(d, "bullets", 12, 23)
	item(d, "medkit", 16, 23)
	item(d, "armor", 4, 20)
	item(d, "mega", 2, 21)
	item(d, "shells", 5, 12)
	item(d, "medkit", 19, 17)
	item(d, "bullets", 10, 12)
	item(d, "medkit", 10, 4)
	item(d, "suit", 18, 9)

static func _cathedral(d: Dictionary) -> void:
	d.merge({"name": "WASTE CATHEDRAL", "subtitle": "SUBLEVEL 02 / CONTAINMENT FAILURE", "spawn": Vector2i(17, 28), "exit": Vector2i(18, 2), "height": 4.5, "wall": "brick", "ceiling": true, "par": 300}, true)
	room(d, 14, 24, 7, 6)
	room(d, 10, 14, 15, 9, "g")
	door(d, 17, 23)
	room(d, 1, 14, 8, 9)
	door(d, 9, 18)
	room(d, 26, 14, 8, 9)
	door(d, 25, 18, "blue")
	room(d, 1, 3, 9, 10, "r")
	door(d, 5, 13)
	room(d, 25, 3, 9, 10, "r")
	door(d, 29, 13)
	room(d, 12, 2, 12, 11, "g")
	door(d, 17, 13, "red")
	room(d, 27, 24, 6, 5)
	door(d, 29, 23, "", true)
	room(d, 15, 16, 5, 5, "a")
	room(d, 3, 7, 3, 3, "l")
	for p in [Vector2i(12, 17), Vector2i(22, 17), Vector2i(14, 6), Vector2i(21, 6), Vector2i(6, 5), Vector2i(29, 9)]:
		d.grid[p.y][p.x] = "R"
	for p in [Vector2i(14, 25), Vector2i(20, 25), Vector2i(10, 14), Vector2i(24, 14), Vector2i(1, 3), Vector2i(9, 3), Vector2i(25, 3), Vector2i(33, 3), Vector2i(12, 2), Vector2i(23, 2)]:
		prop(d, "torch", p.x, p.y)
	for p in [Vector2i(7, 17), Vector2i(27, 19), Vector2i(31, 12), Vector2i(20, 10)]:
		prop(d, "barrel", p.x, p.y)
	for p in [Vector2i(12, 20), Vector2i(23, 20), Vector2i(4, 17), Vector2i(7, 21), Vector2i(3, 4), Vector2i(8, 10), Vector2i(27, 16), Vector2i(32, 21), Vector2i(27, 6), Vector2i(32, 11), Vector2i(15, 10), Vector2i(21, 10)]:
		enemy(d, "ember" if p.x % 2 else "thrall", p.x, p.y)
	enemy(d, "brute", 8, 4)
	enemy(d, "brute", 31, 4)
	enemy(d, "brute", 18, 6)
	item(d, "bluekey", 2, 5)
	item(d, "redkey", 32, 5)
	item(d, "chaingun", 3, 20)
	item(d, "launcher", 31, 16)
	item(d, "shotgun", 16, 27)
	item(d, "bullets", 6, 20)
	item(d, "bullets", 8, 6)
	item(d, "bullets", 22, 15)
	item(d, "shells", 19, 27)
	item(d, "shells", 2, 11)
	item(d, "shells", 27, 11)
	item(d, "rockets", 31, 20)
	item(d, "rockets", 26, 5)
	item(d, "armor", 31, 26)
	item(d, "mega", 28, 27)
	item(d, "medkit", 15, 27)
	item(d, "medkit", 11, 21)
	item(d, "medkit", 7, 11)
	item(d, "medkit", 33, 10)
	item(d, "medkit", 13, 3)
	item(d, "suit", 23, 22)

static func _heart(d: Dictionary) -> void:
	d.merge({"name": "THE BLACK HEART", "subtitle": "CORE DEPTH / SIGNAL SOURCE", "spawn": Vector2i(17, 30), "exit": Vector2i(17, 2), "height": 5.0, "wall": "rust", "ceiling": false, "par": 240}, true)
	room(d, 14, 26, 7, 6, "r")
	room(d, 9, 18, 17, 7, "g")
	door(d, 17, 25)
	room(d, 1, 18, 7, 7, "r")
	door(d, 8, 21)
	room(d, 27, 18, 7, 7, "r")
	door(d, 26, 21)
	room(d, 7, 2, 21, 15, "r")
	door(d, 17, 17, "red")
	room(d, 29, 10, 5, 6)
	door(d, 28, 13, "", true)
	room(d, 9, 5, 4, 7, "l")
	room(d, 22, 5, 4, 7, "l")
	for p in [Vector2i(14, 6), Vector2i(20, 6), Vector2i(14, 12), Vector2i(20, 12), Vector2i(12, 20), Vector2i(22, 20)]:
		d.grid[p.y][p.x] = "R"
	for p in [Vector2i(14, 27), Vector2i(20, 27), Vector2i(9, 18), Vector2i(25, 18), Vector2i(1, 18), Vector2i(33, 18), Vector2i(7, 2), Vector2i(27, 2), Vector2i(7, 16), Vector2i(27, 16)]:
		prop(d, "torch", p.x, p.y)
	for p in [Vector2i(10, 22), Vector2i(24, 22), Vector2i(4, 20), Vector2i(30, 22)]:
		prop(d, "barrel", p.x, p.y)
	enemy(d, "warden", 17, 7)
	for p in [Vector2i(11, 23), Vector2i(23, 23), Vector2i(3, 19), Vector2i(6, 23), Vector2i(29, 19), Vector2i(32, 23), Vector2i(8, 4), Vector2i(26, 4), Vector2i(8, 14), Vector2i(26, 14)]:
		enemy(d, "brute" if p.x % 3 == 0 else "ember", p.x, p.y)
	item(d, "redkey", 3, 23)
	item(d, "plasma", 30, 20)
	item(d, "cells", 32, 20)
	item(d, "cells", 16, 14)
	item(d, "cells", 18, 5)
	item(d, "cells", 31, 13)
	item(d, "mega", 32, 14)
	item(d, "armor", 18, 29)
	item(d, "launcher", 15, 29)
	item(d, "rockets", 19, 29)
	item(d, "rockets", 11, 19)
	item(d, "rockets", 24, 19)
	item(d, "shells", 2, 20)
	item(d, "medkit", 5, 22)
	item(d, "medkit", 28, 24)
	item(d, "medkit", 15, 3)
	item(d, "medkit", 19, 3)
	item(d, "suit", 10, 24)
	item(d, "chaingun", 17, 28)
	item(d, "bullets", 20, 28)
