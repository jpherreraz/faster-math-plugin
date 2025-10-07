extends Node

var math_facts = {}
var rng = RandomNumberGenerator.new()

func _ready():
	# Load and parse the math facts JSON
	var file = FileAccess.open("res://addons/Faster Math/math-facts.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			math_facts = json.data
			# Math facts loaded successfully
		else:
			# JSON parsing failed
			pass
	else:
		# Could not open math-facts.json
		pass

	# Initialize random number generator
	rng.randomize()

## Get the total number of questions available in the database
func get_total_questions() -> int:
	var total = 0
	for grade_key in math_facts.grades:
		var grade_data = math_facts.grades[grade_key]
		if grade_data.has("tracks"):
			for track_key in grade_data.tracks:
				var track_data = grade_data.tracks[track_key]
				total += track_data.facts.size()
	return total

## Get available tracks in the database
func get_available_tracks() -> Array:
	var tracks = []
	for grade_key in math_facts.grades:
		var grade_data = math_facts.grades[grade_key]
		if grade_data.has("tracks"):
			for track_key in grade_data.tracks:
				var track_number = int(track_key.replace("TRACK", ""))
				if track_number not in tracks:
					tracks.append(track_number)
	tracks.sort()
	return tracks

## Get available grades in the database
func get_available_grades() -> Array:
	var grades = []
	for grade_key in math_facts.grades:
		var grade_data = math_facts.grades[grade_key]
		var grade_number = extract_grade_number_from_key(grade_key)
		grades.append(grade_number)
	grades.sort()
	return grades

## Extract grade number from grade key (e.g., "grade-1" -> 1, "grade-5" -> 5)
func extract_grade_number_from_key(grade_key: String) -> int:
	if grade_key == "grade-5":
		return 5  # Represents "Grades 5 and Above"
	var parts = grade_key.split("-")
	if parts.size() > 1:
		return int(parts[1])
	return 1

## Get a random math question based on specified criteria
##
## Parameters:
## - track: Specific track number (5-12), takes priority over other parameters
## - grade: Grade level (1-5, where 5+ represents "Grades 5 and Above")
## - operator: Math operation (0=+, 1=-, 2=×, 3=÷)
## - no_zeroes: If true, excludes problems containing zero
##
## Returns a dictionary with:
## - question: The math problem without answer (e.g., "6 + 4")
## - expression: Complete problem with answer (e.g., "6 + 4 = 10")
## - operands: Array of numbers used (e.g., [6, 4])
## - operator: Math symbol (e.g., "+")
## - result: The correct answer (e.g., 10)
## - title: Description of the skill being practiced
## - grade: Grade level this problem is appropriate for
func get_math_question(track = null, grade = null, operator = null, no_zeroes = false):
	if not math_facts.has("grades"):
		# No math facts loaded
		return null

	var questions = []
	var question_title = ""
	var question_grade = ""

	# Priority: track > grade > operator
	if track != null:
		# Find questions from specific track
		var track_key = "TRACK" + str(track)
		for grade_key in math_facts.grades:
			var grade_data = math_facts.grades[grade_key]
			if grade_data.has("tracks") and grade_data.tracks.has(track_key):
				questions = grade_data.tracks[track_key].facts
				question_title = grade_data.tracks[track_key].title
				question_grade = grade_data.name
				break

		# If track not found, pick random existing track
		if questions.is_empty():
			var available_tracks = []
			for grade_key in math_facts.grades:
				var grade_data = math_facts.grades[grade_key]
				if grade_data.has("tracks"):
					for available_track_key in grade_data.tracks:
						if available_track_key not in available_tracks:
							available_tracks.append(available_track_key)

			if not available_tracks.is_empty():
				var random_track_key = available_tracks[rng.randi() % available_tracks.size()]
				for grade_key in math_facts.grades:
					var grade_data = math_facts.grades[grade_key]
					if grade_data.has("tracks") and grade_data.tracks.has(random_track_key):
						questions = grade_data.tracks[random_track_key].facts
						question_title = grade_data.tracks[random_track_key].title
						question_grade = grade_data.name
						break

	elif grade != null:
		# Handle grade selection
		var grade_key = ""
		if grade >= 5:
			grade_key = "grade-5"  # "Grades 5 and Above"
		else:
			grade_key = "grade-" + str(grade)

		if math_facts.grades.has(grade_key):
			var grade_data = math_facts.grades[grade_key]
			question_grade = grade_data.name

			# If operator is also specified, try to find questions with that operator
			if operator != null:
				var operator_str = get_operator_string(operator)
				var matching_questions = []
				var matching_title = ""

				for grade_track_key in grade_data.tracks:
					var track_data = grade_data.tracks[grade_track_key]
					for fact in track_data.facts:
						if fact.operator == operator_str:
							matching_questions.append(fact)
							if matching_title == "":
								matching_title = track_data.title

				if not matching_questions.is_empty():
					questions = matching_questions
					question_title = matching_title
				else:
					# Fallback: find closest grade with that operator
					var closest_result = find_closest_grade_with_operator(grade, operator)
					if not closest_result.questions.is_empty():
						questions = closest_result.questions
						question_title = "Closest grade match"
						question_grade = closest_result.grade_name
			else:
				# Get all questions from the grade
				for grade_track_key in grade_data.tracks:
					var track_data = grade_data.tracks[grade_track_key]
					questions.append_array(track_data.facts)
					if question_title == "":
						question_title = grade_data.name

	elif operator != null:
		# Get all questions with specific operator
		var operator_str = get_operator_string(operator)
		for grade_key in math_facts.grades:
			var grade_data = math_facts.grades[grade_key]
			if grade_data.has("tracks"):
				for op_track_key in grade_data.tracks:
					var track_data = grade_data.tracks[op_track_key]
					for fact in track_data.facts:
						if fact.operator == operator_str:
							questions.append(fact)
		question_title = "Operator: " + operator_str
		question_grade = "Mixed"

	# Filter out questions with zeroes if no_zeroes is true
	if no_zeroes:
		var filtered_questions = []
		for question in questions:
			var has_zero = false
			for operand in question.operands:
				if operand == 0:
					has_zero = true
					break
			if not has_zero:
				filtered_questions.append(question)
		questions = filtered_questions

	# Return random question from filtered results
	if questions.is_empty():
		# No questions found matching criteria
		return null

	var random_question = questions[rng.randi() % questions.size()]

	# Generate question without answer (format integers without decimals)
	var operand1 = int(random_question.operands[0]) if random_question.operands[0] == int(random_question.operands[0]) else random_question.operands[0]
	var operand2 = int(random_question.operands[1]) if random_question.operands[1] == int(random_question.operands[1]) else random_question.operands[1]
	var question_text = str(operand1) + " " + random_question.operator + " " + str(operand2)

	return {
		"operands": random_question.operands,
		"operator": random_question.operator,
		"result": random_question.result,
		"expression": random_question.expression,
		"question": question_text,
		"title": question_title,
		"grade": question_grade
	}

## Convert operator integer to string symbol
func get_operator_string(operator_int):
	match operator_int:
		0: return "+"
		1: return "-"
		2: return "x"
		3: return "/"
		_: return "+"

## Convert operator string to integer
func get_operator_number(operator_str: String) -> int:
	match operator_str:
		"+": return 0
		"-": return 1
		"x": return 2
		"/": return 3
		_: return 0

## Extract grade number from grade name (e.g., "Grade 1" -> 1)
func extract_grade_number(grade_name: String) -> int:
	if "5 and Above" in grade_name:
		return 5
	var parts = grade_name.split(" ")
	if parts.size() > 1:
		return int(parts[1])
	return 1

## Find the closest grade that has questions with the specified operator
func find_closest_grade_with_operator(target_grade, operator):
	var operator_str = get_operator_string(operator)
	var grade_distances = []

	# Check all grades for the operator
	for i in range(1, 6):  # grades 1-5
		var grade_key_to_find = ""
		if i >= 5:
			grade_key_to_find = "grade-5"
		else:
			grade_key_to_find = "grade-" + str(i)

		if math_facts.grades.has(grade_key_to_find):
			var grade_data_to_find = math_facts.grades[grade_key_to_find]
			var found_operator = false

			for closest_track_key in grade_data_to_find.tracks:
				var track_data = grade_data_to_find.tracks[closest_track_key]
				for fact in track_data.facts:
					if fact.operator == operator_str:
						found_operator = true
						break
				if found_operator:
					break

			if found_operator:
				var distance = abs(target_grade - i)
				grade_distances.append({"grade": i, "distance": distance})

	# Sort by distance and get closest
	grade_distances.sort_custom(func(a, b): return a.distance < b.distance)

	if grade_distances.is_empty():
		return {"questions": [], "grade_name": ""}

	var closest_grade = grade_distances[0].grade
	var grade_key = ""
	if closest_grade >= 5:
		grade_key = "grade-5"
	else:
		grade_key = "grade-" + str(closest_grade)

	var questions = []
	var grade_data = math_facts.grades[grade_key]
	for final_track_key in grade_data.tracks:
		var track_data = grade_data.tracks[final_track_key]
		for fact in track_data.facts:
			if fact.operator == operator_str:
				questions.append(fact)

	return {
		"questions": questions,
		"grade_name": grade_data.name
	}

## Get multiple math questions at once
## Useful for generating a batch of problems for quizzes or practice sessions
func get_multiple_questions(count: int, track = null, grade = null, operator = null, no_zeroes = false) -> Array:
	var questions = []
	for i in range(count):
		var question = get_math_question(track, grade, operator, no_zeroes)
		if question:
			questions.append(question)
	return questions

## Get track information (title, grade level, question count) for a specific track
func get_track_info(track_number: int) -> Dictionary:
	var track_key = "TRACK" + str(track_number)
	for grade_key in math_facts.grades:
		var grade_data = math_facts.grades[grade_key]
		if grade_data.has("tracks") and grade_data.tracks.has(track_key):
			var track_data = grade_data.tracks[track_key]
			return {
				"track": track_number,
				"title": track_data.title,
				"grade": grade_data.name,
				"question_count": track_data.facts.size()
			}
	return {}

## Get all available track information
func get_all_tracks_info() -> Array:
	var tracks_info = []
	var processed_tracks = []

	for grade_key in math_facts.grades:
		var grade_data = math_facts.grades[grade_key]
		if grade_data.has("tracks"):
			for track_key in grade_data.tracks:
				var track_number = int(track_key.replace("TRACK", ""))
				if track_number not in processed_tracks:
					processed_tracks.append(track_number)
					var track_data = grade_data.tracks[track_key]
					tracks_info.append({
						"track": track_number,
						"title": track_data.title,
						"grade": grade_data.name,
						"question_count": track_data.facts.size()
					})

	# Sort by track number
	tracks_info.sort_custom(func(a, b): return a.track < b.track)
	return tracks_info

## Get questions with specific criteria and filtering
## This is an extended version that provides more filtering options
func get_filtered_questions(track = null, grade = null, operator = null, no_zeroes = false, exclude_operands = []) -> Array:
	var questions = []

	# Get base questions using existing logic
	var base_question = get_math_question(track, grade, operator, no_zeroes)
	if not base_question:
		return []

	# Get all questions that match the same criteria
	var questions_pool = []
	if track != null:
		var track_key = "TRACK" + str(track)
		for grade_key in math_facts.grades:
			var grade_data = math_facts.grades[grade_key]
			if grade_data.has("tracks") and grade_data.tracks.has(track_key):
				questions_pool = grade_data.tracks[track_key].facts
				break
	elif grade != null:
		var grade_key = ""
		if grade >= 5:
			grade_key = "grade-5"
		else:
			grade_key = "grade-" + str(grade)

		if math_facts.grades.has(grade_key):
			var grade_data = math_facts.grades[grade_key]
			for grade_track_key in grade_data.tracks:
				var track_data = grade_data.tracks[grade_track_key]
				questions_pool.append_array(track_data.facts)

	# Apply filters
	for question in questions_pool:
		var include_question = true

		# Filter by operator if specified
		if operator != null:
			var operator_str = get_operator_string(operator)
			if question.operator != operator_str:
				include_question = false

		# Filter out zeroes if requested
		if no_zeroes and include_question:
			for operand in question.operands:
				if operand == 0:
					include_question = false
					break

		# Filter out excluded operands if requested
		if include_question and exclude_operands.size() > 0:
			for operand in question.operands:
				if operand in exclude_operands:
					include_question = false
					break

		if include_question:
			# Format the question the same way as get_math_question()
			var operand1 = int(question.operands[0]) if question.operands[0] == int(question.operands[0]) else question.operands[0]
			var operand2 = int(question.operands[1]) if question.operands[1] == int(question.operands[1]) else question.operands[1]
			var question_text = str(operand1) + " " + question.operator + " " + str(operand2)

			questions.append({
				"operands": question.operands,
				"operator": question.operator,
				"result": question.result,
				"expression": question.expression,
				"question": question_text,
				"title": base_question.title,
				"grade": base_question.grade
			})

	return questions

## Parse input string to determine if it's a single value or range
## Returns: {"is_range": bool, "values": Array}
func parse_input(input_str: String) -> Dictionary:
	var trimmed = input_str.strip_edges()

	# Check if it contains a dash (range format)
	if "-" in trimmed and not trimmed.begins_with("-"):
		var parts = trimmed.split("-")
		if parts.size() == 2:
			var start_str = parts[0].strip_edges()
			var end_str = parts[1].strip_edges()

			if start_str.is_valid_float() and end_str.is_valid_float():
				var start_val = int(float(start_str))
				var end_val = int(float(end_str))

				if start_val <= end_val:
					var values = []
					for i in range(start_val, end_val + 1):
						values.append(i)
					return {"is_range": true, "values": values}

	# Single value or invalid range
	if trimmed.is_valid_float():
		return {"is_range": false, "values": [int(float(trimmed))]}

	# Invalid input
	return {"is_range": false, "values": []}

## Generate questions based on range inputs for operands and optional result constraint
## Parameters:
## - op1_values: Array of possible first operand values
## - op2_values: Array of possible second operand values
## - operator: Math operation (0=+, 1=-, 2=x, 3=/)
## - result_values: Optional array of allowed result values (null = no constraint)
## Returns: Array of question dictionaries
func generate_questions_from_ranges(op1_values: Array, op2_values: Array, operator: int, result_values: Array = []) -> Array:
	var questions = []
	var operator_str = get_operator_string(operator)
	var ui_operators = ["+", "-", "×", "÷"]
	var display_operator = ui_operators[operator]

	for op1 in op1_values:
		for op2 in op2_values:
			var result = _calculate_result(op1, op2, operator)

			# Skip invalid operations
			if result == null:
				continue

			# Check result constraint if specified
			if result_values.size() > 0 and result not in result_values:
				continue

			# Format the question
			var op1_str = str(op1)
			var op2_str = str(op2)
			var result_str = str(int(result)) if result == int(result) else str(result)
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

	return questions

## Calculate result for given operands and operator
## Returns null for invalid operations (like division by zero or non-integer division)
func _calculate_result(op1: float, op2: float, operator: int) -> Variant:
	match operator:
		0: # Addition
			return op1 + op2
		1: # Subtraction
			var result = op1 - op2
			return result if result >= 0 else null  # No negative results
		2: # Multiplication
			return op1 * op2
		3: # Division
			if op2 == 0:
				return null  # No division by zero
			var result = op1 / op2
			return result if result == int(result) else null  # Only integer results
		_:
			return null

## Validate range input constraints for mathematical correctness
## Returns: {"valid": bool, "error": String}
func validate_range_constraints(op1_values: Array, op2_values: Array, operator: int, result_values: Array = []) -> Dictionary:
	# Check for basic invalid cases
	if op1_values.is_empty() or op2_values.is_empty():
		return {"valid": false, "error": "Operand ranges cannot be empty"}

	match operator:
		1: # Subtraction - need to ensure some valid non-negative results exist
			var has_valid = false
			for op1 in op1_values:
				for op2 in op2_values:
					if op1 >= op2:
						has_valid = true
						break
				if has_valid:
					break
			if not has_valid:
				return {"valid": false, "error": "No valid non-negative subtraction results possible with these ranges"}

		3: # Division - need to ensure some integer results exist and no division by zero
			if 0 in op2_values:
				return {"valid": false, "error": "Division by zero not allowed - second operand range cannot include 0"}

			var has_valid = false
			for op1 in op1_values:
				for op2 in op2_values:
					if op2 != 0 and (op1 % op2) == 0:
						has_valid = true
						break
				if has_valid:
					break
			if not has_valid:
				return {"valid": false, "error": "No valid integer division results possible with these ranges"}

	return {"valid": true, "error": ""}

## Check if the plugin is ready and math facts are loaded
func is_ready() -> bool:
	return math_facts.has("grades") and not math_facts.grades.is_empty()

## Get statistics about the loaded math facts
func get_statistics() -> Dictionary:
	if not is_ready():
		return {}

	var stats = {
		"total_questions": get_total_questions(),
		"total_grades": math_facts.grades.size(),
		"total_tracks": get_available_tracks().size(),
		"grades": get_available_grades(),
		"tracks": get_available_tracks()
	}

	# Count questions by operator
	var operator_counts = {"+": 0, "-": 0, "x": 0, "/": 0}
	for grade_key in math_facts.grades:
		var grade_data = math_facts.grades[grade_key]
		if grade_data.has("tracks"):
			for track_key in grade_data.tracks:
				var track_data = grade_data.tracks[track_key]
				for fact in track_data.facts:
					if operator_counts.has(fact.operator):
						operator_counts[fact.operator] += 1

	stats["operators"] = operator_counts
	return stats