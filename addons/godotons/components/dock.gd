@tool
extends Control

var config: AddonManifest = AddonManifest.new()

@onready var tree: Tree = get_node("VBox/Tree")
@onready var remove: Texture2D = preload("res://addons/godotons/remove.png")
@onready var integrate: Texture2D = preload("res://addons/godotons/integrate.png")

func _success(message: String) -> void:
	print_rich("[color=green]%s[/color]" % [message])

func _info(message: String) -> void:
	print_rich("[color=cyan]%s[/color]" % [message])

func _error(message: String, err: Error) -> void:
	print_rich("[color=red]%s: %d (%s)" % [message, err, error_string(err)])

func _enter_tree() -> void:
	Engine.register_singleton("Godotons", self)

func _exit_tree() -> void:
	Engine.unregister_singleton("Godotons")

func _ready() -> void:
	tree.item_edited.connect(_tree_edited)
	tree.button_clicked.connect(_tree_clicked)
	pass

func _save_config() -> void:
	_info("Saving config...")
	var save_err: Error = config.Save()
	if save_err != OK:
		_error("Failed to save config", save_err)
		return
	_success("Saved config!")

func _save_backup_config() -> void:
	_info("Saving backup...")
	var save_err: Error = config.Save(true)
	if save_err != OK:
		_error("Failed to save backup", save_err)
		return
	_success("Saved backup!")

func _load_config() -> void:
	_info("Loading config from disk...")
	config.LoadFromDisk()
	if config.Addons.size() == 0:
		_error("No addons loaded. Config empty or load errored. Check pushed errors.", 0)
		return
	_build_tree()
	_info("Loaded!")

func _load_backup_config() -> void:
	_info("Loading config from backup file...")
	config.LoadFromDisk(true)
	if config.Addons.size() == 0:
		_error("No addons loaded. Config empty or load errored. Check pushed errors.", 0)
		return
	_info("Loaded!")

func _tree_edited() -> void:
	var root_item: Array[TreeItem] = tree.get_root().get_children()
	var addons: Array[AddonConfig] = []
	for item in root_item:
		var addon: AddonConfig = AddonConfig.new()
		addon.Name = item.get_text(0)

		for child in item.get_children():
			var child_label: String = child.get_text(0)
			match child_label:
				"Repo":
					addon.Repo = child.get_text(1)
				"Update on Apply":
					addon.Update = child.is_checked(1)
				"Branch":
					addon.Branch = child.get_text(1)
				"Upstream Path":
					addon.UpstreamPath = child.get_text(1)
				"Project Path":
					addon.ProjectPath = child.get_text(1)
		addons.append(addon)
	
	config.Addons = addons
	_save_config()
	pass

func _tree_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int) -> void:
	_info("%d" % id)
	match id:
		AddonConfig.TREE_BUTTONS.APPLY_ALL:
			_info("Run integration on all addons")
		AddonConfig.TREE_BUTTONS.APPLY_ONE:
			var idx: int = item.get_meta("index", -1)
			if idx == -1:
				push_error("Index %d is out of bounds, max: %d" % [idx, config.Addons.size()])
				_error("Index %d is out of bounds, max: %d" % [idx, config.Addons.size()], ERR_DOES_NOT_EXIST)
				return
			var addon: AddonConfig = config.Addons[idx]
			_info("Run integration on one addon: %s" % [addon.Name])
		AddonConfig.TREE_BUTTONS.DELETE_ONE:
			_info("Delete one addon")

func _new_addon() -> void:
	config.New()
	_build_tree()

func _build_tree() -> void:
	tree.clear()

	var root := tree.create_item()
	root.set_text(0, "Addons")
	root.add_button(1, integrate, AddonConfig.TREE_BUTTONS.APPLY_ALL , false, "Apply the entire addon configuration to the project")

	var tree_index: int = 0

	for addon in config.Addons:
		addon.TreeBranch(tree, root, tree_index, remove, integrate)
		tree_index += 1


func _integrate() -> void:
	_info("Beginning integration run with %d addons" % [config.Addons.size()])
