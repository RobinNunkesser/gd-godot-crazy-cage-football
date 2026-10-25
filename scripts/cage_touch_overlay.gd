extends CanvasLayer
class_name CageTouchOverlay

## CageTouchOverlay: Ergonomisches On-Screen Arcade-Touch-Overlay für Tablets & Web
## Bietet einen dynamischen virtuellen Analogstick (links), Jump- & Boost-Buttons (rechts)
## sowie Quick-Access Tasten (Pause & Kamera-Fokus) für Touchscreens.

signal pause_requested
signal camera_focus_requested

@export var force_visible: bool = false:
	set(val):
		force_visible = val
		if val:
			is_touch_active = true
		else:
			_detect_touch_device()
		_update_visibility()
@export var joystick_radius: float = 70.0
@export var deadzone: float = 0.15

var is_touch_active: bool = false
var is_gameplay_active: bool = false

# Touch-Tracking IDs (-1 = inaktiv)
var _joystick_touch_id: int = -1
var _jump_touch_id: int = -1
var _boost_touch_id: int = -1

# Positionen & Vektoren
var _joystick_center: Vector2 = Vector2.ZERO
var _joystick_default_pos: Vector2 = Vector2(140.0, 580.0)
var _input_vector: Vector2 = Vector2.ZERO

# UI Nodes
var root_control: Control
var joystick_base: Panel
var joystick_knob: Panel
var jump_btn: Button
var boost_btn: Button
var pause_btn: Button
var cam_btn: Button

func _ready() -> void:
	layer = 15
	_detect_touch_device()
	if not is_instance_valid(root_control):
		_build_ui()
	_update_visibility()
	var vp = get_viewport()
	if vp and not vp.size_changed.is_connected(_on_viewport_resized):
		vp.size_changed.connect(_on_viewport_resized)

func _on_pause_pressed() -> void:
	pause_requested.emit()

func _on_cam_pressed() -> void:
	camera_focus_requested.emit()

func _get_viewport_size() -> Vector2:
	var vp = get_viewport()
	if vp:
		return vp.get_visible_rect().size
	return Vector2(1280.0, 720.0)

func _detect_touch_device() -> void:
	if force_visible:
		is_touch_active = true
		return
	
	# 1. Native Mobile (Android / iOS)
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		is_touch_active = true
		return
	
	# 2. Web Export (WASM im Browser)
	if OS.has_feature("web"):
		if OS.has_feature("web_android") or OS.has_feature("web_ios"):
			is_touch_active = true
			return
		# In Browsern prüfen, ob ein echter Touchscreen vorhanden ist (z. B. iPadOS)
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			var touch_points = js.eval("('maxTouchPoints' in navigator) ? navigator.maxTouchPoints : 0")
			if touch_points != null and int(touch_points) > 0:
				is_touch_active = true
				return
		# Desktop Browser (Mac, Windows, Linux) ohne Touchscreen -> aus
		is_touch_active = false
		return

	# 3. Desktop Native -> standardmäßig aus
	is_touch_active = false

func toggle_touch_overlay() -> bool:
	is_touch_active = !is_touch_active
	_update_visibility()
	return is_touch_active

func set_gameplay_active(active: bool) -> void:
	is_gameplay_active = active
	_reset_joystick()
	_update_visibility()

func _update_visibility() -> void:
	if not is_instance_valid(root_control):
		return
	# Root ist aktiv, wenn Touchscreen erkannt wurde oder forciert ist
	root_control.visible = is_touch_active
	
	# Joystick & Action-Buttons sind nur während des Matches aktiv (nicht in Lobby / Pausenmenü)
	var match_active = is_touch_active and is_gameplay_active
	if is_instance_valid(joystick_base):
		joystick_base.visible = match_active
	if is_instance_valid(jump_btn):
		jump_btn.visible = match_active
	if is_instance_valid(boost_btn):
		boost_btn.visible = match_active
	if is_instance_valid(pause_btn):
		pause_btn.visible = match_active
	if is_instance_valid(cam_btn):
		cam_btn.visible = match_active

