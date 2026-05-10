extends Node2D

var draw_detection = false
var draw_attack = false
var detection_radius = 0
var attack_radius = 0

func _draw():
	if draw_detection:
		draw_circle(Vector2(0, 0), detection_radius, Color(1, 1, 0, 0.1))
	if draw_attack:
		draw_circle(Vector2(0, 0), attack_radius, Color(1, 0, 0, 0.2))
