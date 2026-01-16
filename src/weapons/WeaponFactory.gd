class_name WeaponFactory
extends RefCounted

## Factory for creating weapon instances from definitions.
## Adding a new weapon only requires a new definition + behavior script.

const OrbitMeleeBehavior := preload("res://src/weapons/behaviors/OrbitMeleeBehavior.gd")
const RangedProjectileBehavior := preload("res://src/weapons/behaviors/RangedProjectileBehavior.gd")
const UnarmedBehavior := preload("res://src/weapons/behaviors/UnarmedBehavior.gd")

static func create_weapon(
	definition: WeaponDefinition,
	ball: Node2D,
	combat_system: CombatSystem,
	status_system: StatusSystem
) -> WeaponBehavior:
	var behavior: WeaponBehavior

	match definition.type:
		WeaponDefinition.WeaponType.UNARMED:
			behavior = UnarmedBehavior.new()
		WeaponDefinition.WeaponType.ORBIT_MELEE:
			behavior = OrbitMeleeBehavior.new()
		WeaponDefinition.WeaponType.RANGED_PROJECTILE:
			behavior = RangedProjectileBehavior.new()
		_:
			push_error("Unknown weapon type: %s" % definition.type)
			behavior = UnarmedBehavior.new()

	behavior.initialize(definition, ball, combat_system, status_system)
	return behavior
