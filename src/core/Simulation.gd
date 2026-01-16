class_name Simulation
extends Node

## Main simulation coordinator. Holds references to all systems.
## Manages time scale, pause, step functionality.

signal simulation_paused
signal simulation_resumed
signal simulation_stepped
signal time_scale_changed(scale: float)

var combat_system: CombatSystem
var status_system: StatusSystem
var match_system: MatchSystem

var paused: bool = false
var time_scale: float = 1.0
var _step_requested: bool = false

const TIME_SCALES: Array[float] = [0.25, 1.0, 2.0, 4.0]

func _ready() -> void:
	combat_system = CombatSystem.new()
	combat_system.name = "CombatSystem"
	add_child(combat_system)

	status_system = StatusSystem.new()
	status_system.name = "StatusSystem"
	add_child(status_system)

	match_system = MatchSystem.new()
	match_system.name = "MatchSystem"
	match_system.set_combat_system(combat_system)
	add_child(match_system)

func pause() -> void:
	paused = true
	get_tree().paused = true
	simulation_paused.emit()

func unpause() -> void:
	paused = false
	get_tree().paused = false
	simulation_resumed.emit()

func toggle_pause() -> void:
	if paused:
		unpause()
	else:
		pause()

func step() -> void:
	if not paused:
		pause()

	get_tree().paused = false
	_step_requested = true
	simulation_stepped.emit()

func _physics_process(_delta: float) -> void:
	if _step_requested:
		_step_requested = false
		get_tree().paused = true

func set_time_scale(scale: float) -> void:
	time_scale = clampf(scale, 0.1, 10.0)
	Engine.time_scale = time_scale
	time_scale_changed.emit(time_scale)

func cycle_time_scale() -> void:
	var current_index: int = TIME_SCALES.find(time_scale)
	if current_index == -1:
		current_index = 1
	var next_index: int = (current_index + 1) % TIME_SCALES.size()
	set_time_scale(TIME_SCALES[next_index])

func reset() -> void:
	combat_system.reset()
	status_system.reset()
	match_system.reset()
	set_time_scale(1.0)
	if paused:
		unpause()
