extends Control

func _on_play_button_pressed() -> void:
	hide()
	# Call main.gd's start_game which handles both player + timer
	var main = get_tree().current_scene
	if main.has_method("start_game"):
		main.start_game()

func _on_quit_button_pressed() -> void:
	get_tree().quit()
