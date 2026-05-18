class_name SergeantSelect
extends Node2D

signal sergeant_selected(sergeant_type: String)

var sergeant_positions: Dictionary = {
	"infantry": Vector2(440, 360),
	"archery": Vector2(640, 360),
	"cavalry": Vector2(840, 360)
}
var click_radius: float = 80.0


func _ready() -> void:
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		for sergeant_type: String in sergeant_positions:
			if mouse_pos.distance_to(sergeant_positions[sergeant_type]) < click_radius:
				sergeant_selected.emit(sergeant_type)
				visible = false
				break
