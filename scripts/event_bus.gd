extends Node

signal gold_changed(amount: int)
signal wave_countdown(wave_number: int, seconds_left: int)
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal enemy_spawned(enemy: Node2D)
signal enemy_died(enemy: Node2D)
signal enemy_reached_base(enemy: Node2D)
signal base_hp_changed(current: int, max_hp: int)
signal base_destroyed
signal unit_selected(unit: Node2D)
signal unit_deselected
signal unit_died(unit: Node2D)
