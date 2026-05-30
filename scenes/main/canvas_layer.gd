extends CanvasLayer

@onready var timer = $Timer
@onready var label = $Label
@onready var button = $PlayButton
@onready var title = $Title

func _process(_delta):
	if timer.time_left > 0:
		var time_left = timer.time_left
		var minutes = int(time_left / 60.0)
		var seconds = int(time_left) % 60
		var milliseconds = int(fmod(time_left, 1.0) * 100)
		
		label.text = "%02d:%02d:%02d" % [minutes, seconds, milliseconds]

func _on_button_pressed():
	timer.start()
		
		
func _on_timer_timeout():
	label.text = "00:00:00"
	print("Time is up!")
