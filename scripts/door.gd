class_name RetroDoor
extends Node3D

var game: Node3D
var level: RetroLevel
var tile: Vector2i
var key = ""
var secret = false
var opened = false
var progress = 0.0
var moving: StaticBody3D
var collision: CollisionShape3D
var indicator_material: StandardMaterial3D
var access_color = Color.WHITE

func configure(owner_game: Node3D, owner_level: RetroLevel, info: Dictionary) -> void:
	game = owner_game
	level = owner_level
	tile = info.tile
	key = info.key
	secret = info.secret
	position = level.tile_position(tile)
	var along_z = not level.is_solid(tile + Vector2i.UP) and not level.is_solid(tile + Vector2i.DOWN)
	if not along_z:
		rotation.y = PI / 2.0
	moving = StaticBody3D.new()
	moving.collision_layer = 1
	moving.collision_mask = 0
	add_child(moving)
	var shape = BoxShape3D.new()
	shape.size = Vector3(3.0, level.data.height, 0.32)
	collision = CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = level.data.height / 2.0
	moving.add_child(collision)
	var mesh = MeshInstance3D.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h: float = level.data.height
	var front = [Vector3(-1.5, 0, 0.17), Vector3(1.5, 0, 0.17), Vector3(1.5, h, 0.17), Vector3(-1.5, h, 0.17)]
	var back = [Vector3(1.5, 0, -0.17), Vector3(-1.5, 0, -0.17), Vector3(-1.5, h, -0.17), Vector3(1.5, h, -0.17)]
	var uvs = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for face in [front, back]:
		for i in [0, 1, 2, 0, 2, 3]:
			var shade = level._brightness(tile) if secret else 0.82
			st.set_color(Color(shade, shade * 0.94, shade * 0.86))
			st.set_uv(uvs[i])
			st.add_vertex(face[i])
	mesh.mesh = st.commit()
	var kind = "door" if key == "" else "door_" + key
	if secret:
		kind = level.data.wall
	mesh.material_override = level.material(kind)
	moving.add_child(mesh)
	if not secret:
		for z in [-0.19, 0.19]:
			var sign = Sprite3D.new()
			sign.texture = PixelFont.sign_texture("ACCESS" if key == "" else key.to_upper() + " CARD", Color("e9b56e") if key == "" else Color("70b7f0") if key == "blue" else Color("e36a4d"))
			sign.pixel_size = 0.05
			sign.position = Vector3(0, h - 0.42, z)
			sign.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			if z < 0:
				sign.rotation.y = PI
			moving.add_child(sign)
	if secret:
		return
	for x in [-1.43, 1.43]:
		var frame = MeshInstance3D.new()
		var beam = BoxMesh.new()
		beam.size = Vector3(0.16, level.data.height, 0.55)
		frame.mesh = beam
		frame.position = Vector3(x, level.data.height / 2.0, 0)
		frame.material_override = level.material("door_track")
		add_child(frame)
	var header = MeshInstance3D.new()
	var rail = BoxMesh.new()
	rail.size = Vector3(3.0, 0.17, 0.55)
	header.mesh = rail
	header.position.y = h - 0.085
	header.material_override = level.material("door_track")
	add_child(header)
	indicator_material = StandardMaterial3D.new()
	indicator_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for z in [-0.32, 0.32]:
		var reader = MeshInstance3D.new()
		var reader_box = BoxMesh.new()
		reader_box.size = Vector3(0.19, 0.37, 0.13)
		reader.mesh = reader_box
		reader.position = Vector3(1.33, 1.65, z)
		reader.material_override = level.material("door_track")
		add_child(reader)
		var lamp = MeshInstance3D.new()
		var lens = BoxMesh.new()
		lens.size = Vector3(0.12, 0.08, 0.02)
		lamp.mesh = lens
		lamp.position = Vector3(1.33, 1.73, z + (0.08 if z > 0 else -0.08))
		lamp.material_override = indicator_material
		add_child(lamp)
	update_indicator()

func update_indicator() -> void:
	if indicator_material == null:
		return
	var authorized = key == "" or game.player.keys.has(key)
	access_color = Color("99d882") if opened or authorized else Color("548fd4") if key == "blue" else Color("dc5946")
	indicator_material.albedo_color = access_color

func _process(_delta: float) -> void:
	if game != null:
		update_indicator()

func activate(by_player: bool = true) -> bool:
	if opened:
		return false
	if key != "" and not game.player.keys.has(key):
		if by_player:
			game.notify("YOU NEED THE " + key.to_upper() + " KEYCARD", Color(1, 0.55, 0.3))
			game.audio.play("empty")
		return false
	if secret and not by_player:
		return false
	opened = true
	level.navigation_revision += 1
	game.audio.play("door", -5.0)
	if secret:
		game.secrets += 1
		game.notify("A SECRET IS REVEALED!", Color(1, 0.8, 0.35))
		game.audio.play("key")
	return true

func _physics_process(delta: float) -> void:
	if game == null or game.state != "playing":
		return
	if opened and progress < 1.0:
		progress = minf(1.0, progress + delta * 0.95)
		moving.position.y = progress * (level.data.height + 0.2)
		if progress >= 1.0:
			collision.disabled = true

func restore_open() -> void:
	opened = true
	progress = 1.0
	moving.position.y = level.data.height + 0.2
	collision.set_deferred("disabled", true)
