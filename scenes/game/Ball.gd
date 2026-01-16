class_name Ball
extends RigidBody2D

## Main ball entity with enhanced visuals - trails, effects, animations.

signal died

var definition: BallDefinition
var hp: float = 100.0
var max_hp: float = 100.0
var team: int = -1
var max_speed: float = 420.0
var collision_radius: float = 18.0

var weapon: WeaponBehavior
var ai_controller: SimpleAIController
var _alive: bool = true
var ball_color: Color = Color.WHITE

# Combat stats
var stats_damage_dealt: float = 0.0
var stats_damage_taken: float = 0.0
var stats_hits_landed: int = 0
var stats_hits_received: int = 0
var stats_kills: int = 0
var stats_time_alive: float = 0.0
var stats_max_speed_reached: float = 0.0

# Visual effects
var trail_positions: Array[Vector2] = []
var trail_velocities: Array[Vector2] = []
const MAX_TRAIL_LENGTH: int = 8
const TRAIL_UPDATE_INTERVAL: float = 0.02
var trail_timer: float = 0.0

var damage_flash_timer: float = 0.0
var dash_effect_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO

var death_animation_timer: float = 0.0
var death_particles: Array[Dictionary] = []

# Ball collision sound tracking
var ball_collision_cooldown: float = 0.0
const BALL_COLLISION_SOUND_COOLDOWN: float = 0.1

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var weapon_mount: Node2D = $WeaponMount

func initialize(
	def: BallDefinition,
	combat_system: CombatSystem,
	status_system: StatusSystem,
	weapon_def: WeaponDefinition,
	p_team: int = -1,
	ai_seed: int = 0
) -> void:
	definition = def

	# Apply physics properties
	mass = def.mass
	max_speed = def.max_speed
	linear_damp = def.linear_damp
	angular_damp = def.angular_damp
	collision_radius = def.radius

	# Create physics material
	var mat: PhysicsMaterial = PhysicsMaterial.new()
	mat.friction = def.friction
	mat.bounce = def.bounce
	physics_material_override = mat

	# Set collision shape
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = def.radius
	collision_shape.shape = circle

	# Combat state
	max_hp = def.base_hp
	hp = max_hp
	team = p_team if p_team >= 0 else def.team

	# Visual
	ball_color = def.color
	queue_redraw()

	# Enable ball collision detection for sound effects
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	# Register with combat system
	combat_system.register_ball(self)

	# Create weapon
	if weapon_def:
		weapon = WeaponFactory.create_weapon(weapon_def, self, combat_system, status_system)
		weapon_mount.add_child(weapon)

	# Create AI
	ai_controller = SimpleAIController.new()
	ai_controller.initialize(self, combat_system, ai_seed)
	ai_controller.dashed.connect(_on_ai_dashed)
	add_child(ai_controller)

func _process(delta: float) -> void:
	queue_redraw()

	# Update timers
	damage_flash_timer = maxf(0.0, damage_flash_timer - delta)
	dash_effect_timer = maxf(0.0, dash_effect_timer - delta)
	ball_collision_cooldown = maxf(0.0, ball_collision_cooldown - delta)

	if _alive:
		stats_time_alive += delta
		var current_speed: float = linear_velocity.length()
		if current_speed > stats_max_speed_reached:
			stats_max_speed_reached = current_speed

		# Update trail
		trail_timer += delta
		if trail_timer >= TRAIL_UPDATE_INTERVAL:
			trail_timer = 0.0
			_update_trail()
	else:
		# Death animation
		death_animation_timer += delta
		_update_death_particles(delta)

func _update_trail() -> void:
	var speed: float = linear_velocity.length()
	var speed_ratio: float = speed / max_speed if max_speed > 0 else 0

	# Only show trail when moving fast
	if speed_ratio > 0.3:
		trail_positions.push_front(global_position)
		trail_velocities.push_front(linear_velocity)

		while trail_positions.size() > MAX_TRAIL_LENGTH:
			trail_positions.pop_back()
			trail_velocities.pop_back()
	else:
		# Fade out trail when slow
		if trail_positions.size() > 0:
			trail_positions.pop_back()
			trail_velocities.pop_back()

func _on_ai_dashed(direction: Vector2) -> void:
	dash_effect_timer = 0.3
	dash_direction = direction

