extends SceneTree
## Enemy-direction, animation, source-art, door-indicator and menu-layout checks.
## redot --headless --path . --script res://tests/presentation.gd -- --test

var game: DeadSignalGame
var checks = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: " + label)

func pixels_equal(a: Image, b: Image) -> bool:
	var actual = a.get_data()
	var expected = b.get_data()
	if actual.size() != expected.size(): return false
	for i in range(0, actual.size(), 4):
		if actual[i + 3] != expected[i + 3]: return false
		if expected[i + 3] > 0 and (actual[i] != expected[i] or actual[i + 1] != expected[i + 1] or actual[i + 2] != expected[i + 2]):
			return false
	return true

func verify_sheet(name: String, art: Dictionary) -> void:
	var atlas = game.texture("presentation/" + name).get_image()
	atlas.convert(Image.FORMAT_RGBA8)
	var size = Vector2i(art.size[0], art.size[1])
	check(atlas.get_size() == Vector2i(size.x * art.columns, size.y * art.rows), name + " atlas dimensions")
	for i in range(art.files.size()):
		var source = Image.new()
		source.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/presentation/freedoom/" + art.files[i]))
		source.convert(Image.FORMAT_RGBA8)
		var crop: Array = art.source_bounds[i]
		var body = source.get_region(Rect2i(crop[0], crop[1], crop[2], crop[3]))
		var expected = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		expected.fill(Color.TRANSPARENT)
		expected.blit_rect_mask(body, body, Rect2i(Vector2i.ZERO, body.get_size()), Vector2i(art.origins[i][0], art.origins[i][1]))
		var actual = atlas.get_region(Rect2i((i % art.columns) * size.x, (i / art.columns) * size.y, size.x, size.y))
		check(pixels_equal(actual, expected), name + " authored frame " + str(i) + " colors/alpha/pivot")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	game.player.set_physics_process(false)
	for enemy in game.level.enemies:
		enemy.set_physics_process(false)
	for item in game.level.pickups:
		item.set_process(false)
	for name in DeadSignalGame.WORLD_ART.actors:
		verify_sheet(name, DeadSignalGame.WORLD_ART.actors[name])
	for name in DeadSignalGame.WORLD_ART.sheets:
		verify_sheet(name, DeadSignalGame.WORLD_ART.sheets[name])
	verify_sheet("portraits", DeadSignalGame.WORLD_ART.portraits)
	var player_position = game.player.position
	for kind in Demon.ART:
		var enemy = Demon.new()
		game.level.add_child(enemy)
		enemy.configure(game, {"kind": kind, "tile": Vector2i(14, 16)}, -1)
		enemy.set_physics_process(false)
		enemy.facing_yaw = 0
		var seen: Dictionary = {}
		for direction in range(8):
			var angle = direction * PI / 4.0
			game.player.position = enemy.position + Vector3(sin(angle) * 8, 0, cos(angle) * 8)
			enemy.set_pose("walk", 0)
			seen[str(enemy.sprite.frame) + ":" + str(enemy.sprite.flip_h)] = true
			check(enemy.sprite.frame >= 0 and enemy.sprite.frame < enemy.artwork.files.size(), kind + " direction " + str(direction) + " valid frame")
		check(seen.size() == 8, kind + " has eight distinct viewing directions")
		var walk_frames: Dictionary = {}
		game.player.position = enemy.position + Vector3(0, 0, 8)
		for step in range(4):
			enemy.set_pose("walk", step)
			walk_frames[enemy.sprite.frame] = true
		check(walk_frames.size() == 4, kind + " uses four authored walk poses")
		enemy.set_pose("attack", 2)
		var attack_frame = enemy.sprite.frame
		enemy.set_pose("pain", 0)
		check(enemy.sprite.frame != attack_frame, kind + " has distinct attack/hurt poses")
		enemy.restore({"health": 0, "position": enemy.position, "alerted": true, "facing": 0.7})
		check(enemy.dead and enemy.visual_state == "death" and enemy.visual_step == enemy.artwork.poses.death.size() - 1, kind + " restores its final corpse pose")
		check(is_equal_approx(enemy.snapshot().facing, 0.7), kind + " preserves facing in saved state")
		enemy.queue_free()
	game.player.position = player_position
	var locked: RetroDoor = game.level.doors[3]
	game.player.keys.clear()
	locked.update_indicator()
	check(locked.access_color.b > locked.access_color.g, "blue-key reader is blue when locked")
	game.player.keys.append("blue")
	locked.update_indicator()
	check(locked.access_color.g > locked.access_color.b, "key reader becomes green when authorized")
	var secret: RetroDoor = game.level.doors[4]
	check(secret.secret and secret.indicator_material == null and secret.get_child_count() == 1, "secret walls have no exposed reader/frame hardware")
	for state in ["menu", "difficulty", "paused", "help", "options", "dead", "intermission", "victory"]:
		game.set_state(state)
		var rects = game.hud.menu_rects()
		var options = game.hud.menu_items()
		check(rects.size() == options.size(), state + " menu hit targets match its buttons")
		for i in range(rects.size()):
			check(Rect2(0, 0, 480, 270).encloses(rects[i]), state + " button " + str(i) + " inside viewport")
			check(PixelFont.width(options[i][0], 2) <= rects[i].size.x, state + " button " + str(i) + " large text fits")
	game.set_state("playing")
	var effect_count = game.effects.size()
	game.spawn_effect(game.player.position + Vector3.UP, "explosion", 0.5, 2)
	check(game.effects.size() == effect_count + 1 and game.effects.back().frames == 5, "explosions use their five authored stages")
	var effect: Dictionary = game.effects.back()
	game._process(0.3)
	check(effect.node.frame > 0, "effect sprites advance with time")
	for voice in game.audio.pool:
		if voice.playing:
			await voice.finished
	print("DEAD SIGNAL presentation: %d checks, %d failures" % [checks, failures.size()])
	game.queue_free()
	await process_frame
	await process_frame
	OS.delay_msec(200)
	quit(0 if failures.is_empty() else 1)
