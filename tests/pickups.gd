extends SceneTree
## Pickup asset, ground-placement, animation and collection regressions.
## redot --headless --path . --script res://tests/pickups.gd -- --test

var game: DeadSignalGame
var checks = 0
var failures: Array[String] = []
var next_id = 1000
const TEST_SAVE = "user://dead_signal_pickup_test.save"

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: " + label)

func reset_inventory() -> void:
	game.player.restore({"health": 40, "armor": 0, "ammo": {"bullets": 0, "shells": 0, "rockets": 0, "cells": 0}, "owned": [0, 1], "keys": [], "weapon": 1})

func specimen(kind: String, id: int = -2) -> RetroPickup:
	if id == -2:
		id = next_id
		next_id += 1
	game.level.add_pickup(kind, game.player.position + Vector3(0, 0, -4), id)
	var item: RetroPickup = game.level.pickups.back()
	item.set_process(false)
	return item

func visible_pixels_equal(a: Image, b: Image) -> bool:
	var actual = a.get_data()
	var expected = b.get_data()
	if actual.size() != expected.size():
		return false
	for i in range(0, actual.size(), 4):
		if actual[i + 3] != expected[i + 3]:
			return false
		if expected[i + 3] > 0 and (actual[i] != expected[i] or actual[i + 1] != expected[i + 1] or actual[i + 2] != expected[i + 2]):
			return false
	return true

func verify_art() -> void:
	check(RetroPickup.ART.size() == RetroPickup.LABELS.size(), "art covers every supported pickup type")
	for kind in RetroPickup.ART:
		var art: Dictionary = RetroPickup.ART[kind]
		var size = Vector2i(art.size[0], art.size[1])
		var atlas = game.texture("pickups/" + kind).get_image()
		atlas.convert(Image.FORMAT_RGBA8)
		check(atlas.get_size() == Vector2i(size.x * art.frames.size(), size.y), kind + " atlas has complete frames")
		for i in range(art.frames.size()):
			var source = Image.new()
			source.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/pickups/" + art.get("source_dir", "freedoom") + "/" + art.frames[i] + ".png"))
			source.convert(Image.FORMAT_RGBA8)
			var crop: Array = art.source_bounds[i]
			var cropped = source.get_region(Rect2i(crop[0], crop[1], crop[2], crop[3]))
			var expected = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
			expected.fill(Color.TRANSPARENT)
			expected.blit_rect_mask(cropped, cropped, Rect2i(Vector2i.ZERO, cropped.get_size()), Vector2i(art.origins[i][0], art.origins[i][1]))
			var actual = atlas.get_region(Rect2i(i * size.x, 0, size.x, size.y))
			check(visible_pixels_equal(actual, expected), kind + " frame " + str(i) + " preserves colors, alpha and proportions")
		var icon = game.texture("sprites/" + kind).get_image()
		check(icon.get_size() == Vector2i(32, 32) and icon.get_used_rect().has_area(), kind + " has a separate, visible HUD thumbnail")

func verify_placement(item: RetroPickup) -> void:
	var initial_y = 0.0
	for clock in [0.0, 0.5, 1.0, 2.7]:
		item.clock = clock
		item.update_presentation()
		var mesh = item.sprite.generate_triangle_mesh()
		var lowest = INF
		for vertex in mesh.get_faces():
			lowest = minf(lowest, (item.sprite.global_transform * vertex).y)
		check(lowest >= item.global_position.y + RetroPickup.GROUND_CLEARANCE - 0.0001, item.kind + " geometry stays above the floor at " + str(clock))
		if clock == 0:
			initial_y = item.sprite.position.y
		elif item.presentation.bob == 0:
			check(is_equal_approx(item.sprite.position.y, initial_y), item.kind + " remains grounded rather than bobbing")
	check(item.ground_shadow.global_transform.basis.z.dot(Vector3.UP) > 0.99, item.kind + " shadow lies on the floor")
	if item.presentation.fps > 0:
		item.clock = 0
		item.update_presentation()
		var first = item.sprite.frame
		item.clock = 1.0 / item.presentation.fps + 0.001
		item.update_presentation()
		check(item.sprite.frame != first, item.kind + " plays its authored animation")
		game.set_state("paused")
		var paused_clock = item.clock
		item._process(0.5)
		check(item.clock == paused_clock, item.kind + " animation freezes when paused")
		game.set_state("playing")

