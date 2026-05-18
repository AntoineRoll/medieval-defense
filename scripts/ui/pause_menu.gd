extends Control


func _ready() -> void:
	%ResumeBtn.pressed.connect(_on_resume_pressed)
	%ExitBtn.pressed.connect(_on_exit_pressed)


func show_menu() -> void:
	visible = true


func hide_menu() -> void:
	visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		GameManager.toggle_pause()
	else:
		GameManager.toggle_pause()


func _on_resume_pressed() -> void:
	hide_menu()
	GameManager.toggle_pause()


func _on_exit_pressed() -> void:
	get_tree().quit()
