extends Node

signal chaos_context_updated(
	chaos_score: float,
	temperature: float
)

signal chaos_decision_made(
	proposed_effect: String,
	final_effect: String,
	accepted: bool,
	chaos_score: float,
	temperature: float,
	delta_e: float,
	probability: float,
	random_value: float
)

# =============
# Tuning Values
# =============

@export var t_min: float = 0.25
@export var t_max: float = 1.10
@export var initial_temperature: float = 0.55

# Temperature decay tied to player performance
# Lower performance = stronger cooling
# Higher performance = slower cooling
@export var low_performance_decay: float = 0.90
@export var high_performance_decay: float = 0.98

@export var delta_e_threshold: float = 0.75

@export var game_duration: float = 180.0 # 3 minutes
@export var safe_distance: float = 350.0

@export var time_weight: float = 0.50
@export var safety_weight: float = 0.30
@export var stamina_weight: float = 0.20

# ============
# State Values
# ============

var chaos_score: float = 0.0
var temperature: float = 0.55

var delta_e_values: Dictionary = {
	"none": 0.0,
	"jitter": 0.20,
	"flip_90": 0.45,
	"flip_180": 0.60,
	"carousel": 0.75
}


func _ready() -> void:
	temperature = initial_temperature


# ==================================================
# Chaos context
# Computes Chaos Score and maps it to temperature T
# ==================================================

func update_context(
	distance_to_dog: float,
	stamina_ratio: float,
	time_elapsed: float
) -> Dictionary:
	chaos_score = compute_chaos_score(
		distance_to_dog,
		stamina_ratio,
		time_elapsed
	)

	temperature = map_chaos_score_to_temperature(chaos_score)

	var context: Dictionary = {
		"chaos_score": chaos_score,
		"temperature": temperature
	}

	chaos_context_updated.emit(chaos_score, temperature)

	return context


func compute_chaos_score(
	distance_to_dog: float,
	stamina_ratio: float,
	time_elapsed: float
) -> float:
	var time_progress: float = clamp(
		time_elapsed / game_duration,
		0.0,
		1.0
	)

	var safety_score: float = clamp(
		distance_to_dog / safe_distance,
		0.0,
		1.0
	)

	var stamina_score: float = clamp(
		stamina_ratio,
		0.0,
		1.0
	)

	var score: float = 100.0 * (
		(time_weight * time_progress)
		+ (safety_weight * safety_score)
		+ (stamina_weight * stamina_score)
	)

	return score


func map_chaos_score_to_temperature(score: float) -> float:
	var mapped_temperature: float = t_min + ((t_max - t_min) * (score / 100.0))
	var clamped_temperature: float = clamp(mapped_temperature, t_min, t_max)

	return clamped_temperature


# =============================
# Simulated Annealing decision
# Applies P = e^(-ΔE / T)
# =============================

func evaluate_effect(proposed_effect: String) -> Dictionary:
	var delta_e: float = get_delta_e(proposed_effect)

	var probability: float = 0.0
	var random_value: float = randf()
	var accepted: bool = false
	var final_effect: String = "none"

	if proposed_effect == "none":
		probability = 0.0
		accepted = false
		final_effect = "none"

	elif delta_e > delta_e_threshold:
		probability = 0.0
		accepted = false
		final_effect = "none"

	elif proposed_effect == "jitter":
		# Jitter is treated as a warning cue, so it is always accepted.
		probability = 1.0
		accepted = true
		final_effect = proposed_effect

	else:
		# Manual Simulated Annealing formula:
		# P = e^(-ΔE / T)
		probability = exp(-delta_e / temperature)

		if random_value < probability:
			accepted = true
			final_effect = proposed_effect
		else:
			accepted = false
			final_effect = "none"

	if accepted:
		apply_temperature_decay()

	var result: Dictionary = {
		"proposed_effect": proposed_effect,
		"final_effect": final_effect,
		"accepted": accepted,
		"chaos_score": chaos_score,
		"temperature": temperature,
		"delta_e": delta_e,
		"probability": probability,
		"random_value": random_value
	}

	chaos_decision_made.emit(
		proposed_effect,
		final_effect,
		accepted,
		chaos_score,
		temperature,
		delta_e,
		probability,
		random_value
	)

	return result


# ============================================================
# Temperature Decay
# T decay is tied to player performance through Chaos Score
# ============================================================

func apply_temperature_decay() -> void:
	var performance_ratio: float = clamp(
		chaos_score / 100.0,
		0.0,
		1.0
	)

	var dynamic_decay: float = lerp(
		low_performance_decay,
		high_performance_decay,
		performance_ratio
	)

	temperature = temperature * dynamic_decay
	temperature = clamp(temperature, t_min, t_max)


# ===============
# delta e lookup
# ===============

func get_delta_e(effect_name: String) -> float:
	if delta_e_values.has(effect_name):
		return float(delta_e_values[effect_name])

	return 0.0


# ===============
# public getters
# ===============

func get_chaos_score() -> float:
	return chaos_score


func get_temperature() -> float:
	return temperature
