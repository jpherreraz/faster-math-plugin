@tool
extends VBoxContainer

# JSON file path
const MATH_FACTS_PATH = "res://addons/Faster Math/math-facts.json"

# Header elements removed for cleaner interface

# UI References - Browse Tab
@onready var browse_tree: Tree = $MainTabs/Browse/BrowseTree
@onready var edit_question_button: Button = $MainTabs/Browse/QuestionDetails/QuestionActions/EditQuestionButton
@onready var delete_question_button: Button = $MainTabs/Browse/QuestionDetails/QuestionActions/DeleteButton

# UI References - Questions Tab
@onready var questions_track_option: OptionButton = $MainTabs/Questions/TrackSelection/TrackOption
@onready var new_op1_input: LineEdit = $MainTabs/Questions/NewQuestionEditor/NewQuestionContainer/NewOp1Input
@onready var new_operator_option: OptionButton = $MainTabs/Questions/NewQuestionEditor/NewQuestionContainer/NewOperatorOption
@onready var new_op2_input: LineEdit = $MainTabs/Questions/NewQuestionEditor/NewQuestionContainer/NewOp2Input
@onready var new_result_input: LineEdit = $MainTabs/Questions/NewQuestionEditor/NewQuestionContainer/NewResultInput
@onready var add_button: Button = $MainTabs/Questions/NewQuestionEditor/NewQuestionContainer/AddButton
@onready var questions_container: VBoxContainer = $MainTabs/Questions/QuestionsList/QuestionsContainer

# UI References - Grades Tab
@onready var grades_list: ItemList = $MainTabs/Grades/GradesList
@onready var grade_name_input: LineEdit = $MainTabs/Grades/GradeEditor/GradeForm/GradeNameInput
@onready var grade_key_input: LineEdit = $MainTabs/Grades/GradeEditor/GradeForm/GradeKeyInput
@onready var save_grade_button: Button = $MainTabs/Grades/GradeEditor/GradeActions/SaveGradeButton
@onready var delete_grade_button: Button = $MainTabs/Grades/GradeEditor/GradeActions/DeleteGradeButton

# New inline grade creation UI references (created dynamically)
var new_grade_name_input: LineEdit
var new_grade_key_input: LineEdit
var create_grade_button: Button

# UI References - Tracks Tab
@onready var tracks_list: ItemList = $MainTabs/Tracks/TracksList
@onready var track_number_input: SpinBox = $MainTabs/Tracks/TrackEditor/TrackForm/TrackNumberInput
@onready var track_title_input: LineEdit = $MainTabs/Tracks/TrackEditor/TrackForm/TrackTitleInput
@onready var track_grade_option: OptionButton = $MainTabs/Tracks/TrackEditor/TrackForm/TrackGradeOption
@onready var save_track_button: Button = $MainTabs/Tracks/TrackEditor/TrackActions/SaveTrackButton
@onready var delete_track_button: Button = $MainTabs/Tracks/TrackEditor/TrackActions/DeleteTrackButton

# New inline track creation UI references (created dynamically)
var new_track_number_input: SpinBox
var new_track_title_input: LineEdit
var new_track_grade_option: OptionButton
var create_track_button: Button

# UI References - Dialogs (keeping confirm dialog only)
@onready var confirm_dialog: ConfirmationDialog = $ConfirmDialog

# Data
var math_facts_data = {}
var current_editing_question = null
var current_editing_track = null
var current_editing_grade = null
var selected_tree_item = null
var file_modified = false
var math_generator = null
# Preview label removed - button text shows count instead

# Custom selection tracking system
var custom_selected_items = {}  # Dictionary mapping TreeItem -> true for selected items
var directly_selected_items = {}  # Dictionary mapping TreeItem -> true for items that were directly clicked (not cascaded)
var selection_highlight_color = Color(0.3, 0.6, 1.0, 0.3)  # Light blue highlight
var default_bg_color = Color.TRANSPARENT

# Range selection tracking
var shift_held_during_click = false
var range_selection_in_progress = false

# Normal click processing flag
var normal_click_in_progress = false

# Debug output control
var debug_output_enabled = true
var original_print_function = null

func _ready():
	_setup_ui()
	_connect_signals()
	_load_math_facts()
	_setup_help_content()

func _debug_print(message: String):
	"""Centralized debug print that can be disabled for performance"""
	# All debug output disabled
	pass

func _disable_all_printing():
	"""Completely disable all print statements"""
	# Override the built-in print function with a no-op
	original_print_function = print
	var no_op = func(args): pass
	# This won't work in GDScript, so we'll use a different approach
	pass

func _restore_printing():
	"""Restore normal print functionality"""
	# Can't actually override print in GDScript
	pass

func _setup_ui():
	# Setup browse tree - single column for items only
	browse_tree.select_mode = Tree.SELECT_MULTI

	# Connect to gui_input to capture mouse events with modifier keys
	browse_tree.gui_input.connect(_on_tree_gui_input)

	# Disable built-in Tree selection highlighting - we'll use our custom highlighting instead
	var tree_theme = Theme.new()
	var tree_stylebox = StyleBoxFlat.new()
	tree_stylebox.bg_color = Color.TRANSPARENT  # Make selection background transparent
	tree_stylebox.border_width_left = 0
	tree_stylebox.border_width_right = 0
	tree_stylebox.border_width_top = 0
	tree_stylebox.border_width_bottom = 0
	tree_theme.set_stylebox("selected", "Tree", tree_stylebox)
	tree_theme.set_stylebox("selected_focus", "Tree", tree_stylebox)
	browse_tree.theme = tree_theme

	# Move the Add button out of the container to position it below the inputs
	var new_question_container = $MainTabs/Questions/NewQuestionEditor/NewQuestionContainer
	var add_button_ref = new_question_container.get_node("AddButton")
	new_question_container.remove_child(add_button_ref)

	# Add the button below the input container
	var new_question_editor = $MainTabs/Questions/NewQuestionEditor
	new_question_editor.add_child(add_button_ref)

	# Position it after the NewQuestionContainer
	var container_index = -1
	for i in range(new_question_editor.get_child_count()):
		if new_question_editor.get_child(i).name == "NewQuestionContainer":
			container_index = i
			break
	if container_index >= 0:
		new_question_editor.move_child(add_button_ref, container_index + 1)

	# Add help text right after the "Add New Question:" header
	var help_label = Label.new()
	help_label.text = "💡 Use ranges like '0-5' to generate multiple questions at once"
	help_label.modulate = Color(0.6, 0.6, 0.6)  # Gray text
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Insert help label as the first child after the header
	new_question_editor.add_child(help_label)
	new_question_editor.move_child(help_label, 1)  # After the header, before the container

	# Get reference to math generator
	math_generator = get_node_or_null("/root/FasterMath")

	# Style the delete button to match other tabs
	delete_question_button.modulate = Color(1, 0.7, 0.7)

	# Add placeholder text to hint about range functionality
	new_op1_input.placeholder_text = "e.g., 5 or 0-10"
	new_op2_input.placeholder_text = "e.g., 3 or 1-5"
	new_result_input.placeholder_text = "e.g., 8 or 0-15"

	# Update button text to indicate it can add multiple questions
	add_button.text = "Add Question(s)"

	# Update the header text to indicate multiple questions are possible
	var new_question_label = $MainTabs/Questions/NewQuestionEditor/NewQuestionLabel
	new_question_label.text = "Add New Question(s):"

	# Initial update of button state
	call_deferred("_update_question_preview")

	# Hide/remove the browse controls (Refresh and Add Track buttons)
	var browse_controls = $MainTabs/Browse/BrowseControls
	if browse_controls:
		browse_controls.visible = false

	# Hide the old header buttons for tracks and grades
	var tracks_header = $MainTabs/Tracks/TracksHeader
	if tracks_header:
		tracks_header.visible = false

	var grades_header = $MainTabs/Grades/GradesHeader
	if grades_header:
		grades_header.visible = false

	# Create inline track creation form
	_create_inline_track_form()

	# Create inline grade creation form
	_create_inline_grade_form()

	# Connect signals for inline creation forms (after they're created)
	if create_track_button:
		create_track_button.pressed.connect(_create_new_track_inline)
	if create_grade_button:
		create_grade_button.pressed.connect(_create_new_grade_inline)

func _connect_signals():
	# Browse Tab
	browse_tree.item_selected.connect(_on_tree_item_selected)
	browse_tree.multi_selected.connect(_on_tree_multi_selected)
	browse_tree.nothing_selected.connect(_on_tree_nothing_selected)
	edit_question_button.pressed.connect(_edit_selected_question)
	delete_question_button.pressed.connect(_delete_selected_question)

	# Questions Tab
	questions_track_option.item_selected.connect(_on_questions_track_selected)
	add_button.pressed.connect(_add_new_question_from_editor)

	# Connect input change signals for range preview
	new_op1_input.text_changed.connect(func(text): _update_question_preview())
	new_op2_input.text_changed.connect(func(text): _update_question_preview())
	new_result_input.text_changed.connect(func(text): _update_question_preview())
	new_operator_option.item_selected.connect(func(index): _update_question_preview())

	# Grades Tab
	grades_list.item_selected.connect(_on_grade_selected)
	save_grade_button.pressed.connect(_save_grade)
	delete_grade_button.pressed.connect(_delete_grade)

	# Tracks Tab
	tracks_list.item_selected.connect(_on_track_selected)
	save_track_button.pressed.connect(_save_track)
	delete_track_button.pressed.connect(_delete_track)

	# Inline creation forms (connected after UI setup)
	# These will be connected in _setup_ui after the forms are created

	# Dialog
	confirm_dialog.confirmed.connect(_confirmed_delete)

func _load_math_facts():
	"""Load math facts from JSON file"""
	var file = FileAccess.open(MATH_FACTS_PATH, FileAccess.READ)
	if not file:
		# Cannot open math-facts.json
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		# Invalid JSON format
		return

	math_facts_data = json.data
	file_modified = false
	_populate_browse_tree()
	_populate_tracks_list()
	_populate_questions_track_options()
	_populate_grades_list()
	_populate_grade_options()
	_populate_questions_track_options()

	# Math facts loaded successfully

func _save_math_facts_file():
	"""Save current math facts data to JSON file"""
	var file = FileAccess.open(MATH_FACTS_PATH, FileAccess.WRITE)
	if not file:
		# Cannot save math-facts.json
		return

	var json_string = JSON.stringify(math_facts_data, "\t")
	file.store_string(json_string)
	file.close()

	file_modified = false
	# Math facts saved to file

	# Refresh the plugin's data
	var math_generator = get_node_or_null("/root/FasterMath")
	if math_generator:
		math_generator._ready()

