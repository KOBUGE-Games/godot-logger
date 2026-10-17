# Copyright (c) 2016 KOBUGE Games
# Distributed under the terms of the MIT license.
# https://github.com/KOBUGE-Games/godot-logger/blob/master/LICENSE.md
#
# Upstream repo: https://github.com/KOBUGE-Games/godot-logger

extends Node  # Needed to work as a singleton

##================##
## Inner classes  ##
##================##


class ExternalSink:
	## Queue modes
	enum QUEUE_MODES {
		NONE = 0,
		ALL = 1,
		SMART = 2,
	}

	var name: String
	var queue_mode: QUEUE_MODES
	var buffer: PackedStringArray = PackedStringArray()
	var buffer_idx: int = 0


	func _init(_name: String, _queue_mode: QUEUE_MODES = QUEUE_MODES.NONE) -> void:
		name = _name
		queue_mode = _queue_mode


	## Flush the buffer, i.e. write its contents to the target external sink.
	func flush_buffer() -> void:
		print("[ERROR] [logger] Using method which has to be overriden in your custom sink")


	## Write the string at the end of the sink (append mode), following
	## the queue mode.
	func write(_output: String, _level: int) -> void:
		print("[ERROR] [logger] Using method which has to be overriden in your custom sink")


	func set_queue_mode(new_mode: QUEUE_MODES) -> void:
		queue_mode = new_mode


	func get_queue_mode() -> QUEUE_MODES:
		return queue_mode


	func get_name() -> String:
		return name


	func get_config() -> Dictionary:
		return {
			"queue_mode": get_queue_mode(),
		}


## Class for log files that can be shared between various modules.
class Logfile extends ExternalSink:
	const FILE_BUFFER_SIZE: int = 30
	var path: String = ""


	func _init(_path: String, _queue_mode = QUEUE_MODES.NONE):
		super(_path, _queue_mode)
		if validate_path(_path):
			path = _path
		buffer.resize(FILE_BUFFER_SIZE)


	func get_path() -> String:
		return path


	func get_write_mode() -> FileAccess.ModeFlags:
		if not FileAccess.file_exists(path):
			return FileAccess.WRITE  # create
		else:
			return FileAccess.READ_WRITE  # append


	## Validate the path given as argument, making it possible to write to
	## the designated file or folder. Returns whether the path is valid.
	func validate_path(_path: String) -> bool:
		if not (_path.is_absolute_path() or _path.is_relative_path()):
			print("[ERROR] [logger] The given path '%s' is not valid." % _path)
			return false
		var base_dir: String = _path.get_base_dir()
		var dir: DirAccess = DirAccess.open(base_dir)
		if not dir:
			var err: int = DirAccess.get_open_error()
			if err:
				print("[ERROR] [logger] Could not create the '%s' directory; exited with error %d." % [base_dir, err])
				return false
			else:
				# TODO: Move directory creation to the function that will actually *write*
				dir.make_dir_recursive(base_dir)
				var err2: int = DirAccess.get_open_error()
				if err2:
					print("[ERROR] [logger] Could not create the '%s' directory; exited with error %d." % [base_dir, err2])
					return false

				print("[INFO] [logger] Successfully created the '%s' directory." % base_dir)
		return true


	## Flush the buffer, i.e. write its contents to the target file.
	func flush_buffer() -> void:
		if buffer_idx == 0:
			return  # Nothing to write
		var temp_file: FileAccess = _open_file(path)
		if temp_file:
			temp_file.seek_end()
			for i in range(buffer_idx):
				temp_file.store_line(buffer[i])
			temp_file.close()
			buffer_idx = 0  # We don't clear the memory, we'll just overwrite it


	## Write the string at the end of the file (append mode), following
	## the queue mode.
	func write(output: String, level: int):
		var queue_action: QUEUE_MODES = queue_mode
		if queue_action == QUEUE_MODES.SMART:
			if level >= WARN:  # Don't queue warnings and errors
				queue_action = QUEUE_MODES.NONE
				flush_buffer()
			else:  # Queue the log, not important enough for "smart"
				queue_action = QUEUE_MODES.ALL

		if queue_action == QUEUE_MODES.NONE:
			var temp_file: FileAccess = _open_file(path)
			if temp_file == null:
				return
			else:
				temp_file.seek_end()
				temp_file.store_line(output)
				temp_file.close()

		if queue_action == QUEUE_MODES.ALL:
			buffer[buffer_idx] = output
			buffer_idx += 1
			if buffer_idx >= FILE_BUFFER_SIZE:
				flush_buffer()


	func get_config() -> Dictionary:
		return {
			"path": get_path(),
			"queue_mode": get_queue_mode(),
		}


	func _open_file(_path: String) -> FileAccess:
		var result: FileAccess = FileAccess.open(_path, get_write_mode())

		if result == null:
			var err: int = FileAccess.get_open_error()
			print("[ERROR] [logger] Could not open the '%s' log file; exited with error %d." % [_path, err])
			return null
		else:
			return result


