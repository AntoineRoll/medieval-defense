class_name Cavalry
extends "res://scripts/units/unit.gd"


func _ready() -> void:
	unit_type = Unit.UnitType.CAVALRY
	if not unit_stats:
		unit_stats = preload("res://resources/cavalry_stats.tres")
	super()