func verify_benefit(kind: String) -> void:
	match kind:
		"medkit": check(game.player.health == 65, "medkit restores 25 health")
		"stim": check(game.player.health == 50, "stim restores 10 health")
		"armor": check(game.player.armor == 100, "armor adds 100 protection")
		"bullets", "shells", "rockets", "cells":
			check(game.player.ammo[kind] == {"bullets": 40, "shells": 12, "rockets": 5, "cells": 60}[kind], kind + " grants correct ammo")
		"bluekey", "redkey": check(game.player.keys.has(kind.trim_suffix("key")), kind + " unlocks its matching door")
		"mega": check(game.player.health == 200, "soul orb overcharges health")
		"suit": check(game.player.suit_time == 30, "hazard suit grants 30 seconds")
		"shotgun", "chaingun", "launcher", "plasma":
			var index = {"shotgun": 2, "chaingun": 3, "launcher": 4, "plasma": 5}[kind]
			check(game.player.owned.has(index) and game.player.weapon == index, kind + " equips its matching weapon")
			check(game.player.ammo[Arsenal.definition(index).ammo] == {"shotgun": 16, "chaingun": 80, "launcher": 8, "plasma": 100}[kind], kind + " includes correct starting ammo")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	game.player.set_physics_process(false)
	for enemy in game.level.enemies:
		enemy.set_physics_process(false)
	for item in game.level.pickups:
		item.set_process(false)
	verify_art()
	for kind in RetroPickup.LABELS:
		reset_inventory()
		var item = specimen(kind)
		verify_placement(item)
		var previous_count = game.items
		check(item.collect(), kind + " is collectible")
		verify_benefit(kind)
		check(not item.active and not item.sprite.is_visible_in_tree() and not item.ground_shadow.is_visible_in_tree(), kind + " collection removes both artwork and shadow")
		check(game.items == previous_count + 1 and not item.collect(), kind + " counts exactly once")
	# Full-capacity supplies remain visible and available for later.
	game.player.health = 100
	game.player.armor = 200
	game.player.ammo = Arsenal.AMMO_MAX.duplicate()
	for kind in ["medkit", "stim", "armor", "bullets", "shells", "rockets", "cells"]:
		var item = specimen(kind)
		check(not item.collect() and item.active and item.ground_shadow.is_visible_in_tree(), kind + " stays available at full capacity")
	reset_inventory()
	var auto_item = specimen("medkit", -1)
	var count = game.items
	game.player.position = auto_item.position
	auto_item._process(0)
	check(game.player.health == 65 and not auto_item.active and game.items == count, "walking over a dropped pickup collects it without inflating map statistics")
	game.player.position = game.level.tile_position(game.level.data.spawn)
	game.set_state("paused")
	check(game.save_game(false, TEST_SAVE), "pickup state saves")
	check(game.load_game(TEST_SAVE), "pickup state reloads")
	var restored = 0
	for item in game.level.pickups:
		if item.pickup_id >= 1000:
			restored += 1
			check(item.sprite.is_visible_in_tree() == item.active and item.ground_shadow.is_visible_in_tree() == item.active, "saved pickup " + str(item.pickup_id) + " restores sprite/shadow visibility together")
	check(restored == 22, "all collected and uncollected test pickups survive save/load")
	# The audio server has an independent clock; let active pickup chimes finish.
	for voice in game.audio.pool:
		if voice.playing:
			await voice.finished
	print("DEAD SIGNAL pickups: %d checks, %d failures" % [checks, failures.size()])
	game.queue_free()
	await process_frame
	await process_frame
	OS.delay_msec(200)
	quit(0 if failures.is_empty() else 1)