## Class for customizable logging modules.
class Module:
	var name: String = ""
	var output_level: int = 0
	var output_strategies: Array = []
	var external_sink: ExternalSink = null

	func _init(_name: String, _output_level: int, _output_strategies: Variant, _external_sink: ExternalSink) -> void:
		name = _name
		set_output_level(_output_level)

		if typeof(_output_strategies) == TYPE_INT:  # Only one strategy, use it for all
			for i in range(0, LEVELS.size()):
				output_strategies.append(_output_strategies)
		else:
			for strategy in _output_strategies:  # Need to force deep copy
				output_strategies.append(strategy)

		set_external_sink(_external_sink)


	func get_name() -> String:
		return name


	## Set the custom minimal level for the output of the module.
	## All levels greater or equal to the given once will be output based
	## on their respective strategies, while levels lower than the given one
	## will be discarded.
	func set_output_level(level: int) -> void:
		if not level in range(0, LEVELS.size()):
			print("[ERROR] [%s] The level must be comprised between 0 and %d." % [PLUGIN_NAME, LEVELS.size() - 1])
			return
		output_level = level


	func get_output_level() -> int:
		return output_level


	## Set the common output strategy mask for all levels of the module.
	func set_common_output_strategy(output_strategy_mask: int) -> void:
		if not output_strategy_mask in range(0, MAX_STRATEGY + 1):
			print("[ERROR] [%s] The output strategy mask must be comprised between 0 and %d." % [PLUGIN_NAME, MAX_STRATEGY])
			return
		for i in range(0, LEVELS.size()):
			output_strategies[i] = output_strategy_mask


	## Set the output strategy for the given level or (by default) all
	## levels of the module.
	func set_output_strategy(output_strategy_mask: int, level: int = -1) -> void:
		if not output_strategy_mask in range(0, MAX_STRATEGY + 1):
			print("[ERROR] [%s] The output strategy mask must be comprised between 0 and %d." % [PLUGIN_NAME, MAX_STRATEGY])
			return
		if level == -1:  # Set for all levels
			for i in range(0, LEVELS.size()):
				output_strategies[i] = output_strategy_mask
		else:
			if not level in range(0, LEVELS.size()):
				print("[ERROR] [%s] The level must be comprised between 0 and %d." % [PLUGIN_NAME, LEVELS.size() - 1])
				return
			output_strategies[level] = output_strategy_mask


	func get_output_strategy(level: int = -1) -> Variant:
		if level == -1:
			return output_strategies
		else:
			return output_strategies[level]


	## Set the external sink instance for the module.
	func set_external_sink(new_external_sink: ExternalSink) -> void:
		external_sink = new_external_sink


	func get_external_sink() -> ExternalSink:
		return external_sink


	func get_config() -> Dictionary:
		return {
			"name": get_name(),
			"output_level": get_output_level(),
			"output_strategies": get_output_strategy(),
			"external_sink": get_external_sink().get_config(),
		}


##=============##
##  Constants  ##
##=============##

const PLUGIN_NAME: String = "logger"

# Logging levels - the array and the integers should be matching
const LEVELS: Array[String] = ["VERBOSE", "DEBUG", "INFO", "WARN", "ERROR"]
const VERBOSE: int = 0
const DEBUG: int = 1
const INFO: int = 2
const WARN: int = 3
const ERROR: int = 4

# Output strategies
const STRATEGY_MUTE: int = 0
const STRATEGY_PRINT: int = 1
const STRATEGY_EXTERNAL_SINK: int = 2
const STRATEGY_PRINT_AND_EXTERNAL_SINK: int = STRATEGY_PRINT | STRATEGY_EXTERNAL_SINK
const STRATEGY_MEMORY: int = 4
const MAX_STRATEGY: int = STRATEGY_MEMORY * 2 - 1

