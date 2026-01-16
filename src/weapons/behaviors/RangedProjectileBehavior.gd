class_name RangedProjectileBehavior
extends WeaponBehavior

## Ranged projectile behavior for Bow.
## Fires volleys based on arrow_count, with pooling.

const ProjectileScene := preload("res://scenes/game/Projectile.tscn")

var fire_timer: float = 0.0
var current_target: Node2D = null
var projectile_pool: Array[Node2D] = []
const POOL_SIZE: int = 50

func _ready() -> void:
	_initialize_pool()

func _initialize_pool() -> void:
	for i in range(POOL_SIZE):
		var proj: ProjectileVisual = _create_projectile()
		proj.visible = false
		proj.set_physics_process(false)
		projectile_pool.append(proj)
		get_tree().root.call_deferred("add_child", proj)

func _create_projectile() -> ProjectileVisual:
	var proj: ProjectileVisual = ProjectileVisual.new()
	proj.name = "Projectile"
	proj.collision_layer = 8  # Projectiles layer
	proj.collision_mask = 2 | 4  # Balls layer + Weapons layer
	proj.monitoring = true
	proj.monitorable = false
	proj.radius = definition.projectile_radius
	proj.color = definition.color

	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = definition.projectile_radius
	shape.shape = circle
	proj.add_child(shape)

	proj.set_meta("velocity", Vector2.ZERO)
	proj.set_meta("lifetime", 0.0)
	proj.set_meta("owner_ball", null)
	proj.set_meta("behavior", self)

	proj.body_entered.connect(_on_projectile_hit.bind(proj))
	proj.area_entered.connect(_on_projectile_weapon_hit.bind(proj))

	return proj

class ProjectileVisual extends Area2D:
	var radius: float = 6.0
	var color: Color = Color.WHITE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		# Trail effect
		var trail_color: Color = color
		trail_color.a = 0.3
		var trail_length: float = radius * 4.0
		draw_line(Vector2(-trail_length, 0), Vector2.ZERO, trail_color, radius * 1.5)

		# Glow
		var glow_color: Color = color
		glow_color.a = 0.2
		draw_circle(Vector2.ZERO, radius * 1.8, glow_color)

		# Shadow
		draw_circle(Vector2(2, 2), radius, Color(0, 0, 0, 0.15))

		# Main projectile
		var outer_color: Color = color.darkened(0.1)
		var inner_color: Color = color.lightened(0.3)
		draw_circle(Vector2.ZERO, radius, outer_color)
		draw_circle(Vector2.ZERO, radius * 0.6, inner_color)

		# Highlight
		draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.25, Color(1, 1, 1, 0.4))

		# Arrow tip
		var tip_points: PackedVector2Array = PackedVector2Array([
			Vector2(radius * 1.5, 0),
			Vector2(radius * 0.5, -radius * 0.6),
			Vector2(radius * 0.5, radius * 0.6)
		])
		draw_colored_polygon(tip_points, color.lightened(0.1))

func _physics_process(delta: float) -> void:
	fire_timer -= delta

	_update_active_projectiles(delta)

func _update_active_projectiles(delta: float) -> void:
	for proj in projectile_pool:
		if proj.visible:
			var lifetime: float = proj.get_meta("lifetime")
			lifetime -= delta
			proj.set_meta("lifetime", lifetime)

			if lifetime <= 0:
				_return_to_pool(proj)
				continue

			var vel: Vector2 = proj.get_meta("velocity")
			proj.global_position += vel * delta