func _populate_browse_tree():
	"""Fill the browse tree with grades, tracks, and questions"""
	browse_tree.clear()

	if not math_facts_data.has("grades"):
		return

	var root = browse_tree.create_item()
	root.set_text(0, "Math Facts Database (%d questions)" % _count_total_questions())

	# Add grades
	for grade_key in math_facts_data.grades:
		var grade_data = math_facts_data.grades[grade_key]
		var question_count = _count_grade_questions(grade_key)
		var grade_item = browse_tree.create_item(root)
		grade_item.set_text(0, "%s (%d questions)" % [grade_data.name, question_count])
		grade_item.set_metadata(0, {"type": "grade", "key": grade_key})

		# Add tracks
		if grade_data.has("tracks"):
			for track_key in grade_data.tracks:
				var track_data = grade_data.tracks[track_key]
				var track_item = browse_tree.create_item(grade_item)
				var track_number = int(track_key.replace("TRACK", ""))
				track_item.set_text(0, "Track %d: %s (%d questions)" % [track_number, track_data.title, track_data.facts.size()])
				track_item.set_metadata(0, {"type": "track", "grade_key": grade_key, "track_key": track_key})

				# Add questions
				for i in range(track_data.facts.size()):
					var question = track_data.facts[i]
					var question_item = browse_tree.create_item(track_item)
					question_item.set_text(0, question.expression)
					question_item.set_metadata(0, {
						"type": "question",
						"grade_key": grade_key,
						"track_key": track_key,
						"question_index": i,
						"question": question
					})


func _populate_grade_options():
	"""Fill grade option buttons with available grades"""
	# Update track editor grade options
	track_grade_option.clear()

	# Update inline track creation grade options
	if new_track_grade_option:
		new_track_grade_option.clear()

	if not math_facts_data.has("grades"):
		return

	for grade_key in math_facts_data.grades:
		var grade_data = math_facts_data.grades[grade_key]

		# Add to editor
		track_grade_option.add_item(grade_data.name)
		track_grade_option.set_item_metadata(track_grade_option.get_item_count() - 1, grade_key)

		# Add to inline creation form
		if new_track_grade_option:
			new_track_grade_option.add_item(grade_data.name)
			new_track_grade_option.set_item_metadata(new_track_grade_option.get_item_count() - 1, grade_key)

func _populate_questions_track_options():
	"""Fill Questions tab track dropdown with available tracks"""
	questions_track_option.clear()

	if not math_facts_data.has("grades"):
		return

	for grade_key in math_facts_data.grades:
		var grade_data = math_facts_data.grades[grade_key]
		if grade_data.has("tracks"):
			for track_key in grade_data.tracks:
				var track_data = grade_data.tracks[track_key]
				var track_number = int(track_key.replace("TRACK", ""))
				var display_text = "Track %d: %s (%s)" % [track_number, track_data.title, grade_data.name]
				questions_track_option.add_item(display_text)
				questions_track_option.set_item_metadata(questions_track_option.get_item_count() - 1, {
					"grade_key": grade_key,
					"track_key": track_key
				})

	# Auto-select the first track and load its questions
	if questions_track_option.get_item_count() > 0:
		questions_track_option.selected = 0
		var first_track_meta = questions_track_option.get_item_metadata(0)
		if first_track_meta:
			_populate_questions_list(first_track_meta.grade_key, first_track_meta.track_key)

func _populate_tracks_list():
	"""Fill tracks list with all tracks"""
	tracks_list.clear()

	if not math_facts_data.has("grades"):
		return

	for grade_key in math_facts_data.grades:
		var grade_data = math_facts_data.grades[grade_key]
		if grade_data.has("tracks"):
			for track_key in grade_data.tracks:
				var track_data = grade_data.tracks[track_key]
				var track_number = int(track_key.replace("TRACK", ""))
				var display_text = "Track %d: %s (%s) - %d questions" % [
					track_number, track_data.title, grade_data.name, track_data.facts.size()
				]
				tracks_list.add_item(display_text)
				tracks_list.set_item_metadata(tracks_list.get_item_count() - 1, {
					"grade_key": grade_key,
					"track_key": track_key
				})

func _populate_grades_list():
	"""Fill grades list with all grades"""
	grades_list.clear()

	if not math_facts_data.has("grades"):
		return

	for grade_key in math_facts_data.grades:
		var grade_data = math_facts_data.grades[grade_key]
		var track_count = grade_data.tracks.size() if grade_data.has("tracks") else 0
		var question_count = _count_grade_questions(grade_key)
		var display_text = "%s - %d tracks, %d questions" % [grade_data.name, track_count, question_count]
		grades_list.add_item(display_text)
		grades_list.set_item_metadata(grades_list.get_item_count() - 1, grade_key)

func _count_total_questions() -> int:
	var total = 0
	for grade_key in math_facts_data.grades:
		total += _count_grade_questions(grade_key)
	return total

func _count_grade_questions(grade_key: String) -> int:
	var grade_data = math_facts_data.grades[grade_key]
	var count = 0
	if grade_data.has("tracks"):
		for track_key in grade_data.tracks:
			count += grade_data.tracks[track_key].facts.size()
	return count

# Old cascade functions removed - simplified to immediate cascading only

# Old complex cascade functions removed - using simple immediate approach

func _fresh_start_cascade(parent_item: TreeItem):
	"""Fresh start cascading - simplified for performance"""
	if not parent_item or not is_instance_valid(parent_item):
		return

	var cascade_id = Time.get_ticks_msec() % 100000

	set_meta("cascade_direct_parent", parent_item)
	_cleanup_cascade_timers()
	await get_tree().process_frame
	set_meta("cascading", cascade_id)

	if browse_tree.multi_selected.is_connected(_on_tree_multi_selected):
		browse_tree.multi_selected.disconnect(_on_tree_multi_selected)

	_deselect_all_items()

	var timer = Timer.new()
	timer.wait_time = 0.001
	timer.one_shot = true
	timer.name = "CascadeTimer_Continue_%d" % cascade_id
	add_child(timer)
	timer.set_meta("cascade_id", cascade_id)
	timer.set_meta("parent_item", parent_item)
	timer.set_meta("timer_type", "continue")
	timer.timeout.connect(_on_cascade_timer_timeout.bind(timer))
	timer.start()

func _cleanup_cascade_timers():
	"""Clean up any existing cascade timers before starting a new cascade"""
	var timers_to_remove = []

	for child in get_children():
		if child is Timer and (child.name.begins_with("CascadeTimer_") or (child.has_meta("timer_type") and child.has_meta("cascade_id"))):
			timers_to_remove.append(child)

	for timer in timers_to_remove:
		if timer.timeout.is_connected():
			var connections = timer.timeout.get_connections()
			for connection in connections:
				timer.timeout.disconnect(connection.callable)
		timer.stop()
		remove_child(timer)
		timer.free()

	if timers_to_remove.size() > 0:
		# Cascade timers cleaned up
		pass

func _on_cascade_timer_timeout(timer: Timer):
	"""Unified timer callback that routes to the correct function based on timer metadata"""
	var cascade_id = timer.get_meta("cascade_id")
	var timer_type = timer.get_meta("timer_type")

	timer.queue_free()

	match timer_type:
		"continue":
			var parent_item = timer.get_meta("parent_item")
			_continue_cascade_after_deselect_timer(parent_item, cascade_id, timer)
		"finish":
			_finish_cascade_timer(cascade_id, timer)

func _continue_cascade_after_deselect_timer(parent_item: TreeItem, cascade_id: int, timer: Timer):
	if not has_meta("cascading") or get_meta("cascading") != cascade_id:
		timer.queue_free()
		return

	timer.queue_free()
	_continue_cascade_after_deselect(parent_item, cascade_id)

func _continue_cascade_after_deselect(parent_item: TreeItem, cascade_id: int):
	if not has_meta("cascading") or get_meta("cascading") != cascade_id:
		return

	if parent_item and is_instance_valid(parent_item):
		_custom_select_item(parent_item, true)
	else:
		remove_meta("cascading")
		remove_meta("cascade_direct_parent")
		return

	var children = []
	_collect_all_children(parent_item, children)

	if browse_tree.multi_selected.is_connected(_on_tree_multi_selected):
		browse_tree.multi_selected.disconnect(_on_tree_multi_selected)

	for child in children:
		if child and is_instance_valid(child):
			_custom_select_item(child)

	var timer = Timer.new()
	timer.wait_time = 0.001
	timer.one_shot = true
	timer.name = "CascadeTimer_Finish_%d" % cascade_id
	add_child(timer)
	timer.set_meta("cascade_id", cascade_id)
	timer.set_meta("timer_type", "finish")
	timer.timeout.connect(_on_cascade_timer_timeout.bind(timer))
	timer.start()

func _finish_cascade_timer(cascade_id: int, timer: Timer):
	if not has_meta("cascading") or get_meta("cascading") != cascade_id:
		timer.queue_free()
		return

	timer.queue_free()
	_finish_cascade(cascade_id)

func _finish_cascade(cascade_id: int):
	if not has_meta("cascading") or get_meta("cascading") != cascade_id:
		return

	if not browse_tree.multi_selected.is_connected(_on_tree_multi_selected):
		browse_tree.multi_selected.connect(_on_tree_multi_selected)

	_on_tree_item_selected()

	if has_meta("cascading") and get_meta("cascading") == cascade_id:
		remove_meta("cascading")
		remove_meta("cascade_direct_parent")

# Protection system removed - using fresh start approach

func _get_item_key(item: TreeItem) -> String:
	"""Generate unique key for TreeItem"""
	var metadata = item.get_metadata(0)
	if metadata:
		match metadata.type:
			"question":
				return "q_%s_%s_%d" % [metadata.grade_key, metadata.track_key, metadata.question_index]
			"track":
				return "t_%s_%s" % [metadata.grade_key, metadata.track_key]
			"grade":
				return "g_%s" % metadata.get("grade_key", "unknown")

	# Fallback to text if no metadata
	return "item_%s" % item.get_text(0)

func _deselect_all_items():
	"""Deselect all items using custom selection system"""
	# Fresh cascade: deselecting all items
	_custom_clear_selection()

func _deselect_item_and_children(item: TreeItem):
	"""Recursively deselect an item and all its children"""
	if item.is_selected(0):
		item.deselect(0)

	var child = item.get_first_child()
	while child:
		_deselect_item_and_children(child)
		child = child.get_next()