# Output format identifiers
const FORMAT_IDS: Dictionary[String, String] = {
	"level": "{LVL}",
	"module": "{MOD}",
	"message": "{MSG}",
	"time": "{TIME}",
	"error_message": "{ERR_MSG}",
}

## Maps Error code to strings.
## This might eventually be supported out of the box in Godot,
## so we'll be able to drop this.
const ERROR_MESSAGES: Dictionary[int, String] = {
	OK: "OK.",
	FAILED: "Generic error.",
	ERR_UNAVAILABLE: "Unavailable error.",
	ERR_UNCONFIGURED: "Unconfigured error.",
	ERR_UNAUTHORIZED: "Unauthorized error.",
	ERR_PARAMETER_RANGE_ERROR: "Parameter range error.",
	ERR_OUT_OF_MEMORY: "Out of memory (OOM) error.",
	ERR_FILE_NOT_FOUND: "File: Not found error.",
	ERR_FILE_BAD_DRIVE: "File: Bad drive error.",
	ERR_FILE_BAD_PATH: "File: Bad path error.",
	ERR_FILE_NO_PERMISSION: "File: No permission error.",
	ERR_FILE_ALREADY_IN_USE: "File: Already in use error.",
	ERR_FILE_CANT_OPEN: "File: Can't open error.",
	ERR_FILE_CANT_WRITE: "File: Can't write error.",
	ERR_FILE_CANT_READ: "File: Can't read error.",
	ERR_FILE_UNRECOGNIZED: "File: Unrecognized error.",
	ERR_FILE_CORRUPT: "File: Corrupt error.",
	ERR_FILE_MISSING_DEPENDENCIES: "File: Missing dependencies error.",
	ERR_FILE_EOF: "File: End of file (EOF) error.",
	ERR_CANT_OPEN: "Can't open error.",
	ERR_CANT_CREATE: "Can't create error.",
	ERR_QUERY_FAILED: "Query failed error.",
	ERR_ALREADY_IN_USE: "Already in use error.",
	ERR_LOCKED: "Locked error.",
	ERR_TIMEOUT: "Timeout error.",
	ERR_CANT_CONNECT: "Can't connect error.",
	ERR_CANT_RESOLVE: "Can't resolve error.",
	ERR_CONNECTION_ERROR: "Connection error.",
	ERR_CANT_ACQUIRE_RESOURCE: "Can't acquire resource error.",
	ERR_CANT_FORK: "Can't fork process error.",
	ERR_INVALID_DATA: "Invalid data error.",
	ERR_INVALID_PARAMETER: "Invalid parameter error.",
	ERR_ALREADY_EXISTS: "Already exists error.",
	ERR_DOES_NOT_EXIST: "Does not exist error.",
	ERR_DATABASE_CANT_READ: "Database: Read error.",
	ERR_DATABASE_CANT_WRITE: "Database: Write error.",
	ERR_COMPILATION_FAILED: "Compilation failed error.",
	ERR_METHOD_NOT_FOUND: "Method not found error.",
	ERR_LINK_FAILED: "Linking failed error.",
	ERR_SCRIPT_FAILED: "Script failed error.",
	ERR_CYCLIC_LINK: "Cycling link (import cycle) error.",
	ERR_INVALID_DECLARATION: "Invalid declaration error.",
	ERR_DUPLICATE_SYMBOL: "Duplicate symbol error.",
	ERR_PARSE_ERROR: "Parse error.",
	ERR_BUSY: "Busy error.",
	ERR_SKIP: "Skip error.",
	ERR_HELP: "Help error.",
	ERR_BUG: "Bug error.",
	ERR_PRINTER_ON_FIRE: "Printer on fire error.",
}

##=============##
##  Variables  ##
##=============##

# Configuration
var default_output_level: int = INFO
# TODO: Find (or implement in Godot) a more clever way to achieve that

var default_output_strategies: Array[int] = [STRATEGY_PRINT, STRATEGY_PRINT, STRATEGY_PRINT, STRATEGY_PRINT, STRATEGY_PRINT]
var default_logfile_path: String = "user://%s.log" % ProjectSettings.get_setting("application/config/name")  # TODO @File
var default_configfile_path: String = "user://%s.cfg" % PLUGIN_NAME

