class_name Arena
extends Node2D

## Dynamic arena with varied obstacles, hazards, and boost pads.

signal boost_pad_triggered(ball: Node2D, direction: Vector2, strength: float)

@export var arena_size: Vector2 = Vector2(900, 680)
@export var wall_thickness: float = 20.0

enum ArenaType { SIMPLE, COMPLEX, HAZARDS, OPEN }
var arena_type: ArenaType = ArenaType.COMPLEX

var walls: StaticBody2D
var obstacles: Node2D
var hazards: Node2D
var boost_pads: Node2D
var moving_obstacles: Array[Node2D] = []

func _ready() -> void:
	_create_background()
	_create_walls()

func setup_arena(type: ArenaType) -> void:
	arena_type = type
	_clear_dynamic_objects()

	match type:
		ArenaType.SIMPLE:
			_create_simple_obstacles()
		ArenaType.COMPLEX:
			_create_complex_obstacles()
		ArenaType.HAZARDS:
			_create_hazard_obstacles()
		ArenaType.OPEN:
			pass  # No obstacles

func _clear_dynamic_objects() -> void:
	if obstacles:
		obstacles.queue_free()
	if hazards:
		hazards.queue_free()
	if boost_pads:
		boost_pads.queue_free()
	moving_obstacles.clear()

	obstacles = Node2D.new()
	obstacles.name = "Obstacles"
	add_child(obstacles)

	hazards = Node2D.new()
	hazards.name = "Hazards"
	add_child(hazards)

	boost_pads = Node2D.new()
	boost_pads.name = "BoostPads"
	add_child(boost_pads)

func _create_background() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.size = arena_size
	bg.color = Color(0.12, 0.14, 0.18)
	bg.z_index = -10
	add_child(bg)

	# Grid pattern
	var grid: Node2D = Node2D.new()
	grid.z_index = -9
	add_child(grid)
	var grid_visual: GridVisual = GridVisual.new()
	grid_visual.arena_size = arena_size
	grid.add_child(grid_visual)

class GridVisual extends Node2D:
	var arena_size: Vector2 = Vector2(900, 680)

	func _draw() -> void:
		var grid_spacing: float = 50.0
		var grid_color: Color = Color(0.18, 0.21, 0.26, 0.6)

		var x: float = 0.0
		while x <= arena_size.x:
			draw_line(Vector2(x, 0), Vector2(x, arena_size.y), grid_color, 1.0)
			x += grid_spacing

		var y: float = 0.0
		while y <= arena_size.y:
			draw_line(Vector2(0, y), Vector2(arena_size.x, y), grid_color, 1.0)
			y += grid_spacing

func _create_walls() -> void:
	walls = StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	walls.collision_mask = 0

	var mat: PhysicsMaterial = PhysicsMaterial.new()
	mat.friction = 0.1
	mat.bounce = 0.95
	walls.physics_material_override = mat

	_add_wall_segment(Vector2(arena_size.x / 2, -wall_thickness / 2), Vector2(arena_size.x + wall_thickness * 2, wall_thickness))
	_add_wall_segment(Vector2(arena_size.x / 2, arena_size.y + wall_thickness / 2), Vector2(arena_size.x + wall_thickness * 2, wall_thickness))
	_add_wall_segment(Vector2(-wall_thickness / 2, arena_size.y / 2), Vector2(wall_thickness, arena_size.y + wall_thickness * 2))
	_add_wall_segment(Vector2(arena_size.x + wall_thickness / 2, arena_size.y / 2), Vector2(wall_thickness, arena_size.y + wall_thickness * 2))

	add_child(walls)
	_create_wall_visuals()

func _add_wall_segment(pos: Vector2, size: Vector2) -> void:
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = pos
	walls.add_child(shape)

