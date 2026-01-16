class_name ArenaDefinition
extends Resource

## Data-driven definition for an arena.
## Create .tres files to define different arena layouts.

@export var id: String = "default_arena"
@export var display_name: String = "Default Arena"

@export_group("Size")
@export var size: Vector2 = Vector2(1280, 720)
@export var walls: bool = true

@export_group("Obstacles")
@export var obstacles: Array[ObstacleData] = []

class ObstacleData:
	var shape: String = "box"
	var position: Vector2 = Vector2.ZERO
	var size: Vector2 = Vector2(180, 40)
	var rotation: float = 0.0
