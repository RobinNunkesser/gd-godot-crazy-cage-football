class_name MultiplayerInputManager
extends Node

const PlayerInputSlot = preload("res://addons/multiplayer_input/player_slot.gd")

signal joypad_connected(device_id: int, device_name: String)
signal joypad_disconnected(device_id: int)
signal slot_assigned(slot_index: int, device_type: PlayerInputSlot.DeviceType, device_id: int)

const MAX_SLOTS: int = 4

var slots: Array[PlayerInputSlot] = []

func _init() -> void:
	_init_slots()

func _ready() -> void:
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)
	auto_assign_slots()

func _init_slots() -> void:
	slots.clear()
	for i in range(MAX_SLOTS):
		slots.append(PlayerInputSlot.new(i, PlayerInputSlot.DeviceType.NONE, -1))

## Weist den Slots automatisch Controller und Tastatur-Schemata zu.
## Optional kann eine Liste von Joypad-IDs übergeben werden (z. B. für Unit-Tests: [] für 0 Controller).
func auto_assign_slots(override_pads: Variant = null) -> void:
	var connected_pads: Array = override_pads if override_pads != null else Input.get_connected_joypads()
	var pad_idx = 0
	var kb_idx = 0
	
	for i in range(MAX_SLOTS):
		if pad_idx < connected_pads.size():
			var pad_id = connected_pads[pad_idx]
			slots[i].device_type = PlayerInputSlot.DeviceType.JOYPAD
			slots[i].joypad_id = pad_id
			pad_idx += 1
		else:
			# Tastatur-Fallback für verbleibende Slots (beginnend mit WASD)
			match kb_idx:
				0:
					slots[i].device_type = PlayerInputSlot.DeviceType.KEYBOARD_WASD
					slots[i].joypad_id = -1
				1:
					slots[i].device_type = PlayerInputSlot.DeviceType.KEYBOARD_ARROWS
					slots[i].joypad_id = -1
				2:
					slots[i].device_type = PlayerInputSlot.DeviceType.KEYBOARD_IJKL
					slots[i].joypad_id = -1
				_:
					slots[i].device_type = PlayerInputSlot.DeviceType.NONE
					slots[i].joypad_id = -1
			kb_idx += 1
					
		slot_assigned.emit(i, slots[i].device_type, slots[i].joypad_id)

func assign_joypad(slot_index: int, joy_id: int) -> void:
	if slot_index >= 0 and slot_index < slots.size():
		slots[slot_index].device_type = PlayerInputSlot.DeviceType.JOYPAD
		slots[slot_index].joypad_id = joy_id
		slot_assigned.emit(slot_index, PlayerInputSlot.DeviceType.JOYPAD, joy_id)

func assign_keyboard(slot_index: int, kb_scheme: PlayerInputSlot.DeviceType) -> void:
	if slot_index >= 0 and slot_index < slots.size():
		slots[slot_index].device_type = kb_scheme
		slots[slot_index].joypad_id = -1
		slot_assigned.emit(slot_index, kb_scheme, -1)

func get_slot(slot_index: int) -> PlayerInputSlot:
	if slot_index >= 0 and slot_index < slots.size():
		return slots[slot_index]
	return null

## Shorthand-Methoden für Spieler-Abfragen
func get_move_vector(player_index: int) -> Vector2:
	var slot = get_slot(player_index)
	return slot.get_move_vector() if slot else Vector2.ZERO

func is_action_pressed(player_index: int, action: String) -> bool:
	var slot = get_slot(player_index)
	return slot.is_action_pressed(action) if slot else false

func is_action_just_pressed(player_index: int, action: String) -> bool:
	var slot = get_slot(player_index)
	return slot.is_action_just_pressed(action) if slot else false

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		var pad_name = Input.get_joy_name(device)
		joypad_connected.emit(device, pad_name)
	else:
		joypad_disconnected.emit(device)
	auto_assign_slots()