func _build_ui() -> void:
	root_control = Control.new()
	root_control.name = "TouchOverlayRoot"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	var vp_size = _get_viewport_size()
	_joystick_default_pos = Vector2(130.0, maxf(vp_size.y - 130.0, 200.0))
	_joystick_center = _joystick_default_pos

	# --- 1. Virtueller Joystick (Links) ---
	joystick_base = Panel.new()
	joystick_base.name = "JoystickBase"
	joystick_base.custom_minimum_size = Vector2(joystick_radius * 2.0, joystick_radius * 2.0)
	joystick_base.size = joystick_base.custom_minimum_size
	joystick_base.position = _joystick_center - Vector2(joystick_radius, joystick_radius)
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var base_style = StyleBoxFlat.new()
	base_style.set_corner_radius_all(int(joystick_radius))
	base_style.bg_color = Color(0.04, 0.08, 0.16, 0.45)
	base_style.border_color = Color(0.0, 0.85, 1.0, 0.6)
	base_style.border_width_left = 3
	base_style.border_width_top = 3
	base_style.border_width_right = 3
	base_style.border_width_bottom = 3
	joystick_base.add_theme_stylebox_override("panel", base_style)
	root_control.add_child(joystick_base)

	joystick_knob = Panel.new()
	joystick_knob.name = "JoystickKnob"
	var knob_rad = 32.0
	joystick_knob.custom_minimum_size = Vector2(knob_rad * 2.0, knob_rad * 2.0)
	joystick_knob.size = joystick_knob.custom_minimum_size
	joystick_knob.position = Vector2(joystick_radius - knob_rad, joystick_radius - knob_rad)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var knob_style = StyleBoxFlat.new()
	knob_style.set_corner_radius_all(int(knob_rad))
	knob_style.bg_color = Color(0.0, 0.88, 1.0, 0.8)
	knob_style.border_color = Color(1.0, 1.0, 1.0, 0.9)
	knob_style.border_width_left = 2
	knob_style.border_width_top = 2
	knob_style.border_width_right = 2
	knob_style.border_width_bottom = 2
	joystick_knob.add_theme_stylebox_override("panel", knob_style)
	joystick_base.add_child(joystick_knob)

	# --- 2. Action Buttons (Rechts) ---
	jump_btn = _create_action_button("JUMP", Color(1.0, 0.88, 0.25, 0.85), Color(0.2, 0.15, 0.02, 0.7), 46.0)
	jump_btn.name = "TouchJumpBtn"
	root_control.add_child(jump_btn)

	boost_btn = _create_action_button("BOOST", Color(1.0, 0.2, 0.6, 0.85), Color(0.2, 0.02, 0.12, 0.7), 40.0)
	boost_btn.name = "TouchBoostBtn"
	root_control.add_child(boost_btn)

	# --- 3. Top Quick-Access Buttons ---
	pause_btn = Button.new()
	pause_btn.name = "TouchPauseBtn"
	pause_btn.text = "||"
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var p_style = StyleBoxFlat.new()
	p_style.set_corner_radius_all(14)
	p_style.bg_color = Color(0.08, 0.12, 0.2, 0.7)
	p_style.border_color = Color(0.4, 0.6, 0.9, 0.8)
	p_style.border_width_left = 2
	p_style.border_width_top = 2
	p_style.border_width_right = 2
	p_style.border_width_bottom = 2
	pause_btn.add_theme_stylebox_override("normal", p_style)
	pause_btn.add_theme_stylebox_override("pressed", p_style)
	pause_btn.add_theme_font_size_override("font_size", 20)
	pause_btn.pressed.connect(_on_pause_pressed)
	root_control.add_child(pause_btn)

	cam_btn = Button.new()
	cam_btn.name = "TouchCamBtn"
	cam_btn.text = "CAM"
	cam_btn.focus_mode = Control.FOCUS_NONE
	cam_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	cam_btn.add_theme_stylebox_override("normal", p_style)
	cam_btn.add_theme_stylebox_override("pressed", p_style)
	cam_btn.add_theme_font_size_override("font_size", 20)
	cam_btn.pressed.connect(_on_cam_pressed)
	root_control.add_child(cam_btn)

	_layout_buttons(vp_size)

func _create_action_button(label: String, border_col: Color, bg_col: Color, radius: float) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE # Eingaben werden über _unhandled_input mit Multi-Touch verarbeitet
	btn.custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	btn.size = btn.custom_minimum_size
	
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(int(radius))
	style.bg_color = bg_col
	style.border_color = border_col
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 14)
	return btn

func _layout_buttons(vp_size: Vector2) -> void:
	_joystick_default_pos = Vector2(130.0, maxf(vp_size.y - 130.0, 200.0))
	if _joystick_touch_id == -1:
		_joystick_center = _joystick_default_pos
		if is_instance_valid(joystick_base):
			joystick_base.position = _joystick_center - Vector2(joystick_radius, joystick_radius)

	# Jump Button rechts unten (gut mit rechtem Daumen erreichbar)
	if is_instance_valid(jump_btn):
		jump_btn.position = Vector2(vp_size.x - 125.0, vp_size.y - 130.0)
	
	# Boost Button leicht versetzt links/oberhalb vom Jump Button
	if is_instance_valid(boost_btn):
		boost_btn.position = Vector2(vp_size.x - 225.0, vp_size.y - 95.0)

	# Quick Buttons oben rechts
	if is_instance_valid(pause_btn):
		pause_btn.size = Vector2(50.0, 44.0)
		pause_btn.position = Vector2(vp_size.x - 65.0, 16.0)

	if is_instance_valid(cam_btn):
		cam_btn.size = Vector2(50.0, 44.0)
		cam_btn.position = Vector2(vp_size.x - 125.0, 16.0)