## e.g. "[INFO] [main] The young alpaca started growing a goatie."
var output_format: String = "[{TIME}] [{LVL}] [{MOD}]{ERR_MSG} {MSG}"

## Example with all supported placeholders: "YYYY.MM.DD hh.mm.ss.SSS" [br]
## would output e.g.: "2020.10.09 12:10:47.034".
var time_format: String = "hh:mm:ss"

## Holds the name of the debug module for easy usage across all logging functions.
var default_module_name: String = "main"

# Specific to STRATEGY_MEMORY
var max_memory_size: int = 30
var memory_buffer: Array[String] = []
var memory_idx: int = 0
var memory_first_loop: bool = true
var memory_cache: Array[String] = []
var invalid_memory_cache: bool = false

# Default modules are initialized in _init via add_module
## Holds default and external sinks defined by the user
var external_sinks: Dictionary[String, ExternalSink] = {}
## Holds default and custom modules defined by the user
var modules: Dictionary[String, Module] = {}

##=============##
##  Functions  ##
##=============##


## Log a message in the given module with the given logging level.
func put(level: int, message: String, module: String = default_module_name, error_code: int = -1) -> void:
	var module_ref: Module = get_module(module)
	var output_strategy: int = module_ref.get_output_strategy(level)
	if output_strategy == STRATEGY_MUTE or module_ref.get_output_level() > level:
		return  # Out of scope

	var output: String = format(output_format, level, module, message, error_code)

	if output_strategy & STRATEGY_PRINT:
		print(output)

	if output_strategy & STRATEGY_EXTERNAL_SINK:
		module_ref.get_external_sink().write(output, level)

	if output_strategy & STRATEGY_MEMORY:
		memory_buffer[memory_idx] = output
		memory_idx += 1
		invalid_memory_cache = true
		if memory_idx >= max_memory_size:
			memory_idx = 0
			memory_first_loop = false


# Helper functions for each level
# -------------------------------


## Log a message in the given module with level VERBOSE.
func verbose(message: String, module: String = default_module_name, error_code: int = -1) -> void:
	put(VERBOSE, message, module, error_code)


## Log a message in the given module with level DEBUG.
func debug(message: String, module: String = default_module_name, error_code: int = -1) -> void:
	put(DEBUG, message, module, error_code)


## Log a message in the given module with level INFO.
func info(message: String, module: String = default_module_name, error_code: int = -1) -> void:
	put(INFO, message, module, error_code)


## Log a message in the given module with level WARN.
func warn(message: String, module: String = default_module_name, error_code: int = -1) -> void:
	put(WARN, message, module, error_code)


## Log a message in the given module with level ERROR.
func error(message: String, module: String = default_module_name, error_code: int = -1) -> void:
	put(ERROR, message, module, error_code)


# Module management
# -----------------


## Add a new module with the given parameter or (by default) the
## default ones.
## Returns a reference to the instanced module.
func add_module(_name: String, output_level: int = default_output_level, output_strategies: Array[int] = default_output_strategies, logfile: ExternalSink = null) -> Module:
	if modules.has(_name):
		info("The module '%s' already exists; discarding the call to add it anew." % _name, PLUGIN_NAME)
	else:
		if logfile == null:
			logfile = get_external_sink(default_logfile_path)
		modules[_name] = Module.new(_name, output_level, output_strategies, logfile)
	return modules[_name]


## Retrieve the given module if it exists; if not, it will be created.
func get_module(module: String = default_module_name) -> Module:
	if not modules.has(module):
		info("The requested module '%s' does not exist. It will be created with default values." % module, PLUGIN_NAME)
		add_module(module)
	return modules[module]


## Retrieve the dictionary containing all modules.
func get_modules() -> Dictionary[String, Module]:
	return modules


# Logfiles management
# -------------------


## Sets the new default logfile path. Unless configured otherwise with
## the optional keep_old argument, it will replace the logfile for all
## modules which were configured for the previous logfile path.
func set_default_logfile_path(new_logfile_path: String, keep_old: bool = false) -> void:
	if new_logfile_path == default_logfile_path:
		return  # Nothing to do

	var old_logfile: ExternalSink = get_external_sink(default_logfile_path)
	var new_logfile: ExternalSink = null
	if external_sinks.has(new_logfile_path):  # Already exists
		new_logfile = external_sinks[new_logfile_path]
	else:  # Create a new logfile
		new_logfile = add_logfile(new_logfile_path)
		external_sinks[new_logfile_path] = new_logfile

	if not keep_old:  # Replace the old defaut logfile in all modules that used it
		for module in modules.values():
			if module.get_external_sink() == old_logfile:
				module.set_external_sink(new_logfile)
		external_sinks.erase(default_logfile_path)
	default_logfile_path = new_logfile_path


