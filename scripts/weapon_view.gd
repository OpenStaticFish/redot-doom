class_name WeaponView
extends RefCounted
## Pixel-art viewmodels. Authoring coordinates keep the muzzle, hand and every
## animation frame aligned; presentation stays below the player's aiming area.

const ART = preload("res://assets/weapons/frames.gd").ART
const FRAME_SIZE = Vector2(320, 200)
const STATUS_TOP = 224.0
const BODY_TOP = 164.0
const FLASH_TOP = 158.0
const PROFILES = [
	{"scale": 1.0, "kick": 0.0},
	{"scale": 0.75, "kick": 3.0},
	{"scale": 1.0, "kick": 5.0},
	{"scale": 1.0, "kick": 2.0},
	{"scale": 1.0, "kick": 4.0},
	{"scale": 0.85, "kick": 2.0}
]

func body_frame(player: Marine) -> int:
	if player.cooldown <= 0 or player.switch_dip > 0.01:
		return 0
	var progress = clampf(1.0 - player.cooldown / float(Arsenal.definition(player.weapon).delay), 0, 1)
	match player.weapon:
		0:
			if progress < 0.18: return 1
			if progress < 0.40: return 2
			if progress < 0.65: return 3
			return 1 if progress < 0.8 else 0
		1:
			if progress < 0.25: return 1
			return 2 if progress < 0.55 else 0
		2:
			if progress < 0.20: return 0
			if progress < 0.40: return 1
			if progress < 0.60: return 2
			return 3 if progress < 0.80 else 0
		3, 4:
			return 1 if progress < 0.50 else 0
	return 0

func pose(player: Marine) -> Dictionary:
	var weapon = Arsenal.definition(player.weapon)
	var art: Dictionary = ART.weapons[weapon.id]
	var profile: Dictionary = PROFILES[player.weapon]
	var scale: float = profile.scale
	var frame = body_frame(player)
	var ready: Array = art.body_bounds[0]
	var bounds: Array = art.body_bounds[frame]
	var speed = Vector2(player.velocity.x, player.velocity.z).length()
	var walking = minf(speed / 10.0, 1.0)
	var bob = Vector2(sin(player.walk_time) * 1.5, absf(cos(player.walk_time))) * walking
	var origin = Vector2(240 - 160 * scale, STATUS_TOP - (ready[1] + ready[3]) * scale)
	origin += bob + Vector2(0, player.recoil * profile.kick + player.switch_dip * 32.0)
	# Pumping/punching frames have different silhouettes. They may move down,
	# but neither they nor their flashes can enter the clear aiming corridor.
	origin.y = maxf(origin.y, BODY_TOP - bounds[1] * scale)
	var flash = -1
	if player.muzzle_time > 0 and player.switch_dip <= 0.01 and not art.flash_bounds.is_empty():
		if player.weapon in [3, 5]:
			flash = posmod(player.shot_serial, art.flash_bounds.size())
		else:
			var progress = 1.0 - clampf(player.muzzle_time / 0.07, 0, 1)
			flash = mini(art.flash_bounds.size() - 1, int(progress * art.flash_bounds.size()))
		var flash_bounds: Array = art.flash_bounds[flash]
		origin.y = maxf(origin.y, FLASH_TOP - flash_bounds[1] * scale)
	origin = origin.round()
	return {"id": weapon.id, "body": frame, "flash": flash, "rect": Rect2(origin, FRAME_SIZE * scale)}

func draw(canvas: CanvasItem, game: Node3D) -> void:
	if game.player.health <= 0:
		return
	var presentation = pose(game.player)
	var rect: Rect2 = presentation.rect
	if presentation.flash >= 0:
		canvas.draw_texture_rect_region(game.texture("weapons/" + presentation.id + "_flash"), rect,
			Rect2(Vector2(presentation.flash * FRAME_SIZE.x, 0), FRAME_SIZE))
	canvas.draw_texture_rect_region(game.texture("weapons/" + presentation.id), rect,
		Rect2(Vector2(presentation.body * FRAME_SIZE.x, 0), FRAME_SIZE))
