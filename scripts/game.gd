class_name DeadSignalGame
extends Node3D
## Session orchestration. Combat, world geometry, UI and assets live in focused modules.

const SAVE_PATH = "user://dead_signal.save"
const WORLD_ART = preload("res://assets/presentation/art.gd").ART
var state = "menu"
var back_state = "menu"
var level: RetroLevel
var player: Marine
var hud: RetroHUD
var audio: AudioDirector
var environment: Environment
var post: ColorRect
var texture_cache: Dictionary = {}
var sector_index = 0
var difficulty = 1
var kills = 0
var items = 0
var secrets = 0
var elapsed = 0.0
var campaign_totals: Dictionary = {"kills": 0, "items": 0, "secrets": 0, "time": 0.0}
var checkpoint: Dictionary = {}
var message = ""
var message_color = BrandTheme.ORANGE_LIGHT
var message_time = 0.0
var hit_marker = 0.0
var automap = false
var sensitivity = 0.0025
var music_volume = 0.65
var sfx_volume = 0.8
var always_run = false
var crosshair = true
var crt = true
var effects: Array = []
var transient_root: Node3D
var attract_time = 0.0
var testing = false
var browser: BrowserSupport

func _ready() -> void:
	testing = "--test" in OS.get_cmdline_user_args()
	_setup_input()
	audio = AudioDirector.new()
	add_child(audio)
	_load_settings()
	_setup_environment()
	player = Marine.new()
	add_child(player)
	player.configure(self)
	var ui_layer = CanvasLayer.new()
	ui_layer.layer = 2
	add_child(ui_layer)
	hud = RetroHUD.new()
	hud.game = self
	ui_layer.add_child(hud)
	var post_layer = CanvasLayer.new()
	post_layer.layer = 3
	add_child(post_layer)
	post = ColorRect.new()
	post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = load("res://shaders/retro.gdshader")
	shader_mat.set_shader_parameter("enabled", crt)
	post.material = shader_mat
	post_layer.add_child(post)
	_load_sector(0)
	_title_view()
	if OS.has_feature("web"):
		browser = BrowserSupport.new(self)
	set_state("menu")
	if not testing:
		get_window().focus_exited.connect(_focus_lost)

func texture(path: String) -> Texture2D:
	if not texture_cache.has(path):
		texture_cache[path] = load("res://assets/" + path + ".png")
	return texture_cache[path]

func _setup_input() -> void:
	var bindings = {
		"forward": [KEY_W], "back": [KEY_S], "left": [KEY_A], "right": [KEY_D],
		"turn_left": [KEY_LEFT], "turn_right": [KEY_RIGHT], "sprint": [KEY_SHIFT],
		"fire": [KEY_CTRL], "use": [KEY_E, KEY_SPACE], "map": [KEY_TAB]
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in bindings[action]:
			var event = InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire", click)

func _setup_environment() -> void:
	var world_env = WorldEnvironment.new()
	environment = Environment.new()
	var sky = Sky.new()
	var sky_material = PanoramaSkyMaterial.new()
	sky_material.panorama = texture("textures/sky")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.65, 0.6, 0.55)
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.12, 0.075, 0.07)
	environment.fog_light_energy = 0.6
	environment.fog_density = 0.009
	environment.fog_sky_affect = 0.0
	world_env.environment = environment
	add_child(world_env)

func _load_sector(index: int, inventory: Dictionary = {}) -> void:
	state = "loading"
	if level != null:
		remove_child(level)
		level.queue_free()
	if transient_root != null:
		remove_child(transient_root)
		transient_root.queue_free()
	effects.clear()
	transient_root = Node3D.new()
	transient_root.name = "ProjectilesAndEffects"
	add_child(transient_root)
	sector_index = index
	kills = 0
	items = 0
	secrets = 0
	elapsed = 0
	automap = false
	if not inventory.is_empty():
		player.restore(inventory)
	player.keys.clear()
	player.suit_time = 0
	level = RetroLevel.new()
	add_child(level)
	level.configure(self, index)
	player.position = level.tile_position(level.data.spawn)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.camera.position.y = 1.55
	checkpoint = player.snapshot()
	level.reveal(player.position)
	environment.fog_density = 0.009 if index == 0 else 0.012
	environment.fog_light_color = Color(0.11, 0.075, 0.06) if index != 1 else Color(0.075, 0.095, 0.07)
	hud.reset_portrait()

