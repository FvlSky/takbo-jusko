extends CharacterBody2D

signal stamina_changed(current_stamina: float, max_stamina: float)
signal sprint_state_changed(is_sprinting: bool)
signal player_exhausted(is_exhausted: bool)

# -----------------------------
# TUNING VALUES
# -----------------------------

@export var normal_speed: float = 155.0
@export var sprint_speed: float = 265.0
@export var low_stamina_speed: float = 90.0        # speed when nearly exhausted
@export var low_stamina_threshold: float = 0.40    # below 30% stamina = slow down

@export var max_stamina: float = 100.0
@export var sprint_drain_rate: float = 38.0
@export var stamina_regen_rate: float = 9.0
@export var min_stamina_to_sprint: float = 20.0

# If true, stamina regenerates when the player is not sprinting.
@export var regen_when_not_sprinting: bool = true

# -----------------------------
# STATE VARIABLES
# -----------------------------

var current_stamina: float
var is_sprinting: bool = false
var is_exhausted: bool = false
var last_direction: Vector2 = Vector2.DOWN
var _map_node: Node2D = null


func _ready() -> void:
	add_to_group("player")

	_map_node = get_tree().current_scene.get_node_or_null("MapPivot") as Node2D

	if _map_node == null:
		print("ERROR: MapPivot not found")
	else:
		print("OK: MapPivot found")

	current_stamina = max_stamina
	stamina_changed.emit(current_stamina, max_stamina)


func _physics_process(delta: float) -> void:
	var input_direction := get_screen_relative_input()
	update_sprint_state(input_direction)
	update_stamina(delta)
	move_player(input_direction)


# =========================
# SCREEN-RELATIVE MOVEMENT
# =========================

func get_screen_relative_input() -> Vector2:
	var input_direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	if input_direction != Vector2.ZERO:
		last_direction = input_direction

	return input_direction


func move_player(input_direction: Vector2) -> void:
	var current_speed := normal_speed

	if is_sprinting:
		current_speed = sprint_speed
	else:
		# Slow down gradually as stamina drops below threshold
		var stamina_ratio := get_stamina_ratio()
		if stamina_ratio < low_stamina_threshold:
			# Lerp between low_stamina_speed and normal_speed
			# t = 0.0 means empty stamina, t = 1.0 means just hit threshold
			var t := stamina_ratio / low_stamina_threshold
			current_speed = lerp(low_stamina_speed, normal_speed, t)

	velocity = input_direction * current_speed
	move_and_slide()


# ==============
# STAMINA LOGIC
# ==============

func update_sprint_state(input_direction: Vector2) -> void:
	var is_moving := input_direction != Vector2.ZERO
	var sprint_pressed := Input.is_action_pressed("sprint")
	var has_enough_stamina := current_stamina > min_stamina_to_sprint

	var previous_sprinting := is_sprinting

	is_sprinting = (
		is_moving
		and sprint_pressed
		and has_enough_stamina
		and not is_exhausted
	)

	if previous_sprinting != is_sprinting:
		sprint_state_changed.emit(is_sprinting)


func update_stamina(delta: float) -> void:
	var previous_stamina := current_stamina

	if is_sprinting:
		current_stamina -= sprint_drain_rate * delta
	elif regen_when_not_sprinting:
		# Regen is slow when stamina is low, faster as it recovers
		var stamina_ratio := get_stamina_ratio()
		var regen_multiplier: float = lerp(0.15, 1.0, stamina_ratio)
		current_stamina += stamina_regen_rate * regen_multiplier * delta

	current_stamina = clamp(current_stamina, 0.0, max_stamina)
	update_exhausted_state()

	if previous_stamina != current_stamina:
		stamina_changed.emit(current_stamina, max_stamina)

func update_exhausted_state() -> void:
	var previous_exhausted := is_exhausted

	if current_stamina <= 0.0:
		is_exhausted = true

	# Player can sprint again once stamina recovers enough
	if current_stamina >= min_stamina_to_sprint * 2.0:
		is_exhausted = false

	if previous_exhausted != is_exhausted:
		player_exhausted.emit(is_exhausted)


# ===================================
# PUBLIC FUNCTIONS FOR OTHER SYSTEMS
# ===================================

func get_stamina_ratio() -> float:
	if max_stamina <= 0.0:
		return 0.0
	return current_stamina / max_stamina


func get_current_stamina() -> float:
	return current_stamina


func get_max_stamina() -> float:
	return max_stamina


func get_last_direction() -> Vector2:
	return last_direction


func get_hitbox_node() -> Area2D:
	return $Hitbox


func reset_player_state(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO

	current_stamina = max_stamina
	is_sprinting = false
	is_exhausted = false
	last_direction = Vector2.DOWN

	stamina_changed.emit(current_stamina, max_stamina)
	sprint_state_changed.emit(is_sprinting)
	player_exhausted.emit(is_exhausted)
