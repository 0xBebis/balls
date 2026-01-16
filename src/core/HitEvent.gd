class_name HitEvent
extends RefCounted

## Represents a single hit event in the combat system.
## All damage flows through HitEvents for consistent processing.

var attacker_id: int
var defender_id: int
var relative_speed: float
var hit_normal: Vector2
var base_damage: float
var knockback: float
var tags: Array[String]
var weapon_id: String
var timestamp: int

var attacker: Node2D
var defender: Node2D

static func create(
	p_attacker: Node2D,
	p_defender: Node2D,
	p_base_damage: float,
	p_knockback: float,
	p_weapon_id: String,
	p_tags: Array[String] = []
) -> HitEvent:
	var event: HitEvent = HitEvent.new()
	event.attacker = p_attacker
	event.defender = p_defender
	event.attacker_id = p_attacker.get_instance_id()
	event.defender_id = p_defender.get_instance_id()

	var attacker_vel: Vector2 = Vector2.ZERO
	var defender_vel: Vector2 = Vector2.ZERO

	if p_attacker is RigidBody2D:
		attacker_vel = p_attacker.linear_velocity
	if p_defender is RigidBody2D:
		defender_vel = p_defender.linear_velocity

	event.relative_speed = (attacker_vel - defender_vel).length()
	event.hit_normal = (p_defender.global_position - p_attacker.global_position).normalized()
	event.base_damage = p_base_damage
	event.knockback = p_knockback
	event.weapon_id = p_weapon_id
	event.tags = p_tags
	event.timestamp = Engine.get_physics_frames()

	return event
