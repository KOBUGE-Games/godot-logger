# Copyright (c) 2016 KOBUGE Games
# Distributed under the terms of the MIT license.
# https://github.com/KOBUGE-Games/godot-logger/blob/master/LICENSE.md
#
# Upstream repo: https://github.com/KOBUGE-Games/godot-logger

extends Node # Needed to work as a singleton

### Inner classes

class Logfile:
	# TODO: Godot doesn't support docstrings for inner classes, GoDoIt (GH-1320)
	# """Class for log files that can be shared between various modules."""
	var file = null
	var path = ""
	var queue_mode = QUEUE_NONE
	var buffer = StringArray()
	var buffer_idx = 0

	func _init(_path):
		file = File.new()
		set_path(_path)
		buffer.resize(FILE_BUFFER_SIZE)

	func set_path(new_path):
		if new_path == path:
			return # Spare ourselves some needless checks
		if validate_path(new_path):
			path = new_path

	func get_path():
		return path

	func set_queue_mode(new_mode):
		queue_mode = new_mode

	func get_queue_mode():
		return queue_mode

	func get_write_mode():
		if not file.file_exists(path):
			return File.WRITE # create
		else:
			return File.READ_WRITE # append

	func validate_path(path):
		"""Validate the path given as argument, making it possible to write to
		the designated file or folder. Returns whether the path is valid."""
		if !(path.is_abs_path() or path.is_rel_path()):
			print("[ERROR] [logger] The given path '%s' is not valid." % path)
			return false
		var dir = Directory.new()
		var base_dir = path.get_base_dir()
		if not dir.dir_exists(base_dir):
			# TODO: Move directory creation to the function that will actually *write*
			# TODO: make_dir_recursive seems broken, change that once it's fixed
			#var err = dir.make_dir_recursive(base_dir)
			var err = dir.make_dir(base_dir)
			if err:
				print("[ERROR] [logger] Could not create the '%s' directory; exited with error %d." \
						% [base_dir, err])
				return false
			else:
				print("[INFO] [logger] Successfully created the '%s' directory." % base_dir)
		return true

	func flush_buffer():
		"""Flush the buffer, i.e. write its contents to the target file."""
		var err = file.open(path, get_write_mode())
		if err:
			print("[ERROR] [logger] Could not open the '%s' log file; exited with error %d." \
					% [path, err])
			return
		file.seek_end()
		for i in range(buffer_idx):
			file.store_line(buffer[i])
		file.close()
		buffer_idx = 0 # We don't clear the memory, we'll just overwrite it

	func write(output, level):
		"""Write the string at the end of the file (append mode), following
		the queue mode."""
		var queue_action = queue_mode
		if queue_action == QUEUE_SMART:
			if level >= WARN: # Don't queue warnings and errors
				queue_action = QUEUE_NONE
				flush_buffer()
			else: # Queue the log, not important enough for "smart"
				queue_action = QUEUE_ALL

		if queue_action == QUEUE_NONE:
			var err = file.open(path, get_write_mode())
			if err:
				print("[ERROR] [logger] Could not open the '%s' log file; exited with error %d." \
						% [path, err])
				return
			file.seek_end()
			file.store_line(output)
			file.close()

		if queue_action == QUEUE_ALL:
			buffer[buffer_idx] = output
			buffer_idx += 1
			if buffer_idx >= FILE_BUFFER_SIZE:
				flush_buffer()

### Constants

# Logging levels - the array and the integers should be matching
const LEVELS = ["VERBOSE", "DEBUG", "INFO", "WARN", "ERROR"]
const VERBOSE = 0
const DEBUG = 1
const INFO = 2
const WARN = 3
const ERROR = 4

# Output strategies
const STRATEGY_MUTE = 0
const STRATEGY_PRINT = 1
const STRATEGY_FILE = 2
const STRATEGY_MEMORY = 4
const MAX_STRATEGY = STRATEGY_MEMORY*2 - 1