func _create_wall_visuals() -> void:
	var wall_color: Color = Color(0.3, 0.35, 0.45)
	var glow_color: Color = Color(0.4, 0.5, 0.7, 0.3)

	# Top
	_add_wall_visual(Vector2(arena_size.x / 2, -wall_thickness / 2), Vector2(arena_size.x + wall_thickness * 2, wall_thickness), wall_color, glow_color)
	# Bottom
	_add_wall_visual(Vector2(arena_size.x / 2, arena_size.y + wall_thickness / 2), Vector2(arena_size.x + wall_thickness * 2, wall_thickness), wall_color, glow_color)
	# Left
	_add_wall_visual(Vector2(-wall_thickness / 2, arena_size.y / 2), Vector2(wall_thickness, arena_size.y + wall_thickness * 2), wall_color, glow_color)
	# Right
	_add_wall_visual(Vector2(arena_size.x + wall_thickness / 2, arena_size.y / 2), Vector2(wall_thickness, arena_size.y + wall_thickness * 2), wall_color, glow_color)

func _add_wall_visual(pos: Vector2, size: Vector2, color: Color, glow: Color) -> void:
	var rect: ColorRect = ColorRect.new()
	rect.size = size
	rect.position = pos - size / 2
	rect.color = color
	add_child(rect)

	# Inner glow line
	var glow_rect: ColorRect = ColorRect.new()
	if size.x > size.y:  # Horizontal wall
		glow_rect.size = Vector2(size.x - 4, 3)
		glow_rect.position = pos - Vector2(glow_rect.size.x / 2, -size.y / 2 + 2 if pos.y < arena_size.y / 2 else size.y / 2 - 5)
	else:  # Vertical wall
		glow_rect.size = Vector2(3, size.y - 4)
		glow_rect.position = pos - Vector2(-size.x / 2 + 2 if pos.x < arena_size.x / 2 else size.x / 2 - 5, glow_rect.size.y / 2)
	glow_rect.color = glow
	add_child(glow_rect)

func _create_simple_obstacles() -> void:
	# Just 4 corner obstacles
	var corner_offset: float = 120.0
	_add_rect_obstacle(Vector2(corner_offset, corner_offset), Vector2(60, 60))
	_add_rect_obstacle(Vector2(arena_size.x - corner_offset, corner_offset), Vector2(60, 60))
	_add_rect_obstacle(Vector2(corner_offset, arena_size.y - corner_offset), Vector2(60, 60))
	_add_rect_obstacle(Vector2(arena_size.x - corner_offset, arena_size.y - corner_offset), Vector2(60, 60))

func _create_complex_obstacles() -> void:
	var cx: float = arena_size.x / 2
	var cy: float = arena_size.y / 2

	# Center circular obstacle
	_add_circle_obstacle(Vector2(cx, cy), 45.0)

	# Corner rectangles
	_add_rect_obstacle(Vector2(cx * 0.4, cy * 0.4), Vector2(70, 35))
	_add_rect_obstacle(Vector2(cx * 1.6, cy * 0.4), Vector2(70, 35))
	_add_rect_obstacle(Vector2(cx * 0.4, cy * 1.6), Vector2(70, 35))
	_add_rect_obstacle(Vector2(cx * 1.6, cy * 1.6), Vector2(70, 35))

	# Side circles
	_add_circle_obstacle(Vector2(cx * 0.25, cy), 30.0)
	_add_circle_obstacle(Vector2(cx * 1.75, cy), 30.0)

	# Boost pads in corners
	_add_boost_pad(Vector2(80, 80), Vector2(1, 1).normalized(), 400.0)
	_add_boost_pad(Vector2(arena_size.x - 80, 80), Vector2(-1, 1).normalized(), 400.0)
	_add_boost_pad(Vector2(80, arena_size.y - 80), Vector2(1, -1).normalized(), 400.0)
	_add_boost_pad(Vector2(arena_size.x - 80, arena_size.y - 80), Vector2(-1, -1).normalized(), 400.0)

