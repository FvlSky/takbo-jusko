extends CanvasLayer

@onready var timer = $Timer
@onready var label = $Label
@onready var stamina_bar: TextureRect = $Staminabar

var atlas: AtlasTexture
var frame_width: float
var frame_height: float
var frame_gap: float = 32.0

func _ready() -> void:
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

	# Auto-start timer if restarting from lose/win screen
	if Global.skip_start_screen:
		timer.start()


func start_game() -> void:
	timer.start()


func _process(_delta: float) -> void:
	if timer.time_left > 0:
		var time_left = timer.time_left
		var minutes = int(time_left / 60.0)
		var seconds = int(time_left) % 60
		var milliseconds = int(fmod(time_left, 1.0) * 100)
		label.text = "%02d:%02d:%02d" % [minutes, seconds, milliseconds]


func _on_timer_timeout() -> void:
	label.text = "00:00:00"
	print("Time is up!")


func _on_stamina_changed(current_stamina: float, max_stamina: float) -> void:
	var ratio := current_stamina / max_stamina
	var frame_index := 9 - int(ratio * 9.0)
	frame_index = clamp(frame_index, 0, 9)
	var x_offset := frame_index * (frame_width + frame_gap)
	atlas.region = Rect2(x_offset, 0, frame_width, frame_height)
