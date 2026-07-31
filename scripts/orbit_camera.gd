extends Node3D

const MobileUtils = preload("res://scripts/platform/mobile_utils.gd")

@export var target_path: NodePath
var target: Node3D
@export var min_distance: float = 1.8
@export var max_distance: float = 4.5
@export var orbit_sensitivity: float = 1.0
@export var zoom_sensitivity: float = 0.15
@export var inertia_decay: float = 8.0
@export var touch_drag_threshold: float = 12.0
@export var look_target_height: float = 0.15

var distance: float = 3.0
## Orientation of the virtual trackball centered on the look target.
var orbit_rotation: Quaternion = Quaternion.IDENTITY

var _dragging: bool = false
var _last_pointer: Vector2 = Vector2.ZERO
var _spin_velocity: Vector3 = Vector3.ZERO
var _touch_positions: Dictionary = {}
var _pinch_start_distance: float = 0.0
var _pinch_start_zoom: float = 3.0
var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_orbit_active: bool = false
var _camera: Camera3D
var _is_mobile: bool = false

const _REST_OFFSET := Vector3(0.0, 0.0, 1.0)


func _ready() -> void:
	_camera = get_node_or_null("Camera3D") as Camera3D
	if _camera == null:
		_camera = Camera3D.new()
		_camera.name = "Camera3D"
		add_child(_camera)

	if target_path != NodePath():
		target = get_node_or_null(target_path) as Node3D

	_is_mobile = MobileUtils.is_mobile()
	if _is_mobile:
		orbit_sensitivity = 1.0
		zoom_sensitivity = 0.2
		touch_drag_threshold = 10.0

	distance = GameState.camera_distance
	orbit_rotation = _legacy_angles_to_quat(GameState.camera_yaw, GameState.camera_pitch)
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
		_apply_pointer_drag(event.position)

	if event is InputEventScreenTouch:
		_handle_screen_touch(event)

	if event is InputEventScreenDrag:
		_handle_screen_drag(event)

	if event is InputEventMagnifyGesture:
		distance = clampf(distance / event.factor, min_distance, max_distance)
		_save_camera_state()


func _begin_drag(screen_pos: Vector2) -> void:
	_dragging = true
	_spin_velocity = Vector3.ZERO
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


func _screen_to_trackball(screen_pos: Vector2) -> Vector3:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector3.FORWARD

	var x: float = (screen_pos.x / viewport_size.x) * 2.0 - 1.0
	var y: float = 1.0 - (screen_pos.y / viewport_size.y) * 2.0
	var aspect: float = viewport_size.x / viewport_size.y
	if aspect > 1.0:
		x *= aspect
	else:
		y /= aspect

	var point := Vector2(x, y)
	var length_squared: float = point.length_squared()
	if length_squared <= 1.0:
		return Vector3(point.x, point.y, sqrt(1.0 - length_squared))
	return Vector3(point.x, point.y, 0.0).normalized()


func _apply_pointer_drag(screen_pos: Vector2) -> void:
	var from_point: Vector3 = _screen_to_trackball(_last_pointer)
	var to_point: Vector3 = _screen_to_trackball(screen_pos)
	_apply_trackball_rotation(from_point, to_point)
	_last_pointer = screen_pos


func _apply_trackball_rotation(from_point: Vector3, to_point: Vector3) -> void:
	var axis: Vector3 = from_point.cross(to_point)
	if axis.length_squared() < 0.00001:
		return

	axis = axis.normalized()
	var angle: float = from_point.angle_to(to_point) * orbit_sensitivity
	var delta_rotation := Quaternion(axis, angle)

	# Screen-space arcball: rotate the ball under the pointer (left multiply).
	orbit_rotation = (delta_rotation * orbit_rotation).normalized()
	_spin_velocity = axis * angle


func _apply_zoom(amount: float) -> void:
	distance = clampf(distance + amount, min_distance, max_distance)
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
	distance = clampf(_pinch_start_zoom * ratio, min_distance, max_distance)


