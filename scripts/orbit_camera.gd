extends Node3D

const MobileUtils = preload("res://scripts/platform/mobile_utils.gd")

## Spherical orbit around a target on a bounding sphere.
## Yaw spins around world up; pitch is elevation from the horizon (0°) to
## nearly top-down (89°). look_at(..., UP) guarantees no roll.

@export var target_path: NodePath
var target: Node3D
@export var min_distance: float = 1.0
@export var max_distance: float = 15.0
@export var orbit_sensitivity: float = 1.0
@export var pan_sensitivity: float = 1.0
@export var zoom_sensitivity: float = 0.15
@export var inertia_decay: float = 8.0
@export var touch_drag_threshold: float = 12.0
@export var look_target_height: float = 0.15
@export var min_pitch_deg: float = 0.0
@export var max_pitch_deg: float = 89.0

signal distance_changed(value: float)

var distance: float = 3.0
var orbit_yaw: float = 0.0
var orbit_pitch: float = 30.0
var pan_offset: Vector3 = Vector3.ZERO

var _dragging: bool = false
var _last_pointer: Vector2 = Vector2.ZERO
var _spin_velocity: Vector2 = Vector2.ZERO
var _touch_positions: Dictionary = {}
var _pinch_start_distance: float = 0.0
var _pinch_start_zoom: float = 3.0
var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_orbit_active: bool = false
var _camera: Camera3D
var _is_mobile: bool = false

const _DRAG_DEG_PER_PIXEL := 0.22
const _PAN_WORLD_PER_PIXEL := 0.002


func _ready() -> void:
	_camera = get_node_or_null("Camera3D") as Camera3D
	if _camera == null:
		_camera = Camera3D.new()
		_camera.name = "Camera3D"
		add_child(_camera)
	_camera.position = Vector3.ZERO
	_camera.rotation = Vector3.ZERO

	if target_path != NodePath():
		target = get_node_or_null(target_path) as Node3D

	_is_mobile = MobileUtils.is_mobile()
	if _is_mobile:
		orbit_sensitivity = 1.0
		zoom_sensitivity = 0.2
		touch_drag_threshold = 10.0

	distance = clampf(GameState.camera_distance, min_distance, max_distance)
	orbit_yaw = GameState.camera_yaw
	orbit_pitch = _load_pitch(GameState.camera_pitch)
	_clamp_pitch()
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and _can_orbit():
				_begin_drag(event.position)
			elif not event.pressed:
				_end_drag()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_apply_zoom(-zoom_sensitivity)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_apply_zoom(zoom_sensitivity)

	if event is InputEventMouseMotion and _dragging and _can_orbit():
		_apply_pointer_drag(event.position, event.shift_pressed)

	if event is InputEventPanGesture and _can_orbit():
		_handle_pan_gesture(event)

	if event is InputEventScreenTouch:
		_handle_screen_touch(event)

	if event is InputEventScreenDrag:
		_handle_screen_drag(event)

	if event is InputEventMagnifyGesture:
		distance = clampf(distance / event.factor, min_distance, max_distance)
		_save_camera_state()


func _begin_drag(screen_pos: Vector2) -> void:
	_dragging = true
	_spin_velocity = Vector2.ZERO
	_last_pointer = screen_pos


func _end_drag() -> void:
	_dragging = false
	_save_camera_state()


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touch_positions[event.index] = event.position
		if event.index == 0:
			_touch_start_pos = event.position
			_touch_orbit_active = false
		if _touch_positions.size() == 2:
			_pinch_start_distance = _get_pinch_distance()
			_pinch_start_zoom = distance
			_dragging = false
			_touch_orbit_active = false
	else:
		_touch_positions.erase(event.index)
		if _touch_positions.is_empty():
			_end_drag()
			_touch_orbit_active = false
		elif _touch_positions.size() == 1:
			var remaining_index: int = _touch_positions.keys()[0]
			_touch_start_pos = _touch_positions[remaining_index]
			_touch_orbit_active = false


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	_touch_positions[event.index] = event.position

	if _touch_positions.size() >= 2:
		_apply_pinch_zoom()
		return

	if event.index != 0 or not _can_orbit():
		return

	if not _touch_orbit_active:
		if _touch_start_pos.distance_to(event.position) < touch_drag_threshold:
			return
		_touch_orbit_active = true
		_begin_drag(event.position)
		return

	_apply_pointer_drag(event.position)


func _can_orbit() -> bool:
	return GameState.tool_mode == 0


func _screen_delta_to_orbit(screen_delta: Vector2) -> Vector2:
	var scale: float = _DRAG_DEG_PER_PIXEL * orbit_sensitivity
	return Vector2(screen_delta.x * scale, screen_delta.y * scale)


func _apply_pointer_drag(screen_pos: Vector2, shift_pressed: bool = false) -> void:
	var screen_delta: Vector2 = screen_pos - _last_pointer
	if _is_pan_mode(shift_pressed):
		_apply_pan_delta(screen_delta)
	else:
		var orbit_delta: Vector2 = _screen_delta_to_orbit(screen_delta)
		_apply_orbit_delta(orbit_delta)
		_spin_velocity = orbit_delta * 28.0
	_last_pointer = screen_pos


