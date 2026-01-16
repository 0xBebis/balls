class_name DebugSpawner
extends Control

## Enhanced debug UI with presets, arena types, and ball previews.

signal start_match_requested(config: Dictionary)
signal pause_requested
signal step_requested
signal reset_requested
signal time_scale_changed(scale: float)

# Panel dimensions
const PANEL_X: float = 935.0
const PANEL_Y: float = 10.0
const PANEL_WIDTH: float = 335.0
const PANEL_HEIGHT: float = 700.0

# UI References - Setup Phase
var setup_panel: PanelContainer
var mode_selector: OptionButton
var arena_selector: OptionButton
var preset_buttons: Array[Button] = []
var ball_count_spin: SpinBox
var ball_selectors: Array[OptionButton] = []
var ball_selector_container: VBoxContainer
var start_button: Button

# UI References - Match Phase
var match_panel: PanelContainer
var pause_button: Button
var step_button: Button
var reset_button: Button
var time_scale_button: Button
var status_label: Label
var ball_readout: VBoxContainer

# UI References - Stats Phase
var stats_panel: PanelContainer
var stats_container: VBoxContainer
var new_match_button: Button

var ball_definitions: Array[BallDefinition] = []
var weapon_definitions: Dictionary = {}
var current_time_scale_index: int = 1
const TIME_SCALES: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0]

enum UIPhase { SETUP, MATCH, STATS }
var current_phase: UIPhase = UIPhase.SETUP

# Presets
const PRESETS: Dictionary = {
	"balanced": {"mode": 1, "arena": 1, "balls": ["sword", "dagger", "spear", "bow"]},
	"chaos": {"mode": 1, "arena": 2, "balls": ["random", "random", "random", "random", "random", "random"]},
	"duel": {"mode": 0, "arena": 0, "balls": ["sword", "dagger"]},
	"team": {"mode": 2, "arena": 1, "balls": ["sword", "bow", "spear", "scythe"]}
}

func _ready() -> void:
	position = Vector2(PANEL_X, PANEL_Y)
	size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)

	_load_definitions()
	_build_ui()
	_show_phase(UIPhase.SETUP)

func _load_definitions() -> void:
	var ball_dir: DirAccess = DirAccess.open("res://content/balls")
	if ball_dir:
		ball_dir.list_dir_begin()
		var file_name: String = ball_dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var def: BallDefinition = load("res://content/balls/" + file_name) as BallDefinition
				if def:
					ball_definitions.append(def)
			file_name = ball_dir.get_next()

	# Sort by name for consistent ordering
	ball_definitions.sort_custom(func(a: BallDefinition, b: BallDefinition) -> bool:
		return a.display_name < b.display_name
	)

	var weapon_dir: DirAccess = DirAccess.open("res://content/weapons")
	if weapon_dir:
		weapon_dir.list_dir_begin()
		var file_name: String = weapon_dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var def: WeaponDefinition = load("res://content/weapons/" + file_name) as WeaponDefinition
				if def:
					weapon_definitions[def.id] = def
			file_name = weapon_dir.get_next()

func _build_ui() -> void:
	_build_setup_panel()
	_build_match_panel()
	_build_stats_panel()

func _create_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	return panel