func fire_at_target(target: Node2D) -> void:
	if fire_timer > 0:
		return

	if not target or not is_instance_valid(target):
		return

	var distance: float = owner_ball.global_position.distance_to(target.global_position)
	if distance > definition.fire_range:
		return

	fire_timer = definition.fire_cooldown

	var base_direction: Vector2 = (target.global_position - owner_ball.global_position).normalized()

	for i in range(current_arrow_count):
		var proj: Node2D = _get_from_pool()
		if not proj:
			continue

		var spread_angle: float = 0.0
		if current_arrow_count > 1:
			spread_angle = deg_to_rad(-15 + (30.0 / (current_arrow_count - 1)) * i)

		var direction: Vector2 = base_direction.rotated(spread_angle)
		var velocity: Vector2 = direction * definition.projectile_speed

		proj.global_position = owner_ball.global_position + direction * (owner_ball.collision_radius + 5)
		proj.set_meta("velocity", velocity)
		proj.set_meta("lifetime", definition.projectile_lifetime)
		proj.set_meta("owner_ball", owner_ball)
		proj.rotation = direction.angle()
		proj.visible = true
		proj.set_physics_process(true)

func _get_from_pool() -> Node2D:
	for proj in projectile_pool:
		if not proj.visible:
			return proj
	return null

func _return_to_pool(proj: Node2D) -> void:
	proj.visible = false
	proj.set_physics_process(false)

func _on_projectile_hit(body: Node2D, proj: Node2D) -> void:
	var proj_owner: Node2D = proj.get_meta("owner_ball")

	if body == proj_owner:
		return

	if not body.has_method("is_alive") or not body.is_alive():
		return

	var tags: Array[String] = ["projectile"]

	var hit_event: HitEvent = HitEvent.create(
		proj_owner,
		body,
		current_damage,
		current_knockback,
		definition.id,
		tags
	)

	hit_event.relative_speed = definition.projectile_speed

	if combat_system.process_hit(hit_event):
		combat_system.apply_hit_cooldown(
			hit_event.attacker_id,
			hit_event.defender_id,
			definition.id,
			definition.hit_cooldown
		)
		on_hit(hit_event)

		# Play projectile hit sound
		Audio.play_weapon_hit_ball(0.8)

		if definition.pierce <= 0:
			_return_to_pool(proj)

func _on_projectile_weapon_hit(weapon_area: Area2D, proj: Node2D) -> void:
	# Check if this is a weapon hitbox
	if not weapon_area.has_meta("owner_ball"):
		return

	var weapon_owner: Node2D = weapon_area.get_meta("owner_ball")
	var proj_owner: Node2D = proj.get_meta("owner_ball")

	# Don't collide with own weapons
	if weapon_owner == proj_owner:
		return

	# Check if weapon owner is alive
	if not is_instance_valid(weapon_owner) or not weapon_owner.has_method("is_alive") or not weapon_owner.is_alive():
		return

	# Deflect the projectile - reflect velocity off the weapon
	var vel: Vector2 = proj.get_meta("velocity")
	var to_weapon: Vector2 = (weapon_area.global_position - proj.global_position).normalized()

	# Reflect the velocity
	var reflected_vel: Vector2 = vel.bounce(to_weapon)
	proj.set_meta("velocity", reflected_vel)
	proj.rotation = reflected_vel.angle()

	# Play deflection sound (clack)
	Audio.play_weapon_clash(0.7)

	# Apply small knockback to the weapon owner
	if weapon_owner is RigidBody2D:
		weapon_owner.apply_central_impulse(-to_weapon * 80.0)

	# Deal reduced damage to weapon owner (projectile was deflected but still stings)
	var deflect_damage: float = current_damage * 0.1  # 10% damage on deflect

	var tags: Array[String] = ["projectile", "deflected"]
	var hit_event: HitEvent = HitEvent.create(
		proj_owner,
		weapon_owner,
		deflect_damage,
		0.0,
		definition.id,
		tags
	)

	if combat_system.process_hit(hit_event):
		combat_system.apply_hit_cooldown(
			hit_event.attacker_id,
			hit_event.defender_id,
			"deflect_" + definition.id,
			0.2
		)

func disable() -> void:
	super.disable()
	# Deactivate all projectiles
	for proj in projectile_pool:
		if is_instance_valid(proj) and proj.visible:
			proj.monitoring = false
			_return_to_pool(proj)

func _exit_tree() -> void:
	for proj in projectile_pool:
		if is_instance_valid(proj):
			proj.queue_free()
	projectile_pool.clear()
