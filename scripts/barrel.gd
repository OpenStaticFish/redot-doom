class_name ExplosiveBarrel
extends StaticBody3D

var game: Node3D
var health = 25
var destroyed = false
var sprite: Sprite3D
var clock = 0.0
const ART = preload("res://assets/presentation/art.gd").ART.sheets.barrel

func configure(owner_game: Node3D, pos: Vector3) -> void:
	game = owner_game
	position = pos
	collision_layer = 8
	collision_mask = 0
	var shape = CylinderShape3D.new()
	shape.radius = 0.48
	shape.height = 1.7
	var collider = CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.85
	add_child(collider)
	sprite = Sprite3D.new()
	sprite.texture = game.texture("presentation/barrel")
	sprite.hframes = ART.columns
	sprite.vframes = ART.rows
	sprite.pixel_size = 1.7 / float(ART.size[1])
	sprite.position.y = 0.875
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	add_child(sprite)

func _process(delta: float) -> void:
	if game == null or game.state != "playing" or destroyed:
		return
	clock += delta
	sprite.frame = int(clock * ART.fps) % ART.files.size()

func take_damage(amount: int, _direction: Vector3 = Vector3.ZERO) -> void:
	if destroyed:
		return
	health -= amount
	if health <= 0:
		destroyed = true
		collision_layer = 0
		sprite.visible = false
		call_deferred("_explode")

func _explode() -> void:
	game.spawn_effect(global_position + Vector3.UP * 0.85, "explosion", 0.45, 3.5)
	game.audio.play("explosion", -5)
	game.radial_damage(global_position + Vector3.UP * 0.8, 5.0, 90)

func restore_destroyed() -> void:
	destroyed = true
	health = 0
	collision_layer = 0
	sprite.visible = false