func new_game(mode: int = 1) -> void:
	difficulty = mode
	campaign_totals = {"kills": 0, "items": 0, "secrets": 0, "time": 0.0}
	_load_sector(0, {"health": 100, "armor": 0, "ammo": {"bullets": 80, "shells": 0, "rockets": 0, "cells": 0}, "owned": [0, 1], "keys": [], "weapon": 1})
	set_state("playing")
	notify("SECTOR 01 / THE SILENT FOUNDRY", BrandTheme.ORANGE_LIGHT, 4.0)
	if not testing:
		save_game(false)

func _process(delta: float) -> void:
	message_time = maxf(0, message_time - delta)
	hit_marker = maxf(0, hit_marker - delta)
	if state in ["menu", "difficulty"] or (state in ["help", "options"] and back_state == "menu"):
		attract_time += delta
		player.rotation.y = sin(attract_time * 0.16) * 0.3
	if state == "dead":
		player.camera.position.y = move_toward(player.camera.position.y, 0.4, delta * 1.2)
	if state == "playing":
		elapsed += delta
	for i in range(effects.size() - 1, -1, -1):
		var effect: Dictionary = effects[i]
		if not is_instance_valid(effect.node):
			effects.remove_at(i)
			continue
		if state == "playing":
			effect.time -= delta
			var progress = clampf(1.0 - effect.time / effect.duration, 0, 1)
			effect.node.frame = mini(effect.frames - 1, int(progress * effect.frames))
			effect.node.modulate.a = maxf(0, effect.time / effect.duration)
			effect.node.scale *= 1.0 + delta * 0.8
			if effect.time <= 0:
				effect.node.queue_free()
				effects.remove_at(i)
	hud.update_portrait(delta)
	hud.queue_redraw()

func set_state(next: String) -> void:
	state = next
	hud.selection = 0
	hud.hovered = -1
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if state == "playing" and not testing else Input.MOUSE_MODE_VISIBLE
	if browser != null:
		browser.state_changed(state)

func _input(event: InputEvent) -> void:
	if hud == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_P:
				if state in ["playing", "paused"]:
					set_state("paused" if state == "playing" else "playing")
					get_viewport().set_input_as_handled()
					return
			KEY_F11:
				var mode = DisplayServer.window_get_mode()
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
				get_viewport().set_input_as_handled()
				return
			KEY_ESCAPE:
				if state == "playing":
					if automap:
						automap = false
					else:
						set_state("paused")
				elif state == "paused":
					set_state("playing")
				elif state in ["options", "help"]:
					set_state(back_state)
				elif state == "difficulty":
					set_state("menu")
				get_viewport().set_input_as_handled()
				return
			KEY_F5:
				if state in ["playing", "paused"]:
					save_game()
				get_viewport().set_input_as_handled()
				return
			KEY_F9:
				load_game()
				get_viewport().set_input_as_handled()
				return
	if state != "playing":
		hud.handle_menu_input(event)
		get_viewport().set_input_as_handled()

func _focus_lost() -> void:
	if state == "playing":
		set_state("paused")

func _title_view() -> void:
	player.position = level.tile_position(Vector2i(14, 18))
	player.rotation = Vector3.ZERO
	player.camera.position.y = 1.55

