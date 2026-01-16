class_name UnarmedBehavior
extends WeaponBehavior

## Unarmed behavior - damage scales with collision speed.
## On-hit scaling: +max_speed per hit.

var hitbox: Area2D
var hitbox_shape: CollisionShape2D

func _ready() -> void:
	_create_hitbox()

func _create_hitbox() -> void:
	hitbox = Area2D.new()
	hitbox.name = "UnarmedHitbox"
	hitbox.collision_layer = 4  # Weapons layer
	hitbox.collision_mask = 2   # Balls layer
	hitbox.monitoring = true
	hitbox.monitorable = false

	hitbox_shape = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = owner_ball.collision_radius if owner_ball else 18.0
	hitbox_shape.shape = circle
	hitbox.add_child(hitbox_shape)

	add_child(hitbox)
	hitbox.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body == owner_ball:
		return

	if not body.has_method("is_alive") or not body.is_alive():
		return

	var tags: Array[String] = ["melee", "unarmed"]

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

func get_stats_display() -> Dictionary:
	var stats: Dictionary = super.get_stats_display()
	if owner_ball and owner_ball.has_method("get_max_speed"):
		stats["max_speed"] = owner_ball.get_max_speed()
	return stats
