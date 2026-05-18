class_name FootSoldier
extends "res://scripts/units/unit.gd"


func _ready() -> void:
	unit_type = Unit.UnitType.FOOT_SOLDIER
	if not unit_stats:
		unit_stats = preload("res://resources/foot_soldier_stats.tres")
	super()
