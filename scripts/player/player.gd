extends CharacterBody2D

@export var speed: float = 200.0

func _physics_process(_delta: float) -> void:
	# Now listening for your custom WASD actions
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# 1. Check if the keys are being read
	print("Direction: ", direction) 
	
	velocity = direction * speed
	
	# 2. Check if the speed is actually being applied
	print("Velocity: ", velocity)
	
	move_and_slide()
