class_name RetroHUD
extends Control
## All UI is drawn on the same 480x270 pixel canvas as the game.

const PAPER = BrandTheme.TEXT
const DIM = BrandTheme.MUTED
const AMBER = BrandTheme.ORANGE
const RED = BrandTheme.DANGER
const GREEN = BrandTheme.SUCCESS
var game: Node3D
var selection = 0
var hovered = -1
var weapon_view = WeaponView.new()
const PORTRAITS = RedotPortrait.ART
var portrait = RedotPortrait.new()
var portrait_view: SubViewport
var portrait_material: ShaderMaterial

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_view = SubViewport.new()
	portrait_view.size = Vector2i(PORTRAITS.size[0], PORTRAITS.size[1])
	portrait_view.disable_3d = true
	portrait_view.transparent_bg = true
	portrait_view.gui_disable_input = true
	portrait_view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(portrait_view)
	var image = TextureRect.new()
	image.texture = game.texture("ui/redot_chan/portraits")
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.size = Vector2(portrait_view.size)
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_material = ShaderMaterial.new()
	portrait_material.shader = preload("res://shaders/portrait_blend.gdshader")
	image.material = portrait_material
	portrait_view.add_child(image)
	game.player.pickup_collected.connect(portrait.on_pickup)
	game.player.damaged.connect(portrait.on_damage)
	reset_portrait()

func reset_portrait() -> void:
	portrait.reset(game.player)
	portrait_material.set_shader_parameter("weights", portrait.weights)

func update_portrait(delta: float) -> void:
	portrait.update(game.player, game.state, delta)
	portrait_material.set_shader_parameter("weights", portrait.weights)

func _draw() -> void:
	if game.level == null:
		return
	if game.state in ["playing", "paused", "dead", "intermission", "victory"] or (game.state in ["options", "help"] and game.back_state == "paused"):
		if game.automap:
			_draw_map()
		else:
			_draw_weapon()
			_draw_reticle()
		_draw_status()
		if game.state == "playing":
			_draw_game_info()
		if game.player.hurt_flash > 0:
			draw_rect(Rect2(0, 0, 480, 224), Color(0.7, 0.05, 0.02, game.player.hurt_flash * 0.65))
		elif game.player.bonus_flash > 0:
			draw_rect(Rect2(0, 0, 480, 224), Color(1.0, 0.23, 0.04, game.player.bonus_flash * 0.4))
	match game.state:
		"menu", "difficulty": _draw_title()
		"paused": _draw_paused()
		"help": _draw_help()
		"options": _draw_options()
		"dead": _draw_death()
		"intermission": _draw_intermission()
		"victory": _draw_victory()
	if game.state != "playing":
		_draw_menu_items()
	if game.message_time > 0 and game.state in ["playing", "paused"]:
		PixelFont.text(self, game.message, Vector2(9, 9), game.message_color)

func _panel(rect: Rect2, color: Color = Color(0.07, 0.07, 0.085, 0.98)) -> void:
	draw_rect(rect, color)
	draw_texture_rect(game.texture("ui/panel"), rect, true, Color(1, 1, 1, color.a))
	draw_rect(rect, BrandTheme.BORDER, false)
	draw_line(rect.position + Vector2(5, 0), rect.position + Vector2(25, 0), BrandTheme.ORANGE)

func _stripe(y: int, width: int = 480) -> void:
	draw_rect(Rect2(0, y, width, 1), BrandTheme.BORDER)
	draw_rect(Rect2(width / 2.0 - 40, y, 80, 1), BrandTheme.ORANGE)
	draw_rect(Rect2(width / 2.0 - 18, y + 1, 36, 1), Color(1, 0.23, 0.04, 0.25))

func _brand_header(at: Vector2 = Vector2(14, 12)) -> void:
	# Compact pixel adaptation of the site's orange Redot mark.
	var points = PackedVector2Array([Vector2(2, 3), Vector2(5, 0), Vector2(11, 0), Vector2(14, 3), Vector2(12, 6), Vector2(8, 8), Vector2(4, 6)])
	for i in range(points.size()): points[i] += at
	draw_colored_polygon(points, BrandTheme.ORANGE)
	draw_rect(Rect2(at + Vector2(3, 8), Vector2(10, 5)), BrandTheme.ORANGE)
	draw_rect(Rect2(at + Vector2(5, 9), Vector2(2, 1)), BrandTheme.BACKGROUND)
	draw_rect(Rect2(at + Vector2(9, 9), Vector2(2, 1)), BrandTheme.BACKGROUND)
	PixelFont.text(self, "MADE WITH REDOT", at + Vector2(22, 3), PAPER)

