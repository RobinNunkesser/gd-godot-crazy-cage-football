class_name CageConfig
extends RefCounted

## Isolierte Parameter für Crazy Cage Football (Godot 4 3D)
## Erlaubt einfaches Feintuning gemäß Phase 2 des Intent-Engineerings

# Käfig-Dimensionen (Rechteckig geschlossen)
const CAGE_WIDTH_X: float = 24.0  # Spielfeldlänge Tor zu Tor
const CAGE_DEPTH_Z: float = 14.0  # Spielfeldbreite
const CAGE_HEIGHT_Y: float = 7.0  # Käfighöhe (Decke)
const WALL_THICKNESS: float = 0.4
const BOARD_HEIGHT: float = 1.0   # Feste Unterbande

# Tore
const GOAL_WIDTH: float = 4.0
const GOAL_HEIGHT: float = 2.2
const GOAL_DEPTH: float = 1.8

# Zıppır Spieler-Kugel
const PLAYER_RADIUS: float = 0.6
const PLAYER_MASS: float = 3.0
const PLAYER_DRIVE_FORCE: float = 40.0
const PLAYER_MAX_SPEED: float = 15.0
const PLAYER_JUMP_IMPULSE: float = 10.5 # Zıplama Sprungimpuls
const PLAYER_BOOST_IMPULSE: float = 18.0
const PLAYER_BOOST_COOLDOWN: float = 2.0
const PLAYER_BOUNCE: float = 0.6
const PLAYER_FRICTION: float = 0.4

# Fußball (Hochelastisch)
const BALL_RADIUS: float = 0.35
const BALL_MASS: float = 0.45
const BALL_BOUNCE: float = 0.82
const BALL_FRICTION: float = 0.25
const BALL_LINEAR_DAMP: float = 0.1
const BALL_ANGULAR_DAMP: float = 0.15

# Match-Regeln & Zeiten
const MATCH_DURATION_SECONDS: float = 180.0 # 3 Minuten
const CELEBRATION_DURATION: float = 2.5
const KICKOFF_DELAY: float = 1.0

# Kamera
const CAMERA_HEIGHT: float = 16.0
const CAMERA_OFFSET_Z: float = 18.0
const CAMERA_LERP_SPEED: float = 4.5
