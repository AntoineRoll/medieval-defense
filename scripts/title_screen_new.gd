extends Node2D

signal play_pressed
signal quit_pressed

func _ready():
	if has_node("VBox/PlayBtn"):
		$VBox/PlayBtn.connect("pressed", self, "_on_PlayBtn_pressed")
	if has_node("VBox/QuitBtn"):
		$VBox/QuitBtn.connect("pressed", self, "_on_QuitBtn_pressed")

func _on_PlayBtn_pressed():
	emit_signal("play_pressed")

func _on_QuitBtn_pressed():
	emit_signal("quit_pressed")
	get_tree().quit()
