extends SceneTree
## Native rendering baseline; compare on the same machine, renderer and flags.
## redot --path . --script res://tests/performance.gd -- --test

var game: DeadSignalGame

func _initialize() -> void:
	call_deferred("run")

func sample(label: String) -> void:
	for i in range(30):
		await process_frame
	var frame_ms: Array[float] = []
	var draw_calls: Array[float] = []
	var previous = Time.get_ticks_usec()
	for i in range(120):
		await process_frame
		var now = Time.get_ticks_usec()
		frame_ms.append((now - previous) / 1000.0)
		previous = now
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	frame_ms.sort()
	draw_calls.sort()
	print("PERF %s: median frame %.3f ms, p95 %.3f ms, median draw calls %.0f" % [label, frame_ms[60], frame_ms[113], draw_calls[60]])

func run() -> void:
	seed(1993)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await sample("title")
	game.back_state = "menu"
	game.set_state("help")
	await sample("field manual")
	for sector in range(3):
		game._load_sector(sector, {"health": 100, "armor": 100})
		game.set_state("playing")
		game.player.set_physics_process(false)
		for enemy in game.level.enemies:
			enemy.set_physics_process(false)
		game.elapsed = 20
		game.message_time = 0
		await sample("sector %d" % (sector + 1))
	game.queue_free()
	await process_frame
	await process_frame
	quit()
