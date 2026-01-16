class_name SimpleAIController
extends Node

## High-energy AI with aggressive pursuit, frequent dashing, and exciting movement.

signal dashed(direction: Vector2)

var owner_ball: Node2D
var combat_system: CombatSystem
var current_target: Node2D = null

## AI tuning - Exciting but readable
const BASE_STEERING_FORCE: float = 700.0
const JITTER_STRENGTH: float = 60.0
const TARGET_UPDATE_INTERVAL: float = 0.12

## Dash ability
const DASH_COOLDOWN: float = 2.5
const DASH_STRENGTH: float = 450.0
const DASH_TRIGGER_DISTANCE: float = 180.0

## Charge attack
const CHARGE_BUILDUP_TIME: float = 1.0
const CHARGE_SPEED_BONUS: float = 1.3

## Behavior weights
var aggression: float = 0.5
var reaction_speed: float = 0.5
var dash_tendency: float = 0.5

var target_update_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var noise_offset: float = 0.0
var rng: RandomNumberGenerator
var personality_seed: int = 0

# State tracking
var is_kiting: bool = false
var evade_direction: Vector2 = Vector2.ZERO
var evade_timer: float = 0.0
var charge_timer: float = 0.0
var is_charging: bool = false

func initialize(ball: Node2D, combat: CombatSystem, seed_value: int = 0) -> void:
	owner_ball = ball
	combat_system = combat
	personality_seed = seed_value
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value + ball.get_instance_id()
	noise_offset = rng.randf() * 1000.0

	# Generate personality from seed - bias toward aggression for more action
	aggression = rng.randf_range(0.5, 1.0)  # More aggressive overall
	reaction_speed = rng.randf_range(0.6, 1.0)  # Faster reactions
	dash_tendency = rng.randf_range(0.4, 0.9)  # More dashing

	# Randomize initial dash cooldown - start ready to dash sooner
	dash_cooldown_timer = rng.randf() * DASH_COOLDOWN * 0.3

func _physics_process(delta: float) -> void:
	if not owner_ball or not is_instance_valid(owner_ball):
		return

	if not owner_ball.is_alive():
		return

	# Update timers
	target_update_timer -= delta
	dash_cooldown_timer -= delta
	evade_timer -= delta

	if target_update_timer <= 0:
		target_update_timer = TARGET_UPDATE_INTERVAL * (1.5 - reaction_speed)
		_update_target()

	if current_target and is_instance_valid(current_target) and current_target.is_alive():
		_execute_behavior(delta)
		_try_fire_weapon()
		_try_dash()
	else:
		current_target = null
		_hunt_for_target(delta)

func _update_target() -> void:
	current_target = _find_best_target()

func _find_best_target() -> Node2D:
	if not combat_system:
		return null

	var balls := combat_system.get_alive_balls()
	var best_target: Node2D = null
	var best_score: float = -INF

	for ball in balls:
		if ball == owner_ball:
			continue
		if owner_ball.team >= 0 and ball.team == owner_ball.team:
			continue

		var score: float = _calculate_target_score(ball)
		if score > best_score:
			best_score = score
			best_target = ball

	return best_target

func _calculate_target_score(target: Node2D) -> float:
	var distance: float = owner_ball.global_position.distance_to(target.global_position)
	var hp_ratio: float = target.hp / target.max_hp if target.max_hp > 0 else 1.0

	# Prefer closer targets - stronger preference
	var distance_score: float = 2000.0 / max(distance, 30.0)

	# Prefer low HP targets (more aggressive = more preference)
	var hp_score: float = (1.0 - hp_ratio) * 100.0 * aggression

	# Add some randomness for unpredictability
	var random_score: float = rng.randf() * 30.0

	return distance_score + hp_score + random_score

