extends Node2D

@onready var map = $MapPivot
@onready var director_ai: Node = $DirectorAI
@onready var chaos_engine: Node = $ChaosEngine
@onready var player: Node2D = $MapPivot/SubViewportContainer/SubViewport/Player
@onready var enemy: Node2D = $MapPivot/SubViewportContainer/SubViewport/Enemy
@onready var lose_screen: Control = $CanvasLayer/LoseScreen
@onready var win_screen: Control = $CanvasLayer/WinScreen
@onready var overlay: ColorRect = $CanvasLayer/LoseScreen/Overlay
@onready var start_screen = $CanvasLayer/StartScreen

signal timer_updated(time_left: float, time_elapsed: float)

@export var game_duration: float = 90.0
@export var director_check_interval: float = 0.8

const MIN_SPAWN_DISTANCE: float = 400.0

var time_elapsed: float = 0.0
var time_left: float = 90.0
var director_timer: float = 0.0
var game_over: bool = false
var tilemap: TileMapLayer = null


func _ready() -> void:
	add_to_group("game_manager")

	tilemap = get_tree().get_first_node_in_group("ground_layer")

	print("map node: ", map)
	print("director ai node: ", director_ai)
	print("player node: ", player)
	print("enemy node: ", enemy)
	print("tilemap node: ", tilemap)
	print("Timer started at: ", format_time(time_left))
	print("chaos engine node: ", chaos_engine)
	print("chaos engine script: ", chaos_engine.get_script())

	# Connect lose screen buttons
	$CanvasLayer/LoseScreen/RestartButton.pressed.connect(_on_restart_button_pressed)
	$CanvasLayer/LoseScreen/QuitButton.pressed.connect(_on_quit_button_pressed)

	# Connect win screen buttons
	$CanvasLayer/WinScreen/RestartButton.pressed.connect(_on_restart_button_pressed)
	$CanvasLayer/WinScreen/QuitButton.pressed.connect(_on_quit_button_pressed)

	# Skip start screen if restarting
	if Global.skip_start_screen:
		start_screen.visible = false
		Global.skip_start_screen = false

	# Randomize spawns from walkable tiles
	var spawns := _get_random_spawns()
	player.reset_player_state(spawns[0])
	enemy.global_position = spawns[1]


func _process(delta: float) -> void:
	if game_over:
		return

	time_elapsed += delta
	time_left = max(game_duration - time_elapsed, 0.0)
	timer_updated.emit(time_left, time_elapsed)

	director_timer += delta
	if director_timer >= director_check_interval:
		director_timer = 0.0
		update_director_ai()

	if time_left <= 0.0 and not game_over:
		trigger_lose()


func _input(event: InputEvent) -> void:
	if map == null:
		return
	if event.is_action_pressed("ui_accept"):
		map.trigger_flip(90.0)
	if event.is_action_pressed("ui_cancel"):
		map.start_carousel()


func update_director_ai() -> void:
	if director_ai == null or chaos_engine == null or player == null or enemy == null:
		print("[AI] Missing node reference.")
		return

	var distance_to_dog := player.global_position.distance_to(enemy.global_position)
	var stamina_ratio := 1.0
	if player.has_method("get_stamina_ratio"):
		stamina_ratio = player.get_stamina_ratio()

	var chaos_context: Dictionary = chaos_engine.update_context(
		distance_to_dog,
		stamina_ratio,
		time_elapsed
	)

	if director_ai.has_method("set_chaos_context"):
		director_ai.set_chaos_context(
			chaos_context["chaos_score"],
			chaos_context["temperature"]
		)

	var decision: Dictionary = director_ai.evaluate(
		distance_to_dog,
		stamina_ratio,
		time_elapsed
	)

	var chaos_result: Dictionary = chaos_engine.evaluate_effect(
		decision["selected_effect"]
	)

	print(
		"[Director AI] state=", decision["current_state"],
		" | rule=", decision["selected_rule"],
		" | proposed_effect=", decision["selected_effect"],
		" | distance=", str(round(distance_to_dog)),
		" | stamina=", str(round(stamina_ratio * 100.0)), "%",
		" | time=", str(round(time_elapsed)), "s"
	)

	print(
		"[Chaos Engine] proposed=", chaos_result["proposed_effect"],
		" | final=", chaos_result["final_effect"],
		" | accepted=", chaos_result["accepted"],
		" | chaos=", str(round(chaos_result["chaos_score"])),
		" | T=", str(snapped(chaos_result["temperature"], 0.01)),
		" | dE=", str(chaos_result["delta_e"]),
		" | P=", str(snapped(chaos_result["probability"], 0.01)),
		" | r=", str(snapped(chaos_result["random_value"], 0.01))
	)

	apply_chaos_effect(chaos_result["final_effect"])


func apply_chaos_effect(final_effect: String) -> void:
	if map == null:
		return
	match final_effect:
		"jitter":
			if map.has_method("trigger_jitter"):
				map.trigger_jitter(0.5, 5.0)
		"flip_90":
			if map.has_method("trigger_flip"):
				map.trigger_flip(90.0)
		"flip_180":
			if map.has_method("trigger_flip"):
				map.trigger_flip(180.0)
		"carousel":
			if map.has_method("start_carousel"):
				map.start_carousel()
		"none":
			pass


func trigger_lose() -> void:
	if game_over:
		return
	game_over = true
	overlay.visible = true
	lose_screen.visible = true
	get_tree().paused = true


func trigger_win() -> void:
	if game_over:
		return
	game_over = true
	overlay.visible = true
	win_screen.visible = true
	get_tree().paused = true


func _on_restart_button_pressed() -> void:
	Global.skip_start_screen = true
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit_button_pressed() -> void:
	Global.skip_start_screen = false
	get_tree().quit()


func format_time(seconds_left: float) -> String:
	var total_seconds := int(seconds_left)
	var minutes := int(total_seconds / 60.0)
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


# ──────────────────────────────────────────────────────────────
#  SPAWN SYSTEM
# ──────────────────────────────────────────────────────────────

func _get_walkable_tiles() -> Array:
	if tilemap == null:
		print("ERROR: tilemap not found in group 'ground_layer'")
		return []
	var walkable := []
	for cell in tilemap.get_used_cells():
		var tile_data = tilemap.get_cell_tile_data(cell)
		if tile_data and tile_data.get_custom_data("walkable"):
			walkable.append(cell)
	return walkable


func _tile_to_world(tile: Vector2i) -> Vector2:
	return tilemap.to_global(tilemap.map_to_local(tile))


func _get_random_spawns() -> Array:
	var walkable := _get_walkable_tiles()
	if walkable.is_empty():
		print("ERROR: No walkable tiles found — using fallback spawns")
		return [Vector2(200, 200), Vector2(1000, 1000)]

	walkable.shuffle()

	var player_spawn := Vector2.ZERO
	var enemy_spawn  := Vector2.ZERO

	# Pick player spawn first
	for tile in walkable:
		player_spawn = _tile_to_world(tile)
		break

	# Pick enemy spawn far enough from player
	for tile in walkable:
		var candidate := _tile_to_world(tile)
		if candidate.distance_to(player_spawn) >= MIN_SPAWN_DISTANCE:
			enemy_spawn = candidate
			break

	# Fallback if no valid enemy spawn was found
	if enemy_spawn == Vector2.ZERO:
		print("WARN: No enemy spawn found at MIN_SPAWN_DISTANCE — using last walkable tile")
		enemy_spawn = _tile_to_world(walkable.back())

	return [player_spawn, enemy_spawn]