func menu_action(action: String) -> void:
	audio.play("menu", -7)
	match action:
		"new": set_state("difficulty")
		"continue", "load": load_game()
		"easy": new_game(0)
		"normal": new_game(1)
		"hard": new_game(2)
		"resume": set_state("playing")
		"help", "options":
			back_state = state
			set_state(action)
		"back": set_state(back_state if state in ["help", "options"] else "menu")
		"save": save_game()
		"retry":
			_load_sector(sector_index, checkpoint.duplicate(true))
			set_state("playing")
			if not testing:
				save_game(false)
			notify("BACK IN THE FIGHT")
		"title":
			_load_sector(0)
			_title_view()
			set_state("menu")
		"next": next_sector()
		"quit": get_tree().quit()
		"music":
			music_volume = fposmod(music_volume + 0.25, 1.25)
			if music_volume > 1:
				music_volume = 0
			_apply_settings()
		"sfx":
			sfx_volume = fposmod(sfx_volume + 0.25, 1.25)
			if sfx_volume > 1:
				sfx_volume = 0
			_apply_settings()
		"sensitivity":
			sensitivity += 0.001
			if sensitivity > 0.0056:
				sensitivity = 0.0015
			_apply_settings()
		"run":
			always_run = not always_run
			_apply_settings()
		"crosshair":
			crosshair = not crosshair
			_apply_settings()
		"crt":
			crt = not crt
			_apply_settings()

func notify(text: String, color: Color = BrandTheme.ORANGE_LIGHT, duration: float = 2.6) -> void:
	message = text
	message_color = color
	message_time = duration

func near_interaction() -> Node3D:
	var closest: Node3D = null
	var distance = 3.1
	var forward = -player.transform.basis.z
	for door in level.doors:
		if door.opened:
			continue
		var offset: Vector3 = door.position - player.position
		if offset.length() < distance and forward.dot(offset.normalized()) > 0.15:
			closest = door
			distance = offset.length()
	var exit_offset = level.exit_position - player.position
	if exit_offset.length() < distance and forward.dot(exit_offset.normalized()) > -0.1:
		return level.exit_visual
	return closest

func interact() -> bool:
	var target = near_interaction()
	if target == level.exit_visual:
		return complete_sector()
	if target != null and target is RetroDoor:
		return target.activate()
	return false

func complete_sector() -> bool:
	if sector_index == 2:
		for enemy in level.enemies:
			if enemy.kind == "warden" and not enemy.dead:
				notify("THE SIGNAL STILL LIVES. KILL THE WARDEN.", Color(1, 0.5, 0.3))
				return false
	set_state("intermission")
	audio.play("key", -2)
	return true

func next_sector() -> void:
	campaign_totals.kills += kills
	campaign_totals.items += items
	campaign_totals.secrets += secrets
	campaign_totals.time += elapsed
	if sector_index == 2:
		set_state("victory")
		return
	var inventory = player.snapshot()
	inventory.health = maxi(50, inventory.health)
	_load_sector(sector_index + 1, inventory)
	set_state("playing")
	notify("SECTOR 0" + str(sector_index + 1) + " / " + level.data.name, BrandTheme.ORANGE_LIGHT, 4)
	if not testing:
		save_game(false)

func die() -> void:
	set_state("dead")
	audio.play("death", -1, 0.7)

func alert_enemies(pos: Vector3, radius: float) -> void:
	for demon in level.enemies:
		if demon.position.distance_to(pos) < radius:
			demon.alert()

func launch_projectile(pos: Vector3, direction: Vector3, kind: String, friendly: bool, shooter: CollisionObject3D = null) -> RetroProjectile:
	var projectile = RetroProjectile.new()
	transient_root.add_child(projectile)
	projectile.configure(self, pos, direction, kind, friendly, shooter)
	return projectile

func radial_damage(pos: Vector3, radius: float, amount: int) -> void:
	for target in level.enemies + level.barrels + [player]:
		if not is_instance_valid(target):
			continue
		var center: Vector3 = target.global_position + Vector3.UP * 0.8
		var distance = center.distance_to(pos)
		var query = PhysicsRayQueryParameters3D.create(pos, center, 1)
		var clear = get_world_3d().direct_space_state.intersect_ray(query).is_empty()
		if distance < radius and clear:
			target.take_damage(maxi(1, roundi(amount * (1 - distance / radius))), (center - pos).normalized())

func spawn_effect(pos: Vector3, kind: String, duration: float, size: float) -> void:
	var sprite = Sprite3D.new()
	var art_kind = "plasma_hit" if kind == "plasma" else kind
	var art: Dictionary = WORLD_ART.sheets[art_kind]
	sprite.texture = texture("presentation/" + art_kind)
	sprite.hframes = art.columns
	sprite.vframes = art.rows
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.pixel_size = size / float(maxi(art.size[0], art.size[1]))
	sprite.position = pos
	sprite.no_depth_test = false
	sprite.modulate = Color(0.5, 0.5, 0.5) if kind == "smoke" else Color.WHITE
	transient_root.add_child(sprite)
	effects.append({"node": sprite, "time": duration, "duration": duration, "frames": art.files.size()})

