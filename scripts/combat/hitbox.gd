class_name Hitbox
extends Area2D

@export var damage: int = 10
@export var one_time: bool = true
@export var friendly: bool = false

var _hit_bodies: Array[Node2D] = []


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		if one_time and area in _hit_bodies:
			return
		_hit_bodies.append(area)


func is_friendly_hit() -> bool:
	return friendly


func reset() -> void:
	_hit_bodies.clear()
