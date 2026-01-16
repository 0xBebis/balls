class_name MatchSystem
extends Node

## Manages match state, win conditions, and game modes.

signal match_started(mode: MatchMode)
signal match_ended(winner: Variant)
signal ball_eliminated(ball: Node2D)

enum MatchMode { DUEL, FFA, TEAM_FIGHT }

var current_mode: MatchMode = MatchMode.FFA
var match_active: bool = false
var winner: Variant = null

var combat_system: CombatSystem

func _ready() -> void:
	if combat_system:
		combat_system.ball_died.connect(_on_ball_died)

func set_combat_system(cs: CombatSystem) -> void:
	combat_system = cs
	combat_system.ball_died.connect(_on_ball_died)

func start_match(mode: MatchMode) -> void:
	current_mode = mode
	match_active = true
	winner = null
	match_started.emit(mode)

func _on_ball_died(ball: Node2D) -> void:
	if not match_active:
		return

	ball_eliminated.emit(ball)
	_check_win_condition()

func _check_win_condition() -> void:
	if not match_active:
		return

	var alive: Array[Node2D] = combat_system.get_alive_balls()

	match current_mode:
		MatchMode.DUEL, MatchMode.FFA:
			if alive.size() <= 1:
				if alive.size() == 1:
					winner = alive[0]
				else:
					winner = null
				_end_match()

		MatchMode.TEAM_FIGHT:
			var teams_alive: Dictionary = {}
			for ball in alive:
				if ball.team >= 0:
					teams_alive[ball.team] = true

			if teams_alive.size() <= 1:
				if teams_alive.size() == 1:
					winner = teams_alive.keys()[0]
				else:
					winner = null
				_end_match()

func _end_match() -> void:
	match_active = false
	match_ended.emit(winner)

func get_alive_count() -> int:
	return combat_system.get_alive_balls().size()

func get_team_alive_count(team: int) -> int:
	return combat_system.get_alive_balls_on_team(team).size()

func get_mode_name() -> String:
	match current_mode:
		MatchMode.DUEL:
			return "Duel"
		MatchMode.FFA:
			return "Free For All"
		MatchMode.TEAM_FIGHT:
			return "Team Fight"
	return "Unknown"

func reset() -> void:
	match_active = false
	winner = null
