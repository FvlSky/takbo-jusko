extends Node

# Drag and drop your nodes here while holding CTRL (or type their paths)
@onready var timer = $CanvasLayer/Timer
@onready var label = $CanvasLayer/Label

func _process(delta):
	# 1. Get the time left on the timer
	var time_left = timer.time_left
	
	# 2. Do some quick math to separate minutes and seconds
	var minutes = int(time_left / 60.0)
	var seconds = int(time_left) % 60
	
	# 3. Format it so it always shows two digits (e.g., "02:05" instead of "2:5")
	label.text = "%02d:%02d" % [minutes, seconds]

func _on_timer_timeout():
	# This triggers exactly when the 3 minutes are up!
	label.text = "00:00"
	print("Time is up!")
	# Add your Game Over or level transition logic here
