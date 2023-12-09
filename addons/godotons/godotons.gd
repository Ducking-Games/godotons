@tool
extends EditorPlugin

var dock: Node

var settings_path: String = "godotons/"

var settings_debug_logging = {
	"name": "%senable_debug_logging" % [settings_path],
	"default": false,
	"type": TYPE_BOOL,
}

var setting_remove_settings_on_unload = {
		"name": "%sremove_settings_on_unload" % [settings_path],
		"default": true,
		"type": TYPE_BOOL,
		"tooltip": "Whether or not to remove godotons project settings if it is disabled as an addon",
}

var settings: Array[Dictionary] = [
	settings_debug_logging,
]

func _enter_tree() -> void:
	_manage_settings(false)
	dock = preload("res://addons/godotons/components/dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_UR, dock)
	print_rich("[color=green]Loaded Godotons...[/color]")


func _exit_tree() -> void:
	_manage_settings(true)
	remove_control_from_docks(dock)
	dock.free()
	print_rich("[color=orange]Removed Godotons... Goodbye[/color]")

func _manage_settings(exiting: bool) -> void:

	for setting in settings:
		if exiting:
			var clean_settings: bool = ProjectSettings.get_setting(setting_remove_settings_on_unload.get("name"))
			if clean_settings:
				if ProjectSettings.has_setting(setting.get("name")):
					ProjectSettings.clear(setting.get("name"))
		else:
			var name: String = setting.get("name")
			ProjectSettings.set_setting(name, setting.get("default"))
			ProjectSettings.set_as_basic(name, true)
			ProjectSettings.add_property_info(setting)
			ProjectSettings.set_initial_value(name, setting.get("default"))
