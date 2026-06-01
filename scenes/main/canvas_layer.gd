extends CanvasLayer

@onready var timer = $Timer
@onready var label = $Label
@onready var stamina_bar: TextureRect = $Staminabar

@onready var pause_button: TextureButton = $PauseButton
@onready var restart_button: TextureButton = $RestartButton
@onready var quit_button: TextureButton = $QuitButton

var is_paused: bool = false

var atlas: AtlasTexture
var frame_width: float
var frame_height: float
var frame_gap: float = 32.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# The old Timer node is kept in the scene, but it should not control the countdown anymore
	# main.gd is now the only timer source
	if timer:
		timer.stop()
		timer.autostart = false

	var spritesheet = load("res://assets/ui/STAMINABAR.png")
	frame_width = 224.0
	frame_height = 32.0
	frame_gap = 32.0

	stamina_bar.custom_minimum_size = Vector2(frame_width, frame_height)
	stamina_bar.size = Vector2(frame_width, frame_height)

	atlas = AtlasTexture.new()
	atlas.atlas = spritesheet
	atlas.region = Rect2(0, 0, frame_width, frame_height)
	stamina_bar.texture = atlas

	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.stamina_changed.connect(_on_stamina_changed)
	else:
		print("ERROR: Player not found for stamina bar")

	# Connect to main.gd timer after the parent is ready.
	call_deferred("_connect_game_timer")

	pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
	restart_button.process_mode = Node.PROCESS_MODE_ALWAYS
	quit_button.process_mode = Node.PROCESS_MODE_ALWAYS

	if not pause_button.pressed.is_connected(_on_pause_button_pressed):
		pause_button.pressed.connect(_on_pause_button_pressed)

	if not restart_button.pressed.is_connected(_on_restart_button_pressed):
		restart_button.pressed.connect(_on_restart_button_pressed)

	if not quit_button.pressed.is_connected(_on_quit_button_pressed):
		quit_button.pressed.connect(_on_quit_button_pressed)


func _connect_game_timer() -> void:
	var game_manager = get_parent()

	if game_manager == null or not game_manager.has_signal("timer_updated"):
		game_manager = get_tree().get_first_node_in_group("game_manager")

	if game_manager:
		if not game_manager.timer_updated.is_connected(_on_timer_updated):
			game_manager.timer_updated.connect(_on_timer_updated)

		if "time_left" in game_manager:
			_on_timer_updated(game_manager.time_left, game_manager.time_elapsed)
	else:
		print("ERROR: Game manager not found for timer display")


func start_game() -> void:
	# Timer is now controlled by main.gd
	# This function is kept so main.gd can still call $CanvasLayer.start_game()
	pass


func _process(_delta: float) -> void:
	# Timer display is now updated through _on_timer_updated()
	# This stays empty so the UI does not keep counting while paused
	pass


func _on_timer_updated(time_left: float, _time_elapsed: float) -> void:
	var total_seconds: int = int(time_left)
	var minutes: int = int(total_seconds / 60.0)
	var seconds: int = total_seconds % 60
	var milliseconds: int = int(fmod(time_left, 1.0) * 100)

	label.text = "%02d:%02d:%02d" % [minutes, seconds, milliseconds]


func _on_timer_timeout() -> void:
	# The old Timer node no longer controls the actual game time.
	# This is kept only to avoid breaking any existing signal connection.
	label.text = "00:00:00"
	print("Time is up!")


func _on_stamina_changed(current_stamina: float, max_stamina: float) -> void:
	var ratio := current_stamina / max_stamina
	var frame_index := 9 - int(ratio * 9.0)
	frame_index = clamp(frame_index, 0, 9)
	var x_offset := frame_index * (frame_width + frame_gap)
	atlas.region = Rect2(x_offset, 0, frame_width, frame_height)


func _on_pause_button_pressed() -> void:
	is_paused = not is_paused
	get_tree().paused = is_paused


func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()