## Return the default logfile path.
func get_default_logfile_path() -> String:
	return default_logfile_path


## Add a new logfile that can then be attached to one or more modules.
## Returns a reference to the instanced logfile.
func add_logfile(logfile_path: String = default_logfile_path) -> ExternalSink:
	if external_sinks.has(logfile_path):
		info("A logfile pointing to '%s' already exists; discarding the call to add it anew." % logfile_path, PLUGIN_NAME)
	else:
		external_sinks[logfile_path] = Logfile.new(logfile_path)
	return external_sinks[logfile_path]


## Retrieve the first given external sink if it exists, otherwise returns null.
func get_external_sink(_external_sink_name: String) -> ExternalSink:
	if not external_sinks.has(_external_sink_name):
		warn("The requested external sink pointing to '%s' does not exist." % _external_sink_name, PLUGIN_NAME)
		return null
	else:
		return external_sinks[_external_sink_name]


## Retrieve the dictionary containing all external sinks.
func get_external_sinks() -> Dictionary[String, ExternalSink]:
	return external_sinks


## Flush non-empty buffers.
func flush_buffers() -> void:
	var processed_external_sinks: Array = []
	var external_sink: ExternalSink = null
	for module in modules:
		external_sink = modules[module].get_external_sink()
		if external_sink in processed_external_sinks:
			continue
		external_sink.flush_buffer()
		processed_external_sinks.append(external_sink)


# Default output configuration
# ----------------------------


## Set the default output strategy mask of the given level or (by
## default) all levels for all modules without a custom strategy.
func set_default_output_strategy(output_strategy_mask: int, level: int = -1) -> void:
	if not output_strategy_mask in range(0, MAX_STRATEGY + 1):
		error("The output strategy mask must be comprised between 0 and %d." % MAX_STRATEGY, PLUGIN_NAME)
		return
	if level == -1:  # Set for all levels
		for i in range(0, LEVELS.size()):
			default_output_strategies[i] = output_strategy_mask
		info("The default output strategy mask was set to '%d' for all levels." % [output_strategy_mask], PLUGIN_NAME)
	else:
		if not level in range(0, LEVELS.size()):
			error("The level must be comprised between 0 and %d." % (LEVELS.size() - 1), PLUGIN_NAME)
			return
		default_output_strategies[level] = output_strategy_mask
		info("The default output strategy mask was set to '%d' for the '%s' level." % [output_strategy_mask, LEVELS[level]], PLUGIN_NAME)


## Get the default output strategy mask of the given level or (by
## default) all levels for all modules without a custom strategy.
func get_default_output_strategy(level: int) -> int:
	return default_output_strategies[level]


## Set the default minimal level for the output of all modules without
## a custom output level. [br]
## All levels greater or equal to the given once will be output based on
## their respective strategies, while levels lower than the given one will
## be discarded.
## 
func set_default_output_level(level: int) -> void:
	if not level in range(0, LEVELS.size()):
		error("The level must be comprised between 0 and %d." % (LEVELS.size() - 1), PLUGIN_NAME)
		return
	default_output_level = level
	info("The default output level was set to '%s'." % LEVELS[level], PLUGIN_NAME)


## Get the default minimal level for the output of all modules without
## a custom output level.
func get_default_output_level() -> int:
	return default_output_level


# Output formatting
# -----------------


