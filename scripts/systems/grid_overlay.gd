extends Node2D

@export var tile_size: int = 64
@export var grid_width: int = 16
@export var grid_height: int = 9
@export var grid_color: Color = Color(1, 1, 1, 0.15)
@export var center_color: Color = Color(1, 1, 0, 0.3)
@export var show_center_highlight: bool = true


func _draw() -> void:
	var grid_width_px: float = grid_width * tile_size
	var grid_height_px: float = grid_height * tile_size

	for x in range(grid_width + 1):
		var x_pos: float = x * tile_size
		draw_line(Vector2(x_pos, 0), Vector2(x_pos, grid_height_px), grid_color, 1.0)

	for y in range(grid_height + 1):
		var y_pos: float = y * tile_size
		draw_line(Vector2(0, y_pos), Vector2(grid_width_px, y_pos), grid_color, 1.0)

	if show_center_highlight:
		var cx: float = (grid_width / 2) * tile_size
		var cy: float = (grid_height / 2) * tile_size
		draw_rect(Rect2(cx, cy, tile_size, tile_size), center_color, false, 2.0)
