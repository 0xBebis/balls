class_name OrbitMeleeBehavior
extends WeaponBehavior

## Orbiting melee hitbox behavior for Sword, Dagger, Spear, and Scythe.
## Supports multiple hitboxes evenly spaced around the orbit.
## Weapons physically bounce off balls and other weapons using impulse forces.

var hitboxes: Array[Area2D] = []
var orbit_angle: float = 0.0
var weapon_count: int = 1

const WEAPON_VS_WEAPON_DAMAGE_MULT: float = 0.12  # 12% damage for weapon clashes
const WEAPON_VS_BALL_BOUNCE_FORCE: float = 800.0  # Force when weapon hits a ball
const WEAPON_VS_WEAPON_BOUNCE_FORCE: float = 650.0  # Force when weapons clash
const BOUNCE_COOLDOWN: float = 0.07  # Cooldown for bounces

# Track recent bounces to prevent spam
var bounce_cooldowns: Dictionary = {}

func _ready() -> void:
	weapon_count = definition.weapon_count if definition else 1
	_create_hitboxes()

func _create_hitboxes() -> void:
	var angle_offset: float = TAU / weapon_count

	for i in range(weapon_count):
		var hitbox: Area2D = Area2D.new()
		hitbox.name = "WeaponHitbox_%d" % i
		hitbox.collision_layer = 4  # Weapons layer
		hitbox.collision_mask = 2 | 4  # Balls layer + Weapons layer
		hitbox.monitoring = true
		hitbox.monitorable = true

		# Store references for collision handling
		hitbox.set_meta("owner_ball", owner_ball)
		hitbox.set_meta("behavior", self)
		hitbox.set_meta("hitbox_index", i)

		var hitbox_shape: CollisionShape2D = CollisionShape2D.new()
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = definition.hitbox_size
		hitbox_shape.shape = circle
		hitbox.add_child(hitbox_shape)

		add_child(hitbox)
		hitbox.body_entered.connect(_on_body_entered.bind(hitbox))
		hitbox.area_entered.connect(_on_area_entered.bind(hitbox))

		hitboxes.append(hitbox)

	_update_hitbox_positions()

func _physics_process(delta: float) -> void:
	orbit_angle += current_rotation_speed * delta
	_update_hitbox_positions()
	_cleanup_cooldowns(delta)
	queue_redraw()

func _cleanup_cooldowns(delta: float) -> void:
	var to_remove: Array = []
	for key in bounce_cooldowns:
		bounce_cooldowns[key] -= delta
		if bounce_cooldowns[key] <= 0:
			to_remove.append(key)
	for key in to_remove:
		bounce_cooldowns.erase(key)

func _update_hitbox_positions() -> void:
	var angle_offset: float = TAU / weapon_count

	for i in range(hitboxes.size()):
		var hitbox: Area2D = hitboxes[i]
		var angle: float = orbit_angle + angle_offset * i
		hitbox.position = Vector2(current_reach, 0).rotated(angle)

func _get_bounce_key(obj_a: Node, obj_b: Node) -> String:
	var id_a: int = obj_a.get_instance_id()
	var id_b: int = obj_b.get_instance_id()
	return "%d_%d" % [mini(id_a, id_b), maxi(id_a, id_b)]

func _can_bounce(obj_a: Node, obj_b: Node) -> bool:
	var key: String = _get_bounce_key(obj_a, obj_b)
	return not bounce_cooldowns.has(key)

func _apply_bounce_cooldown(obj_a: Node, obj_b: Node) -> void:
	var key: String = _get_bounce_key(obj_a, obj_b)
	bounce_cooldowns[key] = BOUNCE_COOLDOWN

func _draw() -> void:
	if hitboxes.is_empty():
		return

	var weapon_color: Color = definition.color if definition else Color.WHITE
	var hitbox_size: float = definition.hitbox_size
	var angle_offset: float = TAU / weapon_count

	for i in range(hitboxes.size()):
		var hitbox: Area2D = hitboxes[i]
		var angle: float = orbit_angle + angle_offset * i

		# Draw orbit trail (faded arc)
		var trail_color: Color = weapon_color
		trail_color.a = 0.12
		draw_arc(Vector2.ZERO, current_reach, angle - 1.2, angle, 10, trail_color, hitbox_size * 1.3)

		# Draw orbit line with glow
		var line_color: Color = weapon_color.darkened(0.2)
		line_color.a = 0.35
		draw_line(Vector2.ZERO, hitbox.position, line_color, 2.5)

		# Draw weapon shadow
		var shadow_offset: Vector2 = Vector2(2, 2)
		draw_circle(hitbox.position + shadow_offset, hitbox_size, Color(0, 0, 0, 0.2))

		# Draw weapon hitbox with gradient effect
		var outer_color: Color = weapon_color.darkened(0.1)
		var inner_color: Color = weapon_color.lightened(0.2)
		draw_circle(hitbox.position, hitbox_size, outer_color)
		draw_circle(hitbox.position, hitbox_size * 0.65, inner_color)

		# Draw highlight
		var highlight_pos: Vector2 = hitbox.position + Vector2(-hitbox_size * 0.25, -hitbox_size * 0.25)
		draw_circle(highlight_pos, hitbox_size * 0.22, Color(1, 1, 1, 0.35))

		# Draw outline
		draw_arc(hitbox.position, hitbox_size, 0, TAU, 20, weapon_color.darkened(0.4), 1.5)

