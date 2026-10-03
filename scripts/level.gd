class_name RetroLevel
extends Node3D

const TILE = 3.0
const SOLID = ["#", "C", "R"]
var game: Node3D
var data: Dictionary
var enemies: Array = []
var pickups: Array = []
var doors: Array = []
var barrels: Array = []
var explored: Dictionary = {}
var door_tiles: Dictionary = {}
var materials: Dictionary = {}
var surfaces: Dictionary = {}
var total_secrets = 0
var total_items = 0
var exit_position: Vector3
var exit_visual: MeshInstance3D
var navigation_revision = 0
var animation_clock = 0.0
var animation_frame = -1
var revealed_tiles: Dictionary = {}

const WORLD_ART = preload("res://assets/presentation/art.gd").ART

func _process(delta: float) -> void:
	if game == null or game.state not in ["playing", "menu", "difficulty"]:
		return
	animation_clock += delta
	var frame = int(animation_clock * 3)
	if frame == animation_frame:
		return
	animation_frame = frame
	for kind in WORLD_ART.animated_textures:
		if materials.has(kind):
			var frames: Array = WORLD_ART.animated_textures[kind]
			materials[kind].albedo_texture = game.texture("textures/" + frames[frame % frames.size()])

func configure(owner_game: Node3D, index: int) -> void:
	game = owner_game
	data = Campaign.build(index)
	_build_geometry()
	_build_entities()
	exit_position = tile_position(data.exit)
	var panel = QuadMesh.new()
	panel.size = Vector2(1.8, 1.8)
	exit_visual = MeshInstance3D.new()
	exit_visual.mesh = panel
	exit_visual.material_override = material("exit")
	exit_visual.position = exit_position + Vector3(0, 1.7, -1.25)
	add_child(exit_visual)

func tile_position(tile: Vector2i) -> Vector3:
	return Vector3((tile.x + 0.5) * TILE, 0, (tile.y + 0.5) * TILE)

func position_tile(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.z / TILE))

func cell(tile: Vector2i) -> String:
	if tile.x < 0 or tile.y < 0 or tile.x >= data.size.x or tile.y >= data.size.y:
		return "#"
	return data.grid[tile.y][tile.x]

func is_solid(tile: Vector2i) -> bool:
	return cell(tile) in SOLID

func material(kind: String) -> StandardMaterial3D:
	if materials.has(kind):
		return materials[kind]
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = game.texture("textures/" + kind)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	materials[kind] = mat
	return mat

func _surface(kind: String) -> SurfaceTool:
	if not surfaces.has(kind):
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(material(kind))
		surfaces[kind] = st
	return surfaces[kind]

func _quad(kind: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tint: Color, uv_scale: Vector2 = Vector2.ONE) -> void:
	var st = _surface(kind)
	var vertices = [a, b, c, d]
	var uvs = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_color(tint)
		st.set_uv(uvs[i] * uv_scale)
		st.add_vertex(vertices[i])

func _brightness(tile: Vector2i) -> float:
	var brightness = 0.58 if data.index == 0 else 0.51
	for lamp in data.lamps:
		var dist = Vector2(tile - lamp).length()
		brightness = maxf(brightness, 1.03 - dist * 0.12)
	return brightness

