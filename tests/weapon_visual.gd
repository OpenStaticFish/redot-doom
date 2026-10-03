extends SceneTree
## Native-rendered regressions for the first-person weapons and clear aiming area.
## redot --path . --script res://tests/weapon_visual.gd -- --test
## --capture-dir=/tmp/opencode chooses an existing screenshot output directory.

const CLEAR_AIM = Rect2i(218, 113, 44, 44)
var game: DeadSignalGame
var output = "/tmp/opencode"
var weapon_canvas: WeaponCanvas
var view: SubViewport
var failures: Array[String] = []
var checks = 0
var before: Image

class WeaponCanvas extends Control:
	var game: DeadSignalGame
	func _draw() -> void:
		game.hud.weapon_view.draw(self, game)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			output = arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: " + label)

func render_weapon() -> Image:
	weapon_canvas.queue_redraw()
	game.hud.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()

func capture(name: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	check(image.save_png(output.path_join("dead-signal-weapon-" + name + ".png")) == OK, "capture " + name)
	return image

func assert_clear(image: Image, label: String) -> void:
	var clear = true
	for y in range(CLEAR_AIM.position.y, CLEAR_AIM.end.y):
		for x in range(CLEAR_AIM.position.x, CLEAR_AIM.end.x):
			if image.get_pixel(x, y).a > 0.01:
				clear = false
				break
		if not clear:
			break
	check(clear, label + " leaves the rendered aiming area transparent")
	check(image.get_used_rect().has_area(), label + " still renders a visible weapon")

func verify_source_pixels() -> void:
	# Compare our stdlib decoder/atlas output with Godot's independent PNG decoder.
	# Original guns/flashes must remain exact. Only explicit hand masks can change.
	for weapon in WeaponView.ART.weapons:
		var art: Dictionary = WeaponView.ART.weapons[weapon]
		for kind in ["body", "flash"]:
			var frames: Array = art[kind + "_frames"]
			if frames.is_empty():
				continue
			var suffix = "_flash" if kind == "flash" else ""
			var atlas = game.texture("weapons/" + weapon + suffix).get_image()
			atlas.convert(Image.FORMAT_RGBA8)
			for i in range(frames.size()):
				var source = Image.new()
				source.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/weapons/freedoom/" + frames[i] + ".png"))
				source.convert(Image.FORMAT_RGBA8)
				var expected = Image.create(320, 200, false, Image.FORMAT_RGBA8)
				expected.fill(Color.TRANSPARENT)
				var origin = Vector2i(art[kind + "_origins"][i][0], art[kind + "_origins"][i][1])
				expected.blit_rect_mask(source, source, Rect2i(Vector2i.ZERO, source.get_size()), origin)
				if kind == "body" and art.hand_layer != "":
					var mask = game.texture("weapons/" + art.hand_mask).get_image().get_region(Rect2i(i * 320, 0, 320, 200))
					var hands = game.texture("weapons/" + art.hand_layer).get_image().get_region(Rect2i(i * 320, 0, 320, 200))
					verify_hand_layer(expected, mask, hands, frames[i], weapon)
					for y in range(200):
						for x in range(320):
							if mask.get_pixel(x, y).a > 0:
								expected.set_pixel(x, y, Color.TRANSPARENT)
						expected.blit_rect_mask(hands, hands, Rect2i(0, 0, 320, 200), Vector2i.ZERO)
				var actual = atlas.get_region(Rect2i(i * 320, 0, 320, 200))
				check(visible_pixels_equal(actual, expected), frames[i] + " preserves source guns/flashes, authored origin and composes only the adapted hands")

func verify_hand_layer(source: Image, mask: Image, hands: Image, name: String, weapon: String) -> void:
	var palette: Dictionary = {}
	for material in WeaponView.ART.hand_palettes:
		for hex in WeaponView.ART.hand_palettes[material]:
			palette[Color(hex).to_rgba32()] = material
	var removed = 0
	var painted = 0
	var skin = 0
	var sleeve = 0
	var cuff = 0
	var confined = true
	var valid_colors = true
	var preserved_metal = true
	for y in range(200):
		for x in range(320):
			var original = source.get_pixel(x, y)
			var cut = mask.get_pixel(x, y).a > 0
			var pixel = hands.get_pixel(x, y)
			if cut:
				removed += 1
				if original.a == 0: confined = false
				if weapon != "fist" and original.r > 31.0 / 255.0 and maxf(original.r, maxf(original.g, original.b)) - minf(original.r, minf(original.g, original.b)) <= 3.0 / 255.0:
					preserved_metal = false
			if pixel.a > 0:
				painted += 1
				if not cut: confined = false
				var material: String = palette.get(pixel.to_rgba32(), "")
				if material == "": valid_colors = false
				elif material == "skin": skin += 1
				elif material == "sleeve": sleeve += 1
				elif material == "cuff": cuff += 1
	check(confined, name + " replacement is confined to the original visible hands")
	check(preserved_metal, name + " hand mask never selects grey weapon metal")
	check(removed > painted and painted > 0, name + " has narrower hand/wrist contours")
	check(valid_colors and skin > 0, name + " uses only Redot-chan's skin/sleeve palettes")
	if name != "shtga0":
		check(sleeve > 0 and cuff > 0, name + " keeps the black sleeve and red cuff through animation")

func visible_pixels_equal(actual: Image, expected: Image) -> bool:
	var a = actual.get_data()
	var b = expected.get_data()
	if a.size() != b.size():
		return false
	for i in range(0, a.size(), 4):
		if a[i + 3] != b[i + 3]:
			return false
		# Godot's fix_alpha_border fills RGB in invisible edge pixels to avoid
		# filtering fringes. Those pixels' alpha must match; their RGB is unused.
		if b[i + 3] > 0 and (a[i] != b[i] or a[i + 1] != b[i + 1] or a[i + 2] != b[i + 2]):
			return false
	return true

func stamp(image: Image, text: String, at: Vector2i) -> void:
	var cursor = at
	for letter in text:
		var glyph: Array = PixelFont.GLYPHS[letter]
		for y in range(7):
			for x in range(5):
				if glyph[y] & (1 << (4 - x)):
					image.set_pixel(cursor.x + x, cursor.y + y, Color("ffc077"))
		cursor.x += 6

func run() -> void:
	root.content_scale_size = Vector2i(480, 270)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var old_capture = output.path_join("dead-signal-foundry.png")
	if FileAccess.file_exists(old_capture):
		before = Image.load_from_file(old_capture)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	game.player.set_physics_process(false)
	for enemy in game.level.enemies:
		enemy.set_physics_process(false)
	game.player.position = game.level.tile_position(Vector2i(14, 18))
	game.player.owned = [0, 1, 2, 3, 4, 5]
	game.player.ammo = {"bullets": 240, "shells": 48, "rockets": 12, "cells": 200}
	game.player.armor = 100
	game.player.keys = ["blue"]
	game.message_time = 0
	game.elapsed = 20
	game.crosshair = true
	view = SubViewport.new()
	view.size = Vector2i(480, 224)
	view.transparent_bg = true
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	weapon_canvas = WeaponCanvas.new()
	weapon_canvas.game = game
	view.add_child(weapon_canvas)
	verify_source_pixels()
	var board = Image.create(1440, 540, false, Image.FORMAT_RGBA8)
	board.fill(Color.BLACK)
	for weapon in range(6):
		game.player.weapon = weapon
		game.player.cooldown = 0
		game.player.recoil = 0
		game.player.muzzle_time = 0
		game.player.switch_dip = 0
		game.player.velocity = Vector3.ZERO
		var name: String = Arsenal.definition(weapon).id
		assert_clear(await render_weapon(), name + " idle")
		var screenshot = await capture(name)
		board.blit_rect(screenshot, Rect2i(0, 0, 480, 270), Vector2i((weapon % 3) * 480, (weapon / 3) * 270))
		if weapon == 2 and before != null and before.get_size() == Vector2i(480, 270):
			var comparison = Image.create(960, 286, false, Image.FORMAT_RGBA8)
			comparison.fill(Color("151c1e"))
			comparison.blit_rect(before, Rect2i(0, 0, 480, 270), Vector2i(0, 16))
			comparison.blit_rect(screenshot, Rect2i(0, 0, 480, 270), Vector2i(480, 16))
			stamp(comparison, "BEFORE", Vector2i(10, 4))
			stamp(comparison, "UPDATED", Vector2i(490, 4))
			comparison.save_png(output.path_join("dead-signal-weapon-comparison.png"))
		for phase in [0.0, 0.1, 0.25, 0.45, 0.65, 0.85]:
			var age: float = phase * Arsenal.definition(weapon).delay
			game.player.cooldown = Arsenal.definition(weapon).delay - age
			game.player.recoil = maxf(0, 1.0 - age * 5.0)
			game.player.muzzle_time = maxf(0, 0.07 - age) if weapon != 0 else 0
			game.player.shot_serial = int(phase * 10)
			assert_clear(await render_weapon(), name + " firing phase " + str(phase))
			if phase == 0:
				await capture(name + "-fire")
			elif weapon == 2 and phase in [0.45, 0.65]:
				await capture(name + "-pump-" + str(int(phase * 100)))
			elif weapon == 0 and phase in [0.25, 0.45]:
				await capture(name + "-punch-" + str(int(phase * 100)))
		# Both extremes of bob and a partially lowered switching pose.
		game.player.cooldown = 0
		game.player.muzzle_time = 0
		game.player.recoil = 0
		game.player.velocity = Vector3(12, 0, 0)
		for clock in [PI / 2, PI * 1.5]:
			game.player.walk_time = clock
			assert_clear(await render_weapon(), name + " moving " + str(clock))
		game.player.switch_dip = 0.5
		assert_clear(await render_weapon(), name + " switching")
	board.save_png(output.path_join("dead-signal-weapons-overview.png"))
	# Changing weapons after a shot must not put the previous flash on the new gun.
	game.player.weapon = 1
	game.player.muzzle_time = 0.07
	game.player.recoil = 1
	game.player.select_weapon(2)
	check(game.player.muzzle_time == 0 and game.player.recoil == 0, "weapon switch clears stale firing presentation")
	# Wait for the last switch click to finish on the independent audio clock.
	var last_voice: AudioStreamPlayer = game.audio.pool[(game.audio.voice - 1) % game.audio.pool.size()]
	if last_voice.playing:
		await last_voice.finished
	print("DEAD SIGNAL weapons: %d rendered/source checks, %d failures" % [checks, failures.size()])
	game.queue_free()
	view.queue_free()
	await process_frame
	await process_frame
	OS.delay_msec(80)
	quit(0 if failures.is_empty() else 1)
