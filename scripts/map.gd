extends Node2D

var grass_sprites = []
var rock_sprites = []

export var grass_count = 50
export var rock_count = 30
export var map_radius_units = 40

func _ready():
	load_sprite_paths()
	spawn_decorations()

func load_sprite_paths():
	for i in range(1, 17):
		grass_sprites.append("res://assets/sprites/grass_" + str(i) + ".png")
		rock_sprites.append("res://assets/sprites/rock_" + str(i) + ".png")

func spawn_decorations():
	randomize()
	
	for i in range(grass_count):
		spawn_sprite(get_random_grass())
	
	for i in range(rock_count):
		spawn_sprite(get_random_rock())

func get_random_grass():
	return grass_sprites[randi() % grass_sprites.size()]

func get_random_rock():
	return rock_sprites[randi() % rock_sprites.size()]

func spawn_sprite(texture_path):
	var sprite = Sprite.new()
	sprite.texture = load(texture_path)
	sprite.position = get_random_grid_position()
	add_child(sprite)

func get_random_grid_position():
	var angle = rand_range(0, 2 * PI)
	var radius = rand_range(5, map_radius_units) * 16
	var x = round(radius * cos(angle) / 16) * 16
	var y = round(radius * sin(angle) / 16) * 16
	return Vector2(x, y)
