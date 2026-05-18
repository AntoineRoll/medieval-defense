extends GutTest

const Unit = preload("res://scripts/units/unit.gd")


func test_setup_stats_assigns_hp() -> void:
	var unit = preload("res://scenes/units/foot_soldier.tscn").instantiate()
	add_child_autofree(unit)
	unit.setup_stats(100, 80, 128, 32, 10, 1.0)
	assert_eq(unit.max_hp, 100, "max_hp should be set")


func test_setup_stats_assigns_speed() -> void:
	var unit = preload("res://scenes/units/foot_soldier.tscn").instantiate()
	add_child_autofree(unit)
	unit.setup_stats(100, 80, 128, 32, 10, 1.0)
	assert_eq(unit.speed, 80.0, "speed should be set")


func test_setup_stats_assigns_attack_range() -> void:
	var unit = preload("res://scenes/units/foot_soldier.tscn").instantiate()
	add_child_autofree(unit)
	unit.setup_stats(100, 80, 128, 32, 10, 1.0)
	assert_eq(unit.attack_range, 32.0, "attack_range should be set")


func test_take_damage_reduces_current_hp() -> void:
	var unit = preload("res://scenes/units/foot_soldier.tscn").instantiate()
	add_child_autofree(unit)
	var initial_hp: int = unit.current_hp
	unit.take_damage(10)
	assert_eq(unit.current_hp, initial_hp - 10, "HP should decrease by damage amount")


func test_take_damage_multiple_hits() -> void:
	var unit = preload("res://scenes/units/foot_soldier.tscn").instantiate()
	add_child_autofree(unit)
	unit.take_damage(25)
	unit.take_damage(25)
	assert_eq(unit.current_hp, 50, "HP should be 50 after two 25-damage hits")


func test_get_hp_returns_current() -> void:
	var unit = preload("res://scenes/units/foot_soldier.tscn").instantiate()
	add_child_autofree(unit)
	unit.take_damage(30)
	assert_eq(unit.get_hp(), unit.current_hp, "get_hp() should return current HP")


func test_get_max_hp_returns_max() -> void:
	var unit = preload("res://scenes/units/foot_soldier.tscn").instantiate()
	add_child_autofree(unit)
	assert_eq(unit.get_max_hp(), unit.max_hp, "get_max_hp() should return max HP")


func test_foot_soldier_has_correct_unit_type() -> void:
	var unit = preload("res://scenes/units/foot_soldier.tscn").instantiate()
	add_child_autofree(unit)
	assert_eq(unit.unit_type, Unit.UnitType.FOOT_SOLDIER, "Foot soldier should have FOOT_SOLDIER type")


func test_get_unit_type_method() -> void:
	var unit = preload("res://scenes/units/foot_soldier.tscn").instantiate()
	add_child_autofree(unit)
	assert_eq(unit.get_unit_type(), Unit.UnitType.FOOT_SOLDIER, "get_unit_type() should return FOOT_SOLDIER")


func test_set_selected_emits_signal() -> void:
	var unit = preload("res://scenes/units/foot_soldier.tscn").instantiate()
	add_child_autofree(unit)
	watch_signals(unit)
	unit.set_selected(true)
	assert_signal_emitted(unit, "selected_changed", "set_selected(true) should emit selected_changed")