# Default module config
const DEFAULT_MODULE = {
  "output_level": null,
  "output_strategies": [null, null, null, null, null],
  "logfile": null,
}

# Output format identifiers
const FORMAT_IDS = {
  "level": "{LVL}",
  "module": "{MOD}",
  "message": "{MSG}"
}

# Queue modes
const QUEUE_NONE = 0
const QUEUE_ALL = 1
const QUEUE_SMART = 2

const FILE_BUFFER_SIZE = 30

### Variables

# Configuration
var default_output_level = INFO
# TODO: Find (or implement in Godot) a more clever way to achieve that
var default_output_strategies = [STRATEGY_PRINT, STRATEGY_PRINT, STRATEGY_PRINT, STRATEGY_PRINT, STRATEGY_PRINT]
# e.g. "[INFO] [main] The young alpaca started growing a goatie."
var output_format = "[{LVL}] [{MOD}] {MSG}"
var default_logfile_path = "user://" + Globals.get("application/name") + ".log"
var default_logfile = null
var max_remembered_messages = 30

# Holds default and custom modules defined by the user
# Default modules are initialized in _init
var modules = {
  "logger": DEFAULT_MODULE,
  "main": DEFAULT_MODULE
}

### Functions

func put(level, message, module = "main"):
	"""Log a message in the given module with the given logging level."""
	var output_strategy = get_module_output_strategy(module, level)
	if output_strategy == STRATEGY_MUTE or get_module_output_level(module) > level:
		return # Out of scope

	var output = output_format
	output = output.replace(FORMAT_IDS.level, LEVELS[level])
	output = output.replace(FORMAT_IDS.module, module)
	output = output.replace(FORMAT_IDS.message, message)

	if output_strategy & STRATEGY_PRINT:
		print(output)

	if output_strategy & STRATEGY_FILE:
		modules[module].logfile.write(output, level)

	if output_strategy & STRATEGY_MEMORY:
		pass # TODO: Implement support for MEMORY strategy

# Helper functions for each level

func verbose(message, module = "main"):
	"""Log a message in the given module with level VERBOSE."""
	put(VERBOSE, message, module)

func debug(message, module = "main"):
	"""Log a message in the given module with level DEBUG."""
	put(DEBUG, message, module)

func info(message, module = "main"):
	"""Log a message in the given module with level INFO."""
	put(INFO, message, module)

func warn(message, module = "main"):
	"""Log a message in the given module with level WARN."""
	put(WARN, message, module)

func error(message, module = "main"):
	"""Log a message in the given module with level ERROR."""
	put(ERROR, message, module)

# Output configuration

func set_default_output_strategy(output_strategy_mask, level = -1):
	"""Set the default output strategy mask of the given level or (by
	default) all levels for all modules without a custom strategy."""
	if not output_strategy_mask in range(0, MAX_STRATEGY + 1):
		error("The output strategy mask must be comprised between 0 and %d." \
				% MAX_STRATEGY, "logger")
		return
	if level == -1: # Set for all levels
		for i in range(0, LEVELS.size()):
			default_output_strategies[i] = output_strategy_mask
		info("The default output strategy mask was set to '%d' for all levels." \
				% [output_strategy_mask], "logger")
	else:
		if not level in range(0, LEVELS.size()):
			error("The level must be comprised between 0 and %d." % LEVELS.size() - 1, "logger")
			return
		default_output_strategies[level] = output_strategy_mask
		info("The default output strategy mask was set to '%d' for the '%s' level." \
				% [output_strategy_mask, LEVELS[level]], "logger")

func get_default_output_strategy(level):
	"""Get the default output strategy mask of the given level or (by
	default) all levels for all modules without a custom strategy."""
	return default_output_strategies[level]

