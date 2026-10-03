extends SceneTree
## Redot portrait events, holds, eased/interruptible blends and menu coverage.
## redot --headless --path . --script res://tests/redot_ui.gd -- --test
## With a display, add --capture for shader pixel checks/screens; --animate for motion frames.

const SAVE_PATH = "user://dead_signal_redot_ui_test.save"
var game: DeadSignalGame
var portrait: RedotPortrait
var checks = 0
var failures: Array[String] = []
var capture = false
var animate = false
var output = "/tmp/opencode"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--capture": capture = true
		elif arg == "--animate": animate = true
		elif arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: " + label)

func freeze_actors() -> void:
	game.set_process(false)
	game.player.set_physics_process(false)
	for enemy in game.level.enemies: enemy.set_physics_process(false)
	for item in game.level.pickups: item.set_process(false)

func clean(health: int = 100) -> void:
	game.set_state("playing")
	game.player.health = health
	game.player.armor = 0
	game.player.hurt_flash = 0
	game.player.bonus_flash = 0
	game.player.recoil = 0
	game.player.muzzle_time = 0
	game.hud.reset_portrait()

func step(delta: float) -> void:
	game._process(delta)

func pickup(kind: String) -> RetroPickup:
	game.level.add_pickup(kind, game.player.position + Vector3(4, 0, 0), -1)
	var item: RetroPickup = game.level.pickups.back()
	item.set_process(false)
	return item

func equal_weights(a: PackedFloat32Array, b: PackedFloat32Array) -> bool:
	if a.size() != b.size(): return false
	for i in range(a.size()):
		if not is_equal_approx(a[i], b[i]): return false
	return true

func normalized(weights: PackedFloat32Array) -> bool:
	var total = 0.0
	for weight in weights:
		if weight < 0 or weight > 1: return false
		total += weight
	return is_equal_approx(total, 1.0)

func test_assets() -> void:
	var art: Dictionary = RedotPortrait.ART
	var atlas = game.texture("ui/redot_chan/portraits").get_image()
	check(art.columns == 8 and art.expressions.size() == 8, "eight portrait frames match the blend shader")
	check(atlas.get_size() == Vector2i(art.size[0] * art.columns, art.size[1]), "portrait atlas dimensions")
	check(art.eye_anchor == [21, 25], "expressions share a stable eye-line anchor")
	var signatures: Dictionary = {}
	for name in art.expressions:
		var image = atlas.get_region(Rect2i(art.expressions[name] * 42, 0, 42, 44))
		var bounds = image.get_used_rect()
		check(bounds.size.x > 20 and bounds.size.y > 30, name + " retains a recognizable head")
		check(image.get_pixel(41, 0).a == 0, name + " background is transparent")
		signatures[image.get_data().hex_encode()] = true
	check(signatures.size() == 8, "every expression has distinct artwork")
	var focused = atlas.get_region(Rect2i(art.expressions.focused * 42, 0, 42, 44))
	for x in [16, 24]:
		var amber = 0
		for y in range(23, 27):
			for px in range(x, x + 5):
				var color = focused.get_pixel(px, y)
				if color.r > 0.7 and color.g < 0.7 and color.b < 0.3: amber += 1
		check(amber >= 2, "retained focused artwork has an open amber eye at " + str(x))
	check(BrandTheme.ORANGE == Color("ff3b0a") and BrandTheme.BACKGROUND == Color("09090b"), "palette matches Redot branding")
	check(game.texture("ui/status").get_image().get_pixel(0, 0) == BrandTheme.ORANGE, "status artwork uses the brand accent")

func test_events() -> void:
	for kind in RetroPickup.ART:
		game.player.restore({"health": 50, "armor": 0, "ammo": {"bullets": 0, "shells": 0, "rockets": 0, "cells": 0}})
		clean(50)
		var item = pickup(kind)
		check(item.collect(), kind + " actual pickup succeeds")
		step(0)
		check(portrait.current_expression == "happy", kind + " emits a pickup reaction")
		game.player.bonus_flash = 0
		step(1.2)
		check(portrait.current_expression == "happy", kind + " reaction outlasts its screen flash")
		var remaining = portrait.pickup_remaining
		check(not item.collect() and portrait.pickup_remaining == remaining, kind + " consumed item cannot refresh a reaction")
		step(0.41)
		check(portrait.current_expression != "happy", kind + " reaction expires rather than sticking")
	clean()
	var medkit = pickup("medkit")
	check(not medkit.collect() and portrait.pickup_remaining == 0, "full-health rejection causes no happy face")
	check(pickup("bluekey").collect(), "first repeated pickup")
	step(1.1)
	check(pickup("redkey").collect(), "second repeated pickup")
	step(1.1)
	check(portrait.current_expression == "happy", "another accepted pickup renews the full hold")
	clean()
	game.player.take_damage(8)
	step(0.22)
	game.player.hurt_flash = 0
	step(1.0)
	check(portrait.current_expression == "hurt", "damage face lasts after the red flash ends")
	game.player.take_damage(8)
	step(1.3)
	check(portrait.current_expression == "hurt", "another hit renews the full damage hold")
	step(0.11)
	check(portrait.current_expression == "calm", "damage returns to the health-aware idle face")
	for weapon in range(6):
		game.player.owned = [0, 1, 2, 3, 4, 5]
		game.player.weapon = weapon
		for health in [100, 45, 18]:
			clean(health)
			game.player.ammo = {"bullets": 80, "shells": 40, "rockets": 20, "cells": 100}
			var idle = portrait.current_expression
			var before = portrait.weights.duplicate()
			var label = "weapon %d at %d health" % [weapon, health]
			check(game.player.fire(), label + " actual shot succeeds")
			step(0.22)
			check(portrait.current_expression == idle and equal_weights(before, portrait.weights), label + " keeps the same face during recoil/muzzle flash")
			game.player.muzzle_time = 0
			game.player.recoil = 0
			step(0.7)
			check(portrait.current_expression == idle and equal_weights(before, portrait.weights), label + " keeps the same face after firing")
	clean()
	game.player.weapon = 1
	game.player.ammo.bullets = 0
	var before = portrait.weights.duplicate()
	check(not game.player.fire(), "dry firing is rejected")
	step(0.22)
	check(portrait.current_expression == "calm" and equal_weights(before, portrait.weights), "dry firing leaves the face unchanged")
	game.player.health = 0
	check(not game.player.fire(), "dead players cannot fire")
	step(0.22)
	check(portrait.current_expression == "defeated", "rejected firing does not replace the death face")