## Format the fields: [br]
## * YYYY = Year [br]
## * MM = Month [br]
## * DD = Day [br]
## * hh = Hour [br]
## * mm = Minutes [br]
## * ss = Seconds [br]
## * SSS = Milliseconds [br]
func get_formatted_datetime() -> String:
	var unix_time: float = Time.get_unix_time_from_system()
	var time_zone: Dictionary = Time.get_time_zone_from_system()
	unix_time += time_zone.bias * 60
	var datetime: Dictionary = Time.get_datetime_dict_from_unix_time(int(unix_time))
	datetime.millisecond = int(unix_time * 1000) % 1000
	var result: String = time_format
	result = result.replace("YYYY", "%04d" % [datetime.year])
	result = result.replace("MM", "%02d" % [datetime.month])
	result = result.replace("DD", "%02d" % [datetime.day])
	result = result.replace("hh", "%02d" % [datetime.hour])
	result = result.replace("mm", "%02d" % [datetime.minute])
	result = result.replace("ss", "%02d" % [datetime.second])
	result = result.replace("SSS", "%03d" % [datetime.millisecond])
	return result


func format(template: String, level: int, module: String, message: String, error_code: int = -1) -> String:
	var output: String = template
	output = output.replace(FORMAT_IDS.level, LEVELS[level])
	output = output.replace(FORMAT_IDS.module, module)
	output = output.replace(FORMAT_IDS.message, str(message))
	output = output.replace(FORMAT_IDS.time, get_formatted_datetime())

	# Error message substitution
	var error_message: String = ERROR_MESSAGES.get(error_code, "")
	if not error_message.is_empty():
		output = output.replace(FORMAT_IDS.error_message, " " + error_message)
	else:
		output = output.replace(FORMAT_IDS.error_message, "")

	return output


## Set the output string format using the following identifiers:
## [code]{LVL}[/code] for the level, [code]{MOD}[/code] for the module, [code]{MSG}[/code] for the message.
## The three identifiers should be contained in the output format string.
func set_output_format(new_format: String) -> void:
	for key in FORMAT_IDS:
		if new_format.find(FORMAT_IDS[key]) == -1:
			error("Invalid output string format. It lacks the '%s' identifier." % FORMAT_IDS[key], PLUGIN_NAME)
			return
	output_format = new_format
	info("Successfully changed the output format to '%s'." % output_format, PLUGIN_NAME)


## Get the output string format.
func get_output_format() -> String:
	return output_format


# Strategy "memory"
# -----------------


## Set the maximum amount of messages to be remembered when
## using the STRATEGY_MEMORY output strategy.
func set_max_memory_size(new_size: int) -> void:
	if new_size <= 0:
		error("The maximum amount of remembered messages must be a positive non-null integer. Received %d." % new_size, PLUGIN_NAME)
		return

	var new_buffer: Array[String] = []
	var new_idx: int = 0
	new_buffer.resize(new_size)

	# Better algorithm welcome :D
	if memory_first_loop:
		var offset = 0
		if memory_idx > new_size:
			offset = memory_idx - new_size
			memory_first_loop = false
		else:
			new_idx = memory_idx
		for i in range(0, min(memory_idx, new_size)):
			new_buffer[i] = memory_buffer[i + offset]
	else:
		var delta: int = 0
		if max_memory_size > new_size:
			delta = max_memory_size - new_size
		else:
			new_idx = max_memory_size
			memory_first_loop = true
		for i in range(0, min(max_memory_size, new_size)):
			new_buffer[i] = memory_buffer[(memory_idx + delta + i) % max_memory_size]

	memory_buffer = new_buffer
	memory_idx = new_idx
	invalid_memory_cache = true
	max_memory_size = new_size
	info("Successfully set the maximum amount of remembered messages to %d." % max_memory_size, PLUGIN_NAME)


## Get the maximum amount of messages to be remembered when
## using the STRATEGY_MEMORY output strategy.
func get_max_memory_size() -> int:
	return max_memory_size


## Get an array of the messages remembered following STRATEGY_MEMORY.
## The messages are sorted from the oldest to the newest.
func get_memory() -> Array[String]:
	if invalid_memory_cache:  # Need to recreate the cached ordered array
		memory_cache = []
		if not memory_first_loop:  # else those would be uninitialized
			for i in range(memory_idx, max_memory_size):
				memory_cache.append(memory_buffer[i])
		for i in range(0, memory_idx):
			memory_cache.append(memory_buffer[i])
		invalid_memory_cache = false
	return memory_cache


## Clear the buffer or remembered messages.
func clear_memory() -> void:
	memory_buffer.clear()
	memory_idx = 0
	memory_first_loop = true
	invalid_memory_cache = true


# Configuration loading/saving
# ----------------------------

