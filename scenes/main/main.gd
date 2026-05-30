extends Node2D

@onready var map = $MapPivot
@onready var director_ai: Node = $DirectorAI
@onready var player: Node2D = $MapPivot/SubViewportContainer/SubViewport/Player
@onready var enemy: Node2D = $MapPivot/SubViewportContainer/SubViewport/Enemy

signal timer_updated(time_left: float, time_elapsed: float)

@export var game_duration: float = 180.0
@export var director_check_interval: float = 1.0

var time_elapsed: float = 0.0
var time_left: float = 180.0
var director_timer: float = 0.0

func _ready() -> void:
	print("map node: ", map)
	print("director ai node: ", director_ai)
	print("player node: ", player)
	print("enemy node: ", enemy)
	print("Timer started at: ", format_time(time_left))

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
	if director_ai == null or player == null or enemy == null:
		print("[Director AI] Missing node reference.")
		return  # ← return is INSIDE the if block
	var distance_to_dog := player.global_position.distance_to(enemy.global_position)
	var stamina_ratio := 1.0
	if player.has_method("get_stamina_ratio"):
		stamina_ratio = player.get_stamina_ratio()
	var decision: Dictionary = director_ai.evaluate(
		distance_to_dog,
		stamina_ratio,
		time_elapsed
	)
	print(
		"[Director AI] state=", decision["current_state"],
		" | rule=", decision["selected_rule"],
		" | effect=", decision["selected_effect"],
		" | distance=", str(round(distance_to_dog)),
		" | stamina=", str(round(stamina_ratio * 100.0)), "%",
		" | time=", str(round(time_elapsed)), "s"
	)
	if map == null:
		return
	match decision["selected_effect"]:
		"flip_90":
			map.trigger_flip(90.0)
		"flip_180":
			map.trigger_flip(180.0)
		"carousel":
			map.start_carousel()
		"jitter":
			map.trigger_jitter(0.5, 5.0)
		"none":
			pass

func format_time(seconds_left: float) -> String:
	var total_seconds := int(seconds_left)
	var minutes : int = total_seconds / 60
	var seconds : int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]
