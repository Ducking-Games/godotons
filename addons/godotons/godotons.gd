@tool
extends EditorPlugin

var dock: Node

func _enter_tree() -> void:
	dock = preload("res://addons/godotons/components/dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_UR, dock)
	print_rich("[color=green]Loaded Godotons...[/color]")


func _exit_tree() -> void:
	remove_control_from_docks(dock)
	dock.free()
	print_rich("[color=orange]Removed Godotons... Goodbye[/color]")

