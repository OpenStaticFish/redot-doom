class_name RedotPortrait
extends RefCounted
## Event-driven reactions, independent of short world/weapon flashes.
## Interrupted fades start from the current mixture, never a snapped frame.

const ART = preload("res://assets/ui/redot_chan/art.gd").ART
const PICKUP_HOLD = 1.6
const HURT_HOLD = 1.4
const TRANSITION_TIME = 0.22

var current_expression = "calm"
var pickup_remaining = 0.0
var hurt_remaining = 0.0
var blend_time = TRANSITION_TIME
var weights = PackedFloat32Array()
var from_weights = PackedFloat32Array()

func _init() -> void:
	weights.resize(ART.expressions.size())
	weights[ART.expressions.calm] = 1.0
	from_weights = weights.duplicate()

func reset(player: Marine, state: String = "playing") -> void:
	pickup_remaining = 0.0
	hurt_remaining = 0.0
	current_expression = _desired_expression(player, state)
	weights.fill(0.0)
	weights[ART.expressions[current_expression]] = 1.0
	from_weights = weights.duplicate()
	blend_time = TRANSITION_TIME

func on_pickup() -> void:
	pickup_remaining = PICKUP_HOLD

func on_damage() -> void:
	hurt_remaining = HURT_HOLD

func update(player: Marine, state: String, delta: float) -> void:
	delta = maxf(0.0, delta)
	# Pause/help/options don't consume the reaction the player is looking at.
	if state == "playing":
		pickup_remaining = maxf(0.0, pickup_remaining - delta)
		hurt_remaining = maxf(0.0, hurt_remaining - delta)
	var desired = _desired_expression(player, state)
	if desired != current_expression:
		from_weights = weights.duplicate()
		current_expression = desired
		blend_time = 0.0
	blend_time = minf(TRANSITION_TIME, blend_time + delta)
	var progress = blend_time / TRANSITION_TIME
	var eased = progress * progress * (3.0 - 2.0 * progress)
	var target: int = ART.expressions[current_expression]
	for i in range(weights.size()):
		weights[i] = lerpf(from_weights[i], 1.0 if i == target else 0.0, eased)

func _desired_expression(player: Marine, state: String) -> String:
	if player.health <= 0 or state == "dead": return "defeated"
	if state in ["intermission", "victory"]: return "happy"
	if hurt_remaining > 0: return "hurt"
	if player.health <= 20: return "panic"
	if pickup_remaining > 0: return "happy"
	if player.health <= 50: return "tired"
	return "calm"