func _create_hazard_obstacles() -> void:
	var cx: float = arena_size.x / 2
	var cy: float = arena_size.y / 2

	# Moving obstacles
	_add_moving_obstacle(Vector2(cx, cy * 0.5), Vector2(50, 25), Vector2(150, 0), 2.0)
	_add_moving_obstacle(Vector2(cx, cy * 1.5), Vector2(50, 25), Vector2(150, 0), 2.0)
	_add_moving_obstacle(Vector2(cx * 0.5, cy), Vector2(25, 50), Vector2(0, 100), 1.5)
	_add_moving_obstacle(Vector2(cx * 1.5, cy), Vector2(25, 50), Vector2(0, 100), 1.5)

	# Rotating obstacle in center
	_add_rotating_obstacle(Vector2(cx, cy), 80.0, 1.5)

	# Boost pads pointing toward center
	_add_boost_pad(Vector2(100, cy), Vector2(1, 0), 500.0)
	_add_boost_pad(Vector2(arena_size.x - 100, cy), Vector2(-1, 0), 500.0)
	_add_boost_pad(Vector2(cx, 100), Vector2(0, 1), 500.0)
	_add_boost_pad(Vector2(cx, arena_size.y - 100), Vector2(0, -1), 500.0)

	# Danger zones
	_add_danger_zone(Vector2(cx * 0.3, cy * 0.3), 50.0, 15.0)
	_add_danger_zone(Vector2(cx * 1.7, cy * 0.3), 50.0, 15.0)
	_add_danger_zone(Vector2(cx * 0.3, cy * 1.7), 50.0, 15.0)
	_add_danger_zone(Vector2(cx * 1.7, cy * 1.7), 50.0, 15.0)

func _add_rect_obstacle(pos: Vector2, size: Vector2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0

	var mat: PhysicsMaterial = PhysicsMaterial.new()
	mat.friction = 0.2
	mat.bounce = 0.9
	body.physics_material_override = mat

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)

	# Visual
	var visual: ObstacleVisual = ObstacleVisual.new()
	visual.obstacle_size = size
	visual.obstacle_type = "rect"
	body.add_child(visual)

	obstacles.add_child(body)

func _add_circle_obstacle(pos: Vector2, radius: float) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0

	var mat: PhysicsMaterial = PhysicsMaterial.new()
	mat.friction = 0.15
	mat.bounce = 0.95
	body.physics_material_override = mat

	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	body.add_child(shape)

	# Visual
	var visual: ObstacleVisual = ObstacleVisual.new()
	visual.obstacle_radius = radius
	visual.obstacle_type = "circle"
	body.add_child(visual)

	obstacles.add_child(body)

func _add_moving_obstacle(pos: Vector2, size: Vector2, move_range: Vector2, period: float) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0

	var mat: PhysicsMaterial = PhysicsMaterial.new()
	mat.friction = 0.1
	mat.bounce = 1.0
	body.physics_material_override = mat

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)

	# Visual
	var visual: ObstacleVisual = ObstacleVisual.new()
	visual.obstacle_size = size
	visual.obstacle_type = "moving"
	visual.glow_color = Color(1.0, 0.6, 0.2, 0.5)
	body.add_child(visual)

	# Movement script
	var mover: MovingObstacle = MovingObstacle.new()
	mover.base_position = pos
	mover.move_range = move_range
	mover.period = period
	body.add_child(mover)

	obstacles.add_child(body)
	moving_obstacles.append(body)

