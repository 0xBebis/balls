extends Node2D

## Main game coordinator. Manages arena, balls, and systems.

const BallScene := preload("res://scenes/game/Ball.tscn")
const ArenaScene := preload("res://scenes/game/Arena.tscn")
const DebugSpawnerScene := preload("res://scenes/ui/DebugSpawner.tscn")

var simulation: Simulation
var arena: Arena
var debug_spawner: DebugSpawner
var ball_container: Node2D

var spawned_balls: Array[Node2D] = []
var rng: RandomNumberGenerator

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	_setup_systems()
	_setup_arena()
	_setup_ui()
	_connect_signals()

func _setup_systems() -> void:
	simulation = Simulation.new()
	simulation.name = "Simulation"
	add_child(simulation)

	simulation.match_system.match_ended.connect(_on_match_ended)
	simulation.match_system.ball_eliminated.connect(_on_ball_eliminated)

func _setup_arena() -> void:
	arena = ArenaScene.instantiate()
	# Offset arena so walls (which extend into negative space) are visible
	arena.position = Vector2(25, 20)
	add_child(arena)

	ball_container = Node2D.new()
	ball_container.name = "Balls"
	# Ball container needs same offset as arena
	ball_container.position = Vector2(25, 20)
	add_child(ball_container)

func _setup_ui() -> void:
	var canvas_layer: CanvasLayer = CanvasLayer.new()
	canvas_layer.name = "UI"
	add_child(canvas_layer)

	debug_spawner = DebugSpawnerScene.instantiate()
	canvas_layer.add_child(debug_spawner)

func _connect_signals() -> void:
	debug_spawner.start_match_requested.connect(_on_start_match)
	debug_spawner.pause_requested.connect(_on_pause_requested)
	debug_spawner.step_requested.connect(_on_step_requested)
	debug_spawner.reset_requested.connect(_on_reset_requested)
	debug_spawner.time_scale_changed.connect(_on_time_scale_changed)

func _on_start_match(config: Dictionary) -> void:
	_clear_balls()

	rng.randomize()

	var mode: MatchSystem.MatchMode
	match config.mode:
		0:
			mode = MatchSystem.MatchMode.DUEL
		1:
			mode = MatchSystem.MatchMode.FFA
		2:
			mode = MatchSystem.MatchMode.TEAM_FIGHT
		_:
			mode = MatchSystem.MatchMode.FFA

	# Setup arena type
	var arena_type: Arena.ArenaType = Arena.ArenaType.COMPLEX
	if config.has("arena_type"):
		match config.arena_type:
			0:
				arena_type = Arena.ArenaType.SIMPLE
			1:
				arena_type = Arena.ArenaType.COMPLEX
			2:
				arena_type = Arena.ArenaType.HAZARDS
			3:
				arena_type = Arena.ArenaType.OPEN
	arena.setup_arena(arena_type)

	var selected_balls: Array = config.selected_balls
	var weapon_defs: Dictionary = config.weapon_definitions
	var ball_count: int = selected_balls.size()

	if selected_balls.is_empty():
		debug_spawner.update_status("No balls selected!")
		return

	var spawn_positions: Array[Vector2] = arena.get_spawn_positions(ball_count, rng)

	for i in range(ball_count):
		var ball_def: BallDefinition = selected_balls[i]
		var weapon_def: WeaponDefinition = weapon_defs.get(ball_def.weapon_id)

		var team: int = -1
		if mode == MatchSystem.MatchMode.TEAM_FIGHT:
			team = i % 2
		elif mode == MatchSystem.MatchMode.DUEL:
			team = i

		var ball: Ball = _spawn_ball(ball_def, weapon_def, spawn_positions[i], team, rng.randi())
		spawned_balls.append(ball)

	simulation.match_system.start_match(mode)
	_update_status()

func _spawn_ball(
	ball_def: BallDefinition,
	weapon_def: WeaponDefinition,
	pos: Vector2,
	team: int,
	ai_seed: int
) -> Ball:
	var ball: Ball = BallScene.instantiate()
	ball.position = pos
	ball_container.add_child(ball)

	ball.initialize(
		ball_def,
		simulation.combat_system,
		simulation.status_system,
		weapon_def,
		team,
		ai_seed
	)

	return ball

func _clear_balls() -> void:
	for ball in spawned_balls:
		if is_instance_valid(ball):
			ball.queue_free()
	spawned_balls.clear()
	simulation.reset()

func _on_pause_requested() -> void:
	simulation.toggle_pause()
	debug_spawner.set_paused(simulation.paused)

func _on_step_requested() -> void:
	simulation.step()
	debug_spawner.set_paused(true)

func _on_reset_requested() -> void:
	_clear_balls()
	debug_spawner.update_status("Ready")

func _on_time_scale_changed(scale: float) -> void:
	simulation.set_time_scale(scale)

func _on_match_ended(winner: Variant) -> void:
	var status_text: String
	if winner == null:
		status_text = "Match ended: Draw!"
	elif winner is Node2D:
		var info: Dictionary = winner.get_display_info()
		status_text = "Winner: %s!" % info.name
	elif winner is int:
		status_text = "Team %d wins!" % (winner + 1)
	else:
		status_text = "Match ended!"

	debug_spawner.update_status(status_text)
	debug_spawner.show_end_game_stats(spawned_balls, winner)

func _on_ball_eliminated(ball: Node2D) -> void:
	_update_status()

func _update_status() -> void:
	var alive: int = simulation.match_system.get_alive_count()
	var mode_name: String = simulation.match_system.get_mode_name()
	debug_spawner.update_status("%s - %d alive" % [mode_name, alive])

func _process(_delta: float) -> void:
	debug_spawner.update_ball_readout(spawned_balls)
