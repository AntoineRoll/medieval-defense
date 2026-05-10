extends Node2D

signal hp_changed(current_hp, max_hp)
signal base_destroyed

export var max_hp = 200
var current_hp = 200
var selected = false
var click_radius = 60
var game_over = false

func _ready():
	add_to_group("buildings")
	if has_node("CollisionArea"):
		$CollisionArea.add_to_group("base")
		print("Base: Added CollisionArea to 'base' group")

func _draw():
	draw_circle(Vector2(0, 0), 40, Color(0.55, 0.27, 0.07))
	draw_rect(Rect2(-30, -50, 60, 10), Color(0.3, 0.3, 0.3))
	var bar_width = 60
	var bar_height = 8
	var pos = Vector2(-bar_width / 2, -50)
	var ratio = float(current_hp) / float(max_hp)
	draw_rect(Rect2(pos, Vector2(bar_width, bar_height)), Color(1, 0, 0))
	var fill_color = Color(0, 1, 0) if ratio > 0.5 else Color(1, 1, 0) if ratio > 0.25 else Color(1, 0, 0)
	draw_rect(Rect2(pos, Vector2(bar_width * ratio, bar_height)), fill_color)
	if selected:
		draw_circle(Vector2(0, 0), click_radius, Color(1, 1, 0, 0.2))

func get_hp():
	return current_hp

func get_max_hp():
	return max_hp

func is_clicked(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		return get_global_mouse_position().distance_to(global_position) < 100.0
	return false

var damage_events = 0

func take_damage(amount):
	damage_events += 1
	current_hp -= amount
	current_hp = max(0, current_hp)
	emit_signal("hp_changed", current_hp, max_hp)
	update()
	if current_hp <= 0 and not game_over:
		game_over = true
		emit_signal("base_destroyed")

func set_selected(value):
	selected = value
	update()
	var main = get_tree().current_scene
	if main and main.has_method("update_action_bar"):
		if value:
			main.update_action_bar(self)
		else:
			main.update_action_bar(null)
