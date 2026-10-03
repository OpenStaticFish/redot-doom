extends SceneTree
## Pixel-equivalence and submission-cost check for the cached glyph atlas.
## redot --path . --script res://tests/pixel_font.gd

class FontCanvas extends Control:
	var reference = false
	var elapsed_us: Array[int] = []
	var commands = 0

	func legacy(value: String, at: Vector2, color: Color, scale: int, shadow: bool) -> void:
		if shadow:
			legacy(value, at + Vector2(scale, scale), Color(0.02, 0.02, 0.025, color.a), scale, false)
		var x = int(at.x)
		for letter in value.to_upper():
			var rows = PixelFont.GLYPHS.get(letter, PixelFont.GLYPHS["?"])
			for y in range(7):
				for bit in range(5):
					if rows[y] & (1 << (4 - bit)):
						draw_rect(Rect2(x + bit * scale, int(at.y) + y * scale, scale, scale), color)
						commands += 1
			x += 6 * scale

	func _draw() -> void:
		commands = 0
		var started = Time.get_ticks_usec()
		var alphabet = "".join(PixelFont.GLYPHS.keys())
		var values = [alphabet, "lowercase ~ fallback", "HEALTH 100 / ARMOR 200", "DEAD SIGNAL", "AMMO 1 2 3 4 5 6"]
		for i in range(values.size()):
			var scale = i if i > 0 else 1
			var color = Color(1, 0.23, 0.04, 0.65 if i % 2 else 1.0)
			var at = Vector2(6.7, 8.4 + i * 40)
			if reference:
				legacy(values[i], at, color, scale, i % 2 == 0)
			else:
				PixelFont.text(self, values[i], at, color, scale, i % 2 == 0)
				commands += values[i].replace(" ", "").length() * (2 if i % 2 == 0 else 1)
		elapsed_us.append(Time.get_ticks_usec() - started)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var atlas = PixelFont.atlas()
	assert(atlas == PixelFont.atlas(), "glyph atlas is cached")
	var views: Array[SubViewport] = []
	var canvases: Array[FontCanvas] = []
	for reference in [false, true]:
		var view = SubViewport.new()
		view.size = Vector2i(480, 270)
		view.disable_3d = true
		view.transparent_bg = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var canvas = FontCanvas.new()
		canvas.reference = reference
		canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		view.add_child(canvas)
		views.append(view)
		canvases.append(canvas)
	for i in range(24):
		for canvas in canvases:
			canvas.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
	var actual = views[0].get_texture().get_image()
	var expected = views[1].get_texture().get_image()
	var differences = 0
	for y in range(270):
		for x in range(480):
			if actual.get_pixel(x, y) != expected.get_pixel(x, y):
				differences += 1
	for canvas in canvases:
		canvas.elapsed_us.sort()
	print("PIXEL FONT: %d differing pixels; commands %d → %d; median submission %d → %d us" % [differences, canvases[1].commands, canvases[0].commands, canvases[1].elapsed_us[12], canvases[0].elapsed_us[12]])
	quit(0 if differences == 0 else 1)