func _logo() -> void:
	draw_texture_rect(game.texture("ui/logo"), Rect2(32, 30, 416, 64), false)

func _draw_title() -> void:
	draw_rect(Rect2(0, 0, 480, 270), Color(0.035, 0.035, 0.043, 0.88))
	draw_texture_rect(game.texture("ui/brand_background"), Rect2(0, 0, 480, 270), false, Color(1, 1, 1, 0.87))
	_stripe(0)
	_brand_header()
	PixelFont.text(self, "FS-09 / NO SIGNAL", Vector2(370, 15), AMBER)
	_logo()
	PixelFont.centered(self, "THE DEAD ARE ON THE OTHER END.", 99, PAPER)
	if game.state == "difficulty":
		PixelFont.centered(self, "CHOOSE YOUR FATE", 126, AMBER)
		var desc = ["HALF DAMAGE. EXPLORE THE FACILITY.", "THE CLASSIC EXPERIENCE.", "NO MERCY. KEEP MOVING.", ""][clampi(selection, 0, 3)]
		PixelFont.centered(self, desc, 243, DIM)
	else:
		PixelFont.centered(self, "REDOT-CHAN / FACILITY 09", 115, DIM)
		PixelFont.centered(self, "ARROWS / ENTER  OR  CLICK TO SELECT", 248, DIM)
	_stripe(265)

func _draw_weapon() -> void:
	weapon_view.draw(self, game)

func _draw_reticle() -> void:
	if not game.crosshair or game.automap or game.state == "dead":
		return
	var color = Color(0.75, 0.78, 0.62, 0.8) if game.hit_marker <= 0 else AMBER
	for offset in [-5, 3]:
		draw_rect(Rect2(240 + offset, 135, 3, 1), color)
		draw_rect(Rect2(240, 135 + offset, 1, 3), color)
	if game.hit_marker > 0:
		for x in [-1, 1]:
			for y in [-1, 1]:
				draw_line(Vector2(240 + x * 7, 135 + y * 7), Vector2(240 + x * 10, 135 + y * 10), AMBER)

func _draw_status() -> void:
	var player = game.player
	draw_texture_rect(game.texture("ui/status"), Rect2(0, 224, 480, 46), false)
	draw_line(Vector2(0, 224), Vector2(480, 224), BrandTheme.ORANGE)
	draw_line(Vector2(0, 225), Vector2(480, 225), Color("39180f"))
	for x in [79, 164, 207, 290, 398]:
		draw_line(Vector2(x, 226), Vector2(x, 270), BrandTheme.BACKGROUND)
		draw_line(Vector2(x + 1, 226), Vector2(x + 1, 270), BrandTheme.BORDER)
	PixelFont.text(self, "AMMO", Vector2(23, 229), DIM)
	PixelFont.text(self, "HEALTH", Vector2(99, 229), DIM)
	PixelFont.text(self, "ARMOR", Vector2(234, 229), DIM)
	PixelFont.text(self, "ARSENAL", Vector2(321, 229), DIM)
	PixelFont.text(self, "KEYS", Vector2(427, 229), DIM)
	var weapon = Arsenal.definition(player.weapon)
	var ammunition = "--" if weapon.ammo == "" else str(player.ammo[weapon.ammo])
	PixelFont.text(self, ammunition, Vector2(39 - PixelFont.width(ammunition, 3) / 2.0, 241), AMBER, 3)
	PixelFont.text(self, str(player.health), Vector2(116 - PixelFont.width(str(player.health), 3) / 2.0, 241), RED if player.health < 30 else PAPER, 3)
	PixelFont.text(self, "%", Vector2(149, 255), DIM)
	PixelFont.text(self, str(player.armor), Vector2(246 - PixelFont.width(str(player.armor), 3) / 2.0, 241), PAPER, 3)
	PixelFont.text(self, "%", Vector2(276, 255), DIM)
	_panel(Rect2(167, 227, 37, 40), Color(0.035, 0.035, 0.043))
	var portrait_size = Vector2(PORTRAITS.size[0], PORTRAITS.size[1])
	var portrait_scale = minf(37.0 / portrait_size.x, 39.0 / portrait_size.y)
	var displayed = portrait_size * portrait_scale
	draw_texture_rect(portrait_view.get_texture(), Rect2(Vector2(185.5, 247.5) - displayed / 2.0, displayed), false)
	_resource_bar(Rect2(86, 265, 70, 2), float(player.health) / 100.0, RED if player.health < 30 else GREEN)
	_resource_bar(Rect2(214, 265, 69, 2), float(player.armor) / 200.0, BrandTheme.ORANGE_LIGHT)
	if weapon.ammo != "":
		_resource_bar(Rect2(8, 265, 64, 2), float(player.ammo[weapon.ammo]) / Arsenal.AMMO_MAX[weapon.ammo], AMBER)
	for i in range(6):
		var pos = Vector2(310 + (i % 3) * 28, 242 + (i / 3) * 13)
		if player.weapon == i:
			draw_rect(Rect2(pos - Vector2(4, 2), Vector2(15, 11)), BrandTheme.ORANGE)
		PixelFont.text(self, str(i + 1), pos, BrandTheme.BACKGROUND if player.weapon == i else PAPER if player.owned.has(i) else Color("4b4b53"), 1, player.weapon != i)
	for i in range(2):
		var key = ["blue", "red"][i]
		if player.keys.has(key):
			draw_texture_rect(game.texture("sprites/" + key + "key"), Rect2(411 + i * 29, 241, 27, 27), false)
		else:
			draw_rect(Rect2(417 + i * 29, 249, 14, 7), Color(0.12, 0.16, 0.17))

