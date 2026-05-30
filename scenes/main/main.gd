extends Node2D

# Existing map reference
@onready var map = $MapPivot

# Director AI references
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
	director_timer += delta

	if director_timer >= director_check_interval:
		director_timer = 0.0
		update_director_ai()


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