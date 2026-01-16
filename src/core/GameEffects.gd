extends Node

## Global game effects manager for juice and feedback.
## Handles screen shake, hit freeze, damage numbers, impact effects.

# Screen shake state
var shake_amount: float = 0.0
var shake_decay: float = 8.0
var camera_offset: Vector2 = Vector2.ZERO

# Hit freeze state
var freeze_timer: float = 0.0
var pre_freeze_time_scale: float = 1.0

# Damage numbers container
var damage_numbers: Array[Node2D] = []
const MAX_DAMAGE_NUMBERS: int = 30

# Impact effects container
var impact_effects: Array[Node2D] = []
const MAX_IMPACT_EFFECTS: int = 20

# References
var game_root: Node2D = null
var effects_container: Node2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	_update_screen_shake(delta)
	_update_hit_freeze(delta)
	_cleanup_effects()

var base_position: Vector2 = Vector2(25, 20)

func set_game_root(root: Node2D) -> void:
	game_root = root
	game_root.position = base_position

	# Create effects container
	effects_container = Node2D.new()
	effects_container.name = "Effects"
	effects_container.z_index = 100
	game_root.add_child(effects_container)

# ============================================
# SCREEN SHAKE
# ============================================

func shake(amount: float, decay: float = 8.0) -> void:
	shake_amount = maxf(shake_amount, amount)
	shake_decay = decay

func _update_screen_shake(delta: float) -> void:
	if not game_root or not is_instance_valid(game_root):
		return

	if shake_amount > 0.1:
		camera_offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		shake_amount = lerpf(shake_amount, 0.0, shake_decay * delta)
		game_root.position = base_position + camera_offset
	else:
		shake_amount = 0.0
		camera_offset = Vector2.ZERO
		game_root.position = base_position

# ============================================
# HIT FREEZE (HITSTOP)
# ============================================

var last_freeze_time: int = 0

func hit_freeze(_duration: float) -> void:
	# Disabled for now - was causing time scale conflicts
	pass

func _update_hit_freeze(_delta: float) -> void:
	# Disabled for now
	pass

# ============================================
# DAMAGE NUMBERS
# ============================================

func spawn_damage_number(pos: Vector2, damage: float, is_crit: bool = false) -> void:
	if not effects_container or not is_instance_valid(effects_container):
		return

	# Pool management
	if damage_numbers.size() >= MAX_DAMAGE_NUMBERS:
		var oldest: Node2D = damage_numbers.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	var num: DamageNumber = DamageNumber.new()
	num.position = pos
	num.damage = damage
	num.is_crit = is_crit
	effects_container.add_child(num)
	damage_numbers.append(num)

# ============================================
# IMPACT EFFECTS
# ============================================

func spawn_impact(pos: Vector2, color: Color, size: float = 1.0, is_death: bool = false) -> void:
	if not effects_container or not is_instance_valid(effects_container):
		return

	# Pool management
	if impact_effects.size() >= MAX_IMPACT_EFFECTS:
		var oldest: Node2D = impact_effects.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	var impact: ImpactEffect = ImpactEffect.new()
	impact.position = pos
	impact.effect_color = color
	impact.effect_size = size
	impact.is_death = is_death
	effects_container.add_child(impact)
	impact_effects.append(impact)

func spawn_sparks(pos: Vector2, direction: Vector2, color: Color, count: int = 5) -> void:
	if not effects_container or not is_instance_valid(effects_container):
		return

	var sparks: SparkEffect = SparkEffect.new()
	sparks.position = pos
	sparks.direction = direction
	sparks.spark_color = color
	sparks.spark_count = count
	effects_container.add_child(sparks)
	impact_effects.append(sparks)

# ============================================
# SCREEN FLASH
# ============================================

func screen_flash(color: Color = Color.WHITE, duration: float = 0.1) -> void:
	if not effects_container or not is_instance_valid(effects_container):
		return

	var flash: ScreenFlash = ScreenFlash.new()
	flash.flash_color = color
	flash.duration = duration
	flash.z_index = 200
	effects_container.add_child(flash)

# ============================================
# SLOW MOTION
# ============================================