func _add_rotating_obstacle(pos: Vector2, arm_length: float, rotation_speed: float) -> void:
	var pivot: Node2D = Node2D.new()
	pivot.position = pos
	obstacles.add_child(pivot)

	# Center circle
	var center: StaticBody2D = StaticBody2D.new()
	center.collision_layer = 1
	center.collision_mask = 0
	var center_shape: CollisionShape2D = CollisionShape2D.new()
	var center_circle: CircleShape2D = CircleShape2D.new()
	center_circle.radius = 20.0
	center_shape.shape = center_circle
	center.add_child(center_shape)
	var center_visual: ObstacleVisual = ObstacleVisual.new()
	center_visual.obstacle_radius = 20.0
	center_visual.obstacle_type = "circle"
	center_visual.glow_color = Color(1.0, 0.3, 0.3, 0.5)
	center.add_child(center_visual)
	pivot.add_child(center)

	# Arms (2 opposite)
	for i in range(2):
		var arm: StaticBody2D = StaticBody2D.new()
		arm.position = Vector2(arm_length * (1 if i == 0 else -1), 0)
		arm.collision_layer = 1
		arm.collision_mask = 0
		var arm_shape: CollisionShape2D = CollisionShape2D.new()
		var arm_rect: RectangleShape2D = RectangleShape2D.new()
		arm_rect.size = Vector2(arm_length * 0.8, 15)
		arm_shape.shape = arm_rect
		arm_shape.position = Vector2(-arm_length * 0.4 * (1 if i == 0 else -1), 0)
		arm.add_child(arm_shape)

		var arm_visual: ObstacleVisual = ObstacleVisual.new()
		arm_visual.obstacle_size = Vector2(arm_length * 0.8, 15)
		arm_visual.obstacle_type = "moving"
		arm_visual.glow_color = Color(1.0, 0.3, 0.3, 0.5)
		arm_visual.offset = Vector2(-arm_length * 0.4 * (1 if i == 0 else -1), 0)
		arm.add_child(arm_visual)

		pivot.add_child(arm)

	# Rotation script
	var rotator: RotatingObstacle = RotatingObstacle.new()
	rotator.rotation_speed = rotation_speed
	pivot.add_child(rotator)

	moving_obstacles.append(pivot)

func _add_boost_pad(pos: Vector2, direction: Vector2, strength: float) -> void:
	var area: Area2D = Area2D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 2  # Balls layer

	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 35.0
	shape.shape = circle
	area.add_child(shape)

	# Visual
	var visual: BoostPadVisual = BoostPadVisual.new()
	visual.direction = direction
	area.add_child(visual)

	# Connect signal
	area.body_entered.connect(_on_boost_pad_entered.bind(direction, strength))

	boost_pads.add_child(area)

func _on_boost_pad_entered(body: Node2D, direction: Vector2, strength: float) -> void:
	if body is RigidBody2D:
		body.apply_central_impulse(direction * strength)
		boost_pad_triggered.emit(body, direction, strength)

func _add_danger_zone(pos: Vector2, radius: float, dps: float) -> void:
	var area: Area2D = Area2D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 2

	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)

	# Visual
	var visual: DangerZoneVisual = DangerZoneVisual.new()
	visual.radius = radius
	area.add_child(visual)

	# Damage ticker
	var ticker: DangerZoneTicker = DangerZoneTicker.new()
	ticker.dps = dps
	area.add_child(ticker)

	hazards.add_child(area)

func get_spawn_positions(count: int, p_rng: RandomNumberGenerator) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var margin: float = 80.0
	var min_distance: float = 100.0

	for i in range(count):
		var attempts: int = 0
		var pos: Vector2 = Vector2.ZERO

		while attempts < 100:
			pos = Vector2(
				p_rng.randf_range(margin, arena_size.x - margin),
				p_rng.randf_range(margin, arena_size.y - margin)
			)

			var valid: bool = true

			for other_pos in positions:
				if pos.distance_to(other_pos) < min_distance:
					valid = false
					break

			# Avoid center for hazard arenas
			if valid and arena_type == ArenaType.HAZARDS:
				if pos.distance_to(arena_size / 2) < 120:
					valid = false

			if valid:
				break
			attempts += 1

		positions.append(pos)

	return positions

func get_arena_center() -> Vector2:
	return arena_size / 2

