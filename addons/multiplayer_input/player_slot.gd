class_name PlayerInputSlot
extends RefCounted

enum DeviceType {
	NONE,
	KEYBOARD_WASD,
	KEYBOARD_ARROWS,
	KEYBOARD_IJKL,
	JOYPAD
}

var slot_index: int = 0
var device_type: DeviceType = DeviceType.NONE
var joypad_id: int = -1
var deadzone: float = 0.2

# Custom mapping overrides (Action -> Array of Keycodes / Joypad Buttons)
var custom_key_bindings: Dictionary = {}

func _init(p_slot: int = 0, p_type: DeviceType = DeviceType.NONE, p_joy_id: int = -1) -> void:
	slot_index = p_slot
	device_type = p_type
	joypad_id = p_joy_id

## Liefert den 2D-Bewegungsvektor (Analog-Stick oder WASD/Pfeile)
func get_move_vector() -> Vector2:
	var vec = Vector2.ZERO
	
	if device_type == DeviceType.JOYPAD and joypad_id >= 0:
		var x = Input.get_joy_axis(joypad_id, JOY_AXIS_LEFT_X)
		var y = Input.get_joy_axis(joypad_id, JOY_AXIS_LEFT_Y)
		
		# Deadzone Filter
		if abs(x) < deadzone:
			x = 0.0
		if abs(y) < deadzone:
			y = 0.0
			
		# D-Pad Fallback falls Analog-Stick in Neutralstellung
		if x == 0.0 and y == 0.0:
			if Input.is_joy_button_pressed(joypad_id, JOY_BUTTON_DPAD_LEFT):
				x -= 1.0
			if Input.is_joy_button_pressed(joypad_id, JOY_BUTTON_DPAD_RIGHT):
				x += 1.0
			if Input.is_joy_button_pressed(joypad_id, JOY_BUTTON_DPAD_UP):
				y -= 1.0
			if Input.is_joy_button_pressed(joypad_id, JOY_BUTTON_DPAD_DOWN):
				y += 1.0
				
		vec = Vector2(x, y)
	elif device_type == DeviceType.KEYBOARD_WASD:
		var x = 0.0
		var y = 0.0
		if Input.is_key_pressed(KEY_A): x -= 1.0
		if Input.is_key_pressed(KEY_D): x += 1.0
		if Input.is_key_pressed(KEY_W): y -= 1.0
		if Input.is_key_pressed(KEY_S): y += 1.0
		vec = Vector2(x, y)
	elif device_type == DeviceType.KEYBOARD_ARROWS:
		var x = 0.0
		var y = 0.0
		if Input.is_key_pressed(KEY_LEFT): x -= 1.0
		if Input.is_key_pressed(KEY_RIGHT): x += 1.0
		if Input.is_key_pressed(KEY_UP): y -= 1.0
		if Input.is_key_pressed(KEY_DOWN): y += 1.0
		vec = Vector2(x, y)
	elif device_type == DeviceType.KEYBOARD_IJKL:
		var x = 0.0
		var y = 0.0
		if Input.is_key_pressed(KEY_J): x -= 1.0
		if Input.is_key_pressed(KEY_L): x += 1.0
		if Input.is_key_pressed(KEY_I): y -= 1.0
		if Input.is_key_pressed(KEY_K): y += 1.0
		vec = Vector2(x, y)
		
	if vec.length_squared() > 1.0:
		vec = vec.normalized()
	return vec

## Prüft standardisierte Aktionen ("primary", "secondary", "tertiary", "start")
func is_action_pressed(action_name: String) -> bool:
	return _check_action(action_name, 0)

func is_action_just_pressed(action_name: String) -> bool:
	return _check_action(action_name, 1)

func is_action_just_released(action_name: String) -> bool:
	return _check_action(action_name, 2)

func _check_action(action: String, mode: int) -> bool:
	var act = action.to_lower()
	
	if device_type == DeviceType.JOYPAD and joypad_id >= 0:
		var btn = -1
		match act:
			"primary", "jump", "fire", "gas", "select":
				btn = JOY_BUTTON_A
			"secondary", "special", "nitro", "bomb", "back", "boost":
				btn = JOY_BUTTON_B
			"tertiary", "brake", "dash":
				btn = JOY_BUTTON_X
			"start", "pause":
				btn = JOY_BUTTON_START
				
		if btn != -1:
			match mode:
				0: return Input.is_joy_button_pressed(joypad_id, btn)
				1: return Input.is_joy_button_pressed(joypad_id, btn) # Polling fallback
				2: return not Input.is_joy_button_pressed(joypad_id, btn)
				
	elif device_type == DeviceType.KEYBOARD_WASD:
		var key = KEY_NONE
		match act:
			"primary", "jump", "fire", "gas", "select":
				key = KEY_SPACE
			"secondary", "special", "nitro", "bomb", "boost":
				key = KEY_SHIFT
			"tertiary", "brake", "dash":
				key = KEY_Q
			"start", "pause":
				key = KEY_ESCAPE
		if key != KEY_NONE:
			match mode:
				0: return Input.is_key_pressed(key) or (act in ["secondary", "special", "nitro", "bomb", "boost"] and Input.is_key_pressed(KEY_E))
				1: return Input.is_physical_key_pressed(key) or (act in ["secondary", "special", "nitro", "bomb", "boost"] and Input.is_physical_key_pressed(KEY_E))
				2: return not Input.is_key_pressed(key)
				
	elif device_type == DeviceType.KEYBOARD_ARROWS:
		var key = KEY_NONE
		match act:
			"primary", "jump", "fire", "gas", "select":
				key = KEY_ENTER
			"secondary", "special", "nitro", "bomb", "boost":
				key = KEY_SHIFT
			"tertiary", "brake", "dash":
				key = KEY_PERIOD
			"start", "pause":
				key = KEY_ESCAPE
		if key != KEY_NONE:
			match mode:
				0: return Input.is_key_pressed(key) or (act in ["secondary", "special", "nitro", "bomb", "boost"] and (Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_KP_ENTER)))
				1: return Input.is_physical_key_pressed(key) or (act in ["secondary", "special", "nitro", "bomb", "boost"] and (Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_KP_ENTER)))
				2: return not Input.is_key_pressed(key)
				
	elif device_type == DeviceType.KEYBOARD_IJKL:
		var key = KEY_NONE
		match act:
			"primary", "jump", "fire", "gas", "select":
				key = KEY_U
			"secondary", "special", "nitro", "bomb", "boost":
				key = KEY_O
			"tertiary", "brake", "dash":
				key = KEY_H
			"start", "pause":
				key = KEY_ESCAPE
		if key != KEY_NONE:
			match mode:
				0: return Input.is_key_pressed(key)
				1: return Input.is_physical_key_pressed(key)
				2: return not Input.is_key_pressed(key)
				
	return false