func _draw_game_info() -> void:
	PixelFont.text(self, "S0" + str(game.sector_index + 1), Vector2(450, 9), DIM)
	if not game.automap:
		var target = game.near_interaction()
		if target != null:
			var hint = "E / EXIT SECTOR"
			if target is RetroDoor:
				hint = "E / SEARCH WALL" if target.secret else "E / OPEN DOOR"
				if target.key != "" and not game.player.keys.has(target.key):
					hint = "LOCKED / " + target.key.to_upper() + " KEYCARD REQUIRED"
			PixelFont.centered(self, hint, 204, AMBER)
		elif game.elapsed < 10:
			PixelFont.centered(self, "WASD MOVE / E USE / TAB MAP", 211, PAPER)
		else:
			var label = Arsenal.definition(game.player.weapon).name
			PixelFont.text(self, label, Vector2(471 - PixelFont.width(label), 212), DIM)
	if game.player.suit_time > 0:
		PixelFont.text(self, "SUIT " + str(ceili(game.player.suit_time)) + "S", Vector2(9, 211), GREEN)
	for enemy in game.level.enemies:
		if enemy.kind == "warden" and enemy.alerted and not enemy.dead:
			_panel(Rect2(137, 23, 206, 13), Color(0.045, 0.04, 0.035))
			draw_rect(Rect2(139, 25, 202 * float(enemy.health) / enemy.max_health, 3), RED)
			PixelFont.centered(self, "THE WARDEN", 30, AMBER)