func _build_setup_panel() -> void:
	setup_panel = _create_panel()

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	setup_panel.add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	# Title
	var title: Label = Label.new()
	title.text = "MATCH SETUP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	# Quick Presets
	var preset_label: Label = Label.new()
	preset_label.text = "Quick Start:"
	preset_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(preset_label)

	var preset_grid: GridContainer = GridContainer.new()
	preset_grid.columns = 2
	vbox.add_child(preset_grid)

	for preset_name in ["balanced", "chaos", "duel", "team"]:
		var btn: Button = Button.new()
		btn.text = preset_name.capitalize()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_preset_pressed.bind(preset_name))
		preset_grid.add_child(btn)
		preset_buttons.append(btn)

	vbox.add_child(HSeparator.new())

	# Mode selector
	var mode_hbox: HBoxContainer = HBoxContainer.new()
	vbox.add_child(mode_hbox)
	var mode_label: Label = Label.new()
	mode_label.text = "Mode:"
	mode_label.custom_minimum_size.x = 60
	mode_hbox.add_child(mode_label)
	mode_selector = OptionButton.new()
	mode_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_selector.add_item("Duel (1v1)", 0)
	mode_selector.add_item("Free For All", 1)
	mode_selector.add_item("Team Battle", 2)
	mode_selector.select(1)
	mode_selector.item_selected.connect(_on_mode_changed)
	mode_hbox.add_child(mode_selector)

	# Arena selector
	var arena_hbox: HBoxContainer = HBoxContainer.new()
	vbox.add_child(arena_hbox)
	var arena_label: Label = Label.new()
	arena_label.text = "Arena:"
	arena_label.custom_minimum_size.x = 60
	arena_hbox.add_child(arena_label)
	arena_selector = OptionButton.new()
	arena_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena_selector.add_item("Simple", 0)
	arena_selector.add_item("Complex", 1)
	arena_selector.add_item("Hazards", 2)
	arena_selector.add_item("Open", 3)
	arena_selector.select(1)
	arena_hbox.add_child(arena_selector)

	# Ball count
	var count_hbox: HBoxContainer = HBoxContainer.new()
	vbox.add_child(count_hbox)
	var count_label: Label = Label.new()
	count_label.text = "Fighters:"
	count_label.custom_minimum_size.x = 60
	count_hbox.add_child(count_label)
	ball_count_spin = SpinBox.new()
	ball_count_spin.min_value = 2
	ball_count_spin.max_value = 8
	ball_count_spin.value = 4
	ball_count_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ball_count_spin.value_changed.connect(_on_ball_count_changed)
	count_hbox.add_child(ball_count_spin)

	vbox.add_child(HSeparator.new())

	# Ball selection
	var select_label: Label = Label.new()
	select_label.text = "Select Fighters:"
	select_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(select_label)

	ball_selector_container = VBoxContainer.new()
	ball_selector_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ball_selector_container.add_theme_constant_override("separation", 3)
	vbox.add_child(ball_selector_container)

	_rebuild_ball_selectors()

	vbox.add_child(HSeparator.new())

	# Start button
	start_button = Button.new()
	start_button.text = "START MATCH"
	start_button.custom_minimum_size.y = 45
	start_button.add_theme_font_size_override("font_size", 15)
	start_button.pressed.connect(_on_start_pressed)
	vbox.add_child(start_button)

func _build_match_panel() -> void:
	match_panel = _create_panel()
	match_panel.visible = false

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 5)
	match_panel.add_child(vbox)

	# Title
	var title: Label = Label.new()
	title.text = "MATCH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	# Status
	status_label = Label.new()
	status_label.text = "Ready"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	vbox.add_child(status_label)

	vbox.add_child(HSeparator.new())

	# Controls row 1
	var controls1: HBoxContainer = HBoxContainer.new()
	vbox.add_child(controls1)

	pause_button = Button.new()
	pause_button.text = "Pause"
	pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_button.pressed.connect(_on_pause_pressed)
	controls1.add_child(pause_button)

	step_button = Button.new()
	step_button.text = "Step"
	step_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step_button.pressed.connect(_on_step_pressed)
	controls1.add_child(step_button)

	# Controls row 2
	var controls2: HBoxContainer = HBoxContainer.new()
	vbox.add_child(controls2)

	reset_button = Button.new()
	reset_button.text = "Stop"
	reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_button.pressed.connect(_on_reset_pressed)
	controls2.add_child(reset_button)

	time_scale_button = Button.new()
	time_scale_button.text = "1.0x"
	time_scale_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_scale_button.pressed.connect(_on_time_scale_pressed)
	controls2.add_child(time_scale_button)

	vbox.add_child(HSeparator.new())

	# Ball readout
	var readout_label: Label = Label.new()
	readout_label.text = "FIGHTERS:"
	readout_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(readout_label)

	var readout_scroll: ScrollContainer = ScrollContainer.new()
	readout_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	readout_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(readout_scroll)

	ball_readout = VBoxContainer.new()
	ball_readout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ball_readout.add_theme_constant_override("separation", 4)
	readout_scroll.add_child(ball_readout)

func _build_stats_panel() -> void:
	stats_panel = _create_panel()
	stats_panel.visible = false

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 5)
	stats_panel.add_child(vbox)

	# Title
	var title: Label = Label.new()
	title.text = "RESULTS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Stats scroll
	var stats_scroll: ScrollContainer = ScrollContainer.new()
	stats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(stats_scroll)

	stats_container = VBoxContainer.new()
	stats_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_container.add_theme_constant_override("separation", 6)
	stats_scroll.add_child(stats_container)

	vbox.add_child(HSeparator.new())

	# New match button
	new_match_button = Button.new()
	new_match_button.text = "NEW MATCH"
	new_match_button.custom_minimum_size.y = 40
	new_match_button.add_theme_font_size_override("font_size", 14)
	new_match_button.pressed.connect(_on_new_match_pressed)
	vbox.add_child(new_match_button)

