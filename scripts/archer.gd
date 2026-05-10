extends "res://scripts/unit.gd"

func _ready():
	setup_stats(60, 70, 160, 128, 8, 1.0, true)
	print("Archer: is_ranged = " + str(is_ranged))
	._ready()
