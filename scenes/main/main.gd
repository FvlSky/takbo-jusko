extends Node2D

# existing map reference
@onready var map = $MapPivot

# timer
signal timer_updated(time_left: float, time_elapsed: float)

@export var game_duration: float = 180.0 # 3 minutes
var time_elapsed: float = 0.0
var time_left: float = 180.0

# director AI references
@onready var director_ai: Node = $DirectorAI
@onready var player: Node2D = $MapPivot/SubViewportContainer/SubViewport/Player
@onready var enemy: Node2D = $MapPivot/SubViewportContainer/SubViewport/Enemy

@export var director_check_interval: float = 1.0

var time_elapsed: float = 0.0
var director_timer: float = 0.0


func _ready() -> void:
	print("map node: ", map)
	print("director ai node: ", director_ai)
	print("player node: ", player)
	print("enemy node: ", enemy)


func _process(delta: float) -> void:
	time_elapsed += delta
	time_left = max(game_duration - time_elapsed, 0.0)

	timer_updated.emit(time_left, time_elapsed)

	if time_left <= 0.0:
		print("Time is up!")
		# Later: connect this to LoseScreen


func _input(event: InputEvent) -> void:
	if map == null:
		return

	# Manual test controls for map effects
	if event.is_action_pressed("ui_accept"):
		map.trigger_flip(90.0)

	if event.is_action_pressed("ui_cancel"):
		map.start_carousel()


func update_director_ai() -> void:
	if director_ai == null or player == null or enemy == null:
		print("[Director AI] Missing node reference.")
		return

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