func _rebuild_ball_selectors() -> void:
	for child in ball_selector_container.get_children():
		child.queue_free()
	ball_selectors.clear()

	var count: int = int(ball_count_spin.value)
	var mode: int = mode_selector.get_selected_id()

	for i in range(count):
		var panel: PanelContainer = PanelContainer.new()
		ball_selector_container.add_child(panel)

		var hbox: HBoxContainer = HBoxContainer.new()
		panel.add_child(hbox)

		# Team/Fighter label
		var label: Label = Label.new()
		if mode == 2:  # Team Battle
			var team_name: String = "RED" if i % 2 == 0 else "BLU"
			label.text = "%s:" % team_name
			label.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if i % 2 == 0 else Color(0.4, 0.6, 1))
		else:
			label.text = "#%d:" % (i + 1)
		label.custom_minimum_size.x = 35
		label.add_theme_font_size_override("font_size", 11)
		hbox.add_child(label)

		# Ball selector
		var selector: OptionButton = OptionButton.new()
		selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		selector.add_item("Random", 9999)  # Use high ID to avoid conflicts
		for j in range(ball_definitions.size()):
			var def: BallDefinition = ball_definitions[j]
			var weapon_info: String = def.weapon_id.capitalize()
			selector.add_item("%s (%s)" % [def.display_name, weapon_info], j)
		selector.select(0)
		selector.item_selected.connect(_on_ball_selection_changed.bind(i))
		hbox.add_child(selector)

		ball_selectors.append(selector)

func _on_preset_pressed(preset_name: String) -> void:
	if not PRESETS.has(preset_name):
		return

	var preset: Dictionary = PRESETS[preset_name]

	# Set mode
	mode_selector.select(preset.mode)

	# Set arena
	arena_selector.select(preset.arena)

	# Set ball count and selections
	var balls: Array = preset.balls
	ball_count_spin.value = balls.size()
	_rebuild_ball_selectors()

	# Need to wait a frame for selectors to be created
	await get_tree().process_frame

	for i in range(mini(balls.size(), ball_selectors.size())):
		var ball_id: String = balls[i]
		if ball_id == "random":
			ball_selectors[i].select(0)
		else:
			# Find matching ball definition
			for j in range(ball_definitions.size()):
				if ball_definitions[j].weapon_id == ball_id:
					ball_selectors[i].select(j + 1)  # +1 because Random is index 0
					break

func _on_ball_selection_changed(_idx: int, _ball_index: int) -> void:
	# Could add preview here in the future
	pass

func _show_phase(phase: UIPhase) -> void:
	current_phase = phase
	setup_panel.visible = (phase == UIPhase.SETUP)
	match_panel.visible = (phase == UIPhase.MATCH)
	stats_panel.visible = (phase == UIPhase.STATS)

func _on_mode_changed(_index: int) -> void:
	# Adjust ball count for duel
	if mode_selector.get_selected_id() == 0:  # Duel
		ball_count_spin.value = 2
	_rebuild_ball_selectors()

func _on_ball_count_changed(_value: float) -> void:
	_rebuild_ball_selectors()

func _on_start_pressed() -> void:
	var selected_balls: Array[BallDefinition] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	for selector in ball_selectors:
		var idx: int = selector.get_selected_id()
		if idx == 9999:  # Random
			var random_def: BallDefinition = ball_definitions[rng.randi_range(0, ball_definitions.size() - 1)]
			selected_balls.append(random_def)
		else:
			selected_balls.append(ball_definitions[idx])

	var config: Dictionary = {
		"mode": mode_selector.get_selected_id(),
		"arena_type": arena_selector.get_selected_id(),
		"selected_balls": selected_balls,
		"weapon_definitions": weapon_definitions
	}
	start_match_requested.emit(config)
	_show_phase(UIPhase.MATCH)

func _on_pause_pressed() -> void:
	pause_requested.emit()

func _on_step_pressed() -> void:
	step_requested.emit()

func _on_reset_pressed() -> void:
	reset_requested.emit()
	_show_phase(UIPhase.SETUP)

func _on_time_scale_pressed() -> void:
	current_time_scale_index = (current_time_scale_index + 1) % TIME_SCALES.size()
	time_scale_button.text = "%.2fx" % TIME_SCALES[current_time_scale_index]
	time_scale_changed.emit(TIME_SCALES[current_time_scale_index])

func _on_new_match_pressed() -> void:
	reset_requested.emit()
	_show_phase(UIPhase.SETUP)

func update_status(text: String) -> void:
	status_label.text = text

