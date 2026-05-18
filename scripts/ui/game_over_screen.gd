class_name GameOverScreen
extends Node2D

signal replay_pressed
signal quit_pressed

@onready var replay_btn: Button = %GameOverReplayBtn
@onready var quit_btn: Button = %GameOverQuitBtn
@onready var title_label: Label = %TitleLabel


func _ready() -> void:
	replay_btn.button_down.connect(_on_replay_pressed)
	quit_btn.button_down.connect(_on_quit_pressed)


func set_title(won: bool) -> void:
	title_label.text = "You Win!" if won else "Game Over"


func _on_replay_pressed() -> void:
	replay_pressed.emit()


func _on_quit_pressed() -> void:
	quit_pressed.emit()
	get_tree().quit()