func _handle_pan_gesture(event: InputEventPanGesture) -> void:
	if _is_pan_mode(event.shift_pressed):
		_apply_pan_delta(event.delta)
	else:
		var orbit_delta: Vector2 = _screen_delta_to_orbit(event.delta)
		_apply_orbit_delta(orbit_delta)
		_spin_velocity = Vector2.ZERO
	get_viewport().set_input_as_handled()


func _is_pan_mode(shift_pressed: bool = false) -> bool:
	return shift_pressed or Input.is_key_pressed(KEY_SHIFT)


func _apply_pan_delta(screen_delta: Vector2) -> void:
	_spin_velocity = Vector2.ZERO
	var scale: float = _PAN_WORLD_PER_PIXEL * pan_sensitivity * distance
	var offset_dir: Vector3 = _spherical_offset(orbit_yaw, orbit_pitch, 1.0).normalized()
	var right: Vector3 = Vector3.UP.cross(offset_dir)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var cam_up: Vector3 = offset_dir.cross(right).normalized()
	pan_offset -= right * screen_delta.x * scale
	pan_offset += cam_up * screen_delta.y * scale


func _apply_orbit_delta(delta: Vector2) -> void:
	# Grab the near wall of the orbit sphere: drag left → scene spins clockwise.
	orbit_yaw -= delta.x
	orbit_pitch += delta.y
	_clamp_pitch()


func _clamp_pitch() -> void:
	orbit_pitch = clampf(orbit_pitch, min_pitch_deg, max_pitch_deg)


func _apply_zoom(amount: float) -> void:
	var previous: float = distance
	distance = clampf(distance + amount, min_distance, max_distance)
	if not is_equal_approx(previous, distance):
		distance_changed.emit(distance)
	_update_camera()
	_save_camera_state()


func _get_pinch_distance() -> float:
	if _touch_positions.size() < 2:
		return 0.0
	var keys: Array = _touch_positions.keys()
	var a: Vector2 = _touch_positions[keys[0]]
	var b: Vector2 = _touch_positions[keys[1]]
	return a.distance_to(b)


func _apply_pinch_zoom() -> void:
	var current_distance: float = _get_pinch_distance()
	if _pinch_start_distance <= 0.0 or current_distance <= 0.0:
		return
	var ratio: float = _pinch_start_distance / current_distance
	var previous: float = distance
	distance = clampf(_pinch_start_zoom * ratio, min_distance, max_distance)
	if not is_equal_approx(previous, distance):
		distance_changed.emit(distance)


func _process(delta: float) -> void:
	_handle_keyboard(delta)

	if not _dragging and _touch_positions.size() < 2 and _spin_velocity.length_squared() > 0.0001:
		_apply_orbit_delta(_spin_velocity * delta)
		_spin_velocity = _spin_velocity.lerp(Vector2.ZERO, inertia_decay * delta)

	_update_camera()


func _handle_keyboard(delta: float) -> void:
	var rotate_speed: float = 90.0 * delta
	if Input.is_action_pressed("orbit_left"):
		_apply_orbit_delta(Vector2(-rotate_speed, 0.0))
	if Input.is_action_pressed("orbit_right"):
		_apply_orbit_delta(Vector2(rotate_speed, 0.0))
	if Input.is_action_pressed("zoom_in"):
		_apply_zoom(-zoom_sensitivity * 2.0)
	if Input.is_action_pressed("zoom_out"):
		_apply_zoom(zoom_sensitivity * 2.0)


func _get_look_target() -> Vector3:
	var target_pos := Vector3.ZERO
	if target:
		target_pos = target.global_position
	return target_pos + Vector3(0.0, look_target_height, 0.0) + pan_offset


func _spherical_offset(yaw_deg: float, pitch_deg: float, radius: float) -> Vector3:
	var yaw_rad: float = deg_to_rad(yaw_deg)
	var pitch_rad: float = deg_to_rad(pitch_deg)
	return Vector3(
		cos(pitch_rad) * sin(yaw_rad),
		sin(pitch_rad),
		cos(pitch_rad) * cos(yaw_rad)
	) * radius


func _update_camera() -> void:
	if not is_finite(distance):
		distance = clampf(distance, min_distance, max_distance)
		if not is_finite(distance):
			distance = min_distance

	var look_target: Vector3 = _get_look_target()
	var offset: Vector3 = _spherical_offset(orbit_yaw, orbit_pitch, distance)
	if not look_target.is_finite() or not offset.is_finite():
		return
	global_position = look_target + offset
	look_at(look_target, Vector3.UP)


func set_camera_distance(value: float) -> void:
	if not is_finite(value):
		return
	var next_distance: float = clampf(value, min_distance, max_distance)
	if is_equal_approx(distance, next_distance):
		return
	distance = next_distance
	_update_camera()
	_save_camera_state()
	distance_changed.emit(distance)


func get_camera_distance() -> float:
	return distance


func _load_pitch(saved_pitch: float) -> float:
	# Older saves used negative pitch (0 = horizon, negative = above).
	if saved_pitch < 0.0:
		return clampf(-saved_pitch, min_pitch_deg, max_pitch_deg)
	return clampf(saved_pitch, min_pitch_deg, max_pitch_deg)


func _save_camera_state() -> void:
	GameState.camera_yaw = orbit_yaw
	GameState.camera_pitch = orbit_pitch
	GameState.camera_distance = distance
	SaveManager.save_game(GameState.build_save_data())
