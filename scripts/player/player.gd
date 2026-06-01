extends CharacterBody2D

signal stamina_changed(current_stamina: float, max_stamina: float)
signal sprint_state_changed(is_sprinting: bool)
signal player_exhausted(is_exhausted: bool)

# -----------------------------
# TUNING VALUES
# -----------------------------

@export var normal_speed: float = 155.0
@export var sprint_speed: float = 265.0
@export var low_stamina_speed: float = 90.0
@export var low_stamina_threshold: float = 0.40

@export var max_stamina: float = 100.0
@export var sprint_drain_rate: float = 38.0
@export var stamina_regen_rate: float = 9.0
@export var min_stamina_to_sprint: float = 20.0

@export var regen_when_not_sprinting: bool = true

# -----------------------------
# STATE VARIABLES
# -----------------------------

var current_stamina: float
var is_sprinting: bool = false
var is_exhausted: bool = false
var last_direction: Vector2 = Vector2.DOWN
var _map_node: Node2D = null

# ──────────────────────────────────────────────────────────────
#  ANIMATION TREE
# ──────────────────────────────────────────────────────────────
@onready var animation_tree: AnimationTree = $AnimationTree
var _anim_playback: AnimationNodeStateMachinePlayback

# ──────────────────────────────────────────────────────────────
#  SPRINT STREAK TRACKING
# ──────────────────────────────────────────────────────────────
var _sprint_streak    : int   = 0
var _was_sprinting    : bool  = false
var _sprint_gap_timer : float = 0.0

const _SPRINT_GAP_WINDOW : float = 0.75

# ──────────────────────────────────────────────────────────────
#  PANIC DETECTION
# ──────────────────────────────────────────────────────────────
var _prev_input_dir   : Vector2 = Vector2.ZERO
var _dir_change_times : Array   = []

const _PANIC_WINDOW    : float = 2.0
const _PANIC_THRESHOLD : int   = 3
const _PANIC_TURN_DOT  : float = 0.30

# ──────────────────────────────────────────────────────────────
#  CAUGHT FLAG
# ──────────────────────────────────────────────────────────────
var _is_caught: bool = false


func _ready() -> void:
	add_to_group("player")

	_map_node = get_tree().current_scene.get_node_or_null("MapPivot") as Node2D
	if _map_node == null:
		print("ERROR: MapPivot not found")
	else:
		print("OK: MapPivot found")

	current_stamina = max_stamina
	stamina_changed.emit(current_stamina, max_stamina)

	# ── Animation Tree ────────────────────────────────────────
	animation_tree.active = true
	_anim_playback = animation_tree["parameters/playback"]

	# ── Connect Hitbox ────────────────────────────────────────
	var hitbox := get_node_or_null("Hitbox") as Area2D
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
		print("OK: Hitbox connected")
	else:
		print("ERROR: Hitbox node not found on Player")


# ──────────────────────────────────────────────────────────────
#  HITBOX DETECTION
# ──────────────────────────────────────────────────────────────
func _on_hitbox_body_entered(body: Node) -> void:
	if _is_caught:
		return
	if body.is_in_group("dog"):
		_is_caught = true
		print("DOG CAUGHT PLAYER")
		var main = get_tree().current_scene
		if main.has_method("trigger_lose"):
			main.trigger_lose()


# ──────────────────────────────────────────────────────────────
#  MAIN LOOP
# ──────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	var input_direction := get_screen_relative_input()
	update_sprint_state(input_direction)
	update_stamina(delta)
	move_player(input_direction)
	update_animation(input_direction)

	# ── Sprint streak ──────────────────────────────────────────
	if is_sprinting and not _was_sprinting:
		if _sprint_gap_timer <= _SPRINT_GAP_WINDOW:
			_sprint_streak += 1
		else:
			_sprint_streak = 1

		_sprint_gap_timer = 0.0

		if _sprint_streak >= 2:
			_notify_dog("on_player_sprint_streak", [_sprint_streak])

	if not is_sprinting:
		_sprint_gap_timer += delta

	_was_sprinting = is_sprinting

	# ── Panic detection ────────────────────────────────────────
	if input_direction.length() > 0.1 and _prev_input_dir.length() > 0.1:
		var dot := _prev_input_dir.dot(input_direction)
		if dot < _PANIC_TURN_DOT:
			var now := Time.get_ticks_msec() / 1000.0
			_dir_change_times.append(now)

			_dir_change_times = _dir_change_times.filter(
				func(t: float) -> bool: return (now - t) <= _PANIC_WINDOW
			)

			if _dir_change_times.size() >= _PANIC_THRESHOLD:
				_notify_dog("on_player_panic", [])

	if input_direction.length() > 0.1:
		_prev_input_dir = input_direction


# ──────────────────────────────────────────────────────────────
#  ANIMATION
# ──────────────────────────────────────────────────────────────
func update_animation(input_direction: Vector2) -> void:
	if input_direction != Vector2.ZERO:
		# Moving — use Run state
		_anim_playback.travel("Run")
		animation_tree["parameters/Run/blend_position"] = input_direction
		# Keep idle blend position in sync with last direction
		animation_tree["parameters/Idle/blend_position"] = input_direction
	else:
		# Stopped — use Idle state, keep facing last direction
		_anim_playback.travel("Idle")
		animation_tree["parameters/Idle/blend_position"] = last_direction


# ──────────────────────────────────────────────────────────────
#  HELPER
# ──────────────────────────────────────────────────────────────
func _notify_dog(method: String, args: Array) -> void:
	var dog = get_tree().get_first_node_in_group("dog")
	if dog and dog.has_method(method):
		dog.callv(method, args)


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
		var stamina_ratio := get_stamina_ratio()
		if stamina_ratio < low_stamina_threshold:
			var t := stamina_ratio / low_stamina_threshold
			current_speed = lerp(low_stamina_speed, normal_speed, t)

	velocity = input_direction * current_speed
	move_and_slide()


# ==============
# STAMINA LOGIC
# ==============

func update_sprint_state(input_direction: Vector2) -> void:
	var is_moving          := input_direction != Vector2.ZERO
	var sprint_pressed     := Input.is_action_pressed("sprint")
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
	velocity        = Vector2.ZERO

	current_stamina = max_stamina
	is_sprinting    = false
	is_exhausted    = false
	_is_caught      = false
	last_direction  = Vector2.DOWN

	stamina_changed.emit(current_stamina, max_stamina)
	sprint_state_changed.emit(is_sprinting)
	player_exhausted.emit(is_exhausted)

	# Reset animation to idle facing down
	if _anim_playback:
		_anim_playback.travel("Idle")
		animation_tree["parameters/Idle/blend_position"] = Vector2.DOWN
