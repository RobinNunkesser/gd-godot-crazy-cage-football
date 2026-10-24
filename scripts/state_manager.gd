class_name CageStateManager
extends RefCounted

const CageConfig = preload("res://scripts/config.gd")

## Match-State-Machine für Crazy Cage Football

enum MatchState {
	LOBBY,
	WARMUP,
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

var current_state: MatchState = MatchState.LOBBY
var time_remaining: float = CageConfig.MATCH_DURATION_SECONDS
var celebration_timer: float = 0.0
var warmup_timer: float = 3.0
var scores: Dictionary = {1: 0, 2: 0} # Team 1 = Rot (links), Team 2 = Blau (rechts)

var last_scoring_team: int = 0

func enter_lobby() -> void:
	scores = {1: 0, 2: 0}
	last_scoring_team = 0
	current_state = MatchState.LOBBY
	state_changed.emit(current_state)

func start_match(duration: float = CageConfig.MATCH_DURATION_SECONDS) -> void:
	scores = {1: 0, 2: 0}
	last_scoring_team = 0
	time_remaining = duration
	celebration_timer = 0.0
	warmup_timer = 3.0
	current_state = MatchState.WARMUP
	state_changed.emit(current_state)
	score_updated.emit(1, 0)
	score_updated.emit(2, 0)
	timer_updated.emit(time_remaining)

func reset_match(duration: float = CageConfig.MATCH_DURATION_SECONDS) -> void:
	start_match(duration)

func start_play() -> void:
	if current_state == MatchState.KICKOFF or current_state == MatchState.WARMUP or current_state == MatchState.RESET:
		current_state = MatchState.PLAYING
		state_changed.emit(current_state)

func update_logic(delta: float) -> void:
	match current_state:
		MatchState.LOBBY:
			pass
		MatchState.WARMUP:
			warmup_timer -= delta
			if warmup_timer <= 0.0:
				current_state = MatchState.PLAYING
				state_changed.emit(current_state)
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
			warmup_timer = CageConfig.KICKOFF_DELAY
			current_state = MatchState.WARMUP
			state_changed.emit(current_state)
		MatchState.KICKOFF:
			warmup_timer = CageConfig.KICKOFF_DELAY
			current_state = MatchState.WARMUP
			state_changed.emit(current_state)
		MatchState.MATCH_OVER:
			pass

func trigger_goal(scoring_team: int) -> void:
	if current_state != MatchState.PLAYING:
		return
	
	last_scoring_team = scoring_team
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
