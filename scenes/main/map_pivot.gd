extends Node2D

# ---- State ----
var is_flipping: bool = false
var target_rotation: float = 0.0
const FLIP_SPEED: float = 180.0

var carousel_active: bool = false
const CAROUSEL_SPEED: float = 25.0

var jitter_active: bool = false
var jitter_intensity: float = 5.0
var jitter_timer: float = 0.0

func _ready():
	position = Vector2(940, 640)
	$SubViewportContainer.position = Vector2(-640, -640)

func _process(delta):
	_handle_flip(delta)
	_handle_jitter(delta)
	_handle_carousel(delta)

func trigger_flip(degrees: float):
	if is_flipping:
		return
	is_flipping = true
	target_rotation = rotation_degrees + degrees

func _handle_flip(delta):
	if not is_flipping:
		return
	var diff = target_rotation - rotation_degrees
	if abs(diff) < 0.5:
		rotation_degrees = target_rotation
		is_flipping = false
	else:
		rotation_degrees += sign(diff) * FLIP_SPEED * delta

func start_carousel():
	carousel_active = true

func stop_carousel():
	carousel_active = false

func _handle_carousel(delta):
	if carousel_active:
		rotation_degrees += CAROUSEL_SPEED * delta

func trigger_jitter(intensity: float, duration: float):
	jitter_active = true
	jitter_intensity = intensity
	jitter_timer = duration

func _handle_jitter(delta):
	if not jitter_active:
		return
	jitter_timer -= delta
	if jitter_timer <= 0:
		jitter_active = false
		return
	position = Vector2(940, 640) + Vector2(
		randf_range(-jitter_intensity, jitter_intensity),
		randf_range(-jitter_intensity, jitter_intensity)
	)
