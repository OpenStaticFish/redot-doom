class_name Demon
extends CharacterBody3D

const ART = preload("res://assets/presentation/art.gd").ART.actors
const TYPES = {
	"thrall": {"health": 50, "speed": 3.4, "damage": 8, "delay": 1.6, "size": 0.028, "range": 23.0},
	"ember": {"health": 75, "speed": 3.0, "damage": 13, "delay": 1.9, "size": 0.031, "range": 30.0},
	"brute": {"health": 180, "speed": 2.6, "damage": 24, "delay": 2.1, "size": 0.039, "range": 28.0},
	"warden": {"health": 1300, "speed": 2.8, "damage": 25, "delay": 1.3, "size": 0.058, "range": 42.0}
}
var game: Node3D
var kind = "thrall"
var enemy_id = 0
var stats: Dictionary
var health = 50
var max_health = 50
var dead = false
var alerted = false
var sprite: Sprite3D
var collider: CollisionShape3D
var aim_height = 1.1
var animation_clock = 0.0
var attack_cooldown = 0.0
var windup = 0.0
var attack_pose = 0.0
var pain = 0.0
var death_time = 0.0
var path_timer = 0.0
var path: Array = []
var sees_player = false
var sight_timer = 0.0
var was_boss_enraged = false
var facing_yaw = 0.0
var visual_state = "walk"
var visual_step = 0
var artwork: Dictionary
var ground_shadow: Sprite3D

func configure(owner_game: Node3D, info: Dictionary, id: int) -> void:
	game = owner_game
	kind = info.kind
	enemy_id = id
	stats = TYPES[kind]
	artwork = ART[kind]
	health = stats.health
	max_health = health
	position = game.level.tile_position(info.tile)
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8
	var height = 80.0 * stats.size
	aim_height = height * 0.5
	var shape = CapsuleShape3D.new()
	shape.radius = 0.42 if kind != "warden" else 0.8
	shape.height = height * 0.84
	collider = CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height / 2.0
	add_child(collider)
	sprite = Sprite3D.new()
	sprite.texture = game.texture("presentation/" + kind)
	sprite.hframes = artwork.columns
	sprite.vframes = artwork.rows
	sprite.pixel_size = height / float(artwork.ready_height)
	sprite.position.y = artwork.size[1] * sprite.pixel_size / 2.0 + 0.025
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	add_child(sprite)
	ground_shadow = Sprite3D.new()
	ground_shadow.texture = game.texture("pickups/shadow")
	ground_shadow.pixel_size = (1.3 if kind != "warden" else 3.0) / 64.0
	ground_shadow.rotation.x = -PI / 2.0
	ground_shadow.scale.y = 0.6
	ground_shadow.position.y = 0.012
	ground_shadow.modulate.a = 0.7
	ground_shadow.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(ground_shadow)
	update_presentation()
	attack_cooldown = randf_range(0.7, 1.7)
	path_timer = randf_range(0, 0.6)

func _process(_delta: float) -> void:
	if game != null:
		update_presentation()

func set_pose(state_name: String, step: int = 0) -> void:
	visual_state = state_name
	visual_step = step
	update_presentation()

func update_presentation() -> void:
	if sprite == null or game.player == null:
		return
	var offset: Vector3 = game.player.global_position - global_position
	var angle = wrapf(atan2(offset.x, offset.z) - facing_yaw, -PI, PI)
	var direction = posmod(roundi(angle / (PI / 4.0)), 8)
	var poses: Array = artwork.poses[visual_state]
	var pose: Array = poses[clampi(visual_step, 0, poses.size() - 1)][direction]
	sprite.frame = pose[0]
	sprite.flip_h = pose[1]

