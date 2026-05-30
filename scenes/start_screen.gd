extends Control

func _on_play_button_pressed():
	hide()
	# tell the parent CanvasLayer to start the timer
	get_parent().start_game()

func _on_quit_button_pressed():
	get_tree().quit()