func _on_tree_item_selected():
	"""Handle tree item selection (supports multi-selection)"""
	var selected_items = _get_selected_items()
	var directly_selected_items = _custom_get_directly_selected_items()

	if selected_items.is_empty():
		edit_question_button.disabled = true
		edit_question_button.text = "Edit"
		delete_question_button.disabled = true
		delete_question_button.text = "Delete"
		return

	# For single direct selection, show specific edit/delete text
	if directly_selected_items.size() == 1:
		var metadata = directly_selected_items[0].get_metadata(0)
		if not metadata:
			edit_question_button.disabled = true
			edit_question_button.text = "Edit"
			delete_question_button.disabled = true
			delete_question_button.text = "Delete"
			return

		match metadata.type:
			"question":
				edit_question_button.disabled = false
				edit_question_button.text = "Edit Question"
				delete_question_button.disabled = false
				delete_question_button.text = "Delete Question"
			"track":
				edit_question_button.disabled = false
				edit_question_button.text = "Edit Track"
				delete_question_button.disabled = false
				delete_question_button.text = "Delete Track"
			"grade":
				edit_question_button.disabled = false
				edit_question_button.text = "Edit Grade"
				delete_question_button.disabled = false
				delete_question_button.text = "Delete Grade"
	else:
		# For multiple direct selection, count item types and create descriptive text
		var question_count = 0
		var track_count = 0
		var grade_count = 0

		for item in directly_selected_items:
			var metadata = item.get_metadata(0)
			if metadata:
				match metadata.type:
					"question":
						question_count += 1
					"track":
						track_count += 1
					"grade":
						grade_count += 1

		# Create descriptive delete button text
		var delete_parts = []
		if question_count > 0:
			if question_count == 1:
				delete_parts.append("1 Question")
			else:
				delete_parts.append("%d Questions" % question_count)
		if track_count > 0:
			if track_count == 1:
				delete_parts.append("1 Track")
			else:
				delete_parts.append("%d Tracks" % track_count)
		if grade_count > 0:
			if grade_count == 1:
				delete_parts.append("1 Grade")
			else:
				delete_parts.append("%d Grades" % grade_count)

		# Only disable delete if no valid items were found
		if delete_parts.is_empty():
			delete_question_button.disabled = true
			delete_question_button.text = "Delete"
		else:
			var delete_text = "Delete " + ", ".join(delete_parts)
			delete_question_button.disabled = false
			delete_question_button.text = delete_text

		edit_question_button.disabled = true
		edit_question_button.text = "Edit (Select 1 item)"

	# Store the first directly selected item for backward compatibility
	selected_tree_item = directly_selected_items[0] if directly_selected_items.size() > 0 else null

# Custom selection system functions
func _custom_select_item(item: TreeItem, is_direct_selection: bool = false):
	"""Add item to custom selection and apply visual highlighting"""
	if item and is_instance_valid(item):
		custom_selected_items[item] = true
		if is_direct_selection:
			directly_selected_items[item] = true

		# Always apply visual highlighting immediately
		item.set_custom_bg_color(0, selection_highlight_color)

func _custom_deselect_item(item: TreeItem):
	"""Remove item from custom selection and remove visual highlighting"""
	if item and is_instance_valid(item) and custom_selected_items.has(item):
		custom_selected_items.erase(item)
		directly_selected_items.erase(item)  # Also remove from direct selection tracking
		item.set_custom_bg_color(0, default_bg_color)

func _apply_batch_visual_updates():
	"""Apply visual highlighting to all items collected during batch mode"""
	if not has_meta("items_to_highlight"):
		return

	var items_to_highlight = get_meta("items_to_highlight")

	browse_tree.set_block_signals(true)

	for item in items_to_highlight:
		if item and is_instance_valid(item):
			item.set_custom_bg_color(0, selection_highlight_color)

	browse_tree.set_block_signals(false)

func _custom_clear_selection():
	"""Clear all custom selections and remove all visual highlighting"""
	for item in custom_selected_items.keys():
		if item and is_instance_valid(item):
			item.set_custom_bg_color(0, default_bg_color)
	custom_selected_items.clear()
	directly_selected_items.clear()

func _custom_get_selected_items() -> Array:
	"""Get all custom selected items as an array"""
	var selected_items = []
	for item in custom_selected_items.keys():
		if item and is_instance_valid(item):
			selected_items.append(item)
	return selected_items

func _custom_get_directly_selected_items() -> Array:
	"""Get only directly selected items (not cascaded children)"""
	var selected_items = []
	for item in directly_selected_items.keys():
		if item and is_instance_valid(item):
			selected_items.append(item)
	return selected_items

func _custom_is_selected(item: TreeItem) -> bool:
	"""Check if item is in custom selection"""
	return item and is_instance_valid(item) and custom_selected_items.has(item)

func _cascade_deselect_item_and_children(item: TreeItem):
	"""Deselect an item and all its children recursively"""
	if not item or not is_instance_valid(item):
		return

	# Deselect the item itself
	_custom_deselect_item(item)

	# Deselect all children recursively
	var child = item.get_first_child()
	while child:
		_cascade_deselect_item_and_children(child)
		child = child.get_next()

func _cascade_select_item_and_children(item: TreeItem, is_root: bool = true):
	"""Select an item and all its children recursively (for multi-selection) - OPTIMIZED"""
	if not item or not is_instance_valid(item):
		return

	# Select the item itself - mark as direct selection only for the root
	_custom_select_item(item, is_root)

	# Use fast cascade for children instead of recursion
	_cascade_select_children_fast(item)

func _get_selected_items() -> Array:
	"""Get all selected items - now uses custom selection system"""
	return _custom_get_selected_items()

func _on_tree_nothing_selected():
	"""Handle when user clicks in empty space and nothing is selected"""
	# Skip processing if we're already cascading
	if has_meta("cascading"):
		return

	# Clear all custom selections
	_custom_clear_selection()

	# Update button states
	_on_tree_item_selected()

func _on_tree_multi_selected(item: TreeItem, column: int, selected: bool):
	"""Handle multi-selection using custom selection system"""
	# GLOBAL LOCK: Don't process ANY multi-select events during range selection
	if range_selection_in_progress:
		return

	# GLOBAL LOCK: Don't process ANY multi-select events during normal click processing
	if normal_click_in_progress:
		return

	# IMPORTANT: Always ignore Tree deselection events for our custom system
	# The Tree widget tries to deselect items when we clear our custom selection,
	# but we want our custom selection to be the source of truth
	if not selected:
		return

	# Use the captured Shift state from the mouse event instead of Input.is_key_pressed
	var is_range_select = shift_held_during_click

	# If Shift is held, this is a range selection
	if is_range_select and selected:
		# Handle range selection

		# SET GLOBAL LOCK IMMEDIATELY
		range_selection_in_progress = true

		# Get the current selection to find the range start point
		var current_selections = _custom_get_directly_selected_items()
		# Check if we have existing selections

		if current_selections.is_empty():
			# No previous selection - just select this item normally
			_custom_clear_selection()
			_custom_select_item(item, true)
			range_selection_in_progress = false  # Clear lock
			# Update button states and return
			_on_tree_item_selected()
		else:
			# Range selection from last selected item to this item
			_handle_range_selection_to_item(item)
			# Lock will be cleared in _handle_range_selection_to_item
			# DON'T call _on_tree_item_selected here - it might trigger more events

		return

	# Skip processing if we're already cascading
	if has_meta("cascading"):
		return

	# Handle non-range selections normally
	if selected:
		var metadata = item.get_metadata(0)

		# Check if this is a true multiselect (Ctrl/Cmd held)
		var is_multiselect = Input.is_action_pressed("ui_select") or Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)

		# DELAY CASCADE DECISION - use a timer to check if Shift becomes pressed in the next frame
		# This handles cases where Shift key detection is delayed
		if metadata and (metadata.type == "grade" or metadata.type == "track") and not is_multiselect and not is_range_select:
			# Check for delayed Shift detection
			# Use a timer to check Shift state in the next frame (more reliable than call_deferred)
			var delay_timer = Timer.new()
			delay_timer.wait_time = 0.001  # Very short delay, just enough for input to settle
			delay_timer.one_shot = true
			delay_timer.name = "DelayedShiftCheck_%d" % Time.get_ticks_msec()
			add_child(delay_timer)
			delay_timer.timeout.connect(_delayed_cascade_check.bind(item, delay_timer))
			delay_timer.start()
			# Timer started for delayed check
			return
		else:
			# Either it's a question, or it's a track/grade with modifier keys held
			if is_multiselect:
				# Multi-selection mode - add to existing selection with highlighting
				if metadata and (metadata.type == "grade" or metadata.type == "track"):
					# For tracks/grades in individual multi-select (Cmd+click), cascade to children but don't clear previous selections
					_cascade_select_item_and_children(item, true)  # Mark root as directly selected
				else:
					# For questions, just select the individual item
					_custom_select_item(item, true)  # Mark as directly selected
			else:
				# Single selection mode - clear everything first, then select this item
				_custom_clear_selection()
				_custom_select_item(item, true)  # Mark as directly selected
	else:
		# Item is being deselected - handle cascading deselection for grades/tracks
		var metadata = item.get_metadata(0)
		if metadata and (metadata.type == "grade" or metadata.type == "track"):
			_cascade_deselect_item_and_children(item)
		else:
			_custom_deselect_item(item)

	# Update button states
	_on_tree_item_selected()

func _on_tree_gui_input(event: InputEvent):
	"""Capture mouse input events and handle range selection directly"""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			shift_held_during_click = event.shift_pressed

			# Get the clicked item directly
			var clicked_item = browse_tree.get_item_at_position(event.position)
			if clicked_item:
				# DIRECT RANGE SELECTION: Handle shift+click immediately here
				if shift_held_during_click:
					var current_selections = _custom_get_directly_selected_items()
					if not current_selections.is_empty():
						range_selection_in_progress = true
						_handle_range_selection_to_item(clicked_item)
						# Prevent normal Tree processing
						return
				else:
					# NORMAL CLICK: Handle regular selection
					_handle_normal_click(clicked_item)
					# Prevent normal Tree processing
					return
		else:
			# Clear the flag when mouse is released
			shift_held_during_click = false

func _handle_normal_click(clicked_item: TreeItem):
	"""Handle normal (non-shift) clicks on items"""
	# Check if this item is already selected
	var is_already_selected = custom_selected_items.has(clicked_item)

	if is_already_selected:
		# Item is selected - deselect everything and select just this item
		_custom_clear_selection()
		_custom_select_item(clicked_item, true)
	else:
		# Item is not selected - check if we should cascade or just select it
		var metadata = clicked_item.get_metadata(0)
		if metadata and (metadata.type == "grade" or metadata.type == "track"):
			_custom_clear_selection()
			_custom_select_item(clicked_item, true)
			_cascade_select_children_silent(clicked_item)
		else:
			_custom_clear_selection()
			_custom_select_item(clicked_item, true)

	# Update button states immediately
	_on_tree_item_selected()

