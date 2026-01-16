class_name BallDefinition
extends Resource

## Data-driven definition for a ball entity.
## Create .tres files to define different ball types.

@export var id: String = "default"
@export var display_name: String = "Ball"

@export_group("Physics")
@export var radius: float = 18.0
@export var mass: float = 1.0
@export var max_speed: float = 420.0
@export var linear_damp: float = 0.2
@export var angular_damp: float = 0.2
@export var friction: float = 0.4
@export var bounce: float = 0.8

@export_group("Combat")
@export var base_hp: float = 100.0
@export var weapon_id: String = "unarmed"
@export var team: int = -1

@export_group("Visuals")
@export var color: Color = Color.WHITE
@export var sprite: Texture2D = null
