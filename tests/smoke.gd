extends SceneTree
## Integration checks against real scenes, physics bodies, and campaign state.
## redot --headless --path . --script res://tests/smoke.gd -- --test

var game: DeadSignalGame
var failures: Array[String] = []
var checks = 0
const TEST_SAVE = "user://dead_signal_integration.save"

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error("FAIL: " + description)

func frames(count: int = 2) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func key(code: Key) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)

func quiet_enemies() -> void:
	for enemy in game.level.enemies:
		enemy.set_physics_process(false)

func pickup(kind: String) -> RetroPickup:
	for item in game.level.pickups:
		if item.kind == kind:
			return item
	return null

func _reachable(d: Dictionary, keys: Array) -> Dictionary:
	var queue: Array = [d.spawn]
	var visited = {d.spawn: true}
	var blocked: Dictionary = {}
	for door in d.doors:
		if door.key != "" and not keys.has(door.key):
			blocked[door.tile] = true
	var cursor = 0
	while cursor < queue.size():
		var tile: Vector2i = queue[cursor]
		cursor += 1
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = tile + offset
			if next.x < 0 or next.y < 0 or next.x >= d.size.x or next.y >= d.size.y:
				continue
			if visited.has(next) or blocked.has(next) or d.grid[next.y][next.x] in RetroLevel.SOLID:
				continue
			visited[next] = true
			queue.append(next)
	return visited

func validate_campaign() -> void:
	for sector in range(3):
		var d = Campaign.build(sector)
		var keys: Array = []
		var reached: Dictionary = {}
		for pass_index in range(4):
			reached = _reachable(d, keys)
			for item in d.pickups:
				if item.kind.ends_with("key") and reached.has(item.tile):
					var card = item.kind.trim_suffix("key")
					if not keys.has(card):
						keys.append(card)
		check(reached.has(d.exit), "sector %d has solvable key progression to exit" % sector)
		for item in d.pickups:
			check(reached.has(item.tile), "sector %d pickup %s is reachable" % [sector, item.kind])
		for enemy in d.enemies:
			check(reached.has(enemy.tile), "sector %d enemy %s is on accessible floor" % [sector, enemy.kind])
		check(not _reachable(d, []).has(d.exit), "sector %d exit requires its key" % sector)

