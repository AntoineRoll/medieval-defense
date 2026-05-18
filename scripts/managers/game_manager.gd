extends Node

enum GameState { TITLE, SERGEANT_SELECT, PLAYING, PAUSED, WON, LOST }

signal state_changed(from_state: GameState, to_state: GameState)

var state: GameState = GameState.TITLE:
	set(value):
		var old: GameState = state
		state = value
		state_changed.emit(old, value)

var gold: int = 200:
	set(value):
		gold = value
		EventBus.gold_changed.emit(gold)

var wave_number: int = 0
var selected_sergeant: String = ""
var game_over: bool = false

const FOOT_SOLDIER_COST: int = 50
const ARCHER_COST: int = 75
const CAVALRY_COST: int = 100
const TOWER_COST: int = 25
const KILL_REWARD: int = 10
const STARTING_GOLD: int = 200
const SERGEANT_BONUS_MULT: float = 1.2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.enemy_died.connect(_on_enemy_died)


func _on_enemy_died(_enemy: Node2D) -> void:
	if not game_over:
		add_gold(KILL_REWARD)


func reset_game() -> void:
	gold = STARTING_GOLD
	wave_number = 0
	selected_sergeant = ""
	game_over = false
	state = GameState.TITLE
	StateMachine.transition(StateMachine.State.TITLE)


func start_game(sergeant_type: String) -> void:
	selected_sergeant = sergeant_type
	wave_number = 0
	gold = STARTING_GOLD
	game_over = false
	state = GameState.PLAYING
	StateMachine.transition(StateMachine.State.PLAYING)


func can_afford(cost: int) -> bool:
	return gold >= cost


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	return true


func add_gold(amount: int) -> void:
	gold += amount


func end_game(won: bool) -> void:
	game_over = true
	state = GameState.WON if won else GameState.LOST
	if not won:
		StateMachine.transition(StateMachine.State.LOST)


func toggle_pause() -> void:
	if state == GameState.PLAYING:
		state = GameState.PAUSED
		get_tree().paused = true
		StateMachine.transition(StateMachine.State.PAUSED)
	elif state == GameState.PAUSED:
		state = GameState.PLAYING
		get_tree().paused = false
		StateMachine.transition(StateMachine.State.PLAYING)


static func _sergeant_matches(sergeant: String, unit_type: int) -> bool:
	match sergeant:
		"infantry":
			return unit_type == Unit.UnitType.FOOT_SOLDIER
		"archery":
			return unit_type == Unit.UnitType.ARCHER
		"cavalry":
			return unit_type == Unit.UnitType.CAVALRY
	return false


func apply_sergeant_bonus(unit: Node2D) -> void:
	if not unit.has_method("apply_bonus") or not unit.has_method("get_unit_type"):
		return
	if selected_sergeant == "" or not _sergeant_matches(selected_sergeant, unit.get_unit_type()):
		return
	unit.apply_bonus(SERGEANT_BONUS_MULT)
