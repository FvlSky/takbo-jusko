extends SubViewportContainer

# --- Flip ---
var target_rotation: float = 0.0
var is_flipping: bool = false
const FLIP_SPEED: float = 180.0  # degrees/sec

# --- Jitter ---
var jitter_active: bool = false
var jitter_intensity: float = 5.0
var jitter_timer: float = 0.0
var base_pos: Vector2

# --- Carousel ---
var carousel_active: bool = false
const CAROUSEL_SPEED: float = 25.0

func _ready():
	base_pos = position
	position = Vector2.ZERO

func _process(delta):
	_handle_flip(delta)
	_handle_jitter(delta)
	_handle_carousel(delta)

# ---- FLIP ----
func trigger_flip(degrees: float):
	if is_flipping:
		return
	is_flipping = true
	target_rotation = rotation_degrees + degrees
	# emit telegraph signal here
	# SignalBus.telegraph_warning.emit(degrees)

func _handle_flip(delta):
	if not is_flipping:
		return
	var diff = target_rotation - rotation_degrees
	if abs(diff) < 0.5:
		rotation_degrees = target_rotation
		is_flipping = false
	else:
		rotation_degrees += sign(diff) * FLIP_SPEED * delta

# ---- JITTER ----
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
		position = base_pos
		return
	position = base_pos + Vector2(
		randf_range(-jitter_intensity, jitter_intensity),
		randf_range(-jitter_intensity, jitter_intensity)
	)

# ---- CAROUSEL ----
func start_carousel():
	carousel_active = true

func stop_carousel():
	carousel_active = false

func _handle_carousel(delta):
	if carousel_active:
		rotation_degrees += CAROUSEL_SPEED * delta