func _on_body_entered(body: Node) -> void:
	# Play thud sound when balls collide with each other
	if body is Ball and body != self and _alive:
		if ball_collision_cooldown <= 0:
			# Calculate intensity based on relative velocity
			var relative_velocity: float = (linear_velocity - body.linear_velocity).length()
			var intensity: float = clampf(relative_velocity / 400.0, 0.5, 1.2)
			Audio.play_ball_collision(intensity)
			ball_collision_cooldown = BALL_COLLISION_SOUND_COOLDOWN

func record_damage_dealt(amount: float) -> void:
	stats_damage_dealt += amount
	stats_hits_landed += 1

func record_damage_taken(amount: float) -> void:
	stats_damage_taken += amount
	stats_hits_received += 1
	damage_flash_timer = 0.15

func record_kill() -> void:
	stats_kills += 1

func get_combat_stats() -> Dictionary:
	return {
		"name": definition.display_name if definition else "Ball",
		"weapon": definition.weapon_id if definition else "none",
		"damage_dealt": stats_damage_dealt,
		"damage_taken": stats_damage_taken,
		"hits_landed": stats_hits_landed,
		"hits_received": stats_hits_received,
		"kills": stats_kills,
		"time_alive": stats_time_alive,
		"max_speed": stats_max_speed_reached,
		"alive": _alive,
		"hp_remaining": hp if _alive else 0.0,
		"dps": stats_damage_dealt / stats_time_alive if stats_time_alive > 0 else 0.0
	}

func is_alive() -> bool:
	return _alive and hp > 0

func die() -> void:
	if not _alive:
		return

	_alive = false
	died.emit()

	# Play death sound
	Audio.play_ball_death()

	# Disable physics and collision
	set_physics_process(false)
	collision_shape.set_deferred("disabled", true)

	# Disable weapon to stop it from dealing damage
	if weapon:
		weapon.disable()

	# Create death particles
	_spawn_death_particles()

func _spawn_death_particles() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	for i in range(12):
		var angle: float = rng.randf() * TAU
		var speed: float = rng.randf_range(80, 200)
		var particle: Dictionary = {
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"size": rng.randf_range(3, 8),
			"life": 1.0,
			"color": ball_color.lightened(rng.randf_range(-0.2, 0.3))
		}
		death_particles.append(particle)

func _update_death_particles(delta: float) -> void:
	for particle in death_particles:
		particle.pos += particle.vel * delta
		particle.vel *= 0.95  # Friction
		particle.life -= delta * 0.8

func add_max_speed(amount: float) -> void:
	max_speed += amount

func get_max_speed() -> float:
	return max_speed

func get_collision_radius() -> float:
	return collision_radius

func get_weapon_stats() -> Dictionary:
	if weapon:
		return weapon.get_stats_display()
	return {}

func get_display_info() -> Dictionary:
	return {
		"name": definition.display_name if definition else "Ball",
		"hp": hp,
		"max_hp": max_hp,
		"team": team,
		"weapon": definition.weapon_id if definition else "none",
		"weapon_stats": get_weapon_stats(),
		"alive": _alive
	}

func _draw() -> void:
	if not _alive:
		_draw_death_effect()
		return

	# Draw speed trail
	_draw_trail()

	# Draw dash effect
	if dash_effect_timer > 0:
		_draw_dash_effect()

	# Draw shadow
	var shadow_offset: Vector2 = Vector2(4, 4)
	var shadow_color: Color = Color(0, 0, 0, 0.25)
	draw_circle(shadow_offset, collision_radius, shadow_color)

	# Damage flash
	var flash_intensity: float = damage_flash_timer / 0.15
	var draw_color: Color = ball_color
	if flash_intensity > 0:
		draw_color = ball_color.lerp(Color.WHITE, flash_intensity * 0.7)

	# Draw main ball with gradient effect
	var inner_color: Color = draw_color.lightened(0.25)
	var outer_color: Color = draw_color.darkened(0.1)
	draw_circle(Vector2.ZERO, collision_radius, outer_color)
	draw_circle(Vector2.ZERO, collision_radius * 0.65, inner_color)

	# Draw highlight (top-left shine)
	var highlight_color: Color = Color(1, 1, 1, 0.35)
	var highlight_pos: Vector2 = Vector2(-collision_radius * 0.3, -collision_radius * 0.3)
	draw_circle(highlight_pos, collision_radius * 0.2, highlight_color)

	# Speed-based glow
	var speed_ratio: float = linear_velocity.length() / max_speed if max_speed > 0 else 0
	if speed_ratio > 0.5:
		var glow_alpha: float = (speed_ratio - 0.5) * 0.6
		var glow_color: Color = ball_color
		glow_color.a = glow_alpha
		draw_arc(Vector2.ZERO, collision_radius + 3, 0, TAU, 24, glow_color, 4.0)

	# Draw outline
	var outline_color: Color = draw_color.darkened(0.4)
	draw_arc(Vector2.ZERO, collision_radius, 0, TAU, 32, outline_color, 2.0)

	# Draw team indicator
	if team >= 0:
		var indicator_color: Color = Color(1.0, 0.3, 0.3) if team == 0 else Color(0.3, 0.5, 1.0)
		draw_circle(Vector2.ZERO, collision_radius * 0.22, indicator_color)
		draw_arc(Vector2.ZERO, collision_radius * 0.22, 0, TAU, 12, indicator_color.darkened(0.3), 1.5)

	# Draw HP bar
	_draw_hp_bar()