func test_blends_and_priority() -> void:
	clean()
	game.player.ammo.bullets = 80
	portrait.on_pickup()
	step(0.055)
	check(is_equal_approx(portrait.weights[RedotPortrait.ART.expressions.happy], 0.15625), "transition uses smoothstep easing, not a hard cut")
	var before = portrait.weights.duplicate()
	portrait.on_damage()
	step(0)
	check(equal_weights(before, portrait.weights), "mid-fade damage starts from the displayed mixture without snapping")
	for i in range(14):
		step(1.0 / 60.0)
		check(normalized(portrait.weights), "interrupted blend " + str(i) + " remains normalized")
	check(portrait.weights[RedotPortrait.ART.expressions.hurt] == 1, "interrupted fade reaches its damage target")
	check(game.player.fire(), "actual shot during a damage reaction")
	step(0.05)
	check(portrait.current_expression == "hurt", "shooting cannot cut off a damage reaction")
	clean()
	portrait.on_pickup()
	step(0.055)
	check(game.player.fire(), "actual shot during a pickup transition")
	step(0.055)
	check(is_equal_approx(portrait.weights[RedotPortrait.ART.expressions.happy], 0.5), "firing does not restart the pickup fade")
	step(0.11)
	check(portrait.current_expression == "happy", "shooting cannot cut off a pickup reaction")
	clean()
	game.player.weapon = 3
	game.player.ammo.bullets = 80
	var idle_weights = portrait.weights.duplicate()
	for i in range(12):
		check(game.player.fire(), "automatic shot " + str(i) + " succeeds")
		step(0.1)
		check(portrait.current_expression == "calm" and equal_weights(idle_weights, portrait.weights), "automatic fire " + str(i) + " leaves the portrait unchanged")
	clean(45)
	check(portrait.current_expression == "tired", "wounded idle expression")
	clean(18)
	portrait.on_pickup()
	check(game.player.fire(), "actual shot at critical health")
	step(0.22)
	check(portrait.current_expression == "panic", "critical health remains readable during pickups and firing")
	portrait.on_damage()
	step(0.22)
	check(portrait.current_expression == "hurt", "critical health still acknowledges an actual hit")
	step(1.2)
	check(portrait.current_expression == "panic", "critical warning returns after the hit")
	clean()
	portrait.on_pickup()
	step(0.22)
	var remaining = portrait.pickup_remaining
	for state in ["paused", "options", "help"]:
		game.set_state(state)
		step(5)
		check(portrait.pickup_remaining == remaining, state + " preserves the pickup hold")
	game.set_state("playing")
	step(0.2)
	check(portrait.current_expression == "happy", "pickup reaction survives pause and resume")
	game.player.health = 0
	game.set_state("dead")
	step(0.22)
	check(portrait.current_expression == "defeated", "death overrides all queued reactions")
	clean(18)
	for state in ["intermission", "victory"]:
		game.set_state(state)
		step(0.22)
		check(portrait.current_expression == "happy", state + " celebrates instead of showing combat faces")