func run() -> void:
	seed(1993)
	validate_campaign()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	check(game.state == "menu", "boots into title screen")
	check(game.level.enemies.size() == 10, "first sector contains full encounter roster")
	check(game.audio.music.playing, "original score starts")
	var music_stream: AudioStreamWAV = game.audio.music.stream
	check(music_stream.get_length() > 30 and absf(music_stream.loop_end / float(music_stream.mix_rate) - music_stream.get_length()) < 0.01, "compressed music loops at its actual sample count")
	key(KEY_ENTER)
	await frames()
	check(game.state == "difficulty", "keyboard title navigation")
	key(KEY_DOWN)
	key(KEY_ENTER)
	await frames()
	check(game.state == "playing" and game.difficulty == 1, "difficulty selection starts campaign")
	quiet_enemies()
	var initial_z = game.player.position.z
	Input.action_press("forward")
	await frames(20)
	Input.action_release("forward")
	check(game.player.position.z < initial_z - 1, "WASD input moves real CharacterBody3D")
	# A closed door should actually block the player.
	var entry: RetroDoor = game.level.doors[0]
	game.player.position = entry.position + Vector3(0, 0, 2)
	game.player.velocity = Vector3.ZERO
	Input.action_press("forward")
	await frames(30)
	check(game.player.position.z > entry.position.z + 0.4, "closed door physically blocks movement")
	Input.action_release("forward")
	check(game.interact(), "use action activates nearby door")
	await frames(80)
	check(entry.opened and entry.progress >= 1, "door completes slide animation")
	Input.action_press("forward")
	await frames(25)
	Input.action_release("forward")
	check(game.player.position.z < entry.position.z, "open door can be traversed")
	var locked: RetroDoor = game.level.doors[3]
	check(not locked.activate(), "blue gate rejects missing key")
	check(pickup("bluekey").collect(), "keycard pickup works")
	check(locked.activate(), "blue gate accepts acquired key")
	var secret: RetroDoor = game.level.doors[4]
	check(secret.activate(), "secret wall opens")
	check(game.secrets == 1 and not secret.activate(), "secret counted exactly once")
	check(not pickup("medkit").collect(), "full-health medkit remains available")
	game.player.health = 55
	check(pickup("medkit").collect() and game.player.health == 80, "medkit restores health and counts item")
	pickup("armor").collect()
	var before_health = game.player.health
	var before_armor = game.player.armor
	game.player.take_damage(20)
	check(game.player.health == before_health - 12 and game.player.armor == before_armor - 8, "armor absorbs 40 percent of incoming damage")
	check(pickup("shotgun").collect() and game.player.owned.has(2), "weapon pickup unlocks shotgun")
	# Real hitscan collision with a stationary enemy, without bypassing damage.
	var target: Demon = game.level.enemies[0]
	game.player.position = target.position + Vector3(0, 0, 4)
	game.player.rotation.y = 0
	game.player.select_weapon(1)
	await frames()
	var bullets = game.player.ammo.bullets
	for shot in range(5):
		game.player.cooldown = 0
		game.player.fire()
		await frames()
	check(game.player.ammo.bullets == bullets - 5, "hitscan spends one bullet per shot")
	check(target.dead and game.kills == 1, "hitscan kills collider and updates statistics")
	var melee_target: Demon = game.level.enemies[1]
	game.player.position = melee_target.position + Vector3(0, 0, 1.7)
	game.player.select_weapon(0)
	await frames()
	var melee_health = melee_target.health
	var melee_bullets = game.player.ammo.bullets
	game.player.cooldown = 0
	check(game.player.fire(), "fist fires without ammunition")
	check(melee_target.health < melee_health and game.player.ammo.bullets == melee_bullets, "melee damages a nearby collider without spending ammo")
	game.player.position = melee_target.position + Vector3(0, 0, 3)
	game.player.select_weapon(2)
	await frames()
	var shells = game.player.ammo.shells
	game.player.cooldown = 0
	game.player.fire()
	check(melee_target.dead and game.player.ammo.shells == shells - 1, "shotgun pellet spread kills and consumes one shell")
	game.player.ammo.shells = 0
	game.player.cooldown = 0
	check(not game.player.fire(), "empty weapon rejects firing")
	game.player.ammo.shells = shells - 1
	# AI acquires the player and follows them using actual collision and LOS.
	var hunter: Demon = game.level.enemies[2]
	game.player.position = hunter.position + Vector3(0, 0, 6)
	hunter.set_physics_process(true)
	var hunter_pos = hunter.position
	await frames(40)
	check(hunter.alerted and hunter.position.distance_to(hunter_pos) > 0.3, "enemy spots and pursues player")
	hunter.set_physics_process(false)
	# Pausing preserves simulation time and position.
	key(KEY_ESCAPE)
	await frames()
	check(game.state == "paused", "escape pauses")
	var pause_pos = game.player.position
	var pause_time = game.elapsed
	Input.action_press("forward")
	await frames(15)
	Input.action_release("forward")
	check(game.player.position == pause_pos and game.elapsed == pause_time, "pause freezes gameplay")
	key(KEY_ESCAPE)
	await frames()
	check(game.state == "playing", "escape resumes")
	key(KEY_TAB)
	await frames()
	check(game.automap, "Tab opens discovered automap")
	key(KEY_TAB)
	await frames()
	game.player.health = 87
	game.player.ammo.bullets = 123
	game.player.position = game.level.tile_position(Vector2i(14, 18))
	game.player.velocity = Vector3.ZERO
	game.set_state("paused")
	check(game.save_game(false, TEST_SAVE), "session saves to disk")
	game.player.health = 1
	game.player.ammo.bullets = 0
	check(game.load_game(TEST_SAVE), "session loads from disk")
	quiet_enemies()
	check(game.player.health == 87 and game.player.ammo.bullets == 123, "save restores inventory and health")
	check(game.level.enemies[0].dead and game.level.doors[3].opened and game.secrets == 1, "save restores enemies, locks and secret statistics")
	check(game.player.keys.has("blue"), "save restores keys")
	# Full progression preserves inventory and resets level-local keys.
	game.complete_sector()
	check(game.state == "intermission", "exit shows level summary")
	game.next_sector()
	quiet_enemies()
	check(game.sector_index == 1 and game.state == "playing", "descends into second sector")
	check(game.player.owned.has(2) and game.player.ammo.bullets == 123 and game.player.keys.is_empty(), "inventory carries over; keycards are sector-local")
	pickup("chaingun").collect()
	pickup("launcher").collect()
	check(game.player.owned.has(3) and game.player.owned.has(4), "second sector unlocks heavy weapons")
	# A live projectile must hit a body, rather than passing through it.
	var victim: Demon = game.level.enemies[0]
	game.player.position = victim.position + Vector3(0, 0, 3)
	game.player.rotation.y = 0
	game.player.select_weapon(3)
	await frames()
	var rotary_health = victim.health
	game.player.cooldown = 0
	game.player.fire()
	check(victim.health < rotary_health and game.player.cooldown < 0.12, "rotary cannon uses rapid hitscan fire")
	var victim_health = victim.health
	game.launch_projectile(victim.position + Vector3(0, 1, 3), Vector3.FORWARD, "plasma", true)
	await frames(15)
	check(victim.health < victim_health, "projectile sweeps collide and inflict damage")
	game.player.health = 100
	game.player.armor = 0
	game.player.select_weapon(4)
	game.player.cooldown = 0
	var rockets = game.player.ammo.rockets
	game.player.fire()
	await frames(20)
	check(victim.dead and game.player.ammo.rockets == rockets - 1, "rocket launcher fires explosive projectile and spends ammunition")
	check(game.player.health < 100, "rocket splash also damages the shooter at close range")
	game.player.health = 100
	game.launch_projectile(game.player.position + Vector3(0, 1, 2), Vector3.FORWARD, "fireball", false)
	await frames(15)
	check(game.player.health < 100, "hostile fireball collides with and damages player")
	var barrel: ExplosiveBarrel = game.level.barrels[0]
	game.player.position = barrel.position + Vector3(0, 0, 4.3)
	game.player.health = 100
	game.player.armor = 0
	barrel.take_damage(100)
	await frames(3)
	check(barrel.destroyed and game.player.health < 100, "explosive barrel inflicts radial damage")
	game.complete_sector()
	game.next_sector()
	quiet_enemies()
	check(game.sector_index == 2, "third sector loads")
	check(not game.complete_sector(), "boss seals final exit while alive")
	var boss: Demon
	for demon in game.level.enemies:
		if demon.kind == "warden": boss = demon
	check(boss != null and boss.max_health > 1000, "final arena has boss encounter")
	pickup("plasma").collect()
	check(game.player.owned.has(5) and game.player.ammo.cells >= 100, "plasma unlock and ammo")
	game.player.cooldown = 0
	var cells = game.player.ammo.cells
	game.player.fire()
	check(game.player.ammo.cells == cells - 1, "plasma rifle spends cells when launching bolts")
	pickup("suit").collect()
	game.player.position = game.level.tile_position(Vector2i(9, 7))
	game.player.health = 100
	await frames(45)
	check(game.player.health == 100, "hazard suit protects against lava")
	game.player.suit_time = 0
	game.player.hazard_timer = 0
	await frames(3)
	check(game.player.health < 100, "unprotected lava deals damage")
	boss.take_damage(boss.max_health / 2 + 1)
	boss.set_physics_process(true)
	await frames(3)
	check(boss.was_boss_enraged, "Warden enters second phase below half health")
	boss.set_physics_process(false)
	boss.take_damage(9999)
	check(game.complete_sector(), "boss death unlocks final exit")
	game.next_sector()
	check(game.state == "victory", "campaign reaches victory epilogue")
	game.new_game(2)
	quiet_enemies()
	game.player.take_damage(9999)
	check(game.state == "dead", "lethal damage opens retry menu")
	game.menu_action("retry")
	check(game.state == "playing" and game.player.health == 100 and game.kills == 0, "retry restores sector checkpoint")
	print("DEAD SIGNAL: %d integration checks, %d failures" % [checks, failures.size()])
	game.queue_free()
	await process_frame
	await process_frame
	# Let the real-time audio mixer release refs after accelerated physics tests.
	OS.delay_msec(80)
	quit(0 if failures.is_empty() else 1)