func update_ball_readout(balls: Array) -> void:
	if current_phase != UIPhase.MATCH:
		return

	for child in ball_readout.get_children():
		child.queue_free()

	for ball in balls:
		if not is_instance_valid(ball):
			continue

		var info: Dictionary = ball.get_display_info()
		var panel: PanelContainer = PanelContainer.new()
		if not info.alive:
			panel.modulate.a = 0.5
		ball_readout.add_child(panel)

		var hbox: HBoxContainer = HBoxContainer.new()
		panel.add_child(hbox)

		# Color indicator
		var color_rect: ColorRect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(8, 0)
		color_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		color_rect.color = ball.ball_color if ball.has_method("is_alive") else Color.GRAY
		hbox.add_child(color_rect)

		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 1)
		hbox.add_child(vbox)

		# Name row
		var name_label: Label = Label.new()
		var status_str: String = "" if info.alive else " [X]"
		name_label.text = "%s%s" % [info.name, status_str]
		name_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(name_label)

		# HP bar
		var hp_bar: ProgressBar = ProgressBar.new()
		hp_bar.custom_minimum_size.y = 12
		hp_bar.max_value = info.max_hp
		hp_bar.value = info.hp
		hp_bar.show_percentage = false
		vbox.add_child(hp_bar)

		# HP text
		var hp_label: Label = Label.new()
		hp_label.text = "%.0f / %.0f" % [info.hp, info.max_hp]
		hp_label.add_theme_font_size_override("font_size", 10)
		hp_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		vbox.add_child(hp_label)

func set_paused(is_paused: bool) -> void:
	pause_button.text = "Resume" if is_paused else "Pause"

func show_end_game_stats(balls: Array, winner: Variant) -> void:
	_show_phase(UIPhase.STATS)

	for child in stats_container.get_children():
		child.queue_free()

	# Winner announcement
	var winner_panel: PanelContainer = PanelContainer.new()
	stats_container.add_child(winner_panel)

	var winner_label: Label = Label.new()
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.add_theme_font_size_override("font_size", 14)
	if winner == null:
		winner_label.text = "DRAW!"
		winner_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
	elif winner is Node2D and winner.has_method("get_combat_stats"):
		var stats: Dictionary = winner.get_combat_stats()
		winner_label.text = "WINNER: %s" % stats.name
		winner_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	elif winner is int:
		var team_name: String = "RED TEAM" if winner == 0 else "BLUE TEAM"
		winner_label.text = "%s WINS!" % team_name
		winner_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5) if winner == 0 else Color(0.5, 0.7, 1))
	winner_panel.add_child(winner_label)

	stats_container.add_child(HSeparator.new())

	# Sort balls by damage dealt
	var sorted_balls: Array = balls.duplicate()
	sorted_balls.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		if not is_instance_valid(a) or not a.has_method("get_combat_stats"):
			return false
		if not is_instance_valid(b) or not b.has_method("get_combat_stats"):
			return true
		return a.get_combat_stats().damage_dealt > b.get_combat_stats().damage_dealt
	)

	# Stats for each ball
	for ball in sorted_balls:
		if not is_instance_valid(ball) or not ball.has_method("get_combat_stats"):
			continue

		var stats: Dictionary = ball.get_combat_stats()
		var panel: PanelContainer = PanelContainer.new()
		if not stats.alive:
			panel.modulate.a = 0.7
		stats_container.add_child(panel)

		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		panel.add_child(vbox)

		# Name with weapon
		var name_label: Label = Label.new()
		var alive_str: String = "" if stats.alive else " [DEAD]"
		name_label.text = "%s (%s)%s" % [stats.name, stats.weapon, alive_str]
		name_label.add_theme_font_size_override("font_size", 12)
		if stats.alive:
			name_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
		vbox.add_child(name_label)

		# Stats grid
		var grid: GridContainer = GridContainer.new()
		grid.columns = 2
		vbox.add_child(grid)

		_add_stat_row(grid, "Damage", "%.0f / %.0f" % [stats.damage_dealt, stats.damage_taken])
		_add_stat_row(grid, "DPS", "%.1f" % stats.dps)
		_add_stat_row(grid, "Kills", "%d" % stats.kills)

		# Efficiency with color coding
		var efficiency: float = stats.damage_dealt / stats.damage_taken if stats.damage_taken > 0 else stats.damage_dealt
		var eff_color: Color = Color(0.5, 1, 0.5) if efficiency >= 1.5 else (Color(1, 0.5, 0.5) if efficiency < 0.8 else Color(0.8, 0.8, 0.8))
		_add_stat_row(grid, "Efficiency", "%.2f" % efficiency, eff_color)

func _add_stat_row(grid: GridContainer, label_text: String, value_text: String, color: Color = Color(0.8, 0.8, 0.8)) -> void:
	var label: Label = Label.new()
	label.text = label_text + ":"
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	grid.add_child(label)

	var value: Label = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 10)
	value.add_theme_color_override("font_color", color)
	grid.add_child(value)
