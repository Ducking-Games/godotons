@tool
extends Resource
class_name Logs

static func _success(message: String) -> void:
	print_rich("[godotons] [color=green]%s[/color]" % [message])

static func _successi(message: String) -> void:
	_success("    %s" % [message])
	

static func _info(message: String) -> void:
	print_rich("[godotons] [color=cyan]%s[/color]" % [message])

static func _infoi(message: String) -> void:
	_info("    %s" % [message])

static func _notice(message: String) -> void:
	print_rich("[godotons] [color=orange]%s[/color]" % [message])

static func _noticei(message: String) -> void:
	_notice("    %s" % [message])

static func _minor(message: String) -> void:
	print_rich("[godotons] [color=gray]%s[/color]" % [message])

static func _minori(message: String) -> void:
	_minor("    %s" % [message])

static func _error(message: String, err: Error) -> void:
	push_error("%s: " % [message], error_string(err))
	print_rich("[godotons] [color=red]%s: %d (%s)" % [message, err, error_string(err)])

static func _dinfo(message: String) -> void:
	var debug_enabled: bool = ProjectSettings.get_setting("godotons/enable_debug_logging", false)
	if debug_enabled:
		_info(message)

static func _dinfoi(message: String) -> void:
	_dinfo("    %s" % [message])

static func _dnotice(message: String) -> void:
	var debug_enabled: bool = ProjectSettings.get_setting("godotons/enable_debug_logging", false)
	if debug_enabled:
		_notice(message)

static func _dnoticei(message: String) -> void:
	_dnotice("    %s" % [message])

static func _dminor(message: String) -> void:
	var debug_enabled: bool = ProjectSettings.get_setting("godotons/enable_debug_logging", false)
	if debug_enabled:
		_minor(message)

static func _dminori(message: String) -> void:
	_dminor("    %s" % [message])
