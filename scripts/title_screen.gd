extends Node2D

signal sergeant_selected(sergeant_type)

var sergeant_positions = {
	"infantry": Vector2(440, 360),
	"archery": Vector2(640, 360),
	"cavalry": Vector2(840, 360)
}
var click_radius = 80

func _ready():
	print("Title screen loaded")
	set_process_input(true)

func _input(event):
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		var mouse_pos = get_viewport().get_mouse_position()
		print("TitleScreen click at: " + str(mouse_pos))
		for type in sergeant_positions:
			if mouse_pos.distance_to(sergeant_positions[type]) < click_radius:
				print("Clicked on: " + type)
				emit_signal("sergeant_selected", type)
				visible = false
				break
