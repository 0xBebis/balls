class_name WeaponDefinition
extends Resource

## Data-driven definition for a weapon.
## Create .tres files to define different weapon types.

enum WeaponType { UNARMED, ORBIT_MELEE, RANGED_PROJECTILE }

@export var id: String = "unarmed"
@export var display_name: String = "Unarmed"
@export var type: WeaponType = WeaponType.UNARMED

@export_group("Base Stats")
@export var base_damage: float = 5.0
@export var knockback: float = 1.0
@export var hit_cooldown: float = 0.12

@export_group("Orbit Melee")
@export var rotation_speed: float = 8.0
@export var reach: float = 34.0
@export var hitbox_size: float = 12.0
@export var weapon_count: int = 1

@export_group("Ranged Projectile")
@export var fire_cooldown: float = 0.7
@export var fire_range: float = 520.0
@export var arrow_count: int = 1
@export var projectile_speed: float = 820.0
@export var projectile_lifetime: float = 2.2
@export var projectile_radius: float = 6.0
@export var pierce: int = 0

@export_group("Status Effects")
@export var applies_poison: bool = false
@export var poison_stacks: int = 1
@export var poison_power: float = 1.0

@export_group("Scaling")
@export var damage_add_per_hit: float = 0.0
@export var rotation_speed_add_per_hit: float = 0.0
@export var reach_add_per_hit: float = 0.0
@export var arrow_count_add_per_hit: int = 0
@export var poison_power_add_per_hit: float = 0.0
@export var max_speed_add_per_hit: float = 0.0

@export_group("Visuals")
@export var color: Color = Color.WHITE