func _draw_map() -> void:
	draw_rect(Rect2(0, 0, 480, 224), BrandTheme.BACKGROUND)
	var level = game.level
	var scale = mini(7, floori(198.0 / level.data.size.y))
	var origin = Vector2((480 - level.data.size.x * scale) / 2.0, 13)
	for y in range(level.data.size.y):
		for x in range(level.data.size.x):
			var tile = Vector2i(x, y)
			if not level.explored.has(tile):
				continue
			var color = BrandTheme.SURFACE
			if level.is_solid(tile):
				var at = origin + Vector2(tile) * scale
				for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					if level.is_solid(tile + offset):
						continue
					var start = at
					var end = at
					match offset:
						Vector2i.UP: end += Vector2(scale, 0)
						Vector2i.DOWN:
							start += Vector2(0, scale - 1)
							end += Vector2(scale, scale - 1)
						Vector2i.LEFT: end += Vector2(0, scale)
						Vector2i.RIGHT:
							start += Vector2(scale - 1, 0)
							end += Vector2(scale - 1, scale)
					draw_line(start, end, BrandTheme.ORANGE_LIGHT)
				continue
			elif level.cell(tile) in ["l", "a"]:
				color = Color(0.45, 0.18, 0.09) if level.cell(tile) == "l" else Color(0.25, 0.36, 0.14)
			draw_rect(Rect2(origin + Vector2(tile) * scale, Vector2.ONE * (scale - 1)), color)
	for door in level.doors:
		if not level.explored.has(door.tile):
			continue
		var color = Color("3974b3") if door.key == "blue" else RED if door.key == "red" else DIM
		if door.secret and not door.opened:
			color = Color(0.35, 0.3, 0.23)
		draw_rect(Rect2(origin + Vector2(door.tile) * scale, Vector2.ONE * (scale - 1)), color * (0.35 if door.opened else 1.0))
	for pickup in level.pickups:
		var tile = level.position_tile(pickup.position)
		if pickup.active and level.explored.has(tile):
			var color = AMBER
			if pickup.kind == "bluekey": color = Color("5bafff")
			elif pickup.kind == "redkey": color = RED
			elif pickup.kind == "medkit": color = GREEN
			draw_rect(Rect2(origin + Vector2(tile) * scale + Vector2(2, 2), Vector2(2, 2)), color)
	for demon in level.enemies:
		var tile = level.position_tile(demon.position)
		if not demon.dead and demon.alerted and level.explored.has(tile):
			draw_rect(Rect2(origin + Vector2(tile) * scale + Vector2(1, 1), Vector2(3, 3)), RED)
	var p = origin + Vector2(game.player.position.x, game.player.position.z) / RetroLevel.TILE * scale
	var direction = Vector2(-sin(game.player.rotation.y), -cos(game.player.rotation.y))
	var side = direction.orthogonal()
	draw_colored_polygon(PackedVector2Array([p + direction * 5, p - direction * 3 + side * 3, p - direction * 3 - side * 3]), GREEN)
	var exit_tile: Vector2i = level.data.exit
	if level.explored.has(exit_tile):
		draw_rect(Rect2(origin + Vector2(exit_tile) * scale, Vector2.ONE * (scale - 1)), GREEN)
	PixelFont.text(self, "SECTOR 0" + str(game.sector_index + 1) + " / AUTOMAP", Vector2(9, 9), PAPER)
	PixelFont.text(self, "TAB TO CLOSE / MOVEMENT REMAINS ACTIVE", Vector2(9, 212), DIM)
	PixelFont.text(self, "KILLS " + str(game.kills) + "/" + str(level.enemies.size()), Vector2(342, 212), RED)

func _dim_screen(alpha: float = 0.83) -> void:
	draw_rect(Rect2(0, 0, 480, 270), Color(0.035, 0.035, 0.043, alpha))

func _draw_paused() -> void:
	_dim_screen(0.66)
	_panel(Rect2(102, 37, 276, 195))
	PixelFont.centered(self, "PAUSED", 53, AMBER, 3)
	PixelFont.centered(self, "REDOT-CHAN / SIGNAL ON HOLD", 81, DIM)
	PixelFont.centered(self, "SAVE / LOAD IN MENU / P TO RESUME" if OS.has_feature("web") else "F5 SAVE / F9 LOAD / ESC RESUME", 217, DIM)

func _draw_help() -> void:
	_dim_screen()
	PixelFont.centered(self, "FIELD MANUAL", 20, AMBER, 3)
	_panel(Rect2(20, 53, 440, 180))
	PixelFont.text(self, "MOVEMENT / COMBAT", Vector2(34, 66), AMBER)
	var rows = [
		["W A S D", "MOVE / STRAFE"], ["MOUSE / ARROWS", "TURN LEFT / RIGHT"],
		["SHIFT", "RUN"], ["LEFT CLICK / CTRL", "FIRE / HOLD TO REPEAT"],
		["1 - 6 / WHEEL", "SELECT WEAPON"], ["E / SPACE", "OPEN DOORS / USE EXIT"],
		["TAB", "AUTOMAP"], ["F5 / F9", "QUICKSAVE / QUICKLOAD"], ["P / ESC / F11", "PAUSE / FULLSCREEN"]
	]
	for i in range(rows.size()):
		PixelFont.text(self, rows[i][0], Vector2(34, 81 + i * 12), PAPER)
		PixelFont.text(self, rows[i][1], Vector2(191, 81 + i * 12), DIM)
	PixelFont.text(self, "MISSION / FIND KEYCARDS. FOLLOW SIGNAL. REACH EXIT.", Vector2(34, 196), GREEN)
	PixelFont.text(self, "SEARCH ODD WALLS FOR SECRETS. BARRELS EXPLODE.", Vector2(34, 209), DIM)
	PixelFont.text(self, "CLASSIC AUTO-AIM / NO JUMPING / NO RELOADING", Vector2(34, 222), DIM)

