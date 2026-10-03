extends SceneTree
## A deterministic in-world pickup showcase for visual inspection.
## redot --path . --script res://tests/capture_pickups.gd -- --test --label=after

const KINDS = ["medkit", "stim", "armor", "bullets", "shells", "rockets", "cells", "bluekey", "redkey", "mega", "suit", "shotgun", "chaingun", "launcher", "plasma"]
const NAMES = ["MEDKIT", "STIM", "ARMOR", "BULLETS", "SHELLS", "ROCKETS", "CELLS", "BLUE KEY", "RED KEY", "SOUL ORB", "SUIT", "SHOTGUN", "CHAINGUN", "LAUNCHER", "PLASMA"]
var game: DeadSignalGame
var output = "/tmp/opencode"
var label = "after"

class Labels extends Control:
	var game: DeadSignalGame
	var pickups: Array = []
	var item_names: Array = []
	var label = ""
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 480, 25), Color(0.035, 0.045, 0.045, 0.95))
		PixelFont.text(self, "DEAD SIGNAL / PICKUPS / " + label.to_upper(), Vector2(12, 9), Color("ffc077"))
		for i in range(pickups.size()):
			var at = game.player.camera.unproject_position(pickups[i].global_position)
			var name: String = item_names[i]
			PixelFont.text(self, name, Vector2(at.x - PixelFont.width(name) / 2.0, at.y + 3), Color("d9c9a3"))

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			output = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--label="):
			label = arg.trim_prefix("--label=")
	call_deferred("run")

func run() -> void:
	root.content_scale_size = Vector2i(480, 270)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	game.set_state("paused")
	game.hud.hide()
	game.player.set_physics_process(false)
	for enemy in game.level.enemies:
		enemy.hide()
		enemy.set_physics_process(false)
	for pickup in game.level.pickups:
		pickup.hide()
		pickup.set_process(false)
	for child in game.level.get_children():
		if child is Sprite3D or child is ExplosiveBarrel:
			child.hide()
	game.player.position = game.level.tile_position(game.level.data.spawn)
	game.player.rotation.y = 0
	game.player.camera.position.y = 2.4
	game.player.camera.look_at(game.player.position + Vector3(0, 0.2, -5.3))
	var overlay = CanvasLayer.new()
	overlay.layer = 4
	root.add_child(overlay)
	var names = Labels.new()
	names.game = game
	names.item_names = NAMES
	names.label = label
	overlay.add_child(names)
	for i in range(KINDS.size()):
		var pickup = RetroPickup.new()
		game.level.add_child(pickup)
		var at = game.player.position + Vector3((i % 5 - 2) * 1.8, 0, -3.5 - (i / 5) * 1.9)
		pickup.configure(game, KINDS[i], at, -1)
		pickup.clock = 0
		if pickup.has_method("update_presentation"):
			pickup.update_presentation()
		else:
			pickup._process(0)
		pickup.set_process(false)
		names.pickups.append(pickup)
	names.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	var path = output.path_join("dead-signal-pickups-" + label + ".png")
	assert(image.save_png(path) == OK)
	print("Captured pickups: " + path)
	game.queue_free()
	overlay.queue_free()
	await process_frame
	await process_frame
	OS.delay_msec(80)
	quit()