func _execute_behavior(delta: float) -> void:
	if not owner_ball is RigidBody2D:
		return

	var to_target: Vector2 = current_target.global_position - owner_ball.global_position
	var distance: float = to_target.length()
	var direction: Vector2 = to_target.normalized() if distance > 0 else Vector2.RIGHT

	# Determine if we should kite (ranged weapons stay at distance)
	var ideal_distance: float = _get_ideal_distance()
	is_kiting = distance < ideal_distance * 0.6 and aggression < 0.6

	# Check if we need to evade
	if evade_timer > 0:
		_apply_steering(evade_direction, delta, 1.3)  # Faster evade
		return

	# Check for incoming threats - more reactive
	if _should_evade():
		evade_direction = _calculate_evade_direction()
		evade_timer = 0.2 + rng.randf() * 0.15
		_apply_steering(evade_direction, delta, 1.3)
		return

	# Update charge state
	if is_charging:
		charge_timer += delta
		if charge_timer >= CHARGE_BUILDUP_TIME:
			_release_charge(direction)
	elif distance < 250.0 and distance > 80.0 and rng.randf() < aggression * 0.02:
		# Start charging
		is_charging = true
		charge_timer = 0.0

	if is_kiting:
		# Move away while facing target
		var kite_direction: Vector2 = -direction
		# Add perpendicular movement for strafing
		var strafe: Vector2 = direction.rotated(PI / 2 * (1 if rng.randf() > 0.5 else -1))
		kite_direction = (kite_direction + strafe * 0.7).normalized()
		_apply_steering(kite_direction, delta, 1.0)
	else:
		# Aggressive pursuit - full speed ahead!
		var pursuit_multiplier: float = 1.0 + aggression * 0.5
		_apply_steering(direction, delta, pursuit_multiplier)

func _release_charge(direction: Vector2) -> void:
	is_charging = false
	charge_timer = 0.0
	if owner_ball is RigidBody2D:
		owner_ball.apply_central_impulse(direction * DASH_STRENGTH * CHARGE_SPEED_BONUS)
		dashed.emit(direction)

func _apply_steering(direction: Vector2, _delta: float, multiplier: float = 1.0) -> void:
	# Add dynamic jitter using time-based noise
	var time: float = Time.get_ticks_msec() / 1000.0
	var jitter_x: float = sin((time + noise_offset) * 4.5) * JITTER_STRENGTH
	var jitter_y: float = cos((time + noise_offset) * 3.7) * JITTER_STRENGTH
	var jitter: Vector2 = Vector2(jitter_x, jitter_y)

	var ball_max_speed: float = owner_ball.max_speed
	var desired_velocity: Vector2 = direction * ball_max_speed + jitter
	var current_velocity: Vector2 = owner_ball.linear_velocity

	# Scale steering force by aggression and multiplier
	var force_multiplier: float = (0.9 + aggression * 0.6) * multiplier
	var steering: Vector2 = (desired_velocity - current_velocity).normalized() * BASE_STEERING_FORCE * force_multiplier

	owner_ball.apply_central_force(steering)

	# Clamp velocity to max_speed
	if owner_ball.linear_velocity.length() > ball_max_speed:
		owner_ball.linear_velocity = owner_ball.linear_velocity.normalized() * ball_max_speed

func _hunt_for_target(delta: float) -> void:
	# When no target, move toward center aggressively to find action
	if not owner_ball is RigidBody2D:
		return

	var time: float = Time.get_ticks_msec() / 1000.0

	# Spiral toward center
	var to_center: Vector2 = Vector2(450, 350) - owner_ball.global_position  # Approximate arena center
	var center_dir: Vector2 = to_center.normalized() if to_center.length() > 50 else Vector2.ZERO

	var wander_x: float = sin((time + noise_offset) * 1.2)
	var wander_y: float = cos((time + noise_offset) * 0.9)
	var wander_direction: Vector2 = Vector2(wander_x, wander_y).normalized()

	var hunt_direction: Vector2 = (center_dir * 0.6 + wander_direction * 0.4).normalized()
	_apply_steering(hunt_direction, delta, 0.8)