func _draw_options() -> void:
	_dim_screen()
	_panel(Rect2(82, 27, 316, 218))
	PixelFont.centered(self, "OPTIONS", 40, AMBER, 3)
	PixelFont.centered(self, "ENTER OR LEFT / RIGHT TO CHANGE", 224, DIM)

func _draw_death() -> void:
	_dim_screen(0.57)
	draw_rect(Rect2(0, 0, 480, 270), Color(0.22, 0.01, 0, 0.28))
	PixelFont.centered(self, "YOU DIED", 64, RED, 5)
	PixelFont.centered(self, "THE FACILITY CLAIMS ANOTHER.", 112, PAPER)
	PixelFont.centered(self, "RETRY STARTS AT THIS SECTOR'S CHECKPOINT", 215, DIM)

func _draw_intermission() -> void:
	_dim_screen(0.92)
	_stripe(0)
	PixelFont.centered(self, "SECTOR 0" + str(game.sector_index + 1) + " / CLEARED", 24, GREEN)
	PixelFont.centered(self, game.level.data.name, 49, AMBER, 3)
	draw_line(Vector2(91, 88), Vector2(389, 88), BrandTheme.BORDER)
	var stats = [["KILLS", game.kills, game.level.enemies.size()], ["ITEMS", game.items, game.level.total_items], ["SECRETS", game.secrets, game.level.total_secrets]]
	for i in range(3):
		PixelFont.text(self, stats[i][0], Vector2(108, 107 + i * 29), PAPER, 2)
		var value = str(stats[i][1]) + " / " + str(stats[i][2])
		PixelFont.text(self, value, Vector2(380 - PixelFont.width(value, 2), 107 + i * 29), RED if i == 0 else AMBER, 2)
		_resource_bar(Rect2(108, 127 + i * 29, 272, 3), float(stats[i][1]) / maxf(1, stats[i][2]), RED if i == 0 else AMBER)
	PixelFont.text(self, "TIME " + _time(game.elapsed), Vector2(108, 203), DIM)
	PixelFont.text(self, "PAR " + _time(game.level.data.par), Vector2(294, 203), DIM)
	_stripe(265)

func _draw_victory() -> void:
	_dim_screen(0.93)
	_stripe(0)
	PixelFont.centered(self, "SIGNAL LOST", 38, AMBER, 5)
	PixelFont.centered(self, "THE WARDEN IS DEAD. THE GATE IS CLOSED.", 99, GREEN)
	var lines = ["FOR THE FIRST TIME IN NINE DAYS,", "THE RADIO FALLS SILENT.", "YOU STEP INTO THE ASHEN MORNING.", "THERE IS NOTHING LEFT TO ANSWER."]
	for i in range(lines.size()):
		PixelFont.centered(self, lines[i], 122 + i * 14, PAPER)
	PixelFont.centered(self, "TOTAL KILLS " + str(game.campaign_totals.kills) + " / TIME " + _time(game.campaign_totals.time), 192, DIM)
	PixelFont.centered(self, "THANK YOU FOR PLAYING DEAD SIGNAL", 211, RED)
	_stripe(265)