func save_game(show_message: bool = true, path: String = SAVE_PATH) -> bool:
	if player.health <= 0:
		return false
	var info = {
		"version": 1, "sector": sector_index, "difficulty": difficulty, "player": player.snapshot(),
		"position": player.position, "rotation": player.rotation.y, "kills": kills, "items": items,
		"secrets": secrets, "elapsed": elapsed, "totals": campaign_totals.duplicate(),
		"checkpoint": checkpoint.duplicate(true), "enemies": [], "pickups": [], "doors": [], "barrels": [],
		"explored": level.explored.duplicate()
	}
	for demon in level.enemies:
		info.enemies.append(demon.snapshot())
	for pickup in level.pickups:
		info.pickups.append({"active": pickup.active, "kind": pickup.kind, "position": pickup.position, "id": pickup.pickup_id})
	for door in level.doors:
		info.doors.append(door.opened)
	for barrel in level.barrels:
		info.barrels.append(barrel.destroyed)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		notify("SAVE FAILED", Color(1, 0.4, 0.3))
		return false
	file.store_var(info)
	file.close()
	if show_message:
		notify("RUN SAVED / F9 TO RESTORE")
		audio.play("menu")
	return true

func load_game(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		notify("NO SAVED RUN YET")
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var saved = file.get_var()
	file.close()
	if not saved is Dictionary or saved.get("version", 0) != 1 or saved.get("sector", -1) not in [0, 1, 2]:
		notify("SAVE COULD NOT BE READ")
		return false
	difficulty = int(saved.difficulty)
	_load_sector(int(saved.sector), saved.player)
	player.restore(saved.player)
	player.position = saved.position
	player.rotation.y = saved.rotation
	kills = saved.kills
	items = saved.items
	secrets = saved.secrets
	elapsed = saved.elapsed
	campaign_totals = saved.totals
	checkpoint = saved.checkpoint
	level.explored = saved.explored
	level.revealed_tiles.clear()
	for i in range(mini(saved.enemies.size(), level.enemies.size())):
		level.enemies[i].restore(saved.enemies[i])
	for i in range(saved.pickups.size()):
		var record: Dictionary = saved.pickups[i]
		if i >= level.pickups.size():
			level.add_pickup(record.kind, record.position, record.id)
		level.pickups[i].active = record.active
		level.pickups[i].visible = record.active
	for i in range(mini(saved.doors.size(), level.doors.size())):
		if saved.doors[i]:
			level.doors[i].restore_open()
	for i in range(mini(saved.barrels.size(), level.barrels.size())):
		if saved.barrels[i]:
			level.barrels[i].restore_destroyed()
	set_state("playing")
	notify("RUN RESTORED")
	return true

func _load_settings() -> void:
	var settings = ConfigFile.new()
	if settings.load("user://settings.cfg") == OK:
		sensitivity = float(settings.get_value("game", "sensitivity", sensitivity))
		music_volume = float(settings.get_value("game", "music", music_volume))
		sfx_volume = float(settings.get_value("game", "sfx", sfx_volume))
		always_run = bool(settings.get_value("game", "always_run", always_run))
		crosshair = bool(settings.get_value("game", "crosshair", crosshair))
		crt = bool(settings.get_value("game", "crt", crt))
	audio.set_volumes(music_volume, sfx_volume)

func _apply_settings() -> void:
	audio.set_volumes(music_volume, sfx_volume)
	post.material.set_shader_parameter("enabled", crt)
	var settings = ConfigFile.new()
	settings.set_value("game", "sensitivity", sensitivity)
	settings.set_value("game", "music", music_volume)
	settings.set_value("game", "sfx", sfx_volume)
	settings.set_value("game", "always_run", always_run)
	settings.set_value("game", "crosshair", crosshair)
	settings.set_value("game", "crt", crt)
	settings.save("user://settings.cfg")
