class_name WeaponBehavior
extends Node2D

## Base class for all weapon behaviors.
## Subclasses implement specific weapon logic.

signal hit_landed(hit_event: HitEvent)

var definition: WeaponDefinition
var owner_ball: Node2D
var combat_system: CombatSystem
var status_system: StatusSystem

## Runtime stats that can be modified by scaling
var current_damage: float
var current_knockback: float
var current_rotation_speed: float
var current_reach: float
var current_arrow_count: int
var current_poison_power: float

func initialize(def: WeaponDefinition, ball: Node2D, combat: CombatSystem, status: StatusSystem) -> void:
	definition = def
	owner_ball = ball
	combat_system = combat
	status_system = status

	current_damage = def.base_damage
	current_knockback = def.knockback
	current_rotation_speed = def.rotation_speed
	current_reach = def.reach
	current_arrow_count = def.arrow_count
	current_poison_power = def.poison_power

func on_hit(hit_event: HitEvent) -> void:
	## Called when a hit is confirmed. Apply scaling here.
	current_damage += definition.damage_add_per_hit
	current_rotation_speed += definition.rotation_speed_add_per_hit
	current_reach += definition.reach_add_per_hit
	current_arrow_count += definition.arrow_count_add_per_hit
	current_poison_power += definition.poison_power_add_per_hit

	if owner_ball.has_method("add_max_speed"):
		owner_ball.add_max_speed(definition.max_speed_add_per_hit)

	if definition.applies_poison and status_system:
		status_system.apply_poison(hit_event.defender, definition.poison_stacks, current_poison_power)

	hit_landed.emit(hit_event)

func get_stats_display() -> Dictionary:
	return {
		"damage": current_damage,
		"knockback": current_knockback,
		"rotation_speed": current_rotation_speed,
		"reach": current_reach,
		"arrow_count": current_arrow_count,
		"poison_power": current_poison_power
	}

func fire_at_target(_target: Node2D) -> void:
	## Override in ranged weapons
	pass

func disable() -> void:
	## Called when owner ball dies. Override to clean up hitboxes.
	set_physics_process(false)
	set_process(false)
	visible = false
