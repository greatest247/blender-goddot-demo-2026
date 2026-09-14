extends Camera3D
## Free-fly "TFC" style camera for Godot 4.7
## Attach this script directly to a Camera3D node.
##
## Controls (uses the project's Input Map actions):
##   move_forward / move_backwards / move_left / move_right -> move relative to view
##   move_up / move_down -> move in world space
##   move_fast      -> sprint (hold)
##   Mouse          -> look around
##   Esc            -> release mouse capture
##   Left click     -> re-capture mouse

@export var move_speed: float = 8.0
@export var sprint_multiplier: float = 2.0
@export var mouse_sensitivity: float = 0.15   # degrees per pixel
@export var keyboard_look_speed: float = 90.0 # degrees/sec, for arrow-key look
@export var min_pitch: float = -89.0
@export var max_pitch: float = 89.0

var _yaw: float = 0.0
var _pitch: float = 0.0

# We track action states ourselves instead of trusting Input directly.
# Reason: holding Ctrl and pressing W (Ctrl+W) is intercepted as a shortcut
# by the OS/window manager on some platforms, which can eat the key-up
# event for W. That leaves Input's internal state (and is_action_pressed)
# thinking W is still held, so the camera keeps "walking" forever.
# Tracking our own dict + clearing it on focus loss avoids that.
var _actions_down: Dictionary = {}

const TRACKED_ACTIONS := [
	"move_forward", "move_backwards", "move_left", "move_right", "move_up", "move_down", "move_fast",
	"ui_left", "ui_right", "ui_up", "ui_down",
]

# Used to auto-create any of these actions that are missing from the
# project's Input Map, so the camera still works out of the box.
const DEFAULT_ACTION_KEYS := {
	"move_forward": KEY_W,
	"move_backwards": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"move_up": KEY_SPACE,
	"move_down": KEY_CTRL,
	"move_fast": KEY_SHIFT,
}


func _ensure_default_action(action: String, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action, key_event)


func _ready() -> void:
	for action in DEFAULT_ACTION_KEYS:
		_ensure_default_action(action, DEFAULT_ACTION_KEYS[action])

	# Initialize yaw/pitch from the camera's current rotation so it doesn't
	# snap when the script starts.
	_yaw = rotation_degrees.y
	_pitch = rotation_degrees.x
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	# If the window/app loses focus (e.g. Alt-Tab, or a shortcut like
	# Ctrl+W stealing focus), any keys currently marked "down" may never
	# get a matching key-up event. Force-clear them so movement stops.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_actions_down.clear()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clamp(_pitch, min_pitch, max_pitch)
		rotation_degrees = Vector3(_pitch, _yaw, 0.0)

	for action in TRACKED_ACTIONS:
		if InputMap.has_action(action) and event.is_action(action):
			_actions_down[action] = event.is_pressed()

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# Releasing focus/mouse is a common moment for stuck keys too.
		_actions_down.clear()

	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _is_action_down(action: String) -> bool:
	return _actions_down.get(action, false)


func _process(delta: float) -> void:
	# Arrow keys let the player look around without a mouse.
	var look_step := keyboard_look_speed * delta
	if _is_action_down("ui_left"):
		_yaw += look_step
	if _is_action_down("ui_right"):
		_yaw -= look_step
	if _is_action_down("ui_up"):
		_pitch += look_step
	if _is_action_down("ui_down"):
		_pitch -= look_step
	_pitch = clamp(_pitch, min_pitch, max_pitch)
	rotation_degrees = Vector3(_pitch, _yaw, 0.0)

	var input_dir := Vector3.ZERO

	# Forward/back/strafe relative to camera's current facing.
	if _is_action_down("move_forward"):
		input_dir -= transform.basis.z
	if _is_action_down("move_backwards"):
		input_dir += transform.basis.z
	if _is_action_down("move_left"):
		input_dir -= transform.basis.x
	if _is_action_down("move_right"):
		input_dir += transform.basis.x

	# Vertical movement in world space (not tied to look pitch).
	if _is_action_down("move_up"):
		input_dir += Vector3.UP
	if _is_action_down("move_down"):
		input_dir -= Vector3.UP

	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()

	var speed := move_speed
	if _is_action_down("move_fast"):
		speed *= sprint_multiplier

	position += input_dir * speed * delta
