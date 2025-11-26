Godot Logger - Logging Addon for Godot Engine
===========================================

The *Godot Logger* is a plugin that provides a logging API for
projects developed with [Godot Engine](https://godotengine.org).

# Usage

1. Clone or extract this repository as the `res://addons/godot-logger` folder in your project.
2. Enable the addon from  Project -> Project Settings -> Plugins -> Godot Logger.
3. An autoloaded script will be added to your project singletons list as `KLogger`.

The methods of the API can then be accessed from any other script via the *KLogger*
singleton:
```
  KLogger.warn("Alpaca mismatch!")

  KLogger.add_module("mymodule")
  KLogger.info("Reticulating splines...", "mymodule")
```

Read the code for details about the API, it's extensively documented.

## Output format configuration

The `output_format` property can be customized using format fields from the
`FORMAT_IDS` dictionary. They are placeholders which will be replaced by the
relevant content.

**Log format fields**:

* `{LVL}`     = Level of the log
* `{MOD}`     = Module that does the logging
* `{MSG}`     = Message from the user
* `{TIME}`    = Timestamp when the logging occurred
* `{ERR_MSG}` = Error message corresponding to the error code, if provided.
                It is automatically prepended with a space.

The timestamp format can be configured for each module using the `time_format`
property, with the placeholders described below.

**Timestamp fields**:

* `YYYY` = Year
* `MM` = Month
* `DD` = Day
* `hh` = Hour
* `mm` = Minute
* `ss` = Second
* `SSS` = Millisecond

**Error codes:**

All logging levels can also optionally include an
[`Error` code](https://docs.godotengine.org/en/stable/classes/class_@globalscope.html?#enum-globalscope-error),
which will be mapped to a human-readable error message.

Example:
```
KLogger.error("Failed to rotate the albatross", "main", ERR_INVALID_DATA)
```

### Example

```gdscript
var msg = "Error occurred!"

KLogger.output_format = "[{TIME}] [{LVL}] [{MOD}] {MSG}"
KLogger.time_format = "YYYY.MM.DD hh:mm:ss.SSS"
KLogger.error(msg)

KLogger.time_format = "hh:mm:ss"
KLogger.error(msg)

KLogger.output_format = "[{LVL}] {MSG} at {TIME}"
KLogger.error(msg)
```

Results in:
```
[2020.10.09 12:10:47.034] [ERROR] [main] Error occurred!

[12:10:47] [ERROR] [main] Error occurred!

[ERROR] Error occurred! at 12:10:47
```

## Licensing

The KLogger class and all other files of this repository are distributed under the
MIT license (see the LICENSE.md file).
