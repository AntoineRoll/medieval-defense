class_name Archer
extends "res://scripts/units/unit.gd"

const PROJECTILE_SPEED: float = 400.0


func _ready() -> void:
	unit_type = Unit.UnitType.ARCHER
	if not unit_stats:
		unit_stats = preload("res://resources/archer_stats.tres")
	super()


func _apply_attack() -> void:
	if not _current_target or not _current_target.has_method("take_damage"):
		return
	print("DAMAGE: Archer deals ", attack_damage, " to ", _current_target.name, " at ", Vector2i(_current_target.global_position))
	_spawn_projectile(_current_target, attack_damage)
