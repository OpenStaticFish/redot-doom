class_name Marine
extends CharacterBody3D

signal damaged
signal pickup_collected

var game: Node3D
var camera: Camera3D
var health = 100
var armor = 0
var ammo: Dictionary = {"bullets": 80, "shells": 0, "rockets": 0, "cells": 0}
var owned: Array = [0, 1]
var keys: Array = []
var weapon = 1
var cooldown = 0.0
var recoil = 0.0
var muzzle_time = 0.0
var shot_serial = 0
var walk_time = 0.0
var hurt_flash = 0.0
var bonus_flash = 0.0
var suit_time = 0.0
var hazard_timer = 0.0
var switch_dip = 0.0
var step_distance = 0.0

func configure(owner_game: Node3D) -> void:
	game = owner_game
	name = "Marine"
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	var shape = CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.65
	var collider = CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.84
	add_child(collider)
	camera = Camera3D.new()
	camera.position.y = 1.55
	camera.fov = 78.0
	camera.near = 0.05
	camera.far = 160.0
	camera.current = true
	add_child(camera)

func _unhandled_input(event: InputEvent) -> void:
	if game == null or game.state != "playing" or health <= 0:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * game.sensitivity
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_6:
			select_weapon(event.physical_keycode - KEY_1)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_weapon(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_weapon(-1)

func _physics_process(delta: float) -> void:
	if game == null:
		return
	hurt_flash = maxf(0, hurt_flash - delta * 1.8)
	bonus_flash = maxf(0, bonus_flash - delta * 1.5)
	if game.state != "playing":
		return
	cooldown = maxf(0, cooldown - delta)
	recoil = move_toward(recoil, 0.0, delta * 5.0)
	switch_dip = move_toward(switch_dip, 0.0, delta * 5.0)
	muzzle_time = maxf(0, muzzle_time - delta)
	suit_time = maxf(0, suit_time - delta)
	rotation.y += Input.get_axis("turn_right", "turn_left") * delta * 2.3
	var move_input = Input.get_vector("left", "right", "forward", "back")
	var direction = transform.basis * Vector3(move_input.x, 0, move_input.y)
	var speed = 12.0 if Input.is_action_pressed("sprint") or game.always_run else 8.0
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 65.0)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 65.0)
	velocity.y = -2.0
	move_and_slide()
	var moving = Vector2(velocity.x, velocity.z).length()
	walk_time += moving * delta * 0.75
	camera.position.y = 1.55 + sin(walk_time * 2) * minf(moving / 12.0, 1.0) * 0.025
	if Input.is_action_pressed("fire") and cooldown <= 0:
		fire()
	if Input.is_action_just_pressed("use"):
		game.interact()
	if Input.is_action_just_pressed("map"):
		game.automap = not game.automap
	hazard_timer -= delta
	var floor_type = game.level.cell(game.level.position_tile(position))
	if floor_type in ["a", "l"] and hazard_timer <= 0:
		hazard_timer = 0.65
		if suit_time <= 0:
			take_damage(7 if floor_type == "a" else 12)
	game.level.reveal(position)

func select_weapon(index: int) -> void:
	if not owned.has(index) or index == weapon:
		return
	weapon = index
	switch_dip = 1.0
	muzzle_time = 0.0
	recoil = 0.0
	cooldown = maxf(cooldown, 0.2)
	game.audio.play("menu", -12)

func cycle_weapon(direction: int) -> void:
	var index = weapon
	for i in range(6):
		index = posmod(index + direction, 6)
		if owned.has(index):
			select_weapon(index)
			return

func fire() -> bool:
	if health <= 0:
		return false
	var info = Arsenal.definition(weapon)
	if info.ammo != "" and ammo[info.ammo] < info.cost:
		cooldown = 0.3
		game.audio.play("empty", -6)
		game.notify("OUT OF " + info.ammo.to_upper(), Color(1, 0.55, 0.3))
		return false
	if info.ammo != "":
		ammo[info.ammo] -= info.cost
	cooldown = info.delay
	recoil = 1.0
	shot_serial += 1
	muzzle_time = 0.07 if weapon != 0 else 0.0
	game.audio.play(info.id, -4 if weapon != 5 else -10, randf_range(0.94, 1.04))
	game.alert_enemies(position, 32.0)
	var origin = camera.global_position
	var direction = -global_transform.basis.z
	# Classic vertical auto-aim: yaw is entirely controlled by the player.
	var best_dot = cos(0.075)
	for demon in game.level.enemies:
		if demon.dead:
			continue
		var offset: Vector3 = demon.global_position + Vector3.UP * demon.aim_height - origin
		var flat = Vector3(offset.x, 0, offset.z).normalized()
		var alignment = direction.dot(flat)
		if alignment > best_dot and offset.length() < info.range and game.level.line_of_sight(origin, origin + offset):
			best_dot = alignment
			direction = offset.normalized()
	if weapon in [4, 5]:
		game.launch_projectile(origin + direction * 0.6, direction, "rocket" if weapon == 4 else "plasma", true)
		return true
	for pellet in range(info.pellets):
		var shot = (direction + Vector3(randf_range(-info.spread, info.spread), randf_range(-info.spread, info.spread) * 0.4, randf_range(-info.spread, info.spread))).normalized()
		var query = PhysicsRayQueryParameters3D.create(origin, origin + shot * info.range, 1 | 4 | 8, [get_rid()])
		var hit = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			if hit.collider.has_method("take_damage"):
				hit.collider.take_damage(info.damage + randi_range(-3, 3), shot)
				game.hit_marker = 0.12
			else:
				game.spawn_effect(hit.position + hit.normal * 0.025, "spark", 0.12, 0.14)
	return true

func take_damage(amount: int, _direction: Vector3 = Vector3.ZERO) -> void:
	if health <= 0 or game.state != "playing":
		return
	var damage = roundi(amount * [0.5, 1.0, 1.45][game.difficulty])
	var absorbed = mini(armor, roundi(damage * 0.4))
	armor -= absorbed
	health = maxi(0, health - damage + absorbed)
	hurt_flash = minf(0.6, hurt_flash + 0.18 + amount * 0.004)
	damaged.emit()
	game.audio.play("hurt", -5, randf_range(0.85, 1.1))
	if health <= 0:
		game.die()

func give_ammo(kind: String, amount: int) -> bool:
	if ammo[kind] >= Arsenal.AMMO_MAX[kind]:
		return false
	ammo[kind] = mini(Arsenal.AMMO_MAX[kind], ammo[kind] + amount)
	return true

func snapshot() -> Dictionary:
	return {"health": health, "armor": armor, "ammo": ammo.duplicate(), "owned": owned.duplicate(), "keys": keys.duplicate(), "weapon": weapon, "suit": suit_time}

func restore(info: Dictionary) -> void:
	health = int(info.get("health", 100))
	armor = int(info.get("armor", 0))
	ammo = info.get("ammo", {"bullets": 80, "shells": 0, "rockets": 0, "cells": 0}).duplicate()
	owned = info.get("owned", [0, 1]).duplicate()
	keys = info.get("keys", []).duplicate()
	weapon = int(info.get("weapon", 1))
	suit_time = float(info.get("suit", 0.0))
	cooldown = 0.0
	recoil = 0.0
	muzzle_time = 0.0
	switch_dip = 0.0
	hurt_flash = 0.0
	bonus_flash = 0.0
	velocity = Vector3.ZERO
