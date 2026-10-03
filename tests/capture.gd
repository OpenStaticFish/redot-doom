extends SceneTree
## Rendered inspection: redot --path . --script res://tests/capture.gd -- --test
## Optional output prefix: --capture-dir=/tmp/opencode
var game: DeadSignalGame
var output = "/tmp/opencode"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			output = arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func snap(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	var error = image.save_png(output.path_join("dead-signal-" + name + ".png"))
	assert(error == OK, "Screenshot save failed")
	print("Captured " + name)

func freeze_enemies() -> void:
	for enemy in game.level.enemies:
		enemy.set_physics_process(false)

func run() -> void:
	root.content_scale_size = Vector2i(480, 270)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await snap("title")
	game.new_game()
	freeze_enemies()
	await snap("entry")
	game.player.position = game.level.tile_position(Vector2i(14, 18))
	game.player.owned = [0, 1, 2, 3, 4, 5]
	game.player.weapon = 2
	game.player.ammo.shells = 48
	game.player.armor = 100
	game.player.keys = ["blue"]
	game.message_time = 0
	game.elapsed = 20
	await snap("foundry")
	game.automap = true
	for y in range(game.level.data.size.y):
		for x in range(game.level.data.size.x):
			game.level.explored[Vector2i(x, y)] = true
	await snap("map")
	game.automap = false
	game.menu_action("help")
	await snap("manual")
	game._load_sector(1)
	freeze_enemies()
	game.set_state("playing")
	game.player.position = game.level.tile_position(Vector2i(17, 22))
	game.player.weapon = 3
	game.player.ammo.bullets = 240
	game.elapsed = 20
	await snap("cathedral")
	game._load_sector(2)
	freeze_enemies()
	game.set_state("playing")
	game.player.position = game.level.tile_position(Vector2i(17, 11))
	game.player.weapon = 5
	game.player.ammo.cells = 200
	game.elapsed = 20
	for enemy in game.level.enemies:
		if enemy.kind == "warden": enemy.alerted = true
	await snap("heart")
	game.complete_sector()
	game.set_state("intermission")
	await snap("intermission")
	game.queue_free()
	await process_frame
	await process_frame
	# Audio mixing has its own clock, independent of these rapid capture frames.
	OS.delay_msec(80)
	quit()