func _handle_range_selection_to_item(end_item: TreeItem):
	"""Handle range selection from existing selection to the clicked item"""
	# DISCONNECT the multi_selected signal to prevent spam during range selection
	if browse_tree.multi_selected.is_connected(_on_tree_multi_selected):
		browse_tree.multi_selected.disconnect(_on_tree_multi_selected)

	var current_selections = _custom_get_directly_selected_items()
	if current_selections.is_empty():
		# Reconnect signal, clear flag, and return
		if not browse_tree.multi_selected.is_connected(_on_tree_multi_selected):
			browse_tree.multi_selected.connect(_on_tree_multi_selected)
		range_selection_in_progress = false
		return

	var start_item = current_selections[0]
	var start_metadata = start_item.get_metadata(0)
	var end_metadata = end_item.get_metadata(0)

	if not start_metadata or not end_metadata:
		# Reconnect signal, clear flag, and return
		if not browse_tree.multi_selected.is_connected(_on_tree_multi_selected):
			browse_tree.multi_selected.connect(_on_tree_multi_selected)
		range_selection_in_progress = false
		return

	# Get the range items
	var range_items = _get_range_items_direct(start_item, end_item)

	if range_items.is_empty():
		# Reconnect signal, clear flag, and return
		if not browse_tree.multi_selected.is_connected(_on_tree_multi_selected):
			browse_tree.multi_selected.connect(_on_tree_multi_selected)
		range_selection_in_progress = false
		return

	# Clear existing selection
	_custom_clear_selection()

	# Select ALL range items AND cascade for grades/tracks
	for item in range_items:
		if item and is_instance_valid(item):
			var metadata = item.get_metadata(0)
			var is_direct = (metadata and metadata.type == start_metadata.type)
			_custom_select_item(item, is_direct)

			# CASCADE to children for grades/tracks to show all their content
			if metadata and (metadata.type == "grade" or metadata.type == "track"):
				_cascade_select_children_silent(item)

	# Update button states
	_on_tree_item_selected()

	# Use timer to reconnect signal after a delay
	var reconnect_timer = Timer.new()
	reconnect_timer.wait_time = 0.1  # 100ms delay
	reconnect_timer.one_shot = true
	add_child(reconnect_timer)
	reconnect_timer.timeout.connect(_reconnect_signal_after_delay.bind(reconnect_timer))
	reconnect_timer.start()

func _reconnect_signal_after_delay(timer: Timer):
	"""Reconnect the multi_selected signal after a delay to prevent retriggering"""
	# RECONNECT the multi_selected signal
	if not browse_tree.multi_selected.is_connected(_on_tree_multi_selected):
		browse_tree.multi_selected.connect(_on_tree_multi_selected)

	# CLEAR the guard flag
	range_selection_in_progress = false

	# Clean up timer
	timer.queue_free()

func _find_parent_of_type(item: TreeItem, target_type: String) -> TreeItem:
	"""Find a parent of the given item that matches the target type"""
	var current = item.get_parent()
	while current:
		var metadata = current.get_metadata(0)
		if metadata and metadata.type == target_type:
			return current
		current = current.get_parent()
	return null

func _collect_all_tree_items(item: TreeItem, items_array: Array):
	"""Collect all TreeItems in order"""
	if item:
		items_array.append(item)
		var child = item.get_first_child()
		while child:
			_collect_all_tree_items(child, items_array)
			child = child.get_next()

func _delayed_cascade_check(item: TreeItem, delay_timer: Timer):
	"""Check if Shift was held during the click - if so, handle as range selection instead of cascade"""
	# GLOBAL LOCK: Don't process if range selection is already in progress
	if range_selection_in_progress:
		# Ignoring delayed cascade check during range selection
		delay_timer.queue_free()
		return

	var is_shift_held_now = shift_held_during_click
	# Check if shift was captured

	# Clean up the delay timer
	delay_timer.queue_free()

	if is_shift_held_now:
		# Shift was held - treat as range selection
		_handle_range_selection_to_item(item)
		_on_tree_item_selected()
	else:
		# No Shift, proceed with cascade as normal
		_fresh_start_cascade(item)


# Protection system removed - letting Tree widget handle selection naturally

# Old deselect function removed - no longer needed with simplified cascading

func _is_child_of(potential_child: TreeItem, potential_parent: TreeItem) -> bool:
	"""Check if potential_child is a descendant of potential_parent"""
	var current = potential_child.get_parent()
	while current:
		if current == potential_parent:
			return true
		current = current.get_parent()
	return false

func _cascade_select_item_and_children_visual_only(item: TreeItem):
	"""Select an item and all its children for visual feedback only (no direct marking)"""
	if not item or not is_instance_valid(item):
		return

	# Select all children recursively (for visual feedback only)
	var child = item.get_first_child()
	while child:
		_custom_select_item(child, false)  # NOT marked as direct selection
		_cascade_select_item_and_children_visual_only(child)
		child = child.get_next()

func _get_same_level_items(reference_item: TreeItem) -> Array:
	"""Get all items at the same level as the reference item - OPTIMIZED for range selection"""
	var same_level_items = []
	var parent = reference_item.get_parent()

	if not parent:
		# Reference item is root, return just the root
		same_level_items.append(reference_item)
		return same_level_items

	# Get all siblings (including the reference item)
	var sibling = parent.get_first_child()
	while sibling:
		same_level_items.append(sibling)
		sibling = sibling.get_next()

	return same_level_items

func _get_range_items_direct(start_item: TreeItem, end_item: TreeItem) -> Array:
	"""Get ALL items in tree between start and end - TREE-WIDE RANGE SELECTION"""
	var range_items = []

	# Get ALL items in the entire tree in order
	var all_tree_items = []
	_collect_all_tree_items(browse_tree.get_root(), all_tree_items)

	# Find start and end indices in the full tree
	var start_index = -1
	var end_index = -1
	for i in range(all_tree_items.size()):
		if all_tree_items[i] == start_item:
			start_index = i
		if all_tree_items[i] == end_item:
			end_index = i

	if start_index == -1 or end_index == -1:
		return range_items

	# Ensure start_index <= end_index
	if start_index > end_index:
		var temp = start_index
		start_index = end_index
		end_index = temp

	# Get all items in the range (everything from first to last)
	for i in range(start_index, end_index + 1):
		range_items.append(all_tree_items[i])

	return range_items

func _get_item_path(item: TreeItem) -> Array:
	"""Get the path from root to the given item"""
	var path = []
	var current = item

	while current and current != browse_tree.get_root():
		path.push_front(current)
		current = current.get_parent()

	if current == browse_tree.get_root():
		path.push_front(current)

	return path

func _batch_select_items_optimized(items: Array, item_type: String):
	"""Optimized batch selection that minimizes cascade operations"""
	# Batch selecting items

	# First pass: Select all primary items without cascading
	for item in items:
		if item and is_instance_valid(item):
			var metadata = item.get_metadata(0)
			var is_direct = (metadata and metadata.type == item_type)
			_custom_select_item(item, is_direct)

	# Second pass: Only cascade for grades/tracks, and do it efficiently
	if item_type == "grade" or item_type == "track":
		# Performing optimized cascade for items
		for item in items:
			if item and is_instance_valid(item):
				_cascade_select_children_fast(item)

func _cascade_select_children_fast(parent_item: TreeItem):
	"""Fast cascade selection that avoids recursive calls for better performance"""
	if not parent_item or not is_instance_valid(parent_item):
		return

	# Use iterative approach with a queue instead of recursion
	var items_to_process = [parent_item]
	var processed_count = 0
	var is_silent = has_meta("silent_cascade_mode")

	while not items_to_process.is_empty():
		var current_item = items_to_process.pop_front()

		# Add all children to the queue
		var child = current_item.get_first_child()
		while child:
			_custom_select_item(child, false)  # NOT marked as direct selection
			items_to_process.append(child)
			processed_count += 1
			child = child.get_next()

		# Safety check to prevent infinite loops
		if processed_count > 10000:
			if not is_silent:
				# Fast cascade hit safety limit, stopping
				pass
			break

func _cascade_select_children_silent(parent_item: TreeItem):
	"""Cascade selection - truly silent during range operations"""
	if not parent_item or not is_instance_valid(parent_item):
		return

	var items_to_process = []
	var child = parent_item.get_first_child()
	while child:
		items_to_process.append(child)
		child = child.get_next()

	var processed_count = 0
	while not items_to_process.is_empty() and processed_count < 10000:
		var current_item = items_to_process.pop_front()
		_custom_select_item(current_item, false)

		var grandchild = current_item.get_first_child()
		while grandchild:
			items_to_process.append(grandchild)
			grandchild = grandchild.get_next()

		processed_count += 1

func _collect_all_children(item: TreeItem, children_array: Array):
	"""Collect all children of an item into an array"""
	var child = item.get_first_child()
	while child:
		children_array.append(child)
		_collect_all_children(child, children_array)
		child = child.get_next()


func _collect_selected_items(item: TreeItem, selected_items: Array):
	"""Recursively collect all selected items"""
	if item.is_selected(0):
		selected_items.append(item)

	var child = item.get_first_child()
	while child:
		_collect_selected_items(child, selected_items)
		child = child.get_next()

func _edit_selected_question():
	"""Handle editing of selected item (question, track, or grade)"""
	if not selected_tree_item:
		return

	var metadata = selected_tree_item.get_metadata(0)
	if not metadata:
		return

	match metadata.type:
		"question":
			# Load question into Questions tab for editing
			for i in range(questions_track_option.get_item_count()):
				var track_meta = questions_track_option.get_item_metadata(i)
				if track_meta.grade_key == metadata.grade_key and track_meta.track_key == metadata.track_key:
					questions_track_option.selected = i
					_populate_questions_list(metadata.grade_key, metadata.track_key)
					break
			# Switch to Questions tab
			var tab_container = $MainTabs
			tab_container.current_tab = 1

		"track":
			# Load track into Tracks tab for editing
			var track_data = math_facts_data.grades[metadata.grade_key].tracks[metadata.track_key]
			var track_number = int(metadata.track_key.replace("TRACK", ""))

			# Find and select the track in the tracks list
			for i in range(tracks_list.get_item_count()):
				var track_meta = tracks_list.get_item_metadata(i)
				if track_meta.grade_key == metadata.grade_key and track_meta.track_key == metadata.track_key:
					tracks_list.select(i)
					_on_track_selected(i)
					break
			# Switch to Tracks tab
			var tab_container = $MainTabs
			tab_container.current_tab = 3

		"grade":
			# Load grade into Grades tab for editing
			for i in range(grades_list.get_item_count()):
				var grade_key = grades_list.get_item_metadata(i)
				if grade_key == metadata.key:
					grades_list.select(i)
					_on_grade_selected(i)
					break
			# Switch to Grades tab
			var tab_container = $MainTabs
			tab_container.current_tab = 2

func _delete_selected_question():
	"""Delete selected items (supports multi-selection)"""
	var selected_items = _get_selected_items()

	if selected_items.is_empty():
		return

	# Create confirmation message based on selection
	var confirmation_text = ""
	if selected_items.size() == 1:
		var metadata = selected_items[0].get_metadata(0)
		if not metadata:
			return

		match metadata.type:
			"question":
				confirmation_text = "Delete question: %s?" % metadata.question.expression
			"track":
				var track_data = math_facts_data.grades[metadata.grade_key].tracks[metadata.track_key]
				confirmation_text = "Delete entire track: %s (%d questions)?" % [track_data.title, track_data.facts.size()]
			"grade":
				var grade_data = math_facts_data.grades[metadata.grade_key]
				var track_count = grade_data.tracks.size() if grade_data.has("tracks") else 0
				var question_count = _count_grade_questions(metadata.grade_key)
				confirmation_text = "Delete grade: %s?\nThis will delete %d tracks and %d questions!" % [grade_data.name, track_count, question_count]
	else:
		# Multiple items selected
		var question_count = 0
		var track_count = 0
		var grade_count = 0

		for item in selected_items:
			var metadata = item.get_metadata(0)
			if metadata:
				match metadata.type:
					"question":
						question_count += 1
					"track":
						track_count += 1
					"grade":
						grade_count += 1

		var items_text = []
		if question_count > 0:
			items_text.append("%d question(s)" % question_count)
		if track_count > 0:
			items_text.append("%d track(s)" % track_count)
		if grade_count > 0:
			items_text.append("%d grade(s)" % grade_count)

		confirmation_text = "Delete %s?\n\nThis action cannot be undone!" % ", ".join(items_text)

	confirm_dialog.dialog_text = confirmation_text
	confirm_dialog.popup_centered()


