extends Node2D

# ============================================================
# Bright Highlight Ring
# Use this under Player and Dog so they are easier to see.
# ============================================================

@export var radius: float = 20.0

# Main glow color
@export var fill_color: Color = Color(0.0, 1.0, 0.2, 0.65)

# Outer soft glow
@export var glow_color: Color = Color(0.0, 1.0, 0.2, 0.28)

# Strong outline
@export var border_color: Color = Color(0.0, 1.0, 0.2, 1.0)

@export var pulse_enabled: bool = true
@export var pulse_speed: float = 4.0
@export var pulse_strength: float = 0.16

var pulse_time: float = 0.0


func _ready() -> void:
	# Keep the highlight behind the sprite but still above the floor.
	z_index = 0.5


func _process(delta: float) -> void:
	if pulse_enabled:
		pulse_time += delta
		queue_redraw()


func _draw() -> void:
	var pulse_scale: float = 1.0

	if pulse_enabled:
		pulse_scale += sin(pulse_time * pulse_speed) * pulse_strength

	var final_radius: float = radius * pulse_scale

	# Outer glow
	draw_circle(Vector2.ZERO, final_radius * 1.45, glow_color)

	# Main bright fill
	draw_circle(Vector2.ZERO, final_radius, fill_color)

	# Inner stronger center
	draw_circle(Vector2.ZERO, final_radius * 0.55, Color(fill_color.r, fill_color.g, fill_color.b, 0.85))

	# Border ring
	draw_arc(Vector2.ZERO, final_radius, 0.0, TAU, 80, border_color, 3.0)
