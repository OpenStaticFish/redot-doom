class_name RetroProp
extends Node3D
## Grounded, animated scenery sharing the same classic sprite pipeline.

const ART = preload("res://assets/presentation/art.gd").ART.sheets
var game: Node3D
var kind = ""
var sprite: Sprite3D
var clock = 0.0

func configure(owner_game: Node3D, prop_kind: String, pos: Vector3) -> void:
	game = owner_game
	kind = prop_kind
	position = pos
	clock = pos.x + pos.z
	var art: Dictionary = ART[kind]
	sprite = Sprite3D.new()
	sprite.texture = game.texture("presentation/" + kind)
	sprite.hframes = art.columns
	sprite.vframes = art.rows
	sprite.pixel_size = art.height / float(art.size[1])
	sprite.position.y = art.height / 2.0 + 0.025
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)

func _process(delta: float) -> void:
	if game == null or game.state not in ["playing", "menu", "difficulty"]:
		return
	clock += delta
	var art: Dictionary = ART[kind]
	sprite.frame = int(clock * art.fps) % art.files.size()
