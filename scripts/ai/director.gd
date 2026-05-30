extends Node
# =======================================
# Director AI — Rule-Based Decision Tree
# =======================================
signal director_decision_made(
	current_state: String,
	selected_rule: String,
	selected_effect: String,
	distance_to_dog: float,
	stamina_ratio: float,
	time_elapsed: float
)
# --------------
# TUNING VALUES
# --------------
@export var danger_distance: float = 90.0
@export var close_distance: float = 160.0
@export var safe_distance: float = 180.0        # lowered from 280
@export var low_stamina_threshold: float = 0.30
@export var medium_stamina_threshold: float = 0.60
@export var mid_game_time: float = 60.0
@export var late_game_time: float = 120.0
@export var effect_cooldown_duration: float = 4.0  # seconds between major effects

# -------------
# OUTPUT STATE
# -------------
var current_state: String = "idle"
var selected_rule: String = "none"
var selected_effect: String = "none"
var effect_cooldown: float = 0.0

func evaluate(distance_to_dog: float, stamina_ratio: float, time_elapsed: float) -> Dictionary:
	# Tick cooldown down by 1 each call (called every 1 second from main.gd)
	effect_cooldown -= 1.0

	if is_danger_close(distance_to_dog):
		# Dog is right on top of the player — jitter as warning, no cooldown needed
		current_state = "warning"
		selected_rule = "dog_danger_close"
		selected_effect = "jitter"

	elif is_low_stamina(stamina_ratio) and is_close(distance_to_dog):
		# Vulnerable and being chased — upgraded from jitter to flip
		current_state = "critical_pressure"
		selected_rule = "low_stamina_and_close_dog"
		selected_effect = _with_cooldown("flip_90")

	elif is_low_stamina(stamina_ratio):
		# Stamina drained even if dog isn't close
		current_state = "low_stamina_pressure"
		selected_rule = "low_stamina_only"
		selected_effect = _with_cooldown("flip_90")

	elif is_late_game(time_elapsed) and is_safe(distance_to_dog) and is_stamina_good(stamina_ratio):
		# Player is thriving late game — punish with carousel
		current_state = "late_game_high_pressure"
		selected_rule = "late_game_safe_player"
		selected_effect = _with_cooldown("carousel")

	elif is_mid_game(time_elapsed) and is_safe(distance_to_dog):
		# Player is too comfortable in mid game
		current_state = "mid_game_pressure"
		selected_rule = "mid_game_safe_player"
		selected_effect = _with_cooldown("flip_180")

	elif is_close(distance_to_dog):
		# Dog is close but not danger-close
		current_state = "close_range_pressure"
		selected_rule = "dog_close"
		selected_effect = _with_cooldown("flip_90")

	elif not is_safe(distance_to_dog) and not is_close(distance_to_dog):
		# Fills the dead zone between close_distance and safe_distance (160–180)
		current_state = "mid_range_pressure"
		selected_rule = "mid_range_roaming"
		selected_effect = _with_cooldown("jitter")

	else:
		current_state = "stable"
		selected_rule = "stable_no_major_distortion"
		selected_effect = "none"

	var decision := {
		"current_state": current_state,
		"selected_rule": selected_rule,
		"selected_effect": selected_effect,
		"distance_to_dog": distance_to_dog,
		"stamina_ratio": stamina_ratio,
		"time_elapsed": time_elapsed
	}

	director_decision_made.emit(
		current_state,
		selected_rule,
		selected_effect,
		distance_to_dog,
		stamina_ratio,
		time_elapsed
	)

	return decision

# =============================
# CONDITION-CHECKING FUNCTIONS
# =============================
func is_danger_close(distance_to_dog: float) -> bool:
	return distance_to_dog <= danger_distance

func is_close(distance_to_dog: float) -> bool:
	return distance_to_dog <= close_distance

func is_safe(distance_to_dog: float) -> bool:
	return distance_to_dog >= safe_distance

func is_low_stamina(stamina_ratio: float) -> bool:
	return stamina_ratio <= low_stamina_threshold

func is_medium_stamina(stamina_ratio: float) -> bool:
	return stamina_ratio <= medium_stamina_threshold

func is_stamina_good(stamina_ratio: float) -> bool:
	return stamina_ratio > medium_stamina_threshold

func is_mid_game(time_elapsed: float) -> bool:
	return time_elapsed >= mid_game_time

func is_late_game(time_elapsed: float) -> bool:
	return time_elapsed >= late_game_time

# ================================
# COOLDOWN HELPER
# ================================
func _with_cooldown(effect: String) -> String:
	if effect_cooldown > 0.0:
		return "none"  # still cooling down, skip this effect
	effect_cooldown = effect_cooldown_duration
	return effect

# ================================
# GETTERS FOR DEBUG OVERLAY / HUD
# ================================
func get_current_state() -> String:
	return current_state

func get_selected_rule() -> String:
	return selected_rule

func get_selected_effect() -> String:
	return selected_effect
