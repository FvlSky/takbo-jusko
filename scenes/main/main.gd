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

# ── Spawn tuning ──────────────────────────────────────────────
## Dog must be at least this far from the player on spawn
const DOG_MIN_DISTANCE: float = 250.0
## Dog must be no further than this (keeps it threatening, not off-screen)
const DOG_MAX_DISTANCE: float = 600.0
## Dot-product threshold for "toward finish line" cone (0.0 = 90°, 1.0 = exact)
const DOG_INTERCEPT_DOT: float = 0.25
## Fraction of the map (from lower-right) that is off-limits for the player spawn
const FINISH_LINE_EXCLUSION_FACTOR: float = 0.55
# ─────────────────────────────────────────────────────────────

var time_elapsed: float = 0.0
var time_left: float = 90.0
var director_timer: float = 0.0
var game_over: bool = false
var game_started: bool = false
var tilemap: TileMapLayer = null


func _ready() -> void:
	add_to_group("game_manager")

	time_left = game_duration
	time_elapsed = 0.0
	timer_updated.emit(time_left, time_elapsed)

	tilemap = get_tree().get_first_node_in_group("ground_layer")

	print("map node: ", map)
	print("director ai node: ", director_ai)
	print("player node: ", player)
	print("enemy node: ", enemy)
	print("tilemap node: ", tilemap)
	print("Timer started at: ", format_time(time_left))
	print("chaos engine node: ", chaos_engine)
	print("chaos engine script: ", chaos_engine.get_script())

	# Freeze player until game starts
	player.set_physics_process(false)

	# Connect lose screen buttons
	var lose_restart = $CanvasLayer/LoseScreen/RestartButton
	var lose_quit = $CanvasLayer/LoseScreen/QuitButton
	if not lose_restart.pressed.is_connected(_on_restart_button_pressed):
		lose_restart.pressed.connect(_on_restart_button_pressed)
	if not lose_quit.pressed.is_connected(_on_quit_button_pressed):
		lose_quit.pressed.connect(_on_quit_button_pressed)

	# Connect win screen buttons
	var win_restart = $CanvasLayer/WinScreen/RestartButton
	var win_quit = $CanvasLayer/WinScreen/QuitButton
	if not win_restart.pressed.is_connected(_on_restart_button_pressed):
		win_restart.pressed.connect(_on_restart_button_pressed)
	if not win_quit.pressed.is_connected(_on_quit_button_pressed):
		win_quit.pressed.connect(_on_quit_button_pressed)

	# Skip start screen if restarting
	if Global.skip_start_screen:
		start_screen.visible = false
		Global.skip_start_screen = false
		start_game()  # start immediately on restart

	# Randomize spawns from walkable tiles
	var spawns := _get_random_spawns()
	player.reset_player_state(spawns[0])
	enemy.global_position = spawns[1]


func start_game() -> void:
	game_started = true
	time_elapsed = 0.0
	time_left = game_duration
	timer_updated.emit(time_left, time_elapsed)

	player.set_physics_process(true)

	# CanvasLayer no longer owns the timer.
	# This call is kept so existing UI/start flow still works.
	$CanvasLayer.start_game()


func _on_play_button_pressed() -> void:
	start_screen.visible = false
	start_game()


func _process(delta: float) -> void:
	if get_tree().paused:
		return

	if game_over or not game_started:
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

	# Pre-compute world positions for every walkable tile (avoids repeated conversion)
	var world_positions: Array = []
	for tile in walkable:
		world_positions.append(_tile_to_world(tile))

	# ── Compute map bounds ────────────────────────────────────
	var min_x: float = world_positions[0].x
	var max_x: float = world_positions[0].x
	var min_y: float = world_positions[0].y
	var max_y: float = world_positions[0].y
	for pos in world_positions:
		if pos.x < min_x: min_x = pos.x
		if pos.x > max_x: max_x = pos.x
		if pos.y < min_y: min_y = pos.y
		if pos.y > max_y: max_y = pos.y

	# ── Finish-line exclusion zone (lower-right corner) ───────
	# Any tile inside BOTH thresholds is considered too close to the finish line.
	var excl_x: float = lerpf(min_x, max_x, 1.0 - FINISH_LINE_EXCLUSION_FACTOR)
	var excl_y: float = lerpf(min_y, max_y, 1.0 - FINISH_LINE_EXCLUSION_FACTOR)

	# ── Pick player spawn ─────────────────────────────────────
	var player_indices: Array = []
	for i in world_positions.size():
		var pos: Vector2 = world_positions[i]
		if not (pos.x >= excl_x and pos.y >= excl_y):
			player_indices.append(i)

	if player_indices.is_empty():
		# Edge case: the entire map is near the finish line — use everything
		print("WARN: All tiles are in finish-line zone — relaxing player spawn constraint")
		for i in world_positions.size():
			player_indices.append(i)

	player_indices.shuffle()
	var player_spawn: Vector2 = world_positions[player_indices[0]]

	print("[Spawn] Player -> ", player_spawn, " (finish zone excluded below x=", excl_x, " y=", excl_y, ")")

	# ── Pick dog spawn (intercept position) ───────────────────
	# The finish line sits at the lower-right corner of the map.
	# We bias the dog toward tiles that lie between the player and that corner,
	# so it naturally cuts off the player's escape route.
	var finish_pos := Vector2(max_x, max_y)
	var to_finish := (finish_pos - player_spawn).normalized()

	var dog_indices: Array = []
	for i in world_positions.size():
		var pos: Vector2 = world_positions[i]
		var dist: float = pos.distance_to(player_spawn)

		# Must be within the intercept distance band
		if dist < DOG_MIN_DISTANCE or dist > DOG_MAX_DISTANCE:
			continue

		# Must be roughly in the direction of the finish line from the player
		var dir: Vector2 = (pos - player_spawn).normalized()
		if dir.dot(to_finish) >= DOG_INTERCEPT_DOT:
			dog_indices.append(i)

	# Fallback 1: relax the directional constraint, keep distance band
	if dog_indices.is_empty():
		print("WARN: No intercept tiles found — relaxing direction constraint")
		for i in world_positions.size():
			var dist: float = world_positions[i].distance_to(player_spawn)
			if dist >= DOG_MIN_DISTANCE and dist <= DOG_MAX_DISTANCE:
				dog_indices.append(i)

	# Fallback 2: relax distance cap too, just enforce minimum
	if dog_indices.is_empty():
		print("WARN: No tiles in distance band — using minimum distance only")
		for i in world_positions.size():
			if world_positions[i].distance_to(player_spawn) >= DOG_MIN_DISTANCE:
				dog_indices.append(i)

	# Last resort: nearest tile that isn't the player tile
	if dog_indices.is_empty():
		print("WARN: No valid dog spawn found — using last walkable tile")
		return [player_spawn, world_positions.back()]

	dog_indices.shuffle()
	var enemy_spawn: Vector2 = world_positions[dog_indices[0]]

	print("[Spawn] Dog   -> ", enemy_spawn, " (dist=", snapped(enemy_spawn.distance_to(player_spawn), 1.0), ")")

	return [player_spawn, enemy_spawn]