func _on_body_entered(body: Node2D, my_hitbox: Area2D) -> void:
	# This handles weapon hitting a ball directly
	if body == owner_ball:
		return

	if not body.has_method("is_alive") or not body.is_alive():
		return

	# Apply bounce force - push the other ball away from the weapon
	if body is RigidBody2D and _can_bounce(my_hitbox, body):
		var weapon_pos: Vector2 = my_hitbox.global_position
		var ball_pos: Vector2 = body.global_position
		var push_dir: Vector2 = (ball_pos - weapon_pos).normalized()

		# Push the hit ball away
		body.apply_central_impulse(push_dir * WEAPON_VS_BALL_BOUNCE_FORCE)

		# Also push our ball back (reaction force)
		if owner_ball is RigidBody2D:
			owner_ball.apply_central_impulse(-push_dir * WEAPON_VS_BALL_BOUNCE_FORCE * 0.5)

		_apply_bounce_cooldown(my_hitbox, body)

		# Play weapon hitting ball sound
		Audio.play_weapon_hit_ball(1.0)

	# Apply damage
	var tags: Array[String] = ["melee"]
	if definition.applies_poison:
		tags.append("poison")

	var hit_event: HitEvent = HitEvent.create(
		owner_ball,
		body,
		current_damage,
		current_knockback,
		definition.id,
		tags
	)

	if combat_system.process_hit(hit_event):
		combat_system.apply_hit_cooldown(
			hit_event.attacker_id,
			hit_event.defender_id,
			definition.id,
			definition.hit_cooldown
		)
		on_hit(hit_event)

func _on_area_entered(other_area: Area2D, my_hitbox: Area2D) -> void:
	# This handles weapon hitting another weapon
	if not other_area.has_meta("owner_ball"):
		return

	var other_owner: Node2D = other_area.get_meta("owner_ball")

	# Don't collide with our own weapons
	if other_owner == owner_ball:
		return

	# Check if both balls are alive
	if not is_instance_valid(owner_ball) or not owner_ball.is_alive():
		return
	if not is_instance_valid(other_owner) or not other_owner.has_method("is_alive") or not other_owner.is_alive():
		return

	# Apply bounce force - push both balls apart from the clash point
	if _can_bounce(my_hitbox, other_area):
		var my_weapon_pos: Vector2 = my_hitbox.global_position
		var other_weapon_pos: Vector2 = other_area.global_position
		var clash_point: Vector2 = (my_weapon_pos + other_weapon_pos) / 2.0

		# Push both balls away from clash point
		if owner_ball is RigidBody2D:
			var push_dir: Vector2 = (owner_ball.global_position - clash_point).normalized()
			owner_ball.apply_central_impulse(push_dir * WEAPON_VS_WEAPON_BOUNCE_FORCE)

		if other_owner is RigidBody2D:
			var push_dir: Vector2 = (other_owner.global_position - clash_point).normalized()
			other_owner.apply_central_impulse(push_dir * WEAPON_VS_WEAPON_BOUNCE_FORCE)

		_apply_bounce_cooldown(my_hitbox, other_area)

		# Play weapon clash sound
		Audio.play_weapon_clash(1.0)

	# Only process damage once (the ball with lower instance ID processes it)
	if owner_ball.get_instance_id() > other_owner.get_instance_id():
		return

	# Calculate clash damage (reduced)
	var clash_damage: float = current_damage * WEAPON_VS_WEAPON_DAMAGE_MULT
	var other_behavior: WeaponBehavior = other_area.get_meta("behavior") if other_area.has_meta("behavior") else null
	var other_damage: float = clash_damage
	if other_behavior:
		other_damage = other_behavior.current_damage * WEAPON_VS_WEAPON_DAMAGE_MULT

	# Create hit events for weapon clash (both take reduced damage)
	var tags: Array[String] = ["melee", "weapon_clash"]

	var hit_event_other: HitEvent = HitEvent.create(
		owner_ball,
		other_owner,
		clash_damage,
		0.0,
		definition.id,
		tags
	)

	var other_weapon_id: String = other_behavior.definition.id if other_behavior else "unknown"
	var hit_event_self: HitEvent = HitEvent.create(
		other_owner,
		owner_ball,
		other_damage,
		0.0,
		other_weapon_id,
		tags
	)

	var clash_id: String = "clash_%d_%d" % [mini(owner_ball.get_instance_id(), other_owner.get_instance_id()),
										   maxi(owner_ball.get_instance_id(), other_owner.get_instance_id())]

	if combat_system.process_hit(hit_event_other):
		combat_system.apply_hit_cooldown(
			hit_event_other.attacker_id,
			hit_event_other.defender_id,
			clash_id,
			0.3
		)
		combat_system.process_hit(hit_event_self)

func on_hit(hit_event: HitEvent) -> void:
	super.on_hit(hit_event)

func disable() -> void:
	super.disable()
	for hitbox in hitboxes:
		hitbox.monitoring = false
		hitbox.set_deferred("monitoring", false)
		hitbox.queue_free()
	hitboxes.clear()
	bounce_cooldowns.clear()