func _draw_trail() -> void:
	for i in range(trail_positions.size()):
		var trail_pos: Vector2 = trail_positions[i] - global_position
		var alpha: float = 1.0 - (float(i) / float(MAX_TRAIL_LENGTH))
		alpha *= 0.4

		var trail_color: Color = ball_color
		trail_color.a = alpha

		var trail_size: float = collision_radius * (1.0 - float(i) / float(MAX_TRAIL_LENGTH) * 0.5)
		draw_circle(trail_pos, trail_size, trail_color)

func _draw_dash_effect() -> void:
	var effect_alpha: float = dash_effect_timer / 0.3
	var dash_color: Color = Color(1, 1, 1, effect_alpha * 0.5)

	# Draw motion lines
	for i in range(3):
		var offset: float = (i - 1) * 8.0
		var perp: Vector2 = dash_direction.rotated(PI / 2) * offset
		var start_pos: Vector2 = -dash_direction * (collision_radius + 10 + i * 5) + perp
		var end_pos: Vector2 = -dash_direction * (collision_radius + 30 + i * 10) + perp
		draw_line(start_pos, end_pos, dash_color, 2.0 - i * 0.5)

func _draw_death_effect() -> void:
	# Draw remaining particles
	for particle in death_particles:
		if particle.life > 0:
			var p_color: Color = particle.color
			p_color.a = particle.life * 0.8
			draw_circle(particle.pos, particle.size * particle.life, p_color)

	# Draw faded ball
	var fade: float = maxf(0, 1.0 - death_animation_timer * 2)
	if fade > 0:
		var dead_color: Color = ball_color
		dead_color.a = fade * 0.3
		draw_circle(Vector2.ZERO, collision_radius * (1.0 + death_animation_timer * 0.5), dead_color)

func _draw_hp_bar() -> void:
	var bar_width: float = collision_radius * 2.2
	var bar_height: float = 5.0
	var bar_y: float = -collision_radius - 14.0
	var bar_x: float = -bar_width / 2.0

	# Background
	var bg_rect: Rect2 = Rect2(bar_x - 1, bar_y - 1, bar_width + 2, bar_height + 2)
	draw_rect(bg_rect, Color(0.05, 0.05, 0.1, 0.9))

	# HP percentage
	var hp_percent: float = clampf(hp / max_hp, 0.0, 1.0)

	# Color gradient
	var bar_color: Color
	if hp_percent > 0.5:
		var t: float = (hp_percent - 0.5) * 2.0
		bar_color = Color(1.0, 0.9, 0.2).lerp(Color(0.3, 0.95, 0.4), t)
	else:
		var t: float = hp_percent * 2.0
		bar_color = Color(0.95, 0.2, 0.2).lerp(Color(1.0, 0.9, 0.2), t)

	# HP fill
	var fill_width: float = bar_width * hp_percent
	if fill_width > 0:
		var fill_rect: Rect2 = Rect2(bar_x, bar_y, fill_width, bar_height)
		draw_rect(fill_rect, bar_color)

		# Shine
		var shine_rect: Rect2 = Rect2(bar_x, bar_y, fill_width, bar_height * 0.35)
		draw_rect(shine_rect, Color(1, 1, 1, 0.3))

	# Border
	draw_rect(Rect2(bar_x, bar_y, bar_width, bar_height), Color(0.25, 0.25, 0.3), false, 1.0)

	# HP text
	var hp_text: String = "%d" % int(hp)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 10
	var text_size: Vector2 = font.get_string_size(hp_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos: Vector2 = Vector2(-text_size.x / 2, bar_y - 3)

	draw_string(font, text_pos + Vector2(1, 1), hp_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0, 0, 0, 0.6))
	draw_string(font, text_pos, hp_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