func set_module_output_strategy(module, output_strategy_mask, level = -1):
	"""Set the custom output strategy mask of the given level or (by
	default) all levels for the given module."""
	if not output_strategy_mask in range(0, MAX_STRATEGY + 1):
		error("The output strategy mask must be comprised between 0 and %d." \
				% MAX_STRATEGY, "logger")
		return
	if level == -1: # Set for all levels
		for i in range(0, LEVELS.size()):
			modules[module].output_strategies[i] = output_strategy_mask
		info("The '%s' module's output strategy mask was set to '%d' for all levels." \
				% [module, output_strategy_mask], "logger")
	else:
		if not level in range(0, LEVELS.size()):
			error("The level must be comprised between 0 and %d." % LEVELS.size() - 1, "logger")
			return
		modules[module].output_strategies[level] = output_strategy_mask
		info("The '%s' module's output strategy mask was set to '%d' for the '%s' level." \
				% [module, output_strategy_mask, LEVELS[level]], "logger")

func get_module_output_strategy(module, level):
	"""Get the custom output strategy mask of the given level or (by
	default) all levels for the given module."""
	if modules[module].output_strategies[level] == null:
		return get_default_output_strategy(level)
	else:
		return modules[module].output_strategies[level]

func set_default_output_level(level):
	"""Set the default minimal level for the output of all modules without
	a custom output level.
	All levels greater or equal to the given once will be output based on
	their respective strategies, while levels lower than the given one will
	be discarded.
	"""
	if not level in range(0, LEVELS.size()):
		error("The level must be comprised between 0 and %d." % LEVELS.size() - 1, "logger")
		return
	default_output_level = level
	info("The default output level was set to '%s'." % LEVELS[level], "logger")

func get_default_output_level():
	"""Get the default minimal level for the output of all modules without
	a custom output level."""
	return default_output_level

func set_module_output_level(module, level):
	"""Set the custom minimal level for the output of the given module.
	All levels greater or equal to the given once will be output based on
	their respective strategies, while levels lower than the given one will
	be discarded.
	"""
	if not level in range(0, LEVELS.size()):
		error("The level must be comprised between 0 and %d." % LEVELS.size() - 1, "logger")
		return
	modules[module].output_level = level
	info("The '%s' module's output level was set to '%s'." % [module, LEVELS[level]], "logger")

func get_module_output_level(module):
	"""Get the custom minimal level for the output of the given module."""
	if modules[module].output_level == null:
		return get_default_output_level()
	else:
		return modules[module].output_level

func set_output_format(new_format):
	"""Set the output string format using the following identifiers:
	{LVL} for the level, {MOD} for the module, {MSG} for the message.
	The three identifiers should be contained in the output format string.
	"""
	for key in FORMAT_IDS:
		if new_format.find(FORMAT_IDS[key]) == -1:
			error("Invalid output string format. It lacks the '%s' identifier." \
					% FORMAT_IDS[key], "logger")
			return
	output_format = new_format
	info("Successfully changed the output format to '%s'." % output_format, "logger")

func get_output_format():
	"""Get the output string format."""
	return output_format

# Specific to STRATEGY_FILE

func set_module_logfile(module, logfile):
	"""Set the Logfile instance for the given module."""
	if logfile == modules[module].logfile:
		return # Spare ourselves some needless checks
	modules[module].logfile = logfile

func get_module_logfile(module):
	"""Get the Logfile instance for the given module."""
	if modules[module].logfile == null:
		return get_default_logfile()
	else:
		return modules[module].logfile

# Specific to STRATEGY_MEMORY

func set_max_remembered_messages(max_messages):
	"""Set the maximum amount of messages to be remembered when
	using the STRATEGY_MEMORY output strategy."""
	if max_messages <= 0:
		error("The maximum amount of remembered messages must be a positive non-null integer. Received %d." \
				% max_messages, "logger")
		return
	max_remembered_messages = max_messages
	info("Successfully set the maximum amount of remembered messages to %d." % max_remembered_messages, "logger")

func get_max_remembered_messages():
	"""Get the maximum amount of messages to be remembered when
	using the STRATEGY_MEMORY output strategy."""
	return max_remembered_messages

### Callbacks

func _init():
	default_logfile = Logfile.new(default_logfile_path)
	for key in modules:
		modules[key].logfile = default_logfile