func _get_ideal_distance() -> float:
	# Check weapon type to determine ideal distance
	if owner_ball.weapon:
		var weapon_type: String = ""
		if owner_ball.definition:
			weapon_type = owner_ball.definition.weapon_id

		match weapon_type:
			"bow":
				return 200.0  # Stay far for ranged but not too far
			"spear":
				return 100.0  # Medium range
			"dagger":
				return 40.0   # Get very close
			_:
				return 60.0   # Default melee range

	return 60.0

func _should_evade() -> bool:
	# Check if there's a high-speed threat coming at us
	if not combat_system:
		return false

	var balls := combat_system.get_alive_balls()
	for ball in balls:
		if ball == owner_ball:
			continue
		if owner_ball.team >= 0 and ball.team == owner_ball.team:
			continue

		var to_us: Vector2 = owner_ball.global_position - ball.global_position
		var distance: float = to_us.length()

		if distance < 120.0:
			var their_velocity: Vector2 = ball.linear_velocity
			var closing_speed: float = -to_us.normalized().dot(their_velocity)

			# If they're coming at us fast
			if closing_speed > 250.0:
				return rng.randf() < reaction_speed * 0.6

	return false

func _calculate_evade_direction() -> Vector2:
	# Find a direction away from the biggest threat
	var threat_direction: Vector2 = Vector2.ZERO

	var balls := combat_system.get_alive_balls()
	for ball in balls:
		if ball == owner_ball:
			continue
		if owner_ball.team >= 0 and ball.team == owner_ball.team:
			continue

		var to_us: Vector2 = owner_ball.global_position - ball.global_position
		var distance: float = to_us.length()

		if distance < 180.0 and distance > 0:
			threat_direction += to_us.normalized() / distance

	if threat_direction.length() > 0:
		# Evade perpendicular to threat - more dynamic
		var evade: Vector2 = threat_direction.normalized().rotated(PI / 2 * (1 if rng.randf() > 0.5 else -1))
		return evade

	return Vector2(rng.randf() - 0.5, rng.randf() - 0.5).normalized()

func _try_dash() -> void:
	if dash_cooldown_timer > 0:
		return

	if not owner_ball is RigidBody2D:
		return

	if is_charging:
		return

	var should_dash: bool = false
	var dash_direction: Vector2 = Vector2.ZERO

	var to_target: Vector2 = current_target.global_position - owner_ball.global_position
	var distance: float = to_target.length()

	# Offensive dash - close distance quickly (more frequent)
	if distance > 80.0 and distance < 350.0:
		if rng.randf() < dash_tendency * aggression * 0.5:
			should_dash = true
			dash_direction = to_target.normalized()

	# Defensive dash - escape when low HP
	var hp_ratio: float = owner_ball.hp / owner_ball.max_hp if owner_ball.max_hp > 0 else 1.0
	if hp_ratio < 0.35 and rng.randf() < dash_tendency * 0.6:
		should_dash = true
		dash_direction = -to_target.normalized()

	# Engagement dash - dash to the side for flanking (more frequent)
	if distance < 120.0 and rng.randf() < dash_tendency * 0.35:
		should_dash = true
		dash_direction = to_target.normalized().rotated(PI / 2 * (1 if rng.randf() > 0.5 else -1))

	# Random aggressive dash for chaos
	if rng.randf() < aggression * 0.08:
		should_dash = true
		dash_direction = to_target.normalized()

	if should_dash:
		_perform_dash(dash_direction)

func _perform_dash(direction: Vector2) -> void:
	dash_cooldown_timer = DASH_COOLDOWN * (1.3 - dash_tendency * 0.4)
	owner_ball.apply_central_impulse(direction * DASH_STRENGTH)
	dashed.emit(direction)

func _try_fire_weapon() -> void:
	if owner_ball.weapon and owner_ball.weapon.has_method("fire_at_target"):
		owner_ball.weapon.fire_at_target(current_target)

func get_current_target() -> Node2D:
	return current_target

func get_personality_info() -> Dictionary:
	return {
		"aggression": aggression,
		"reaction_speed": reaction_speed,
		"dash_tendency": dash_tendency,
		"is_kiting": is_kiting,
		"is_charging": is_charging
	}
