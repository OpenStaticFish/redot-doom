extends SceneTree
## Close-up presentation inspection, in addition to the campaign screenshots.
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
	assert(root.get_texture().get_image().save_png(output.path_join("dead-signal-upgraded-" + name + ".png")) == OK)
	print("Captured " + name)

func run() -> void:
	root.content_scale_size = Vector2i(480, 270)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	game.player.set_physics_process(false)
	game.crosshair = true
	for enemy in game.level.enemies:
		enemy.set_physics_process(false)
	for item in game.level.pickups:
		item.set_process(false)
	game.message_time = 0
	game.elapsed = 20
	game.player.position = game.level.doors[0].position + Vector3(0, 0, 2.5)
	game.player.rotation.y = 0
	await snap("door")
	var locked: RetroDoor = game.level.doors[3]
	game.player.position = locked.position + Vector3(0, 0, 2.5)
	await snap("blue-gate")
	game.player.keys.append("blue")
	locked.update_indicator()
	await snap("authorized-gate")
	game.player.position = game.level.tile_position(Vector2i(14, 18))
	game.set_state("paused")
	await snap("pause")
	game.menu_action("options")
	await snap("options")
	game.set_state("difficulty")
	await snap("difficulty")
	game.set_state("playing")
	for enemy in game.level.enemies:
		enemy.hide()
	var types = ["thrall", "ember", "brute", "warden"]
	for i in range(types.size()):
		game._load_sector(2)
		game.player.set_physics_process(false)
		game.set_state("playing")
		game.message_time = 0
		game.elapsed = 20
		for enemy in game.level.enemies:
			enemy.hide()
			enemy.set_physics_process(false)
		var model = Demon.new()
		game.level.add_child(model)
		model.configure(game, {"kind": types[i], "tile": Vector2i(17, 7)}, -1)
		model.set_physics_process(false)
		game.player.position = model.position + Vector3(0, 0, 7 if types[i] != "warden" else 11)
		game.player.rotation.y = 0
		model.set_pose("walk", 0)
		await snap(types[i])
		model.set_pose("attack", 2)
		await snap(types[i] + "-attack")
		model.restore({"health": 0, "position": model.position, "alerted": true})
		await snap(types[i] + "-corpse")
	game.set_state("victory")
	await snap("victory")
	for voice in game.audio.pool:
		if voice.playing:
			await voice.finished
	game.queue_free()
	await process_frame
	await process_frame
	OS.delay_msec(200)
	quit()