func _on_viewport_resized() -> void:
	_layout_buttons(_get_viewport_size())

func _unhandled_input(event: InputEvent) -> void:
	# Falls auf Desktop mit Touchscreen erstmals getoucht wird: Touch-Overlay dynamisch einblenden
	if not is_touch_active:
		if event is InputEventScreenTouch and event.pressed:
			is_touch_active = true
			_update_visibility()
		else:
			return

	if not is_gameplay_active:
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_handle_touch_down(touch.index, touch.position)
		else:
			_handle_touch_up(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_handle_touch_drag(drag.index, drag.position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_handle_touch_down(999, mb.position)
			else:
				_handle_touch_up(999)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_handle_touch_drag(999, mm.position)

func _handle_touch_down(index: int, pos: Vector2) -> void:
	var vp_size = _get_viewport_size()
	
	# 1. Jump Button Hit-Test
	if is_instance_valid(jump_btn) and jump_btn.get_global_rect().has_point(pos):
		_jump_touch_id = index
		Input.action_press("p1_jump")
		_pulse_button(jump_btn, true)
		return
	
	# 2. Boost Button Hit-Test
	if is_instance_valid(boost_btn) and boost_btn.get_global_rect().has_point(pos):
		_boost_touch_id = index
		Input.action_press("p1_boost")
		_pulse_button(boost_btn, true)
		return

	# 3. Joystick: Beliebiger Touch in der linken Bildschirmhälfte
	if pos.x < vp_size.x * 0.5 and _joystick_touch_id == -1:
		_joystick_touch_id = index
		_joystick_center = pos
		joystick_base.position = _joystick_center - Vector2(joystick_radius, joystick_radius)
		_update_joystick(pos)

func _handle_touch_drag(index: int, pos: Vector2) -> void:
	if index == _joystick_touch_id:
		_update_joystick(pos)

func _handle_touch_up(index: int) -> void:
	if index == _joystick_touch_id:
		_joystick_touch_id = -1
		_reset_joystick()
	elif index == _jump_touch_id:
		_jump_touch_id = -1
		Input.action_release("p1_jump")
		_pulse_button(jump_btn, false)
	elif index == _boost_touch_id:
		_boost_touch_id = -1
		Input.action_release("p1_boost")
		_pulse_button(boost_btn, false)

func _update_joystick(pos: Vector2) -> void:
	var diff = pos - _joystick_center
	var dist = diff.length()
	if dist > joystick_radius:
		diff = diff.normalized() * joystick_radius
	
	var knob_rad = 32.0
	joystick_knob.position = (diff + Vector2(joystick_radius, joystick_radius)) - Vector2(knob_rad, knob_rad)
	
	var raw_vec = diff / joystick_radius
	if raw_vec.length() < deadzone:
		_input_vector = Vector2.ZERO
	else:
		_input_vector = raw_vec
	
	_dispatch_action_events(_input_vector)

func _reset_joystick() -> void:
	_input_vector = Vector2.ZERO
	_dispatch_action_events(Vector2.ZERO)
	var knob_rad = 32.0
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(joystick_radius - knob_rad, joystick_radius - knob_rad)
	if is_instance_valid(joystick_base):
		_joystick_center = _joystick_default_pos
		joystick_base.position = _joystick_center - Vector2(joystick_radius, joystick_radius)

func _dispatch_action_events(vec: Vector2) -> void:
	# Horizontale Aktionen
	if vec.x < -deadzone:
		Input.action_press("p1_left", -vec.x)
		Input.action_release("p1_right")
	elif vec.x > deadzone:
		Input.action_press("p1_right", vec.x)
		Input.action_release("p1_left")
	else:
		Input.action_release("p1_left")
		Input.action_release("p1_right")

	# Vertikale Aktionen (Y negativ = oben, Y positiv = unten in 2D)
	if vec.y < -deadzone:
		Input.action_press("p1_up", -vec.y)
		Input.action_release("p1_down")
	elif vec.y > deadzone:
		Input.action_press("p1_down", vec.y)
		Input.action_release("p1_up")
	else:
		Input.action_release("p1_up")
		Input.action_release("p1_down")

func _pulse_button(btn: Button, pressed: bool) -> void:
	if not is_instance_valid(btn):
		return
	var target_scale = Vector2(0.9, 0.9) if pressed else Vector2(1.0, 1.0)
	var tween = create_tween()
	tween.tween_property(btn, "scale", target_scale, 0.08).set_trans(Tween.TRANS_QUAD)

func get_input_vector() -> Vector2:
	return _input_vector
