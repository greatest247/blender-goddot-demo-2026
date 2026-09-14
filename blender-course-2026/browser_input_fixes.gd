extends Node3D
# Drop this on any plain Node3D anywhere in your scene (it doesn't need to be
# a child of the player) to get browser-safe mouse-capture behavior when your
# pointer-locked game is exported to web. No other script needs to know it's
# there — it only touches the global Input.mouse_mode singleton.
#
# What it fixes:
#   1. Accidental tab closing: shows the browser's native "Leave site?"
#      confirmation before the tab actually closes.
#   2. Cursor desync: browsers force-release pointer lock the instant a
#      native browser UI (that confirmation dialog, a tab switch, etc.)
#      appears, but Godot doesn't automatically hear about it, so
#      Input.mouse_mode can get stuck showing MOUSE_MODE_CAPTURED while the
#      OS cursor is actually free. We listen to the browser's own
#      visibility/pointer-lock events directly and force the cursor visible
#      from there — synchronously, since a blocking dialog freezes Godot's
#      render loop and Esc may not even reach the canvas if it lost focus.
#   3. Alt-tab on any platform: releases the mouse when the game window
#      loses OS focus, so switching away doesn't leave the cursor invisibly
#      captured. This part isn't web-specific, but it complements fix #2 and
#      is cheap/harmless everywhere, so it always runs.

func _ready() -> void:
	get_window().focus_exited.connect(_on_window_focus_exited)

	# Everything below this point is web-export only.
	if OS.has_feature("web"):
		_setup_web_hooks()


func _on_window_focus_exited() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _setup_web_hooks() -> void:
	var window := JavaScriptBridge.get_interface("window")
	window.godotForceCursorVisible = JavaScriptBridge.create_callback(_on_web_force_cursor_visible)

	JavaScriptBridge.eval("""
		window.addEventListener('beforeunload', function (e) {
			// Chrome doesn't reliably auto-release pointer lock just because
			// this dialog is about to show, so force it ourselves first.
			if (document.pointerLockElement) {
				document.exitPointerLock();
			}
			var canvas = document.querySelector('canvas');
			if (canvas) { canvas.style.cursor = 'auto'; }
			e.preventDefault();
			e.returnValue = '';
		});
		function godotShowCursorNow() {
			// Set the CSS cursor directly, right here, synchronously.
			// A blocking alert()/confirm()/beforeunload dialog freezes
			// Godot's own render loop, so waiting for Godot to redraw
			// with the new mouse_mode isn't reliable — this takes effect
			// immediately regardless.
			var canvas = document.querySelector('canvas');
			if (canvas) { canvas.style.cursor = 'auto'; }
			window.godotForceCursorVisible();
		}
		document.addEventListener('visibilitychange', function () {
			if (document.hidden) { godotShowCursorNow(); }
		});
		document.addEventListener('pointerlockchange', function () {
			if (!document.pointerLockElement) { godotShowCursorNow(); }
		});
	""", true)


func _on_web_force_cursor_visible(_args = null) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
