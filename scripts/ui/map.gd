class_name Map
extends Node2D

var pattern_textures: Array[Texture2D] = []

@export var tile_size_px: int = 32
@export var tiles_x: int = 64
@export var tiles_y: int = 64
@export var background_z_index: int = -10


func _ready() -> void:
	load_patterns()
	generate_background()


func load_patterns() -> void:
	for i in range(5):
		var path: String = "res://assets/sprites/Grass-pattern_" + str(i + 1) + ".png"
		var tex: Texture2D = load(path)
		if tex:
			pattern_textures.append(tex)
		else:
			push_error("Map: Failed to load " + path)


func generate_background() -> void:
	if pattern_textures.size() < 4:
		push_error("Map: Not all pattern textures loaded")
		return

	var img_width: int = tiles_x * tile_size_px
	var img_height: int = tiles_y * tile_size_px
	var sample_img: Image = pattern_textures[0].get_image()
	var bg_image: Image = Image.create(img_width, img_height, false, sample_img.get_format())

	for y in range(tiles_y):
		for x in range(tiles_x):
			var pattern_weight = [0.10, 0.175, 0.175, 0.025, 0.525]  # Adjust weights for more/less of each pattern
			# Select image according to weights
			var rand_val = randf()
			var cumulative_weight = 0.0
			var selected_index = 0
			for i in range(pattern_weight.size()):
				cumulative_weight += pattern_weight[i]
				if rand_val < cumulative_weight:
					selected_index = i
					break
			var pattern: Texture2D = pattern_textures[selected_index]
			var pattern_img: Image = pattern.get_image()
			# Add a random horizontal flip for more variation
			if randi() % 2 == 0:
				pattern_img.flip_x()
			bg_image.blit_rect(pattern_img, Rect2i(0, 0, tile_size_px, tile_size_px), Vector2i(x * tile_size_px, y * tile_size_px))

	var bg_texture: ImageTexture = ImageTexture.create_from_image(bg_image)

	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = bg_texture
	sprite.centered = true
	sprite.position = Vector2.ZERO
	sprite.z_index = background_z_index
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