func test_lifecycle_and_menus() -> void:
	clean()
	portrait.on_damage()
	portrait.on_pickup()
	game.new_game()
	freeze_actors()
	check(portrait.current_expression == "calm" and portrait.hurt_remaining == 0 and portrait.pickup_remaining == 0, "new run clears old reactions and blends")
	check(game.save_game(false, SAVE_PATH), "portrait test save writes separately from player saves")
	portrait.on_damage()
	check(game.load_game(SAVE_PATH), "portrait test save loads")
	freeze_actors()
	check(portrait.current_expression == "calm" and portrait.hurt_remaining == 0, "loading clears stale damage reactions")
	game.player.take_damage(9999)
	step(0.22)
	game.menu_action("retry")
	freeze_actors()
	check(portrait.current_expression == "calm" and portrait.hurt_remaining == 0, "checkpoint retry clears the death/hurt face")
	portrait.on_pickup()
	game._load_sector(1, game.player.snapshot())
	freeze_actors()
	game.set_state("playing")
	check(portrait.current_expression == "calm" and portrait.pickup_remaining == 0, "sector changes clear transient reactions")
	for state in ["menu", "difficulty", "paused", "help", "options", "dead", "intermission", "victory"]:
		game.set_state(state)
		var rects = game.hud.menu_rects()
		var options = game.hud.menu_items()
		check(rects.size() == options.size(), state + " hit regions match its buttons")
		for i in range(rects.size()):
			check(Rect2(0, 0, 480, 270).encloses(rects[i]), state + " button fits the screen")
			check(PixelFont.width(options[i][0], 2) <= rects[i].size.x, state + " button text fits")
			if i > 0: check(not rects[i].intersects(rects[i - 1]), state + " adjacent buttons do not overlap")

func rendered() -> void:
	game.hud.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func snap(name: String) -> void:
	await rendered()
	check(root.get_texture().get_image().save_png(output.path_join("dead-signal-redot-" + name + ".png")) == OK, "capture " + name)

func shader_matches(atlas: Image, weights: PackedFloat32Array) -> bool:
	var actual = game.hud.portrait_view.get_texture().get_image()
	for y in range(44):
		for x in range(42):
			var expected = Color(0, 0, 0, 0)
			for i in range(weights.size()):
				var pose = atlas.get_pixel(i * 42 + x, y)
				expected += Color(pose.r * pose.a, pose.g * pose.a, pose.b * pose.a, pose.a) * weights[i]
			if expected.a > 0:
				expected.r /= expected.a
				expected.g /= expected.a
				expected.b /= expected.a
			var pixel = actual.get_pixel(x, y)
			if absf(pixel.a - expected.a) > 0.012: return false
			if expected.a > 0 and (absf(pixel.r - expected.r) > 0.012 or absf(pixel.g - expected.g) > 0.012 or absf(pixel.b - expected.b) > 0.012): return false
	return true

func capture_screens() -> void:
	game._load_sector(0, {"health": 100, "armor": 100})
	freeze_actors()
	game.player.position = game.level.tile_position(Vector2i(14, 18))
	game.player.weapon = 2
	game.player.owned = [0, 1, 2, 3, 4, 5]
	game.player.ammo.shells = 48
	game.player.keys = ["blue", "red"]
	game.elapsed = 20
	game.message_time = 0
	game.post.material.set_shader_parameter("enabled", false)
	clean()
	var atlas = game.texture("ui/redot_chan/portraits").get_image()
	for name in RedotPortrait.ART.expressions:
		portrait.weights.fill(0)
		portrait.weights[RedotPortrait.ART.expressions[name]] = 1
		game.hud.portrait_material.set_shader_parameter("weights", portrait.weights)
		await snap("portrait-" + name)
		check(shader_matches(atlas, portrait.weights), name + " shader preserves authored color and alpha")
	clean()
	portrait.on_pickup()
	step(RedotPortrait.TRANSITION_TIME / 2)
	await snap("portrait-blend")
	check(shader_matches(atlas, portrait.weights), "mid-fade shader blends premultiplied color without a dark flash")
	portrait.on_damage()
	step(RedotPortrait.TRANSITION_TIME / 2)
	await rendered()
	check(shader_matches(atlas, portrait.weights), "interrupted three-pose blend matches its continuous weights")
	for state in ["menu", "difficulty", "paused", "help", "options", "dead", "intermission", "victory"]:
		game.back_state = "paused" if state in ["help", "options"] else "menu"
		game.set_state(state)
		step(0.22)
		await snap(state)

func capture_motion() -> void:
	clean()
	game.player.ammo.shells = 48
	for frame in range(240):
		match frame:
			24: pickup("bluekey").collect()
			48: game.player.fire()
			90: game.player.take_damage(10)
			108: game.player.fire()
			156, 162, 168: game.player.fire()
			198: game.player.health = 18
			222: game.player.take_damage(9999)
		step(1.0 / 30.0)
		await rendered()
		var path = output.path_join("redot-portrait-motion-%03d.png" % frame)
		check(root.get_texture().get_image().save_png(path) == OK, "motion frame " + str(frame))

func run() -> void:
	root.content_scale_size = Vector2i(480, 270)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	freeze_actors()
	portrait = game.hud.portrait
	test_assets()
	test_events()
	test_blends_and_priority()
	test_lifecycle_and_menus()
	if capture: await capture_screens()
	if animate: await capture_motion()
	for voice in game.audio.pool:
		if voice.playing: await voice.finished
	print("DEAD SIGNAL Redot UI: %d checks, %d failures" % [checks, failures.size()])
	game.queue_free()
	await process_frame
	await process_frame
	OS.delay_msec(100)
	quit(0 if failures.is_empty() else 1)
