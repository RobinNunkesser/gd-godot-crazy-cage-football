class_name CageStateManager
extends RefCounted

const CageConfig = preload("res://scripts/config.gd")

## Match-State-Machine für Crazy Cage Football

enum MatchState {
	KICKOFF,
	PLAYING,
	GOAL_SCORED,
	CELEBRATION,
	RESET,
	MATCH_OVER
}

signal state_changed(new_state: MatchState)
signal score_updated(team_id: int, new_score: int)
signal timer_updated(time_remaining: float)
signal goal_celebrated(scoring_team: int)
signal match_finished(winning_team: int)

var current_state: MatchState = MatchState.KICKOFF
var time_remaining: float = CageConfig.MATCH_DURATION_SECONDS
var celebration_timer: float = 0.0
var scores: Dictionary = {1: 0, 2: 0} # Team 1 = Rot (links), Team 2 = Blau (rechts)

func reset_match(duration: float = CageConfig.MATCH_DURATION_SECONDS) -> void:
	scores = {1: 0, 2: 0}
	time_remaining = duration
	celebration_timer = 0.0
	current_state = MatchState.KICKOFF
	state_changed.emit(current_state)
	score_updated.emit(1, 0)
	score_updated.emit(2, 0)
	timer_updated.emit(time_remaining)

func start_play() -> void:
	if current_state == MatchState.KICKOFF:
		current_state = MatchState.PLAYING
		state_changed.emit(current_state)

func update_logic(delta: float) -> void:
	match current_state:
		MatchState.KICKOFF:
			pass # Wartet auf ersten Ballkontakt
		MatchState.PLAYING:
			time_remaining -= delta
			timer_updated.emit(maxf(0.0, time_remaining))
			if time_remaining <= 0.0:
				time_remaining = 0.0
				_handle_timer_expiry()
		MatchState.GOAL_SCORED:
			celebration_timer = CageConfig.CELEBRATION_DURATION
			current_state = MatchState.CELEBRATION
			state_changed.emit(current_state)
		MatchState.CELEBRATION:
			celebration_timer -= delta
			if celebration_timer <= 0.0:
				current_state = MatchState.RESET
				state_changed.emit(current_state)
		MatchState.RESET:
			current_state = MatchState.KICKOFF
			state_changed.emit(current_state)
		MatchState.MATCH_OVER:
			pass

func trigger_goal(scoring_team: int) -> void:
	if current_state != MatchState.PLAYING:
		return
	
	if scores.has(scoring_team):
		scores[scoring_team] += 1
		score_updated.emit(scoring_team, scores[scoring_team])
	
	celebration_timer = CageConfig.CELEBRATION_DURATION
	current_state = MatchState.CELEBRATION
	state_changed.emit(current_state)
	goal_celebrated.emit(scoring_team)

func _handle_timer_expiry() -> void:
	current_state = MatchState.MATCH_OVER
	state_changed.emit(current_state)
	match_finished.emit(get_winner())

func get_winner() -> int:
	if scores[1] > scores[2]:
		return 1
	elif scores[2] > scores[1]:
		return 2
	return 0 # Unentschieden