func _process(delta: float) -> void:
	_handle_keyboard(delta)

	if not _dragging and _touch_positions.size() < 2 and _spin_velocity.length_squared() > 0.00001:
		var angle: float = _spin_velocity.length() * delta
		if angle > 0.00001:
			var axis: Vector3 = _spin_velocity.normalized()
			var delta_rotation := Quaternion(axis, angle)
			orbit_rotation = (delta_rotation * orbit_rotation).normalized()
		_spin_velocity = _spin_velocity.lerp(Vector3.ZERO, inertia_decay * delta)

	_update_camera()


func _handle_keyboard(delta: float) -> void:
	var rotate_speed: float = 1.6 * delta
	if Input.is_action_pressed("orbit_left"):
		_rotate_trackball_axis(Vector3.UP, rotate_speed)
	if Input.is_action_pressed("orbit_right"):
		_rotate_trackball_axis(Vector3.UP, -rotate_speed)
	if Input.is_action_pressed("zoom_in"):
		_apply_zoom(-zoom_sensitivity * 2.0)
	if Input.is_action_pressed("zoom_out"):
		_apply_zoom(zoom_sensitivity * 2.0)


func _rotate_trackball_axis(axis: Vector3, angle: float) -> void:
	if axis.length_squared() < 0.00001:
		return
	var delta_rotation := Quaternion(axis.normalized(), angle)
	orbit_rotation = (delta_rotation * orbit_rotation).normalized()


func _get_look_target() -> Vector3:
	var target_pos := Vector3.ZERO
	if target:
		target_pos = target.global_position
	return target_pos + Vector3(0.0, look_target_height, 0.0)


func _update_camera() -> void:
	var look_target := _get_look_target()

	# Rig sits on the ball center; camera orbits on its surface in local +Z.
	global_position = look_target
	quaternion = orbit_rotation
	if _camera:
		_camera.position = _REST_OFFSET * distance
		_camera.rotation = Vector3.ZERO


func _legacy_angles_to_quat(yaw_deg: float, pitch_deg: float) -> Quaternion:
	var yaw_rad: float = deg_to_rad(yaw_deg)
	var pitch_rad: float = deg_to_rad(pitch_deg)
	var direction := Vector3(
		cos(pitch_rad) * sin(yaw_rad),
		sin(-pitch_rad),
		cos(pitch_rad) * cos(yaw_rad)
	).normalized()
	if direction.length_squared() < 0.0001:
		direction = _REST_OFFSET
	return _quaternion_from_to(_REST_OFFSET, direction)


func _quaternion_from_to(from_dir: Vector3, to_dir: Vector3) -> Quaternion:
	var start: Vector3 = from_dir.normalized()
	var dest: Vector3 = to_dir.normalized()
	var cos_theta: float = start.dot(dest)
	var rotation_axis: Vector3 = start.cross(dest)
	if rotation_axis.length_squared() < 0.0001:
		if cos_theta > 0.0:
			return Quaternion.IDENTITY
		rotation_axis = start.cross(Vector3.RIGHT)
		if rotation_axis.length_squared() < 0.0001:
			rotation_axis = start.cross(Vector3.UP)
	rotation_axis = rotation_axis.normalized()
	var angle: float = acos(clampf(cos_theta, -1.0, 1.0))
	return Quaternion(rotation_axis, angle)


func _quat_to_legacy_angles(quat: Quaternion) -> Vector2:
	var direction: Vector3 = (quat * _REST_OFFSET).normalized()
	var yaw_rad: float = atan2(direction.x, direction.z)
	var pitch_rad: float = asin(clampf(-direction.y, -1.0, 1.0))
	return Vector2(rad_to_deg(yaw_rad), rad_to_deg(pitch_rad))


func _save_camera_state() -> void:
	var angles: Vector2 = _quat_to_legacy_angles(orbit_rotation)
	GameState.camera_yaw = angles.x
	GameState.camera_pitch = angles.y
	GameState.camera_distance = distance
	SaveManager.save_game(GameState.build_save_data())
