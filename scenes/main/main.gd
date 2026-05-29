extends Node2D

@onready var map = $MapPivot

func _ready():
	print("map node: ", map)

func _input(event):
	if map == null:
		return
	if event.is_action_pressed("ui_accept"):
		map.trigger_flip(90.0)
	if event.is_action_pressed("ui_cancel"):
		map.start_carousel()
