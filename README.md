Logger - Logging singleton for Godot Engine
===========================================

The *Logger* class is a GDScript singleton that provides a logging API for
projects developed with [Godot Engine](https://godotengine.org).

# Usage

Copy the `logger.gd` file into your project folder, and define it as an autoloaded
singleton in your project's settings (e.g. with the name *Logger*):
```
Logger="*res://logger.gd"
```

The methods of the API can then be accessed from any other script via the *Logger*
singleton:
```
  Logger.warn("Alpaca mismatch!")

  Logger.add_module("mymodule")
  Logger.info("Reticulating splines...", "mymodule")
```

Read the code for details about the API, it's extensively documented.

Error Codes
-----------

All logging levels can also optionally include an [error code](https://docs.godotengine.org/en/stable/classes/class_@globalscope.html?#enum-globalscope-error), which will be mapped to the corresponding error message as of Godot 3.2.
```
Logger.error('failed to rotate the albatross', 'main', ERR_INVALID_DATA)
```

## Output format configuration

The `output_format` property can be customized using format fields from the
`FORMAT_IDS` dictionary. They are placeholders which will be replaced by the
relevant content.

**Log format fields**:

* `{LVL}`     = Level of the log
* `{MOD}`     = Module that does the logging
* `{MSG}`     = Message from the user
* `{TIME}`    = Timestamp when the logging occurred
* `{ERR_MSG}` = Godot error message corrsesponding to provided error code

The timestamp format can be configured for each module using the `time_format`
property, with the placeholders described below.

**Timestamp fields**:

* `YYYY` = Year
* `MM` = Month
* `DD` = Day
* `hh` = Hour
* `mm` = Minute
* `ss` = Second

### Example

```gdscript
var msg = "Error occurred!"

Logger.output_format = "[{TIME}] [{LVL}] [{MOD}]{ERR_MSG} {MSG}"
Logger.time_format = "YYYY.MM.DD hh:mm:ss"
Logger.error(msg)

Logger.time_format = "hh:mm:ss"
Logger.error(msg)

Logger.output_format = "[{LVL}] {MSG} at {TIME}"
Logger.error(msg)
```

Results in:
```
[2020.10.09 12:10:47] [ERROR] [main] Error occurred!

[12:10:47] [ERROR] [main] Error occurred!

[ERROR] Error occurred! at 12:10:47
```

## Licensing

The Logger class and all other files of this repository are distributed under the
MIT license (see the LICENSE.md file).
