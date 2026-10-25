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
const CELEBRATION_DURATION: float = 2.0
const KICKOFF_DELAY: float = 2.0

# Kamera (Im Käfig platziert mit Übersicht und Distanz zum Spielgeschehen)
const CAMERA_HEIGHT: float = 5.2
const CAMERA_OFFSET_Z: float = 6.0
const CAMERA_LERP_SPEED: float = 5.0

# Power-Up Parameter & Typen (Konsolidiert: 5 Pickups)
enum PowerUpType {
	NONE,
	SUPER_SHOT,    # 1. Super-Shot / Feuerball (Ball brennt, fliegt mit 2x Speed)
	SPEED_BOOTS,   # 2. Speed-Boots (Sprint-Boost für 6 s)
	MAGNET_FOOT,   # 3. Magnetfuß / Klebeball (Ball haftet am Spieler für Dribblings)
	FREEZE_TACKLE, # 4. Freeze-Tackle (Gegenspieler wird 2 s eingefroren)
	CAGE_SHAKER    # 5. Cage-Shaker (Stoßwelle schleudert Gegner von den Banden)
}

static var powerups_enabled: bool = true

const POWERUP_SPAWN_INTERVAL: float = 10.0
const POWERUP_MAX_ACTIVE: int = 3
const POWERUP_RADIUS: float = 0.45
const POWERUP_SPEED_DURATION: float = 6.0
const POWERUP_MAGNET_DURATION: float = 6.0
const POWERUP_FREEZE_DURATION: float = 2.0
const POWERUP_SUPER_SHOT_MULT: float = 2.2


