@tool
extends EditorPlugin

const AUTOLOAD_NAME = "FasterMath"
const AUTOLOAD_PATH = "res://addons/Faster Math/faster_math.gd"
const DOCK_SCENE = preload("res://addons/Faster Math/dock.tscn")

var dock

func _enter_tree():
	# Add the autoload when the plugin is enabled
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)

	# Add the dock to the editor
	dock = DOCK_SCENE.instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)

	# Pass the math generator reference to the dock
	_setup_dock_with_autoload()

	# Plugin enabled successfully

func _setup_dock_with_autoload():
	if dock and dock.has_method("set_math_generator"):
		# Load the math generator script and create an instance
		var math_gen_script = load(AUTOLOAD_PATH)
		if math_gen_script:
			var math_generator = math_gen_script.new()
			dock.set_math_generator(math_generator)

func _exit_tree():
	# Remove the dock from the editor
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null

	# Remove the autoload when the plugin is disabled
	remove_autoload_singleton(AUTOLOAD_NAME)
	# Plugin disabled