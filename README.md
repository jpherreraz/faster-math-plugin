# Faster Math Generator

A smart math question generator addon for Godot that creates targeted practice problems organized by grade level, tracks, and operations. Provides instant access to thousands of math problems with flexible filtering options.

## Features

- **Grade-Based Organization**: Math problems organized by grade levels (1-5+)
- **Track System**: Problems categorized into different learning tracks (5-12)
- **Operation Filtering**: Filter problems by mathematical operations (addition, subtraction, multiplication, division)
- **Smart Generation**: Intelligent question generation with range support
- **Editor Integration**: Built-in dock panel for creating and managing questions
- **Batch Operations**: Create multiple questions at once using ranges
- **JSON Database**: Comprehensive math facts database

## Installation

1. Copy the `Faster Math` folder to your project's `addons` directory
2. Go to Project → Project Settings → Plugins
3. Find "Faster Math Generator" in the list and enable it
4. The addon will automatically add an autoload singleton and dock panel

## Usage

### In Editor

The dock panel provides a complete interface for managing math questions:

- **Browse Tab**: View and manage all questions, tracks, and grades in a tree structure
- **Questions Tab**: Add new questions with support for ranges (e.g., "0-5" to generate multiple questions)
- **Grades Tab**: Create and edit grade levels
- **Tracks Tab**: Create and edit learning tracks
- **Help Tab**: Complete API documentation

### In Code

The addon provides a global `FasterMath` singleton with comprehensive methods:

#### Core Functions

```gdscript
# Get a random math question with optional filtering
var question = FasterMath.get_math_question(track, grade, operator, no_zeroes)

# Examples:
var q1 = FasterMath.get_math_question()  # Random question
var q2 = FasterMath.get_math_question(null, null, 0)  # Addition only
var q3 = FasterMath.get_math_question(null, 2)  # Grade 2 problems
var q4 = FasterMath.get_math_question(7)  # Track 7 questions
var q5 = FasterMath.get_math_question(null, null, 2, true)  # Multiplication, no zeros
```

#### Question Object Structure

Every question returns a Dictionary with:
- `question`: String - The problem without answer (e.g., "6 + 4")
- `result`: Float - The correct answer (e.g., 10)
- `expression`: String - Complete equation (e.g., "6 + 4 = 10")
- `operands`: Array - Numbers used (e.g., [6, 4])
- `operator`: String - Math symbol (e.g., "+")
- `title`: String - Track description
- `grade`: String - Grade level

#### Batch Functions

```gdscript
# Generate multiple questions at once
var quiz = FasterMath.get_multiple_questions(10)  # 10 random questions
var practice = FasterMath.get_multiple_questions(5, null, 1, 0)  # 5 Grade 1 addition

# Get all questions matching criteria
var filtered = FasterMath.get_filtered_questions(track, grade, operator, no_zeroes, exclude_operands)
```

#### Information Functions

```gdscript
# Get available data
var tracks = FasterMath.get_available_tracks()  # Returns [5, 6, 7, 8, 9, 10, 11, 12]
var grades = FasterMath.get_available_grades()  # Returns [1, 2, 3, 4, 5]

# Get detailed track information
var track_info = FasterMath.get_track_info(7)
var all_tracks = FasterMath.get_all_tracks_info()

# Database statistics
var total = FasterMath.get_total_questions()
var stats = FasterMath.get_statistics()
```

#### Operator Constants

- `0` = Addition (+)
- `1` = Subtraction (-)
- `2` = Multiplication (×)
- `3` = Division (÷)

## Database Management

The editor dock provides a complete interface for managing the math facts database:

### Adding Questions

Use the Questions tab to add new questions. Supports:
- **Single questions**: Enter specific operands
- **Range generation**: Use "0-5" to generate all combinations
- **Smart constraints**: Leave operands empty and specify results to generate all valid combinations

### Managing Structure

- **Grades**: Create grade levels (must start with "grade-")
- **Tracks**: Create learning tracks within grades
- **Questions**: Add and edit individual math problems

All changes are automatically saved to the JSON database.

## File Structure

```
addons/Faster Math/
├── plugin.cfg          # Plugin configuration
├── plugin.gd           # Main plugin script
├── faster_math.gd      # Core math generator logic
├── dock.gd            # Editor dock interface
├── dock.tscn          # Dock scene
├── math-facts.json    # Math problems database
└── README.md          # This file
```

## Requirements

- Godot 4.x
- No external dependencies