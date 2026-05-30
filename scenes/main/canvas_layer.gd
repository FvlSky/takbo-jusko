extends CanvasLayer

@onready var timer = $Timer
@onready var label = $Label

func _process(delta):
	if timer.time_left > 0:
		var time_left = timer.time_left
		var minutes = int(time_left / 60.0)
		var seconds = int(time_left) % 60
		label.text = "%02d:%02d" % [minutes, seconds]

func _on_timer_timeout():
	label.text = "00:00"
	print("Time is up!")
