extends Node2D

@onready var map = $MapPivot
@onready var director_ai: Node = $DirectorAI
@onready var chaos_engine: Node = $ChaosEngine
@onready var player: Node2D = $MapPivot/SubViewportContainer/SubViewport/Player
@onready var enemy: Node2D = $MapPivot/SubViewportContainer/SubViewport/Enemy

signal timer_updated(time_left: float, time_elapsed: float)

@export var game_duration: float = 90.0
@export var director_check_interval: float = 1.5

var time_elapsed: float = 0.0
var time_left: float = 90.0
var director_timer: float = 0.0

func _ready() -> void:
	print("map node: ", map)
	print("director ai node: ", director_ai)
	print("player node: ", player)
	print("enemy node: ", enemy)
	print("Timer started at: ", format_time(time_left))
	print("chaos engine node: ", chaos_engine)
	print("chaos engine script: ", chaos_engine.get_script())

func _process(delta: float) -> void:
	time_elapsed += delta
	time_left = max(game_duration - time_elapsed, 0.0)
	timer_updated.emit(time_left, time_elapsed)
	director_timer += delta
	if director_timer >= director_check_interval:
		director_timer = 0.0
		update_director_ai()
	if time_left <= 0.0:
		print("Time is up!")

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

	# 1. Chaos Engine computes Chaos Score and Temperature
	var chaos_context: Dictionary = chaos_engine.update_context(
		distance_to_dog,
		stamina_ratio,
		time_elapsed
	)

	# 2. Director AI reads the latest Chaos Score and Temperature
	if director_ai.has_method("set_chaos_context"):
		director_ai.set_chaos_context(
			chaos_context["chaos_score"],
			chaos_context["temperature"]
		)

	# 3. Director AI proposes an environmental effect
	var decision: Dictionary = director_ai.evaluate(
		distance_to_dog,
		stamina_ratio,
		time_elapsed
	)

	# 4. Chaos Engine decides if the proposed effect is accepted or rejected
	var chaos_result: Dictionary = chaos_engine.evaluate_effect(
		decision["selected_effect"]
	)

	# 5. Print Director AI output
	print(
		"[Director AI] state=", decision["current_state"],
		" | rule=", decision["selected_rule"],
		" | proposed_effect=", decision["selected_effect"],
		" | distance=", str(round(distance_to_dog)),
		" | stamina=", str(round(stamina_ratio * 100.0)), "%",
		" | time=", str(round(time_elapsed)), "s"
	)

	# 6. Print Chaos Engine output
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

	# 7. Apply only the final accepted effect
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

func format_time(seconds_left: float) -> String:
	var total_seconds := int(seconds_left)
	var minutes := int(total_seconds / 60.0)
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]
