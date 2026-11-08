@tool
extends EditorPlugin

const AUTOLOAD_NAME = "MultiplayerInput"

func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, "res://addons/multiplayer_input/multiplayer_input_manager.gd")

func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)

