# Copyright (c) 2016 KOBUGE Games
# Distributed under the terms of the MIT license.
# https://github.com/KOBUGE-Games/godot-logger/blob/master/LICENSE.md
#
# Upstream repo: https://github.com/KOBUGE-Games/godot-logger

extends Node # Needed to work as a singleton

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

# Output format identifiers
const FORMAT_IDS = {
  "level": "{LVL}",
  "module": "{MOD}",
  "message": "{MSG}"
}

### Variables

# e.g. "[INFO] [main] The young alpaca started growing a goatie."
var output_format = "[{LVL}] [{MOD}] {MSG}"

### Functions

func put(level, message, module = "main"):
	"""Log a message in the given module with the given logging level."""
	var output = output_format
	output = output.replace(FORMAT_IDS.level, LEVELS[level])
	output = output.replace(FORMAT_IDS.module, module)
	output = output.replace(FORMAT_IDS.message, message)
	# TODO: Implement proper support for all strategies
	print(output)

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

func set_output_strategy_mask(output_strategy_mask, level = -1, module = "*"):
	"""Set the output strategy mask of the given level and module or (by
	default) of all modules to the given strategies."""
	pass

func get_output_strategy_mask(level, module = "*"):
	"""Get the output strategy mask of the given level and module or (by
	default) of all modules."""
	pass

func set_minimum_output_level(level, module = "*"):
	"""Set the minimal level for the output of the given module or (by
	default) of all modules.
	All levels greater or equal to the given once will be output based on
	their respective strategies, while levels lower than the given one will
	be discarded.
	"""
	pass

func get_minimum_output_level(module = "*"):
	"""Get the defined minimal level for the output of the given module or
	(by default) or all modules."""
	pass

func set_output_format(new_format):
	"""Set the output string format using the following identifiers:
	{LVL} for the level, {MOD} for the module, {MSG} for the message.
	The three identifiers should be contained in the output format string.
	"""
	for key in FORMAT_IDS:
		if new_format.find(FORMAT_IDS[key]) == -1:
			error("Invalid output string format. It lacks the '%s' identifier." % FORMAT_IDS[key], "logger")
			return
	output_format = new_format
	info("Successfully changed the output format to '%s'." % output_format, "logger")

func get_output_format():
	"""Get the output string format."""
	return output_format

# Specific to STRATEGY_FILE

func set_logfile_path(path, module = "*"):
	"""Set the path to the log file for the given module or (by default)
	for all modules."""
	pass

func get_logfile_path(module = "*"):
	"""Get the path to the log file for the given module or (by default)
	for all modules."""
	pass

# Specific to STRATEGY_MEMORY

func set_max_remembered_messages(max_messages):
	"""Set the maximum amount of messages to be remembered when
	using the STRATEGY_MEMORY output strategy."""
	pass

func get_max_remembered_messages():
	"""Get the maximum amount of messages to be remembered when
	using the STRATEGY_MEMORY output strategy."""
	pass

# Queue management

func set_queue_mode(queue_mode):
	"""Set which messages would be queued before being written to file.
	Might improve performance with too many VERBOSE or DEBUG prints."""
	pass

func get_queue_mode():
	"""Get which messages are queued before being written to file."""
	pass
