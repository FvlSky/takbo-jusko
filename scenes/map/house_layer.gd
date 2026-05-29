extends TileMapLayer

func _ready():
	# Get the Area2D (assuming it's a child node named "Area2D")
	var detection_area = $Area2D
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "Player":
		# Fade roof to 40% opacity
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.4, 0.2) 

func _on_body_exited(body):
	if body.name == "Player":
		# Fade roof back to solid
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 1.0, 0.2)
