extends Node2D

signal replay_pressed
signal quit_pressed

func _ready():
	if has_node("VBox/ReplayBtn"):
		$VBox/ReplayBtn.connect("pressed", self, "_on_ReplayBtn_pressed")
	if has_node("VBox/QuitBtn"):
		$VBox/QuitBtn.connect("pressed", self, "_on_QuitBtn_pressed")

func _on_ReplayBtn_pressed():
	emit_signal("replay_pressed")

func _on_QuitBtn_pressed():
	emit_signal("quit_pressed")
	get_tree().quit()