const config_fields: Dictionary[String, String] = {
	default_output_level = "default_output_level",
	default_output_strategies = "default_output_strategies",
	default_logfile_path = "default_logfile_path",
	max_memory_size = "max_memory_size",
	external_sinks = "external_sinks",
	modules = "modules"
}


## Save the default configuration as well as the set of modules and
## their respective configurations.
## The ConfigFile API is used to generate the config file passed as argument.
## A unique section is used, so that it can be merged in a project's engine.cfg.
## Returns an error code (OK or some ERR_*).
func save_config(configfile: String = default_configfile_path) -> int:
	var config: ConfigFile = ConfigFile.new()

	# Store default config
	config.set_value(PLUGIN_NAME, config_fields.default_output_level, default_output_level)
	config.set_value(PLUGIN_NAME, config_fields.default_output_strategies, default_output_strategies)
	config.set_value(PLUGIN_NAME, config_fields.default_logfile_path, default_logfile_path)
	config.set_value(PLUGIN_NAME, config_fields.max_memory_size, max_memory_size)

	# External sink config
	var external_sinks_arr: Array[Dictionary] = []
	var sorted_keys: Array = external_sinks.keys()
	sorted_keys.sort()  # Sadly doesn't return the array, so we need to split it
	for external_sink in sorted_keys:
		external_sinks_arr.append(external_sinks[external_sink].get_config())
	config.set_value(PLUGIN_NAME, config_fields.external_sinks, external_sinks_arr)

	# Modules config
	var modules_arr: Array[Dictionary] = []
	sorted_keys = modules.keys()
	sorted_keys.sort()
	for module in sorted_keys:
		modules_arr.append(modules[module].get_config())
	config.set_value(PLUGIN_NAME, config_fields.modules, modules_arr)

	# Save and return the corresponding error code
	var err: int = config.save(configfile)
	if err:
		error("Could not save the config in '%s'; exited with error %d." % [configfile, err], PLUGIN_NAME)
		return err
	info("Successfully saved the config to '%s'." % configfile, PLUGIN_NAME)
	return OK


## Load the configuration as well as the set of defined modules and
## their respective configurations. The expect file contents must be those
## produced by the ConfigFile API.
## Returns an error code (OK or some ERR_*).
func load_config(configfile: String = default_configfile_path) -> int:
	# Look for the file
	if not FileAccess.file_exists(configfile):
		warn("Could not load the config in '%s', the file does not exist." % configfile, PLUGIN_NAME)
		return ERR_FILE_NOT_FOUND

	# Load its contents
	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(configfile)
	if err:
		warn("Could not load the config in '%s'; exited with error %d." % [configfile, err], PLUGIN_NAME)
		return err

	# Load default config
	default_output_level = config.get_value(PLUGIN_NAME, config_fields.default_output_level, default_output_level)
	default_output_strategies = config.get_value(PLUGIN_NAME, config_fields.default_output_strategies, default_output_strategies)
	default_logfile_path = config.get_value(PLUGIN_NAME, config_fields.default_logfile_path, default_logfile_path)
	max_memory_size = config.get_value(PLUGIN_NAME, config_fields.max_memory_size, max_memory_size)

	# Load external config and initialize them
	flush_buffers()
	external_sinks = {}
	add_logfile(default_logfile_path)
	for logfile_cfg in config.get_value(PLUGIN_NAME, config_fields.external_sinks, []):
		var logfile: Logfile = Logfile.new(logfile_cfg["path"], logfile_cfg["queue_mode"])
		external_sinks[logfile_cfg["path"]] = logfile

	# Load modules config and initialize them
	modules = {}
	add_module(PLUGIN_NAME)
	add_module(default_module_name)
	for module_cfg in config.get_value(PLUGIN_NAME, config_fields.modules, []):
		var module: Module = Module.new(
			module_cfg["name"], module_cfg["output_level"], module_cfg["output_strategies"], get_external_sink(module_cfg["external_sink"]["path"])
		)
		modules[module_cfg["name"]] = module

	info("Successfully loaded the config from '%s'." % configfile, PLUGIN_NAME)
	return OK


##=============##
##  Callbacks  ##
##=============##


func _init() -> void:
	# Default logfile
	add_logfile(default_logfile_path)
	# Default modules
	add_module(PLUGIN_NAME)  # needs to be instanced first
	add_module(default_module_name)
	memory_buffer.resize(max_memory_size)


func _exit_tree() -> void:
	flush_buffers()
