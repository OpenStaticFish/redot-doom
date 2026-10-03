class_name RetroPickup
extends Node3D

const ART = preload("res://assets/pickups/art.gd").ART.pickups
const GROUND_CLEARANCE = 0.025
const LABELS = {
	"medkit": "MEDKIT +25", "stim": "STIMPACK +10", "armor": "COMBAT ARMOR",
	"bullets": "BULLETS +40", "shells": "SHELLS +12", "rockets": "ROCKETS +5", "cells": "CELLS +60",
	"bluekey": "BLUE KEYCARD ACQUIRED", "redkey": "RED KEYCARD ACQUIRED",
	"mega": "SOUL ORB / HEALTH 200", "suit": "HAZARD SUIT / 30 SECONDS",
	"shotgun": "PUMP SHOTGUN", "chaingun": "ROTARY CANNON", "launcher": "ROCKET LAUNCHER", "plasma": "ARC PLASMA RIFLE"
}
var game: Node3D
var kind = ""
var pickup_id = -1
var active = true
var sprite: Sprite3D
var ground_shadow: Sprite3D
var presentation: Dictionary
var sprite_height = 0.0
var clock = 0.0

func configure(owner_game: Node3D, item_kind: String, pos: Vector3, id: int) -> void:
	game = owner_game
	kind = item_kind
	pickup_id = id
	position = pos
	clock = pos.x + pos.z
	presentation = ART[kind]
	sprite = Sprite3D.new()
	sprite.name = "PickupSprite"
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.texture = game.texture("pickups/" + kind)
	sprite.hframes = presentation.frames.size()
	sprite.pixel_size = presentation.width / float(presentation.size[0])
	sprite_height = presentation.size[1] * sprite.pixel_size
	add_child(sprite)
	ground_shadow = Sprite3D.new()
	ground_shadow.name = "ContactShadow"
	ground_shadow.texture = game.texture("pickups/shadow")
	ground_shadow.pixel_size = presentation.width * 0.95 / 64.0
	ground_shadow.rotation.x = -PI / 2.0
	ground_shadow.scale.y = 0.55
	ground_shadow.position = Vector3(0, 0.012, 0.015)
	ground_shadow.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	ground_shadow.shaded = false
	ground_shadow.modulate.a = 0.65 if presentation.lift == 0 else 0.45
	ground_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground_shadow)
	update_presentation()

func update_presentation() -> void:
	sprite.frame = int(clock * presentation.fps) % presentation.frames.size()
	var lift: float = presentation.lift + sin(clock * 1.7) * presentation.bob
	# Bottom-aligned art and an explicit clearance prevent floor clipping.
	# Ordinary supplies rest on the floor; only keys and the soul orb hover.
	sprite.position.y = sprite_height / 2.0 + GROUND_CLEARANCE + lift

func _process(delta: float) -> void:
	if not active:
		return
	if game.state == "playing":
		clock += delta
		update_presentation()
		if game.player.position.distance_to(position) < 1.15:
			collect()

func collect() -> bool:
	if not active:
		return false
	var player = game.player
	var accepted = true
	match kind:
		"medkit", "stim":
			if player.health >= 100:
				return false
			player.health = mini(100, player.health + (25 if kind == "medkit" else 10))
		"armor":
			if player.armor >= 200:
				return false
			player.armor = mini(200, player.armor + 100)
		"bullets": accepted = player.give_ammo(kind, 40)
		"shells": accepted = player.give_ammo(kind, 12)
		"rockets": accepted = player.give_ammo(kind, 5)
		"cells": accepted = player.give_ammo(kind, 60)
		"bluekey", "redkey":
			var key = kind.trim_suffix("key")
			if not player.keys.has(key):
				player.keys.append(key)
		"mega": player.health = 200
		"suit": player.suit_time = 30.0
		"shotgun", "chaingun", "launcher", "plasma":
			var index = {"shotgun": 2, "chaingun": 3, "launcher": 4, "plasma": 5}[kind]
			var info = Arsenal.definition(index)
			if not player.owned.has(index):
				player.owned.append(index)
				player.select_weapon(index)
			player.give_ammo(info.ammo, {"shotgun": 16, "chaingun": 80, "launcher": 8, "plasma": 100}[kind])
	if not accepted:
		return false
	active = false
	visible = false
	if pickup_id >= 0:
		game.items += 1
	player.bonus_flash = 0.22
	player.pickup_collected.emit()
	game.notify(LABELS[kind], BrandTheme.ORANGE_LIGHT)
	game.audio.play("key" if kind.ends_with("key") else "pickup", -6)
	return true