func _recalculate_question_indices(grade_key: String, track_key: String):
	"""Recalculate question indices after deletion"""
	var questions = math_facts_data.grades[grade_key].tracks[track_key].facts
	for i in range(questions.size()):
		questions[i].index = i + 1



func _get_next_track_number() -> int:
	"""Get the next available track number"""
	var used_numbers = []

	# Check if math facts data is loaded
	if not math_facts_data.has("grades"):
		return 1

	for grade_key in math_facts_data.grades:
		var grade_data = math_facts_data.grades[grade_key]
		if grade_data.has("tracks"):
			for track_key in grade_data.tracks:
				var track_number = int(track_key.replace("TRACK", ""))
				used_numbers.append(track_number)

	used_numbers.sort()
	for i in range(1, 100):
		if i not in used_numbers:
			return i
	return 1

func _create_new_track_inline():
	"""Create a new track using inline form"""
	var track_number = int(new_track_number_input.value)
	var track_title = new_track_title_input.text.strip_edges()

	if track_title == "":
		# Track title cannot be empty
		return

	if new_track_grade_option.selected < 0:
		# Please select a grade
		return

	# Get grade key from metadata
	var grade_key = new_track_grade_option.get_item_metadata(new_track_grade_option.selected)
	if not grade_key:
		# Invalid grade selection
		return

	# Check if grade exists
	if not math_facts_data.grades.has(grade_key):
		# Grade not found in database
		return

	var track_key = "TRACK%d" % track_number

	# Check if track already exists in any grade
	for check_grade_key in math_facts_data.grades:
		var check_grade_data = math_facts_data.grades[check_grade_key]
		if check_grade_data.has("tracks") and check_grade_data.tracks.has(track_key):
			# Track already exists
			return

	# Create new track
	math_facts_data.grades[grade_key].tracks[track_key] = {
		"id": track_key,
		"title": track_title,
		"factCount": 0,
		"facts": []
	}

	file_modified = true
	_populate_browse_tree()
	_populate_tracks_list()
	_populate_questions_track_options()

	# Clear the form
	new_track_number_input.value = _get_next_track_number()
	new_track_title_input.text = ""
	new_track_grade_option.selected = 0

	# Auto-save the file
	_save_math_facts_file()

	# Track created successfully

func _on_track_selected(index: int):
	"""Handle track selection in tracks list"""
	if index < 0:
		return

	var metadata = tracks_list.get_item_metadata(index)
	if not metadata:
		return

	current_editing_track = metadata
	var track_data = math_facts_data.grades[metadata.grade_key].tracks[metadata.track_key]
	var track_number = int(metadata.track_key.replace("TRACK", ""))

	track_number_input.value = track_number
	track_title_input.text = track_data.title

	# Set grade using metadata
	for i in range(track_grade_option.get_item_count()):
		var item_grade_key = track_grade_option.get_item_metadata(i)
		if item_grade_key == metadata.grade_key:
			track_grade_option.selected = i
			break

func _save_track():
	"""Save track changes"""
	if not current_editing_track:
		# No track selected
		return

	var new_title = track_title_input.text.strip_edges()
	if new_title == "":
		# Track title cannot be empty
		return

	# Update track data
	var track_data = math_facts_data.grades[current_editing_track.grade_key].tracks[current_editing_track.track_key]
	track_data.title = new_title

	file_modified = true
	_populate_browse_tree()
	_populate_tracks_list()
	_populate_questions_track_options()

	# Auto-save the file
	_save_math_facts_file()

func _delete_track():
	"""Delete current track"""
	if not current_editing_track:
		# No track selected
		return

	var track_data = math_facts_data.grades[current_editing_track.grade_key].tracks[current_editing_track.track_key]
	confirm_dialog.dialog_text = "Delete track: %s (%d questions)?" % [track_data.title, track_data.facts.size()]
	confirm_dialog.popup_centered()

# Grade Management Functions

func _create_new_grade_inline():
	"""Create a new grade using inline form"""
	var grade_name = new_grade_name_input.text.strip_edges()
	var grade_key = new_grade_key_input.text.strip_edges()

	if grade_name == "":
		# Grade name cannot be empty
		return

	if grade_key == "":
		# Grade key cannot be empty
		return

	# Validate grade key format
	if not grade_key.begins_with("grade-"):
		# Grade key should start with 'grade-'
		return

	# Check if grade already exists
	if math_facts_data.grades.has(grade_key):
		# Grade already exists
		return

	# Create new grade
	math_facts_data.grades[grade_key] = {
		"name": grade_name,
		"trackOrder": [],
		"tracks": {}
	}

	file_modified = true
	_populate_browse_tree()
	_populate_tracks_list()
	_populate_questions_track_options()
	_populate_grades_list()
	_populate_grade_options()  # Update grade dropdowns

	# Clear the form
	new_grade_name_input.text = ""
	new_grade_key_input.text = ""

	# Auto-save the file
	_save_math_facts_file()

	# Grade created successfully

func _on_grade_selected(index: int):
	"""Handle grade selection in grades list"""
	if index < 0:
		return

	var grade_key = grades_list.get_item_metadata(index)
	if not grade_key:
		return

	current_editing_grade = grade_key
	var grade_data = math_facts_data.grades[grade_key]

	grade_name_input.text = grade_data.name
	grade_key_input.text = grade_key

func _save_grade():
	"""Save grade changes"""
	if not current_editing_grade:
		# No grade selected
		return

	var new_name = grade_name_input.text.strip_edges()
	var new_key = grade_key_input.text.strip_edges()

	if new_name == "":
		# Grade name cannot be empty
		return

	if new_key == "":
		# Grade key cannot be empty
		return

	# Validate grade key format
	if not new_key.begins_with("grade-"):
		# Grade key should start with 'grade-'
		return

	# If key changed, we need to rename the grade
	if new_key != current_editing_grade:
		if math_facts_data.grades.has(new_key):
			# Grade key already exists
			return

		# Move grade data to new key
		var grade_data = math_facts_data.grades[current_editing_grade]
		math_facts_data.grades.erase(current_editing_grade)
		math_facts_data.grades[new_key] = grade_data
		current_editing_grade = new_key

	# Update grade name
	math_facts_data.grades[current_editing_grade].name = new_name

	file_modified = true
	_populate_browse_tree()
	_populate_tracks_list()
	_populate_questions_track_options()
	_populate_grades_list()

	# Auto-save the file
	_save_math_facts_file()

func _delete_grade():
	"""Delete current grade"""
	if not current_editing_grade:
		# No grade selected
		return

	var grade_data = math_facts_data.grades[current_editing_grade]
	var track_count = grade_data.tracks.size() if grade_data.has("tracks") else 0
	var question_count = _count_grade_questions(current_editing_grade)

	confirm_dialog.dialog_text = "Delete grade: %s?\nThis will delete %d tracks and %d questions!" % [grade_data.name, track_count, question_count]
	confirm_dialog.popup_centered()

func _confirmed_delete():
	"""Handle confirmed deletion (supports multi-selection)"""
	var selected_items = _get_selected_items()

	# Handle grade deletion from Grades tab (single item)
	if current_editing_grade:
		math_facts_data.grades.erase(current_editing_grade)
		current_editing_grade = null

		file_modified = true
		_populate_browse_tree()
		_populate_tracks_list()
		_populate_grades_list()

		# Clear grade editor
		grade_name_input.text = ""
		grade_key_input.text = ""

		# Auto-save the file
		_save_math_facts_file()
		return

	# Handle tree item deletion (supports multiple items)
	if selected_items.is_empty():
		return

	var items_deleted = 0

	# Process deletions in reverse order to avoid index issues
	selected_items.reverse()

	for item in selected_items:
		var metadata = item.get_metadata(0)
		if not metadata:
			continue

		match metadata.type:
			"question":
				# Remove question from data
				var questions = math_facts_data.grades[metadata.grade_key].tracks[metadata.track_key].facts
				if metadata.question_index < questions.size():
					questions.remove_at(metadata.question_index)
					_recalculate_question_indices(metadata.grade_key, metadata.track_key)
					items_deleted += 1

			"track":
				# Remove entire track
				if math_facts_data.grades.has(metadata.grade_key) and math_facts_data.grades[metadata.grade_key].tracks.has(metadata.track_key):
					math_facts_data.grades[metadata.grade_key].tracks.erase(metadata.track_key)
					items_deleted += 1

			"grade":
				# Remove entire grade
				if math_facts_data.grades.has(metadata.grade_key):
					math_facts_data.grades.erase(metadata.grade_key)
					items_deleted += 1

	if items_deleted > 0:
		file_modified = true
		_populate_browse_tree()
		_populate_tracks_list()
		_populate_grades_list()
		_populate_questions_track_options()
		_populate_grade_options()

		# Auto-save the file
		_save_math_facts_file()

		# Successfully deleted items

# Questions Tab Functions

func _on_questions_track_selected(index: int):
	"""Handle track selection in Questions tab"""
	if index < 0:
		_clear_questions_list()
		_clear_new_question_editor()
		return

	var track_meta = questions_track_option.get_item_metadata(index)
	if not track_meta:
		_clear_questions_list()
		_clear_new_question_editor()
		return

	_populate_questions_list(track_meta.grade_key, track_meta.track_key)
	_clear_new_question_editor()