func _build_geometry() -> void:
	var collision = StaticBody3D.new()
	collision.name = "SectorCollision"
	collision.collision_layer = 1
	collision.collision_mask = 0
	add_child(collision)
	var floor_shape = BoxShape3D.new()
	floor_shape.size = Vector3(data.size.x * TILE, 0.3, data.size.y * TILE)
	var floor_collision = CollisionShape3D.new()
	floor_collision.shape = floor_shape
	floor_collision.position = Vector3(data.size.x * TILE / 2.0, -0.15, data.size.y * TILE / 2.0)
	collision.add_child(floor_collision)
	var h: float = data.height
	for y in range(data.size.y):
		for x in range(data.size.x):
			var tile = Vector2i(x, y)
			if is_solid(tile):
				var adjacent = false
				for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if not is_solid(tile + offset):
						adjacent = true
				if adjacent:
					var shape = BoxShape3D.new()
					shape.size = Vector3(TILE, h + 1.0, TILE)
					var collider = CollisionShape3D.new()
					collider.shape = shape
					collider.position = tile_position(tile) + Vector3.UP * (h / 2.0)
					collision.add_child(collider)
				continue
			var p = Vector3(x * TILE, 0, y * TILE)
			var brightness = _brightness(tile)
			var tint = Color(brightness, brightness * 0.94, brightness * 0.84)
			var floor_kind = {".": "floor", "g": "grate", "r": "rock", "a": "acid", "l": "lava", "D": "floor"}.get(cell(tile), "floor")
			var floor_tint = tint * Color(0.83, 0.83, 0.83) if floor_kind not in ["acid", "lava"] else Color(0.85, 0.85, 0.85)
			_quad(floor_kind, p, p + Vector3(TILE, 0, 0), p + Vector3(TILE, 0, TILE), p + Vector3(0, 0, TILE), floor_tint)
			if data.ceiling:
				var ceiling_kind = "light" if x % 4 == 2 and y % 4 == 2 else "ceiling"
				var ceiling_tint = Color(0.85, 0.82, 0.73) if ceiling_kind == "light" else tint * Color(0.49, 0.49, 0.49)
				_quad(ceiling_kind, p + Vector3(0, h, 0), p + Vector3(TILE, h, 0), p + Vector3(TILE, h, TILE), p + Vector3(0, h, TILE), ceiling_tint)
			for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var adjacent = tile + offset
				if not is_solid(adjacent):
					continue
				var wall_kind: String = {"C": "concrete", "R": "rust"}.get(cell(adjacent), data.wall)
				# Computer bays break up the foundry's metal walls.
				if data.index == 0 and offset == Vector2i.UP and (x + y) % 5 == 0:
					wall_kind = "computer"
				var shade_factor = 0.78 if offset.x != 0 else 1.0
				var color = tint * Color(shade_factor, shade_factor, shade_factor)
				match offset:
					Vector2i.UP: _quad(wall_kind, p, p + Vector3(TILE, 0, 0), p + Vector3(TILE, h, 0), p + Vector3(0, h, 0), color)
					Vector2i.DOWN: _quad(wall_kind, p + Vector3(0, 0, TILE), p + Vector3(TILE, 0, TILE), p + Vector3(TILE, h, TILE), p + Vector3(0, h, TILE), color)
					Vector2i.LEFT: _quad(wall_kind, p, p + Vector3(0, 0, TILE), p + Vector3(0, h, TILE), p + Vector3(0, h, 0), color)
					Vector2i.RIGHT: _quad(wall_kind, p + Vector3(TILE, 0, 0), p + Vector3(TILE, 0, TILE), p + Vector3(TILE, h, TILE), p + Vector3(TILE, h, 0), color)
	for kind in surfaces:
		var mesh = MeshInstance3D.new()
		mesh.name = "Geometry_" + kind
		mesh.mesh = surfaces[kind].commit()
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
	surfaces.clear()

func _build_entities() -> void:
	for info in data.doors:
		var node = RetroDoor.new()
		add_child(node)
		node.configure(game, self, info)
		doors.append(node)
		door_tiles[info.tile] = node
		if info.secret:
			total_secrets += 1
	for i in range(data.enemies.size()):
		var node = Demon.new()
		add_child(node)
		node.configure(game, data.enemies[i], i)
		enemies.append(node)
	for i in range(data.pickups.size()):
		add_pickup(data.pickups[i].kind, tile_position(data.pickups[i].tile), i)
	total_items = pickups.size()
	for info in data.props:
		if info.kind == "barrel":
			var node = ExplosiveBarrel.new()
			add_child(node)
			node.configure(game, tile_position(info.tile))
			barrels.append(node)
		else:
			var prop = RetroProp.new()
			add_child(prop)
			prop.configure(game, info.kind, tile_position(info.tile))

func add_pickup(kind: String, pos: Vector3, id: int = -1) -> void:
	var node = RetroPickup.new()
	add_child(node)
	node.configure(game, kind, pos, id)
	pickups.append(node)

func reveal(pos: Vector3) -> void:
	var center = position_tile(pos)
	if revealed_tiles.has(center):
		return
	revealed_tiles[center] = true
	for y in range(center.y - 5, center.y + 6):
		for x in range(center.x - 5, center.x + 6):
			var tile = Vector2i(x, y)
			if Vector2(tile - center).length_squared() < 30.25:
				explored[tile] = true

func path_between(from: Vector3, to: Vector3) -> Array:
	var start = position_tile(from)
	var target = position_tile(to)
	if start == target:
		return [to]
	var frontier: Array = [start]
	var visited: Dictionary = {start: start}
	var cursor = 0
	while cursor < frontier.size():
		var current: Vector2i = frontier[cursor]
		cursor += 1
		if current == target:
			break
		for offset in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next: Vector2i = current + offset
			if visited.has(next) or is_solid(next):
				continue
			if door_tiles.has(next):
				var door_node = door_tiles[next]
				if not door_node.opened and (door_node.key != "" or door_node.secret):
					continue
			visited[next] = current
			frontier.append(next)
	if not visited.has(target):
		return []
	var path: Array = []
	var step = target
	while step != start:
		path.push_front(tile_position(step))
		step = visited[step]
	return path

func line_of_sight(a: Vector3, b: Vector3) -> bool:
	var query = PhysicsRayQueryParameters3D.create(a, b, 1 | 8)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
