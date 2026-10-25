class_name CageMatchStats
extends RefCounted

## Match-Statistiken für Crazy Cage Football
## Erfasst Torschüsse, Pfostentreffer, Power-Ups, Sprünge, Tackles, Ballbesitz und Höchstgeschwindigkeit.

var goals: Dictionary = {1: 0, 2: 0}
var shots: Dictionary = {1: 0, 2: 0}
var post_hits: Dictionary = {1: 0, 2: 0}
var powerups: Dictionary = {1: 0, 2: 0}
var jumps: Dictionary = {1: 0, 2: 0}
var tackles: Dictionary = {1: 0, 2: 0}
var possession_seconds: Dictionary = {1: 0.0, 2: 0.0}
var max_ball_speed_ms: float = 0.0

func reset() -> void:
	goals = {1: 0, 2: 0}
	shots = {1: 0, 2: 0}
	post_hits = {1: 0, 2: 0}
	powerups = {1: 0, 2: 0}
	jumps = {1: 0, 2: 0}
	tackles = {1: 0, 2: 0}
	possession_seconds = {1: 0.0, 2: 0.0}
	max_ball_speed_ms = 0.0

func record_goal(team_id: int) -> void:
	if goals.has(team_id):
		goals[team_id] += 1

func record_shot(team_id: int) -> void:
	if shots.has(team_id):
		shots[team_id] += 1

func record_post_hit(team_id: int) -> void:
	if post_hits.has(team_id):
		post_hits[team_id] += 1

func record_powerup(team_id: int) -> void:
	if powerups.has(team_id):
		powerups[team_id] += 1

func record_jump(team_id: int) -> void:
	if jumps.has(team_id):
		jumps[team_id] += 1

func record_tackle(team_id: int) -> void:
	if tackles.has(team_id):
		tackles[team_id] += 1

func record_speed(speed: float) -> void:
	if speed > max_ball_speed_ms:
		max_ball_speed_ms = speed

func update_possession(delta: float, team_id: int) -> void:
	if possession_seconds.has(team_id):
		possession_seconds[team_id] += delta

func get_possession_percent(team_id: int) -> float:
	var total = possession_seconds[1] + possession_seconds[2]
	if total <= 0.01:
		return 50.0
	return clampf((possession_seconds.get(team_id, 0.0) / total) * 100.0, 0.0, 100.0)

func get_max_speed_kmh() -> float:
	return max_ball_speed_ms * 3.6
