class_name StatusSystem
extends Node

## Manages status effects (currently only Poison for MVP).
## Ticks effects on physics frames.

signal poison_tick(ball: Node2D, damage: float)
signal poison_applied(ball: Node2D, stacks: int)
signal poison_expired(ball: Node2D)

const POISON_DPS_PER_STACK: float = 0.75
const POISON_DURATION: float = 3.0
const POISON_TICK_INTERVAL: float = 0.25

## Dictionary of ball instance_id -> PoisonState
var _poison_states: Dictionary = {}

class PoisonState:
	var stacks: int = 0
	var remaining_duration: float = 0.0
	var tick_accumulator: float = 0.0
	var poison_power: float = 1.0

func apply_poison(ball: Node2D, stacks: int = 1, poison_power: float = 1.0) -> void:
	var ball_id: int = ball.get_instance_id()

	if not _poison_states.has(ball_id):
		_poison_states[ball_id] = PoisonState.new()

	var state: PoisonState = _poison_states[ball_id]
	state.stacks += stacks
	state.remaining_duration = POISON_DURATION
	state.poison_power = poison_power

	poison_applied.emit(ball, state.stacks)

func get_poison_stacks(ball: Node2D) -> int:
	var ball_id: int = ball.get_instance_id()
	if _poison_states.has(ball_id):
		return _poison_states[ball_id].stacks
	return 0

func _physics_process(delta: float) -> void:
	var to_remove: Array[int] = []

	for ball_id in _poison_states.keys():
		var ball: Node2D = instance_from_id(ball_id) as Node2D
		if not is_instance_valid(ball) or not ball.is_alive():
			to_remove.append(ball_id)
			continue

		var state: PoisonState = _poison_states[ball_id]
		state.remaining_duration -= delta
		state.tick_accumulator += delta

		if state.remaining_duration <= 0:
			to_remove.append(ball_id)
			poison_expired.emit(ball)
			continue

		while state.tick_accumulator >= POISON_TICK_INTERVAL:
			state.tick_accumulator -= POISON_TICK_INTERVAL
			var damage: float = state.stacks * POISON_DPS_PER_STACK * state.poison_power * POISON_TICK_INTERVAL
			ball.hp -= damage
			poison_tick.emit(ball, damage)

			if ball.hp <= 0:
				ball.die()
				to_remove.append(ball_id)
				break

	for ball_id in to_remove:
		_poison_states.erase(ball_id)

func reset() -> void:
	_poison_states.clear()
