extends SceneTree
## Live death progression and access-card regression tests, including screenshots.
## redot --headless --path . --script res://tests/death_and_keycards.gd -- --test
## Run with a display and --capture to also inspect rendered corpses and cards.

const CORPSES = {"thrall": "sprites/possl0.png", "ember": "sprites/troom0.png", "brute": "sprites/bosso0.png", "warden": "sprites/cybrp0.png"}
const SAVE_PATH = "user://dead_signal_corpse_test.save"
var game: DeadSignalGame
var failures: Array[String] = []
var checks = 0
var capture = false
var output = "/tmp/opencode"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--capture": capture = true
		elif arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: " + label)

func frames(count: int) -> void:
	for i in range(count): await physics_frame
	await process_frame

func freeze_other_actors() -> void:
	game.player.set_physics_process(false)
	for enemy in game.level.enemies: enemy.set_physics_process(false)
	for item in game.level.pickups: item.set_process(false)

func corpse_image(enemy: Demon) -> Image:
	var art: Dictionary = enemy.artwork
	var size = Vector2i(art.size[0], art.size[1])
	return enemy.sprite.texture.get_image().get_region(Rect2i((enemy.sprite.frame % art.columns) * size.x, (enemy.sprite.frame / art.columns) * size.y, size.x, size.y))

func assert_corpse(enemy: Demon, label: String) -> void:
	var frame_file: String = enemy.artwork.files[enemy.sprite.frame]
	check(frame_file == CORPSES[enemy.kind], label + " ends on the intended fallen-body sprite")
	var bounds = corpse_image(enemy).get_used_rect()
	var visible_height = bounds.size.y * enemy.sprite.pixel_size
	check(visible_height < enemy.aim_height, label + " visible silhouette is lower than half standing height")
	var bottom = enemy.sprite.position.y + (enemy.artwork.size[1] / 2.0 - bounds.end.y) * enemy.sprite.pixel_size
	check(absf(bottom - 0.025) < 0.001, label + " rests at ground level")
	check(enemy.collision_layer == 0 and enemy.collider.disabled, label + " no longer blocks movement or bullets")

func snap(name: String) -> void:
	if not capture: return
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join("dead-signal-fixed-" + name + ".png")) == OK, "capture " + name)

func test_enemy(enemy: Demon) -> void:
	var position = enemy.position
	game.player.position = position + Vector3(0, 0, 3.5 if enemy.kind != "warden" else 7)
	game.player.rotation.y = 0
	game.player.camera.rotation.x = -0.18
	game.message_time = 0
	game.elapsed = 20
	var before = game.kills
	enemy.set_physics_process(true)
	enemy.take_damage(enemy.max_health + 1)
	check(enemy.dead and game.kills == before + 1, enemy.kind + " live lethal hit is counted once")
	await frames(96)
	assert_corpse(enemy, enemy.kind + " live death")
	check(enemy.visual_step >= enemy.artwork.poses.death.size() - 1, enemy.kind + " real physics ticks complete its collapse")
	await snap(enemy.kind + "-corpse")
	var settled_frame = enemy.sprite.frame
	await frames(40)
	check(enemy.sprite.frame == settled_frame and game.kills == before + 1, enemy.kind + " remains a settled corpse without repeated kill/drop events")
	for angle in [0.0, PI / 2, PI, -PI / 2]:
		game.player.position = position + Vector3(sin(angle) * 5, 0, cos(angle) * 5)
		enemy.update_presentation()
		check(enemy.sprite.frame == settled_frame, enemy.kind + " corpse never changes back to an upright view")

func run() -> void:
	root.content_scale_size = Vector2i(480, 270)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	freeze_other_actors()
	for kind in ["thrall", "ember", "brute"]:
		for enemy in game.level.enemies:
			if enemy.kind == kind and not enemy.dead:
				await test_enemy(enemy)
				break
	game.player.position = game.level.tile_position(game.level.data.spawn)
	game.set_state("paused")
	check(game.save_game(false, SAVE_PATH) and game.load_game(SAVE_PATH), "corpses round-trip through game save/load")
	freeze_other_actors()
	await frames(2)
	for enemy in game.level.enemies:
		if enemy.dead: assert_corpse(enemy, enemy.kind + " saved corpse")
	game._load_sector(2)
	game.set_state("playing")
	freeze_other_actors()
	for enemy in game.level.enemies:
		if enemy.kind == "warden":
			await test_enemy(enemy)
			break
	game.player.camera.rotation.x = 0
	game._load_sector(0)
	game.set_state("playing")
	freeze_other_actors()
	game.player.keys.clear()
	for item in game.level.pickups: item.hide()
	for enemy in game.level.enemies: enemy.hide()
	for kind in ["bluekey", "redkey"]:
		var art: Dictionary = RetroPickup.ART[kind]
		check(float(art.size[0]) / art.size[1] > 1.5, kind + " is a horizontal access card, not a vertical token")
		var icon = game.texture("sprites/" + kind).get_image().get_used_rect()
		check(icon.size.x > icon.size.y * 1.5, kind + " HUD icon retains card proportions")
		game.level.add_pickup(kind, game.player.position + Vector3(-0.9, 0, -3.2), -1)
		var card: RetroPickup = game.level.pickups.back()
		card.set_process(false)
		card.clock = 0
		card.update_presentation()
		game.player.camera.rotation.x = -0.08
		await snap(kind + "-world")
		check(card.collect() and game.player.keys.has(kind.trim_suffix("key")), kind + " still grants the correct access credential")
		game.player.camera.rotation.x = 0
		await snap(kind + "-hud")
	for voice in game.audio.pool:
		if voice.playing: await voice.finished
	print("DEAD SIGNAL corpses/keycards: %d checks, %d failures" % [checks, failures.size()])
	game.queue_free()
	await process_frame
	await process_frame
	OS.delay_msec(200)
	quit(0 if failures.is_empty() else 1)
