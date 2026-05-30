extends Node

# =================================================
# Game Loop — connects Player, Dog, and Director AI
# =================================================

@export var player_node: CharacterBody2D
@export var dog_node: CharacterBody2D
@export var director_ai_node: Node

@export var director_check_interval: float = 1.0

var time_elapsed: float = 0.0
var director_check_timer: float = 0.0


func _ready() -> void:
	# Fallback references if not assigned in Inspector.
	if player_node == null:
		player_node = get_tree().get_first_node_in_group("player") as CharacterBody2D

	if dog_node == null:
		dog_node = get_tree().get_first_node_in_group("dog") as CharacterBody2D

	if director_ai_node == null:
		director_ai_node = get_node_or_null("../DirectorAI")

	print("--- GAME LOOP DEBUG ---")
	print("Player found: ", player_node)
	print("Dog found: ", dog_node)
	print("Director AI found: ", director_ai_node)
	print("-----------------------")


func _process(delta: float) -> void:
	time_elapsed += delta
	director_check_timer += delta

	if director_check_timer >= director_check_interval:
		director_check_timer = 0.0
		update_director_ai()


func update_director_ai() -> void:
	if player_node == null or dog_node == null or director_ai_node == null:
		return

	var distance_to_dog := player_node.global_position.distance_to(dog_node.global_position)

	var stamina_ratio := 1.0
	if player_node.has_method("get_stamina_ratio"):
		stamina_ratio = player_node.get_stamina_ratio()

	var decision: Dictionary = director_ai_node.evaluate(
		distance_to_dog,
		stamina_ratio,
		time_elapsed
	)

	print(
		"[Director AI] ",
		"state=", decision["current_state"],
		" | rule=", decision["selected_rule"],
		" | effect=", decision["selected_effect"],
		" | distance=", str(round(distance_to_dog)),
		" | stamina=", str(round(stamina_ratio * 100.0)),
		"% | time=", str(round(time_elapsed)),
		"s"
	)


func get_time_elapsed() -> float:
	return time_elapsed
