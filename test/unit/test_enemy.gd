extends GutTest

const Enemy = preload("res://scripts/enemies/enemy.gd")


func test_take_damage_reduces_hp() -> void:
	var enemy = Enemy.new()
	autofree(enemy)
	var initial_hp: int = enemy.current_hp
	enemy.take_damage(10)
	assert_eq(enemy.current_hp, initial_hp - 10, "HP should decrease by amount of damage")


func test_take_damage_multiple_hits() -> void:
	var enemy = Enemy.new()
	autofree(enemy)
	enemy.take_damage(10)
	enemy.take_damage(10)
	enemy.take_damage(10)
	assert_eq(enemy.current_hp, enemy.max_hp - 30, "HP should decrease after multiple hits")


func test_die_when_hp_reaches_zero() -> void:
	var enemy = Enemy.new()
	autofree(enemy)
	watch_signals(enemy)
	enemy.take_damage(999)
	assert_signal_emitted(enemy, "enemy_died", "Enemy should emit enemy_died signal when HP reaches 0")


func test_no_damage_after_death() -> void:
	var enemy = Enemy.new()
	autofree(enemy)
	enemy.take_damage(999)
	var hp_after_death: int = enemy.current_hp
	enemy.take_damage(10)
	assert_eq(enemy.current_hp, hp_after_death, "HP should not change after enemy is dead")


func test_get_hp_matches_current() -> void:
	var enemy = Enemy.new()
	autofree(enemy)
	enemy.max_hp = 100
	enemy.current_hp = 75
	assert_eq(enemy.get_hp(), 75, "get_hp() should return current HP")


func test_get_max_hp_matches_max() -> void:
	var enemy = Enemy.new()
	autofree(enemy)
	enemy.max_hp = 100
	assert_eq(enemy.get_max_hp(), 100, "get_max_hp() should return max HP")


func test_base_position_set_and_get() -> void:
	var enemy = Enemy.new()
	autofree(enemy)
	var pos: Vector2 = Vector2(320, 240)
	enemy.set_base_position(pos)
	assert_eq(enemy.base_position, pos, "base_position should match set value")


func test_get_unit_type_returns_foot_soldier() -> void:
	var enemy = Enemy.new()
	autofree(enemy)
	assert_eq(enemy.get_unit_type(), Unit.UnitType.FOOT_SOLDIER, "Enemy should report as FOOT_SOLDIER type")