func _add_new_question_from_editor():
	"""Add new question(s) from the editor, supporting both single values and ranges"""
	print("DEBUG: Starting _add_new_question_from_editor")
	if questions_track_option.selected < 0:
		print("DEBUG: No track selected")
		return

	var track_meta = questions_track_option.get_item_metadata(questions_track_option.selected)
	if not track_meta:
		print("DEBUG: Invalid track selection")
		return

	# Get input texts
	var op1_text = new_op1_input.text.strip_edges()
	var op2_text = new_op2_input.text.strip_edges()
	var result_text = new_result_input.text.strip_edges()
	print("DEBUG: Inputs - op1: '%s', op2: '%s', result: '%s'" % [op1_text, op2_text, result_text])

	# If operands are empty but result is specified, use a special generation approach
	if (op1_text == "" or op2_text == "") and result_text != "":
		print("DEBUG: Using smart generation for empty operands with result constraint")
		var result_parsed_temp = math_generator.parse_input(result_text)
		if not result_parsed_temp.values.is_empty() and math_generator:
			# Use a special function to generate all operand combinations that produce the desired results
			var operator = new_operator_option.selected
			# Parse any specified operands for the actual generation
			var op1_values = []
			var op2_values = []
			if op1_text != "":
				var op1_parsed = math_generator.parse_input(op1_text)
				op1_values = op1_parsed.values
			if op2_text != "":
				var op2_parsed = math_generator.parse_input(op2_text)
				op2_values = op2_parsed.values

			var smart_questions = _generate_questions_with_constraints(result_parsed_temp.values, operator, op1_values, op2_values)
			print("DEBUG: Smart generation produced %d questions" % smart_questions.size())

			if not smart_questions.is_empty():
				# Add questions directly without going through normal range processing
				var track_metadata = questions_track_option.get_item_metadata(questions_track_option.selected)
				var questions = math_facts_data.grades[track_metadata.grade_key].tracks[track_metadata.track_key].facts
				var start_index = questions.size() + 1

				for i in range(smart_questions.size()):
					var question = smart_questions[i]
					question.index = start_index + i
					questions.append(question)

				file_modified = true
				_populate_questions_list(track_metadata.grade_key, track_metadata.track_key)
				_populate_browse_tree()
				_clear_new_question_editor()
				_save_math_facts_file()
				print("DEBUG: Successfully added %d questions via smart generation" % smart_questions.size())
				return
			else:
				print("DEBUG: Smart generation failed")
				return

	if op1_text == "" or op2_text == "":
		print("DEBUG: Missing operand fields")
		return

	if not math_generator:
		print("DEBUG: Math generator not available")
		return

	# Parse inputs using the math generator
	var op1_parsed = math_generator.parse_input(op1_text)
	var op2_parsed = math_generator.parse_input(op2_text)
	var result_parsed = {"is_range": false, "values": []}

	if result_text != "":
		result_parsed = math_generator.parse_input(result_text)

	# Check for valid parsing
	print("DEBUG: Parsed - op1: %s, op2: %s, result: %s" % [op1_parsed.values, op2_parsed.values, result_parsed.values])
	if op1_parsed.values.is_empty() or op2_parsed.values.is_empty():
		print("DEBUG: Invalid operand format")
		return

	if result_text != "" and result_parsed.values.is_empty():
		print("DEBUG: Invalid result format")
		return

	# Validate mathematical constraints
	var operator = new_operator_option.selected
	print("DEBUG: Operator: %d" % operator)
	var validation = math_generator.validate_range_constraints(op1_parsed.values, op2_parsed.values, operator, result_parsed.values)
	print("DEBUG: Validation result: valid=%s, error='%s'" % [validation.valid, validation.error])
	if not validation.valid:
		print("DEBUG: Invalid range combination: %s" % validation.error)
		return

	# Generate questions
	var generated_questions = math_generator.generate_questions_from_ranges(
		op1_parsed.values,
		op2_parsed.values,
		operator,
		result_parsed.values
	)
	print("DEBUG: Generated %d questions" % generated_questions.size())

	if generated_questions.is_empty():
		print("DEBUG: No valid questions could be generated")
		return

	# Confirm large batch additions
	if generated_questions.size() > 50:
		# Large batch generation warning
		# For now, let's proceed - in a real UI you might want a confirmation dialog
		pass

	# Add questions to the track
	var questions = math_facts_data.grades[track_meta.grade_key].tracks[track_meta.track_key].facts
	var start_index = questions.size() + 1

	for i in range(generated_questions.size()):
		var question = generated_questions[i]
		question.index = start_index + i
		questions.append(question)

	file_modified = true
	_populate_questions_list(track_meta.grade_key, track_meta.track_key)
	_populate_browse_tree()

	# Clear the editor for next question
	_clear_new_question_editor()

	# Auto-save the file
	_save_math_facts_file()

	print("DEBUG: Successfully added %d questions" % generated_questions.size())

func _generate_questions_for_results(result_values: Array, operator: int) -> Array:
	"""Generate all possible operand combinations that produce the given results"""
	var questions = []
	var operator_str = math_generator.get_operator_string(operator)
	var ui_operators = ["+", "-", "×", "÷"]
	var display_operator = ui_operators[operator]

	print("DEBUG: _generate_questions_for_results called with result_values: %s, operator: %d" % [result_values, operator])

	var max_result = result_values.max()
	var min_result = result_values.min()

	# For each desired result, generate all valid operand combinations
	for target_result in result_values:
		match operator:
			0: # Addition: op1 + op2 = target_result
				# op1 can be 0 to target_result, op2 = target_result - op1
				for op1 in range(0, target_result + 1):
					var op2 = target_result - op1
					if op2 >= 0:  # Ensure non-negative operands
						_add_question_to_array(questions, op1, op2, target_result, operator_str, display_operator)

			1: # Subtraction: op1 - op2 = target_result
				# op1 can be target_result to reasonable_max, op2 = op1 - target_result
				# Limit to reasonable range to avoid infinite possibilities
				var max_op1 = target_result + 20  # Reasonable limit
				for op1 in range(target_result, max_op1 + 1):
					var op2 = op1 - target_result
					if op2 >= 0:  # Ensure non-negative operands
						_add_question_to_array(questions, op1, op2, target_result, operator_str, display_operator)

			2: # Multiplication: op1 * op2 = target_result
				if target_result == 0:
					# Special case: 0 * anything = 0, anything * 0 = 0
					for i in range(0, 11):  # 0-10 range
						_add_question_to_array(questions, 0, i, 0, operator_str, display_operator)
						if i > 0:  # Avoid duplicate 0*0
							_add_question_to_array(questions, i, 0, 0, operator_str, display_operator)
				else:
					# Find all factor pairs
					for op1 in range(1, target_result + 1):
						if target_result % op1 == 0:  # op1 is a factor
							var op2 = target_result / op1
							_add_question_to_array(questions, op1, op2, target_result, operator_str, display_operator)

			3: # Division: op1 / op2 = target_result
				if target_result == 0:
					# 0 / anything = 0 (except 0/0)
					for op2 in range(1, 21):  # Reasonable range 1-20
						_add_question_to_array(questions, 0, op2, 0, operator_str, display_operator)
				else:
					# op1 = target_result * op2, where op2 >= 1
					for op2 in range(1, 21):  # Reasonable divisor range
						var op1 = target_result * op2
						_add_question_to_array(questions, op1, op2, target_result, operator_str, display_operator)

	print("DEBUG: Generated %d questions for results %s" % [questions.size(), result_values])
	return questions

func _add_question_to_array(questions: Array, op1: int, op2: int, result: int, operator_str: String, display_operator: String):
	"""Helper function to add a formatted question to the questions array"""
	var op1_str = str(op1)
	var op2_str = str(op2)
	var result_str = str(result)
	var expression = "%s %s %s = %s" % [op1_str, display_operator, op2_str, result_str]
	var question_text = "%s %s %s" % [op1_str, operator_str, op2_str]

	var question = {
		"operands": [float(op1), float(op2)],
		"operator": operator_str,
		"result": float(result),
		"expression": expression,
		"question": question_text,
		"index": 1  # Will be updated when added to track
	}

	questions.append(question)

func _generate_questions_with_constraints(result_values: Array, operator: int, op1_values: Array, op2_values: Array) -> Array:
	"""Generate questions with optional operand constraints"""
	var questions = []
	var operator_str = math_generator.get_operator_string(operator)
	var ui_operators = ["+", "-", "×", "÷"]
	var display_operator = ui_operators[operator]

	print("DEBUG: _generate_questions_with_constraints - results: %s, op1_values: %s, op2_values: %s, operator: %d" % [result_values, op1_values, op2_values, operator])

	for target_result in result_values:
		match operator:
			0: # Addition: op1 + op2 = target_result
				if op1_values.is_empty() and op2_values.is_empty():
					# Both operands free - generate all combinations
					for op1 in range(0, target_result + 1):
						var op2 = target_result - op1
						if op2 >= 0:
							_add_question_to_array(questions, op1, op2, target_result, operator_str, display_operator)
				elif not op1_values.is_empty() and op2_values.is_empty():
					# op1 specified, op2 calculated
					for op1 in op1_values:
						var op2 = target_result - op1
						if op2 >= 0:
							_add_question_to_array(questions, op1, op2, target_result, operator_str, display_operator)
				elif op1_values.is_empty() and not op2_values.is_empty():
					# op2 specified, op1 calculated
					for op2 in op2_values:
						var op1 = target_result - op2
						if op1 >= 0:
							_add_question_to_array(questions, op1, op2, target_result, operator_str, display_operator)
				else:
					# Both operands specified - validate they produce the target result
					for op1 in op1_values:
						for op2 in op2_values:
							if op1 + op2 == target_result:
								_add_question_to_array(questions, op1, op2, target_result, operator_str, display_operator)

			1: # Subtraction: op1 - op2 = target_result
				if not op1_values.is_empty() and op2_values.is_empty():
					# op1 specified, op2 calculated
					for op1 in op1_values:
						var op2 = op1 - target_result
						if op2 >= 0:
							_add_question_to_array(questions, op1, op2, target_result, operator_str, display_operator)
				elif op1_values.is_empty() and not op2_values.is_empty():
					# op2 specified, op1 calculated
					for op2 in op2_values:
						var op1 = target_result + op2
						_add_question_to_array(questions, op1, op2, target_result, operator_str, display_operator)
				elif not op1_values.is_empty() and not op2_values.is_empty():
					# Both operands specified - validate they produce the target result
					for op1 in op1_values:
						for op2 in op2_values:
							if op1 - op2 == target_result:
								_add_question_to_array(questions, op1, op2, target_result, operator_str, display_operator)

			2: # Multiplication: op1 * op2 = target_result
				if op1_values.is_empty() and op2_values.is_empty():
					# Both operands free - find all factor pairs
					if target_result == 0:
						for i in range(0, 11):
							_add_question_to_array(questions, 0, i, 0, operator_str, display_operator)
							if i > 0:
								_add_question_to_array(questions, i, 0, 0, operator_str, display_operator)
					else:
						for op1 in range(1, target_result + 1):
							if target_result % op1 == 0:
								var op2 = target_result / op1
								_add_question_to_array(questions, op1, op2, target_result, operator_str, display_operator)
				elif not op1_values.is_empty() and op2_values.is_empty():
					# op1 specified, op2 calculated
					for op1 in op1_values:
						if op1 == 0:
							if target_result == 0:
								_add_question_to_array(questions, 0, 1, 0, operator_str, display_operator)  # 0*1=0 example
						elif target_result % op1 == 0:
							var op2 = target_result / op1
							_add_question_to_array(questions, op1, op2, target_result, operator_str, display_operator)
				elif op1_values.is_empty() and not op2_values.is_empty():
					# op2 specified, op1 calculated
					for op2 in op2_values:
						if op2 == 0:
							if target_result == 0:
								_add_question_to_array(questions, 1, 0, 0, operator_str, display_operator)  # 1*0=0 example
						elif target_result % op2 == 0:
							var op1 = target_result / op2
							_add_question_to_array(questions, op1, op2, target_result, operator_str, display_operator)
				else:
					# Both operands specified - validate they produce the target result
					for op1 in op1_values:
						for op2 in op2_values:
							if op1 * op2 == target_result:
								_add_question_to_array(questions, op1, op2, target_result, operator_str, display_operator)

			3: # Division: op1 / op2 = target_result
				if not op1_values.is_empty() and op2_values.is_empty():
					# op1 specified, op2 calculated
					for op1 in op1_values:
						if target_result == 0:
							if op1 == 0:
								_add_question_to_array(questions, 0, 1, 0, operator_str, display_operator)  # 0/1=0 example
						elif op1 % target_result == 0:
							var op2 = op1 / target_result
							if op2 > 0:  # Avoid division by zero
								_add_question_to_array(questions, op1, op2, target_result, operator_str, display_operator)
				elif op1_values.is_empty() and not op2_values.is_empty():
					# op2 specified, op1 calculated
					for op2 in op2_values:
						if op2 > 0:  # Avoid division by zero
							var op1 = target_result * op2
							_add_question_to_array(questions, op1, op2, target_result, operator_str, display_operator)
				elif not op1_values.is_empty() and not op2_values.is_empty():
					# Both operands specified - validate they produce the target result
					for op1 in op1_values:
						for op2 in op2_values:
							if op2 > 0 and op1 / op2 == target_result:
								_add_question_to_array(questions, op1, op2, target_result, operator_str, display_operator)

	print("DEBUG: Generated %d questions with constraints" % questions.size())
	return questions

