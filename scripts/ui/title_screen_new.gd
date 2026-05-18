class_name TitleScreen
extends Node2D

signal play_pressed
signal quit_pressed

var play_handled: bool = false

@onready var play_btn: Button = %TitlePlayBtn
@onready var quit_btn: Button = %TitleQuitBtn


func _ready() -> void:
	play_btn.button_down.connect(_on_play_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)


func _on_play_pressed() -> void:
	if play_handled:
		return
	play_handled = true
	play_pressed.emit()


func _on_quit_pressed() -> void:
	quit_pressed.emit()
	get_tree().quit()
