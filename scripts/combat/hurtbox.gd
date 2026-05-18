class_name Hurtbox
extends Area2D

signal hurt(hitbox: Area2D)

var invulnerable: bool = false


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if invulnerable:
		return
	if area is Hitbox:
		hurt.emit(area)
