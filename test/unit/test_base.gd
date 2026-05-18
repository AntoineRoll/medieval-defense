extends GutTest

const Base = preload("res://scripts/buildings/base.gd")


func test_take_damage_reduces_hp() -> void:
	var base = Base.new()
	autofree(base)
	var initial_hp: int = base.current_hp
	base.take_damage(10)
	assert_eq(base.current_hp, initial_hp - 10, "HP should decrease by damage amount")


func test_take_damage_multiple_hits() -> void:
	var base = Base.new()
	autofree(base)
	base.take_damage(50)
	base.take_damage(50)
	assert_eq(base.current_hp, base.max_hp - 100, "HP should decrease after multiple hits")


func test_take_damage_does_not_go_below_zero() -> void:
	var base = Base.new()
	autofree(base)
	base.take_damage(9999)
	assert_eq(base.current_hp, 0, "HP should not go below 0")


func test_take_damage_emits_hp_changed_signal() -> void:
	var base = Base.new()
	autofree(base)
	watch_signals(base)
	base.take_damage(10)
	assert_signal_emitted(base, "hp_changed", "take_damage() should emit hp_changed")


func test_base_hp_zero_when_destroyed() -> void:
	var base = Base.new()
	autofree(base)
	base.take_damage(9999)
	assert_eq(base.get_hp(), 0, "HP should be 0 when destroyed")


func test_base_destroyed_guards_double_damage() -> void:
	var base = Base.new()
	autofree(base)
	base.take_damage(9999)
	var hp_after_first: int = base.get_hp()
	base.take_damage(10)
	assert_eq(base.get_hp(), hp_after_first, "HP should not change after base is destroyed")


func test_get_hp_returns_current() -> void:
	var base = Base.new()
	autofree(base)
	base.current_hp = 75
	assert_eq(base.get_hp(), 75, "get_hp() should return current HP")


func test_get_max_hp_returns_max() -> void:
	var base = Base.new()
	autofree(base)
	base.max_hp = 200
	assert_eq(base.get_max_hp(), 200, "get_max_hp() should return max HP")


func test_get_hitbox_radius_returns_radius() -> void:
	var base = Base.new()
	autofree(base)
	assert_eq(base.get_hitbox_radius(), 64.0, "get_hitbox_radius() should return 64.0")


func test_initial_hp_matches_max() -> void:
	var base = Base.new()
	autofree(base)
	assert_eq(base.current_hp, base.max_hp, "current_hp should equal max_hp on init")