func _clear_new_question_editor():
	"""Clear the new question editor"""
	new_op1_input.text = ""
	new_op2_input.text = ""
	new_operator_option.selected = 0
	new_result_input.text = ""

func _update_question_preview():
	"""Update the button state and text when inputs change"""
	if not math_generator:
		return

	# Get current input values
	var op1_text = new_op1_input.text.strip_edges()
	var op2_text = new_op2_input.text.strip_edges()
	var result_text = new_result_input.text.strip_edges()

	var error_message = ""
	var question_count = 0
	var is_valid = false

	# Check for smart generation case (empty operands with result constraint)
	if (op1_text == "" or op2_text == "") and result_text != "":
		var result_parsed_temp = math_generator.parse_input(result_text)
		if result_parsed_temp.values.is_empty():
			error_message = "Invalid result format"
		else:
			var operator = new_operator_option.selected
			# Division and subtraction have infinite possibilities when BOTH operands are missing
			if (op1_text == "" and op2_text == "") and (operator == 3 or operator == 1):
				if operator == 3:
					error_message = "Division has infinite solutions - specify at least one operand"
				else:
					error_message = "Subtraction has infinite solutions - specify at least one operand"
			else:
				# Parse any specified operands
				var op1_values = []
				var op2_values = []
				if op1_text != "":
					var op1_parsed = math_generator.parse_input(op1_text)
					op1_values = op1_parsed.values
				if op2_text != "":
					var op2_parsed = math_generator.parse_input(op2_text)
					op2_values = op2_parsed.values

				var smart_questions = _generate_questions_with_constraints(result_parsed_temp.values, operator, op1_values, op2_values)
				question_count = smart_questions.size()
				if question_count > 0:
					is_valid = true
				else:
					error_message = "No valid questions possible"
	# Standard case - both operands specified
	elif op1_text != "" and op2_text != "":
		# Parse inputs
		var op1_parsed = math_generator.parse_input(op1_text)
		var op2_parsed = math_generator.parse_input(op2_text)
		var result_parsed = {"is_range": false, "values": []}

		if result_text != "":
			result_parsed = math_generator.parse_input(result_text)

		# Check for valid parsing
		if op1_parsed.values.is_empty() or op2_parsed.values.is_empty():
			error_message = "Invalid input format"
		elif result_text != "" and result_parsed.values.is_empty():
			error_message = "Invalid result format"
		else:
			# Validate mathematical constraints
			var operator = new_operator_option.selected
			var validation = math_generator.validate_range_constraints(op1_parsed.values, op2_parsed.values, operator, result_parsed.values)
			if not validation.valid:
				error_message = validation.error
			else:
				# Count potential questions
				var generated_questions = math_generator.generate_questions_from_ranges(
					op1_parsed.values,
					op2_parsed.values,
					operator,
					result_parsed.values
				)
				question_count = generated_questions.size()
				if question_count > 0:
					is_valid = true
				else:
					error_message = "No valid questions possible"
	else:
		# Missing required inputs
		error_message = "Enter operands or result range"

	# Button text now shows all the info we need

	# Update button state and text
	add_button.disabled = not is_valid
	if is_valid:
		if question_count == 1:
			add_button.text = "Add Question"
		else:
			add_button.text = "Add %d Questions" % question_count
		add_button.modulate = Color.WHITE
		add_button.tooltip_text = ""
	else:
		add_button.text = "Add Question(s)"
		add_button.modulate = Color(0.6, 0.6, 0.6)  # Grayed out
		add_button.tooltip_text = error_message

func _populate_questions_list(grade_key: String, track_key: String):
	"""Populate the questions list for the selected track"""
	_clear_questions_list()

	if not math_facts_data.grades.has(grade_key):
		return

	var grade_data = math_facts_data.grades[grade_key]
	if not grade_data.has("tracks") or not grade_data.tracks.has(track_key):
		return

	var track_data = grade_data.tracks[track_key]
	var questions = track_data.facts

	for i in range(questions.size()):
		var question = questions[i]
		_create_question_editor(question, grade_key, track_key, i)

func _create_question_editor(question: Dictionary, grade_key: String, track_key: String, question_index: int):
	"""Create an editable question entry"""
	var question_container = HBoxContainer.new()
	question_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Operand 1
	var op1_input = SpinBox.new()
	op1_input.min_value = -999
	op1_input.max_value = 999
	op1_input.value = question.operands[0]
	op1_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	question_container.add_child(op1_input)

	# Operator
	var operator_option = OptionButton.new()
	operator_option.add_item("+")
	operator_option.add_item("-")
	operator_option.add_item("×")
	operator_option.add_item("÷")
	var operator_map = {"+": 0, "-": 1, "x": 2, "/": 3}
	operator_option.selected = operator_map.get(question.operator, 0)
	question_container.add_child(operator_option)

	# Operand 2
	var op2_input = SpinBox.new()
	op2_input.min_value = -999
	op2_input.max_value = 999
	op2_input.value = question.operands[1]
	op2_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	question_container.add_child(op2_input)

	# Equals label
	var equals_label = Label.new()
	equals_label.text = " = "
	question_container.add_child(equals_label)

	# Result input
	var result_input = SpinBox.new()
	result_input.min_value = -999
	result_input.max_value = 999
	result_input.value = question.result
	result_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	question_container.add_child(result_input)

	# Delete button
	var delete_button = Button.new()
	delete_button.text = "×"
	delete_button.modulate = Color(1, 0.7, 0.7)
	question_container.add_child(delete_button)

	# Connect signals for auto-update
	var update_func = func():
		_update_question_from_inputs(grade_key, track_key, question_index, op1_input, operator_option, op2_input, result_input)

	op1_input.value_changed.connect(update_func)
	operator_option.item_selected.connect(func(index): update_func.call())
	op2_input.value_changed.connect(update_func)
	result_input.value_changed.connect(update_func)

	delete_button.pressed.connect(func(): _delete_question_at_index(grade_key, track_key, question_index))

	questions_container.add_child(question_container)

func _update_question_from_inputs(grade_key: String, track_key: String, question_index: int, op1_input: SpinBox, operator_option: OptionButton, op2_input: SpinBox, result_input: SpinBox):
	"""Update question data when inputs change"""
	var questions = math_facts_data.grades[grade_key].tracks[track_key].facts
	if question_index >= questions.size():
		return

	var ui_operators = ["+", "-", "×", "÷"]
	var json_operators = ["+", "-", "x", "/"]
	var operator = json_operators[operator_option.selected]

	var question = questions[question_index]
	question.operands = [op1_input.value, op2_input.value]
	question.operator = operator
	question.result = result_input.value

	# Format expression
	var op1_str = str(int(op1_input.value)) if op1_input.value == int(op1_input.value) else str(op1_input.value)
	var op2_str = str(int(op2_input.value)) if op2_input.value == int(op2_input.value) else str(op2_input.value)
	var result_str = str(int(result_input.value)) if result_input.value == int(result_input.value) else str(result_input.value)
	var display_operator = ui_operators[operator_option.selected]
	question.expression = "%s %s %s = %s" % [op1_str, display_operator, op2_str, result_str]

	file_modified = true
	_populate_browse_tree()

	# Auto-save the file
	_save_math_facts_file()

func _delete_question_at_index(grade_key: String, track_key: String, question_index: int):
	"""Delete a question at the specified index"""
	var questions = math_facts_data.grades[grade_key].tracks[track_key].facts
	if question_index >= questions.size():
		return

	questions.remove_at(question_index)

	# Recalculate indices
	for i in range(questions.size()):
		questions[i].index = i + 1

	file_modified = true
	_populate_questions_list(grade_key, track_key)
	_populate_browse_tree()

	# Auto-save the file
	_save_math_facts_file()

func _clear_questions_list():
	"""Clear all question editors from the questions container"""
	for child in questions_container.get_children():
		child.queue_free()

func _create_inline_track_form():
	"""Create inline track creation form similar to questions tab"""
	var tracks_tab = $MainTabs/Tracks

	# Create the new track editor container
	var new_track_editor = VBoxContainer.new()
	new_track_editor.name = "NewTrackEditor"

	# Create header label
	var header_label = Label.new()
	header_label.text = "Create New Track:"
	header_label.name = "NewTrackLabel"

	# Create help tip
	var help_label = Label.new()
	help_label.text = "💡 Tracks organize questions by skill level and topic"
	help_label.modulate = Color(0.6, 0.6, 0.6)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Create form container (vertical layout like editing form)
	var form_container = GridContainer.new()
	form_container.name = "NewTrackForm"
	form_container.columns = 2

	# Track number label and input
	var number_label = Label.new()
	number_label.text = "Track Number:"
	var number_input = SpinBox.new()
	number_input.name = "NewTrackNumberInput"
	number_input.min_value = 1
	number_input.max_value = 999
	number_input.value = _get_next_track_number()
	number_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Track title label and input
	var title_label = Label.new()
	title_label.text = "Track Title:"
	var title_input = LineEdit.new()
	title_input.name = "NewTrackTitleInput"
	title_input.placeholder_text = "e.g., Addition Facts 0-5"
	title_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Grade label and selection
	var grade_label = Label.new()
	grade_label.text = "Grade:"
	var grade_option = OptionButton.new()
	grade_option.name = "NewTrackGradeOption"
	grade_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Add to form container
	form_container.add_child(number_label)
	form_container.add_child(number_input)
	form_container.add_child(title_label)
	form_container.add_child(title_input)
	form_container.add_child(grade_label)
	form_container.add_child(grade_option)

	# Create button container
	var button_container = HBoxContainer.new()
	var create_button = Button.new()
	create_button.name = "CreateTrackButton"
	create_button.text = "Create Track"
	create_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_container.add_child(create_button)

	new_track_editor.add_child(header_label)
	new_track_editor.add_child(help_label)
	new_track_editor.add_child(form_container)
	new_track_editor.add_child(button_container)

	# Add separator
	var separator = HSeparator.new()
	new_track_editor.add_child(separator)

	# Insert at the top of the tracks tab
	tracks_tab.add_child(new_track_editor)
	tracks_tab.move_child(new_track_editor, 0)

	# Store references
	new_track_number_input = number_input
	new_track_title_input = title_input
	new_track_grade_option = grade_option
	create_track_button = create_button