func slow_motion(_scale: float, _duration: float) -> void:
	# Disabled for now - was causing time scale conflicts with Simulation
	pass

# ============================================
# KILL POPUP
# ============================================

func spawn_kill_popup(pos: Vector2, killer_name: String, victim_name: String, color: Color) -> void:
	if not effects_container or not is_instance_valid(effects_container):
		return

	var popup: KillPopup = KillPopup.new()
	popup.position = pos + Vector2(0, -50)
	popup.killer_name = killer_name
	popup.victim_name = victim_name
	popup.popup_color = color
	effects_container.add_child(popup)

# ============================================
# CLEANUP
# ============================================

func _cleanup_effects() -> void:
	# Remove invalid references
	damage_numbers = damage_numbers.filter(func(n): return is_instance_valid(n))
	impact_effects = impact_effects.filter(func(e): return is_instance_valid(e))

# ============================================
# EFFECT CLASSES
# ============================================

class DamageNumber extends Node2D:
	var damage: float = 0.0
	var is_crit: bool = false
	var lifetime: float = 0.0
	var velocity: Vector2 = Vector2(0, -80)
	var max_lifetime: float = 0.8

	func _ready() -> void:
		velocity.x = randf_range(-30, 30)
		if is_crit:
			velocity.y = -120

	func _process(delta: float) -> void:
		lifetime += delta
		position += velocity * delta
		velocity.y += 150 * delta  # Gravity
		velocity *= 0.98  # Drag

		if lifetime >= max_lifetime:
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var alpha: float = 1.0 - (lifetime / max_lifetime)
		alpha = clampf(alpha * 1.5, 0.0, 1.0)

		var scale_pop: float = 1.0 + (1.0 - minf(lifetime * 8.0, 1.0)) * 0.5

		var text: String = "%d" % int(damage)
		var font: Font = ThemeDB.fallback_font
		var font_size: int = 16 if is_crit else 12
		font_size = int(font_size * scale_pop)

		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos: Vector2 = -text_size / 2 + Vector2(0, text_size.y * 0.3)

		# Shadow
		var shadow_color: Color = Color(0, 0, 0, alpha * 0.6)
		draw_string(font, text_pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow_color)

		# Main text
		var text_color: Color = Color(1.0, 0.3, 0.3) if is_crit else Color(1.0, 0.95, 0.8)
		text_color.a = alpha
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

class ImpactEffect extends Node2D:
	var effect_color: Color = Color.WHITE
	var effect_size: float = 1.0
	var is_death: bool = false
	var lifetime: float = 0.0
	var max_lifetime: float = 0.3
	var rings: Array[Dictionary] = []

	func _ready() -> void:
		if is_death:
			max_lifetime = 0.5
			# Add multiple expanding rings for death
			rings.append({"radius": 10.0, "speed": 200.0, "width": 4.0})
			rings.append({"radius": 5.0, "speed": 150.0, "width": 6.0})
			rings.append({"radius": 0.0, "speed": 100.0, "width": 8.0})
		else:
			rings.append({"radius": 5.0, "speed": 120.0, "width": 3.0})

	func _process(delta: float) -> void:
		lifetime += delta

		for ring in rings:
			ring.radius += ring.speed * delta

		if lifetime >= max_lifetime:
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var progress: float = lifetime / max_lifetime
		var alpha: float = 1.0 - progress

		# Flash circle (instant then fade)
		if lifetime < 0.05:
			var flash_alpha: float = (1.0 - lifetime / 0.05) * 0.6
			draw_circle(Vector2.ZERO, 20.0 * effect_size, Color(1, 1, 1, flash_alpha))

		# Expanding rings
		for ring in rings:
			var ring_color: Color = effect_color
			ring_color.a = alpha * 0.8
			var width: float = ring.width * (1.0 - progress * 0.5)
			draw_arc(Vector2.ZERO, ring.radius * effect_size, 0, TAU, 24, ring_color, width)

