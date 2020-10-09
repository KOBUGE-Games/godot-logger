Logger - Logging singleton for Godot Engine
===========================================

The *Logger* class is a GDScript singleton that provides a logging API for
projects developed with [Godot Engine](https://godotengine.org).

Usage
-----

Copy the `logger.gd` file into your project folder, and define it as an autoloaded
singleton in your project's settings (e.g. with the name *Logger*):
```
Logger="*res://logger.gd"
```

The methods of the API can then be accessed from any other script via the *Logger*
singleton:
```
  Logger.warn('alpaca mismatch!')
  Logger.info('reticulating splines...', mymodule)
```

Read the code for details about the API, it's extensively documented.


Error Codes
-----------

All logging levels can also optionally include an [error code](https://docs.godotengine.org/en/stable/classes/class_@globalscope.html?#enum-globalscope-error), which will be mapped to the corresponding error message as of Godot 3.2.
```
Logger.error('failed to rotate the albatross', 'main', ERR_INVALID_DATA)
```

Licensing
---------

The Logger class and all other files of this repository are distributed under the
MIT license (see the LICENSE.md file).
