class_name BrowserSupport
extends RefCounted
## Small, optional bridge for browser lifecycle and the accessible page toolbar.

var game: DeadSignalGame
var shell: JavaScriptObject
var pause_callback: JavaScriptObject

func _init(owner_game: DeadSignalGame) -> void:
	game = owner_game
	shell = JavaScriptBridge.get_interface("deadSignal")
	if shell == null:
		return
	pause_callback = JavaScriptBridge.create_callback(_pause)
	shell.registerPause(pause_callback)
	shell.setPersistent(OS.is_userfs_persistent())

func state_changed(state: String) -> void:
	if shell != null:
		shell.setState(state)

func _pause(_args: Array) -> void:
	game.call_deferred("_focus_lost")