class SparkEffect extends Node2D:
	var direction: Vector2 = Vector2.RIGHT
	var spark_color: Color = Color.WHITE
	var spark_count: int = 5
	var sparks: Array[Dictionary] = []
	var lifetime: float = 0.0
	var max_lifetime: float = 0.4

	func _ready() -> void:
		for i in range(spark_count):
			var angle: float = direction.angle() + randf_range(-0.8, 0.8)
			var speed: float = randf_range(100, 250)
			sparks.append({
				"pos": Vector2.ZERO,
				"vel": Vector2(cos(angle), sin(angle)) * speed,
				"size": randf_range(2, 5),
				"life": randf_range(0.6, 1.0)
			})

	func _process(delta: float) -> void:
		lifetime += delta

		for spark in sparks:
			spark.pos += spark.vel * delta
			spark.vel *= 0.95
			spark.life -= delta * 2.5

		if lifetime >= max_lifetime:
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		for spark in sparks:
			if spark.life > 0:
				var color: Color = spark_color
				color.a = clampf(spark.life, 0.0, 1.0)
				draw_circle(spark.pos, spark.size * spark.life, color)

class ScreenFlash extends Node2D:
	var flash_color: Color = Color.WHITE
	var duration: float = 0.1
	var lifetime: float = 0.0

	func _process(delta: float) -> void:
		lifetime += delta
		if lifetime >= duration:
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var alpha: float = 1.0 - (lifetime / duration)
		alpha = clampf(alpha, 0.0, 0.5)
		var color: Color = flash_color
		color.a = alpha
		draw_rect(Rect2(-500, -500, 2000, 2000), color)

class SlowMotion extends Node:
	var target_scale: float = 0.3
	var duration: float = 0.3
	var lifetime: float = 0.0
	var original_scale: float = 1.0
	var last_time: int = 0

	func _ready() -> void:
		original_scale = maxf(Engine.time_scale, 0.1)
		process_mode = Node.PROCESS_MODE_ALWAYS
		last_time = Time.get_ticks_msec()

	func _process(_delta: float) -> void:
		# Use real time since we're modifying time_scale
		var current_time: int = Time.get_ticks_msec()
		var real_delta: float = (current_time - last_time) / 1000.0
		last_time = current_time

		lifetime += real_delta

		var progress: float = lifetime / duration

		if progress < 0.2:
			# Ease into slow motion
			Engine.time_scale = lerpf(original_scale, target_scale, progress / 0.2)
		elif progress < 0.8:
			# Hold
			Engine.time_scale = target_scale
		elif progress < 1.0:
			# Ease out
			Engine.time_scale = lerpf(target_scale, original_scale, (progress - 0.8) / 0.2)
		else:
			Engine.time_scale = original_scale
			queue_free()

class KillPopup extends Node2D:
	var killer_name: String = ""
	var victim_name: String = ""
	var popup_color: Color = Color.WHITE
	var lifetime: float = 0.0
	var max_lifetime: float = 1.2
	var velocity: Vector2 = Vector2(0, -40)

	func _process(delta: float) -> void:
		lifetime += delta
		position += velocity * delta
		velocity *= 0.95

		if lifetime >= max_lifetime:
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var progress: float = lifetime / max_lifetime
		var alpha: float = 1.0 - progress
		alpha = clampf(alpha * 1.5, 0.0, 1.0)

		# Scale animation - pop in then shrink
		var scale_mult: float = 1.0
		if lifetime < 0.1:
			scale_mult = 1.0 + (1.0 - lifetime / 0.1) * 0.5
		else:
			scale_mult = 1.0 - progress * 0.3

		var font: Font = ThemeDB.fallback_font
		var font_size: int = int(18 * scale_mult)

		var text: String = "ELIMINATED!"
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos: Vector2 = -text_size / 2 + Vector2(0, text_size.y * 0.3)

		# Glow/outline
		var glow_color: Color = popup_color.darkened(0.3)
		glow_color.a = alpha * 0.8
		for ox in range(-2, 3):
			for oy in range(-2, 3):
				if ox != 0 or oy != 0:
					draw_string(font, text_pos + Vector2(ox, oy), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, glow_color)

		# Main text
		var text_color: Color = popup_color.lightened(0.3)
		text_color.a = alpha
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
