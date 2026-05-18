extends Node

enum State { TITLE, PLAYING, PAUSED, WON, LOST }

signal state_changed(from_state: State, to_state: State)

var current_state: State = State.TITLE:
	set(value):
		var old: State = current_state
		current_state = value
		state_changed.emit(old, value)


func transition(new_state: State) -> void:
	exit(current_state)
	current_state = new_state
	enter(current_state)


func enter(state: State) -> void:
	match state:
		State.TITLE:
			pass
		State.PLAYING:
			pass
		State.PAUSED:
			pass
		State.WON:
			pass
		State.LOST:
			pass


func exit(state: State) -> void:
	pass


func tick(delta: float) -> void:
	pass
