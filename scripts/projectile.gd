class_name RetroProjectile
extends Node3D

var game: Node3D
var direction: Vector3
var kind = "fireball"
var friendly = false
var speed = 12.0
var damage = 13
var lifetime = 6.0
var ignored: Array[RID] = []
var sprite: Sprite3D
var clock = 0.0
var artwork: Dictionary
const ART = preload("res://assets/presentation/art.gd").ART.sheets

func configure(owner_game: Node3D, pos: Vector3, dir: Vector3, projectile_kind: String, by_player: bool, shooter: CollisionObject3D = null) -> void:
	game = owner_game
	position = pos
	direction = dir.normalized()
	kind = projectile_kind
	friendly = by_player
	speed = {"rocket": 25.0, "plasma": 34.0, "fireball": 11.0, "hellbolt": 14.0}[kind]
	damage = {"rocket": 100, "plasma": 28, "fireball": 13, "hellbolt": 25}[kind]
	if shooter != null:
		ignored.append(shooter.get_rid())
	if friendly:
		ignored.append(game.player.get_rid())
	sprite = Sprite3D.new()
	artwork = ART[kind]
	sprite.texture = game.texture("presentation/" + kind)
	sprite.hframes = artwork.columns
	sprite.vframes = artwork.rows
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	var width = 0.4 if kind == "plasma" else 0.55 if kind == "rocket" else 0.8
	sprite.pixel_size = width / float(maxi(artwork.size[0], artwork.size[1]))
	add_child(sprite)

func _physics_process(delta: float) -> void:
	if game.state != "playing":
		return
	lifetime -= delta
	clock += delta
	if lifetime <= 0:
		queue_free()
		return
	var next = position + direction * speed * delta
	var mask = (1 | 4 | 8) if friendly else (1 | 2 | 8)
	var query = PhysicsRayQueryParameters3D.create(position, next, mask, ignored)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if hit.collider.has_method("take_damage"):
			hit.collider.take_damage(damage, direction)
		if kind == "rocket":
			game.spawn_effect(hit.position, "explosion", 0.45, 3.4)
			game.audio.play("explosion", -4)
			game.radial_damage(hit.position - direction * 0.08, 5.5, 100)
		else:
			game.spawn_effect(hit.position, "plasma" if kind == "plasma" else "explosion", 0.18, 0.7)
		queue_free()
		return
	position = next
	sprite.frame = int(clock * artwork.fps) % artwork.files.size()
	if kind == "rocket" and int(clock * 35) % 3 == 0:
		game.spawn_effect(position - direction * 0.25, "smoke", 0.22, 0.35)