# Visual classes
class ObstacleVisual extends Node2D:
	var obstacle_size: Vector2 = Vector2(50, 50)
	var obstacle_radius: float = 25.0
	var obstacle_type: String = "rect"
	var glow_color: Color = Color(0.4, 0.5, 0.7, 0.4)
	var offset: Vector2 = Vector2.ZERO

	func _draw() -> void:
		var main_color: Color = Color(0.35, 0.4, 0.5)
		var highlight: Color = Color(0.5, 0.55, 0.65)

		match obstacle_type:
			"rect", "moving":
				# Shadow
				draw_rect(Rect2(offset - obstacle_size / 2 + Vector2(3, 3), obstacle_size), Color(0, 0, 0, 0.3))
				# Main
				draw_rect(Rect2(offset - obstacle_size / 2, obstacle_size), main_color)
				# Highlight
				draw_rect(Rect2(offset - obstacle_size / 2 + Vector2(3, 3), obstacle_size - Vector2(6, 6)), highlight)
				# Glow edge
				if obstacle_type == "moving":
					draw_rect(Rect2(offset - obstacle_size / 2, obstacle_size), glow_color, false, 2.0)
			"circle":
				# Shadow
				draw_circle(offset + Vector2(3, 3), obstacle_radius, Color(0, 0, 0, 0.3))
				# Main
				draw_circle(offset, obstacle_radius, main_color)
				# Highlight
				draw_circle(offset, obstacle_radius * 0.7, highlight)
				# Glow edge
				draw_arc(offset, obstacle_radius, 0, TAU, 32, glow_color, 2.0)

class BoostPadVisual extends Node2D:
	var direction: Vector2 = Vector2.RIGHT
	var time: float = 0.0

	func _process(delta: float) -> void:
		time += delta
		queue_redraw()

	func _draw() -> void:
		var pulse: float = 0.5 + 0.5 * sin(time * 4.0)
		var base_color: Color = Color(0.2, 0.8, 0.4, 0.3 + pulse * 0.3)
		var arrow_color: Color = Color(0.3, 1.0, 0.5, 0.6 + pulse * 0.4)

		# Base circle
		draw_circle(Vector2.ZERO, 35.0, base_color)
		draw_arc(Vector2.ZERO, 35.0, 0, TAU, 24, arrow_color, 2.0)

		# Arrow
		var arrow_size: float = 20.0
		var arrow_tip: Vector2 = direction * arrow_size
		var arrow_base: Vector2 = -direction * arrow_size * 0.5
		var perp: Vector2 = direction.rotated(PI / 2) * 8.0

		draw_line(arrow_base - perp, arrow_tip, arrow_color, 3.0)
		draw_line(arrow_base + perp, arrow_tip, arrow_color, 3.0)
		draw_line(arrow_base - perp, arrow_base + perp, arrow_color, 3.0)

class DangerZoneVisual extends Node2D:
	var radius: float = 50.0
	var time: float = 0.0

	func _process(delta: float) -> void:
		time += delta
		queue_redraw()

	func _draw() -> void:
		var pulse: float = 0.5 + 0.5 * sin(time * 3.0)
		var base_color: Color = Color(0.8, 0.2, 0.2, 0.2 + pulse * 0.15)
		var edge_color: Color = Color(1.0, 0.3, 0.3, 0.5 + pulse * 0.3)

		draw_circle(Vector2.ZERO, radius, base_color)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 24, edge_color, 2.0)
		draw_arc(Vector2.ZERO, radius * 0.6, 0, TAU, 16, edge_color * 0.7, 1.5)

class MovingObstacle extends Node:
	var base_position: Vector2 = Vector2.ZERO
	var move_range: Vector2 = Vector2(100, 0)
	var period: float = 2.0
	var time: float = 0.0

	func _process(delta: float) -> void:
		time += delta
		var t: float = sin(time * TAU / period)
		get_parent().position = base_position + move_range * t

class RotatingObstacle extends Node:
	var rotation_speed: float = 1.0

	func _process(delta: float) -> void:
		get_parent().rotation += rotation_speed * delta

class DangerZoneTicker extends Node:
	var dps: float = 10.0
	var bodies_in_zone: Array[Node2D] = []

	func _ready() -> void:
		var parent: Area2D = get_parent() as Area2D
		if parent:
			parent.body_entered.connect(_on_body_entered)
			parent.body_exited.connect(_on_body_exited)

	func _on_body_entered(body: Node2D) -> void:
		if body not in bodies_in_zone:
			bodies_in_zone.append(body)

	func _on_body_exited(body: Node2D) -> void:
		bodies_in_zone.erase(body)

	func _process(delta: float) -> void:
		for body in bodies_in_zone:
			if is_instance_valid(body) and body.has_method("is_alive") and body.is_alive():
				if body.get("hp") != null:
					body.hp -= dps * delta