func _time(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func _resource_bar(rect: Rect2, amount: float, color: Color) -> void:
	draw_rect(rect, Color("242429"))
	var fill = rect
	fill.size.x = floorf(rect.size.x * clampf(amount, 0, 1))
	draw_rect(fill, color)

func menu_items() -> Array:
	match game.state:
		"menu":
			var options = [["ENTER THE FACILITY", "new"]]
			if FileAccess.file_exists(game.SAVE_PATH):
				options.append(["CONTINUE RUN", "continue"])
			options.append_array([["FIELD MANUAL", "help"], ["OPTIONS", "options"]])
			if not OS.has_feature("web"):
				options.append(["QUIT", "quit"])
			return options
		"difficulty": return [["EXPLORER", "easy"], ["MARINE", "normal"], ["NIGHTMARE", "hard"], ["BACK", "back"]]
		"paused": return [["RESUME", "resume"], ["SAVE RUN", "save"], ["LOAD RUN", "load"], ["FIELD MANUAL", "help"], ["OPTIONS", "options"], ["RETURN TO TITLE", "title"]]
		"help": return [["BACK", "back"]]
		"options": return [
			["MUSIC       " + str(roundi(game.music_volume * 100)) + "%", "music"],
			["SOUND FX    " + str(roundi(game.sfx_volume * 100)) + "%", "sfx"],
			["MOUSE SPEED " + str(roundi(game.sensitivity * 1000)), "sensitivity"],
			["ALWAYS RUN  " + ("ON" if game.always_run else "OFF"), "run"],
			["CROSSHAIR   " + ("ON" if game.crosshair else "OFF"), "crosshair"],
			["CRT FILTER  " + ("ON" if game.crt else "OFF"), "crt"], ["BACK", "back"]]
		"dead": return [["RETRY CHECKPOINT", "retry"], ["RETURN TO TITLE", "title"]]
		"intermission": return [["TERMINATE SIGNAL" if game.sector_index == 2 else "DESCEND TO SECTOR 0" + str(game.sector_index + 2), "next"]]
		"victory": return [["RETURN TO TITLE", "title"]]
	return []

func menu_rects() -> Array[Rect2]:
	var count = menu_items().size()
	var y = 135
	var spacing = 21
	match game.state:
		"menu":
			y = 138 if count == 4 else 126
			spacing = 24
		"difficulty":
			y = 142
			spacing = 24
		"paused":
			y = 99
			spacing = 20
		"options":
			y = 79
			spacing = 20
		"help": y = 241
		"dead":
			y = 152
			spacing = 26
		"intermission", "victory": y = 237
	var result: Array[Rect2] = []
	for i in range(count):
		result.append(Rect2(103, y + i * spacing - 4, 274, 20))
	return result

func _draw_menu_items() -> void:
	var options = menu_items()
	var rects = menu_rects()
	selection = clampi(selection, 0, maxi(0, options.size() - 1))
	for i in range(options.size()):
		var selected = i == selection
		var rect: Rect2 = rects[i]
		if selected:
			draw_rect(Rect2(rect.position + Vector2(2, 0), rect.size - Vector2(4, 0)), BrandTheme.ORANGE)
			draw_rect(Rect2(rect.position + Vector2(0, 2), rect.size - Vector2(0, 4)), BrandTheme.ORANGE)
			PixelFont.text(self, ">", rect.position + Vector2(10, 5), BrandTheme.BACKGROUND, 1, false)
		else:
			draw_rect(rect, Color(0.05, 0.05, 0.06, 0.88))
			draw_rect(rect, BrandTheme.BORDER, false)
		var label: String = options[i][0]
		PixelFont.text(self, label, Vector2((480 - PixelFont.width(label, 2)) / 2.0, rect.position.y + 3), BrandTheme.BACKGROUND if selected else PAPER, 2, not selected)

func handle_menu_input(event: InputEvent) -> void:
	var options = menu_items()
	if options.is_empty():
		return
	if event is InputEventMouseMotion:
		var rects = menu_rects()
		hovered = -1
		for i in range(rects.size()):
			if rects[i].has_point(get_global_mouse_position()):
				hovered = i
				selection = i
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var rects = menu_rects()
		for i in range(rects.size()):
			if rects[i].has_point(get_global_mouse_position()):
				selection = i
				game.menu_action(options[i][1])
				return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_UP, KEY_W:
				selection = posmod(selection - 1, options.size())
				game.audio.play("menu", -11)
			KEY_DOWN, KEY_S:
				selection = posmod(selection + 1, options.size())
				game.audio.play("menu", -11)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				game.menu_action(options[selection][1])
			KEY_LEFT, KEY_RIGHT:
				if game.state == "options":
					game.menu_action(options[selection][1])