func _create_inline_grade_form():
	"""Create inline grade creation form similar to questions tab"""
	var grades_tab = $MainTabs/Grades

	# Create the new grade editor container
	var new_grade_editor = VBoxContainer.new()
	new_grade_editor.name = "NewGradeEditor"

	# Create header label
	var header_label = Label.new()
	header_label.text = "Create New Grade:"
	header_label.name = "NewGradeLabel"

	# Create help tip
	var help_label = Label.new()
	help_label.text = "💡 Grades group tracks by educational level"
	help_label.modulate = Color(0.6, 0.6, 0.6)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Create form container (vertical layout like editing form)
	var form_container = GridContainer.new()
	form_container.name = "NewGradeForm"
	form_container.columns = 2

	# Grade name label and input
	var name_label = Label.new()
	name_label.text = "Grade Name:"
	var name_input = LineEdit.new()
	name_input.name = "NewGradeNameInput"
	name_input.placeholder_text = "e.g., Grade 3"
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Grade key label and input
	var key_label = Label.new()
	key_label.text = "Grade Key:"
	var key_input = LineEdit.new()
	key_input.name = "NewGradeKeyInput"
	key_input.placeholder_text = "e.g., grade-3"
	key_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Add to form container
	form_container.add_child(name_label)
	form_container.add_child(name_input)
	form_container.add_child(key_label)
	form_container.add_child(key_input)

	# Create button container
	var button_container = HBoxContainer.new()
	var create_button = Button.new()
	create_button.name = "CreateGradeButton"
	create_button.text = "Create Grade"
	create_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_container.add_child(create_button)

	new_grade_editor.add_child(header_label)
	new_grade_editor.add_child(help_label)
	new_grade_editor.add_child(form_container)
	new_grade_editor.add_child(button_container)

	# Add separator
	var separator = HSeparator.new()
	new_grade_editor.add_child(separator)

	# Insert at the top of the grades tab
	grades_tab.add_child(new_grade_editor)
	grades_tab.move_child(new_grade_editor, 0)

	# Store references
	new_grade_name_input = name_input
	new_grade_key_input = key_input
	create_grade_button = create_button

# Compatibility function for plugin setup
func set_math_generator(generator):
	"""Called by plugin when setting up the dock"""
	math_generator = generator

func _setup_help_content():
	"""Create clean API documentation for developers"""
	var help_container = $MainTabs/Help/HelpContent

	# Clear any existing content
	for child in help_container.get_children():
		child.queue_free()

	_add_help_section(help_container, "Faster Math API", "Developer documentation for using the plugin in your Godot projects.", true)

	# Setup Section
	_add_help_section(help_container, "Getting Started",
		"The plugin is automatically loaded as an autoload named 'FasterMath'.\n\n" +
		"Basic Usage:\n" +
		"var question = FasterMath.get_math_question()\n" +
		"print(question.question)  # \"6 + 4\"\n" +
		"print(question.result)    # 10\n\n" +
		"Question Object Structure:\n" +
		"Every question returns a Dictionary with:\n" +
		"• question: String - The problem without answer\n" +
		"• result: Float - The correct answer\n" +
		"• expression: String - Complete equation\n" +
		"• operands: Array - Numbers used\n" +
		"• operator: String - Math symbol\n" +
		"• title: String - Track description\n" +
		"• grade: String - Grade level")

	# Core Functions
	_add_help_section(help_container, "Core Functions",
		"get_math_question(track=null, grade=null, operator=null, no_zeroes=false)\n" +
		"Get a random math question with optional filtering.\n\n" +
		"Parameters:\n" +
		"• track: int - Specific track number (5-12)\n" +
		"• grade: int - Grade level (1-5)\n" +
		"• operator: int - Math operation (0=+, 1=-, 2=×, 3=÷)\n" +
		"• no_zeroes: bool - Exclude problems with zero\n\n" +
		"Examples:\n" +
		"var q1 = FasterMath.get_math_question()  # Random\n" +
		"var q2 = FasterMath.get_math_question(null, null, 0)  # Addition only\n" +
		"var q3 = FasterMath.get_math_question(null, 2)  # Grade 2\n" +
		"var q4 = FasterMath.get_math_question(7)  # Track 7\n" +
		"var q5 = FasterMath.get_math_question(null, null, 2, true)  # Multiplication, no zeros")

	# Batch Functions
	_add_help_section(help_container, "Batch Functions",
		"get_multiple_questions(count, track=null, grade=null, operator=null, no_zeroes=false)\n" +
		"Generate multiple questions at once for quizzes.\n\n" +
		"Examples:\n" +
		"var quiz = FasterMath.get_multiple_questions(10)  # 10 random questions\n" +
		"var practice = FasterMath.get_multiple_questions(5, null, 1, 0)  # 5 Grade 1 addition\n\n" +
		"Process the questions:\n" +
		"for i in range(quiz.size()):\n" +
		"    var q = quiz[i]\n" +
		"    print(\"Q\", i+1, \": \", q.question, \" = ?\")\n\n" +
		"get_filtered_questions(track=null, grade=null, operator=null, no_zeroes=false, exclude_operands=[])\n" +
		"Get all questions matching criteria with advanced filtering.\n\n" +
		"Example:\n" +
		"var filtered = FasterMath.get_filtered_questions(null, 3, 0, false, [1, 2])")

	# Information Functions
	_add_help_section(help_container, "Information Functions",
		"get_available_tracks() -> Array\n" +
		"Returns array of available track numbers.\n" +
		"var tracks = FasterMath.get_available_tracks()\n\n" +
		"get_available_grades() -> Array\n" +
		"Returns array of available grade levels.\n" +
		"var grades = FasterMath.get_available_grades()\n\n" +
		"get_track_info(track_number) -> Dictionary\n" +
		"Get detailed information about a specific track.\n" +
		"var info = FasterMath.get_track_info(7)\n" +
		"print(info.title, info.grade, info.question_count)\n\n" +
		"get_all_tracks_info() -> Array\n" +
		"Get information about all available tracks.\n" +
		"var all_tracks = FasterMath.get_all_tracks_info()\n" +
		"for track in all_tracks:\n" +
		"    print(\"Track \", track.track, \": \", track.title)")

	# Utility Functions
	_add_help_section(help_container, "Utility Functions",
		"get_total_questions() -> int\n" +
		"Returns total number of questions in database.\n" +
		"var total = FasterMath.get_total_questions()\n\n" +
		"is_ready() -> bool\n" +
		"Check if plugin is loaded and ready to use.\n" +
		"if FasterMath.is_ready():\n" +
		"    var question = FasterMath.get_math_question()\n\n" +
		"get_statistics() -> Dictionary\n" +
		"Get comprehensive statistics about the database.\n" +
		"var stats = FasterMath.get_statistics()\n" +
		"print(\"Total questions: \", stats.total_questions)\n" +
		"print(\"Addition problems: \", stats.operators[\"+\"])")

	# Game Examples
	_add_help_section(help_container, "Game Integration Examples",
		"Math Quiz Game:\n" +
		"extends Control\n" +
		"var current_question\n" +
		"var score = 0\n\n" +
		"func next_question():\n" +
		"    current_question = FasterMath.get_math_question(null, 2, 0)\n" +
		"    if current_question:\n" +
		"        $QuestionLabel.text = current_question.question + \" = ?\"\n" +
		"        $AnswerInput.grab_focus()\n\n" +
		"func check_answer():\n" +
		"    var user_answer = int($AnswerInput.text)\n" +
		"    if user_answer == current_question.result:\n" +
		"        score += 1\n" +
		"        $FeedbackLabel.text = \"Correct!\"\n\n" +
		"Adaptive Difficulty:\n" +
		"var player_grade = 1\n" +
		"var consecutive_correct = 0\n\n" +
		"func on_correct_answer():\n" +
		"    consecutive_correct += 1\n" +
		"    if consecutive_correct >= 5 and player_grade < 5:\n" +
		"        player_grade += 1  # Level up!")

	# Quick Reference
	_add_help_section(help_container, "Quick Reference",
		"Operator Constants:\n" +
		"• 0 = Addition (+)\n" +
		"• 1 = Subtraction (-)\n" +
		"• 2 = Multiplication (×)\n" +
		"• 3 = Division (÷)\n\n" +
		"Grade Levels:\n" +
		"• 1 = Grade 1\n" +
		"• 2 = Grade 2\n" +
		"• 3 = Grade 3\n" +
		"• 4 = Grade 4\n" +
		"• 5+ = Grades 5 and Above\n\n" +
		"Autoload Name: FasterMath\n" +
		"Data File: res://addons/Faster Math/math-facts.json\n\n" +
		"Error Handling:\n" +
		"func safe_get_question(track = null, grade = null):\n" +
		"    if not FasterMath.is_ready():\n" +
		"        return null\n" +
		"    var question = FasterMath.get_math_question(track, grade)\n" +
		"    if question == null:\n" +
		"        question = FasterMath.get_math_question()\n" +
		"    return question")

func _add_help_section(container: VBoxContainer, title: String, content: String, is_header: bool = false):
	"""Add a help section with title and content - simple and clean"""
	# Add some spacing before sections (except first one)
	if container.get_child_count() > 0:
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 20)
		container.add_child(spacer)

	# Title
	var title_label = Label.new()
	title_label.text = title
	if is_header:
		title_label.add_theme_font_size_override("font_size", 52)  # 2x larger for main header (26 * 2)
		title_label.modulate = Color(0.4, 0.8, 1.0)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		title_label.add_theme_font_size_override("font_size", 40)  # 2x bigger section headers (20 * 2)
		title_label.modulate = Color(0.7, 0.9, 1.0)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(title_label)

	# 2x spacer after title
	var title_spacer = Control.new()
	title_spacer.custom_minimum_size = Vector2(0, 20)  # 2x spacing
	container.add_child(title_spacer)

	# Content - 2x larger text
	var content_label = Label.new()
	content_label.text = content
	content_label.add_theme_font_size_override("font_size", 30)  # 2x body text (15 * 2)
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	content_label.modulate = Color(0.85, 0.85, 0.85)
	content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(content_label)