func _physics_process(delta: float) -> void:
	if game == null or game.state != "playing":
		return
	if dead:
		death_time += delta
		set_pose("death", int(death_time * artwork.death_fps))
		return
	animation_clock += delta
	attack_cooldown -= delta
	attack_pose = maxf(0, attack_pose - delta)
	pain = maxf(0, pain - delta)
	var player = game.player
	var offset: Vector3 = player.position - position
	var distance = offset.length()
	sight_timer -= delta
	if sight_timer <= 0:
		sight_timer = 0.18
		sees_player = distance < 48.0 and game.level.line_of_sight(global_position + Vector3.UP * aim_height, player.camera.global_position)
		if sees_player and distance < 29.0 and not alerted:
			alert()
	if not alerted:
		set_pose("walk", 0)
		return
	if kind == "warden" and health < max_health / 2 and not was_boss_enraged:
		was_boss_enraged = true
		game.notify("THE WARDEN IS ENRAGED", Color(1, 0.35, 0.2))
	if pain > 0:
		set_pose("pain")
		velocity = Vector3.ZERO
		return
	if windup > 0:
		windup -= delta
		facing_yaw = atan2(offset.x, offset.z)
		var duration = 0.5 if kind == "warden" else 0.3
		set_pose("attack", mini(2, int((1.0 - windup / duration) * 3)))
		if windup <= 0:
			_attack(distance)
		return
	if sees_player and distance < stats.range and attack_cooldown <= 0:
		windup = 0.3 if kind != "warden" else 0.5
		attack_pose = windup + 0.2
		attack_cooldown = stats.delay * (0.67 if was_boss_enraged else 1.0) * randf_range(0.9, 1.1)
		facing_yaw = atan2(offset.x, offset.z)
		set_pose("attack", 0)
		return
	var direction = Vector3.ZERO
	if sees_player:
		if distance > (5.0 if kind != "warden" else 9.0):
			direction = offset.normalized()
	else:
		path_timer -= delta
		if path_timer <= 0:
			path_timer = 0.7 + randf_range(0, 0.3)
			path = game.level.path_between(position, player.position)
		while not path.is_empty() and position.distance_to(path[0]) < 0.75:
			path.pop_front()
		if not path.is_empty():
			direction = (path[0] - position).normalized()
			for door in game.level.doors:
				if not door.opened and door.key == "" and not door.secret and position.distance_to(door.position) < 2.8:
					door.activate(false)
	direction.y = 0
	if direction.length() > 0.1:
		facing_yaw = atan2(direction.x, direction.z)
	velocity = direction * stats.speed
	velocity.y = -2
	move_and_slide()
	set_pose("walk", int(animation_clock * artwork.walk_fps) % 4 if direction.length() > 0.1 else 0)
	if attack_pose > 0:
		set_pose("attack", 2)

func alert() -> void:
	if alerted or dead:
		return
	alerted = true
	if position.distance_to(game.player.position) < 26:
		game.audio.play("growl", -17, 0.65 if kind in ["brute", "warden"] else 1.1)

func _attack(distance: float) -> void:
	if game.player.health <= 0:
		return
	var origin = global_position + Vector3.UP * aim_height
	var target: Vector3 = game.player.camera.global_position
	if not game.level.line_of_sight(origin, target):
		return
	if distance < 2.3:
		game.player.take_damage(stats.damage * 2)
		game.audio.play("hit", -9)
	elif kind == "thrall":
		game.spawn_effect(origin, "spark", 0.10, 0.55)
		game.audio.play("pistol", -15, 0.8)
		# Telegraphing plus range falloff makes strafing meaningful.
		if randf() < clampf(0.85 - distance * 0.018 - game.player.velocity.length() * 0.025, 0.2, 0.9):
			game.player.take_damage(stats.damage)
	elif kind == "warden":
		var lead = target + game.player.velocity * 0.13
		var direction = (lead - origin).normalized()
		var count = 5 if was_boss_enraged else 3
		for i in range(count):
			var spread = (i - (count - 1) / 2.0) * 0.13
			game.launch_projectile(origin, direction.rotated(Vector3.UP, spread), "hellbolt", false, self)
		game.audio.play("launcher", -14, 0.65)
	else:
		var direction = (target - origin).normalized()
		game.launch_projectile(origin, direction, "fireball" if kind == "ember" else "hellbolt", false, self)
		game.audio.play("plasma", -17, 0.65)

func take_damage(amount: int, direction: Vector3 = Vector3.ZERO) -> void:
	if dead:
		return
	health -= amount
	alert()
	if health <= 0:
		dead = true
		windup = 0
		death_time = 0
		set_pose("death", 0)
		collider.set_deferred("disabled", true)
		collision_layer = 0
		game.kills += 1
		game.audio.play("death", -13, 0.75 if kind in ["brute", "warden"] else randf_range(0.9, 1.15))
		game.spawn_effect(global_position + Vector3.UP, "blood", 0.24, 0.9)
		if kind == "thrall":
			game.level.call_deferred("add_pickup", "bullets", position, -1)
		if kind == "warden":
			game.notify("SIGNAL TERMINATED. FIND THE EXIT.", Color(1, 0.85, 0.5))
			game.spawn_effect(position + Vector3.UP * 2, "explosion", 0.8, 5.0)
			game.audio.play("explosion")
	else:
		pain = 0.13 if kind != "warden" else 0.035
		windup = 0
		if kind != "warden":
			position += Vector3(direction.x, 0, direction.z) * 0.03
		game.spawn_effect(global_position + Vector3.UP * aim_height, "blood", 0.15, 0.35)

func snapshot() -> Dictionary:
	return {"health": health, "position": position, "alerted": alerted, "facing": facing_yaw}

func restore(info: Dictionary) -> void:
	health = int(info.health)
	position = info.position
	alerted = bool(info.alerted)
	facing_yaw = float(info.get("facing", 0.0))
	dead = health <= 0
	if dead:
		death_time = 5.0
		set_pose("death", artwork.poses.death.size() - 1)
		collision_layer = 0
		collider.set_deferred("disabled", true)
	else:
		set_pose("walk", 0)
