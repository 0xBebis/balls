class_name CombatSystem
extends Node

## Central damage pipeline. All damage flows through here.
## Handles hit validation, damage calculation, knockback, and scaling triggers.

signal ball_damaged(ball: Node2D, damage: float, hit_event: HitEvent)
signal ball_died(ball: Node2D)
signal hit_confirmed(hit_event: HitEvent)

## Global tuning constants
const SPEED_SCALE: float = 600.0

var _balls: Array[Node2D] = []
var _hit_cooldowns: Dictionary = {}

func register_ball(ball: Node2D) -> void:
	if ball not in _balls:
		_balls.append(ball)

func unregister_ball(ball: Node2D) -> void:
	_balls.erase(ball)

func get_balls() -> Array[Node2D]:
	return _balls

func get_alive_balls() -> Array[Node2D]:
	var alive: Array[Node2D] = []
	for ball in _balls:
		if ball and is_instance_valid(ball) and ball.is_alive():
			alive.append(ball)
	return alive

func get_alive_balls_on_team(team: int) -> Array[Node2D]:
	var alive: Array[Node2D] = []
	for ball in _balls:
		if ball and is_instance_valid(ball) and ball.is_alive() and ball.team == team:
			alive.append(ball)
	return alive

func process_hit(hit_event: HitEvent) -> bool:
	if not _validate_hit(hit_event):
		return false

	var damage: float = _calculate_damage(hit_event)
	_apply_damage(hit_event.defender, damage)
	_apply_knockback(hit_event, damage)

	# Record stats
	if hit_event.attacker.has_method("record_damage_dealt"):
		hit_event.attacker.record_damage_dealt(damage)
	if hit_event.defender.has_method("record_damage_taken"):
		hit_event.defender.record_damage_taken(damage)

	# Spawn visual effects
	_spawn_hit_effects(hit_event, damage)

	hit_confirmed.emit(hit_event)
	ball_damaged.emit(hit_event.defender, damage, hit_event)

	if hit_event.defender.hp <= 0:
		if hit_event.attacker.has_method("record_kill"):
			hit_event.attacker.record_kill()
		_handle_death(hit_event.defender, hit_event.attacker)

	return true

func _spawn_hit_effects(_hit_event: HitEvent, _damage: float) -> void:
	# Effects disabled for debugging
	pass

func _validate_hit(hit_event: HitEvent) -> bool:
	if not is_instance_valid(hit_event.attacker) or not is_instance_valid(hit_event.defender):
		return false

	if not hit_event.defender.is_alive():
		return false

	if hit_event.attacker == hit_event.defender:
		return false

	# Team check
	if hit_event.attacker.team == hit_event.defender.team and hit_event.attacker.team != -1:
		return false

	# Hit cooldown check
	var cooldown_key: String = "%d_%d_%s" % [hit_event.attacker_id, hit_event.defender_id, hit_event.weapon_id]
	if _hit_cooldowns.has(cooldown_key):
		return false

	return true

func apply_hit_cooldown(attacker_id: int, defender_id: int, weapon_id: String, duration: float) -> void:
	var cooldown_key: String = "%d_%d_%s" % [attacker_id, defender_id, weapon_id]
	_hit_cooldowns[cooldown_key] = duration

func _physics_process(delta: float) -> void:
	var keys_to_remove: Array[String] = []
	for key in _hit_cooldowns.keys():
		_hit_cooldowns[key] -= delta
		if _hit_cooldowns[key] <= 0:
			keys_to_remove.append(key)
	for key in keys_to_remove:
		_hit_cooldowns.erase(key)

func _calculate_damage(hit_event: HitEvent) -> float:
	var speed_factor: float = clampf(hit_event.relative_speed / SPEED_SCALE, 0.0, 1.0)
	return hit_event.base_damage * (1.0 + speed_factor)

func _apply_damage(ball: Node2D, damage: float) -> void:
	ball.hp -= damage

func _apply_knockback(hit_event: HitEvent, damage: float) -> void:
	if hit_event.defender is RigidBody2D:
		var impulse: Vector2 = hit_event.hit_normal * (hit_event.knockback * damage)
		hit_event.defender.apply_central_impulse(impulse)

func _handle_death(ball: Node2D, _killer: Node2D = null) -> void:
	ball.die()
	ball_died.emit(ball)

func reset() -> void:
	_balls.clear()
	_hit_cooldowns.clear()
