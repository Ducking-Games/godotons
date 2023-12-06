@tool
extends Control

const tmp_dir: String = "addons/temp/"

var config: AddonManifest = AddonManifest.new()

@onready var tree: Tree = get_node("VBox/Tree")
@onready var remove: Texture2D = preload("res://addons/godotons/remove.png")
@onready var integrate: Texture2D = preload("res://addons/godotons/integrate.png")

func _success(message: String) -> void:
	print_rich("[godotons] [color=green]%s[/color]" % [message])

func _successi(message: String) -> void:
	_success("    %s" % [message])
	

func _info(message: String) -> void:
	print_rich("[godotons] [color=cyan]%s[/color]" % [message])

func _infoi(message: String) -> void:
	_info("    %s" % [message])

func _note(message: String) -> void:
	print_rich("[godotons] [color=orange]%s[/color]" % [message])

func _error(message: String, err: Error) -> void:
	push_error(error_string(err))
	print_rich("[godotons] [color=red]%s: %d (%s)" % [message, err, error_string(err)])

func _enter_tree() -> void:
	Engine.register_singleton("Godotons", self)

func _exit_tree() -> void:
	Engine.unregister_singleton("Godotons")

func _ready() -> void:
	_load_config()
	tree.item_edited.connect(_tree_edited)
	tree.button_clicked.connect(_tree_clicked)
	EditorInterface.get_resource_filesystem().sources_changed.connect(_editor_reload)
	pass

func _editor_reload(exist: bool) -> void:
	_load_config()

func _save_config() -> void:
	_info("Saving config...")
	var save_err: Error = config.Save()
	if save_err != OK:
		_error("Failed to save config", save_err)
		return
	call_deferred("_build_tree")
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
	call_deferred("_build_tree")
	_info("Loaded!")

func _load_backup_config() -> void:
	_info("Loading config from backup file...")
	config.LoadFromDisk(true)
	if config.Addons.size() == 0:
		_error("No addons loaded. Config empty or load errored. Check pushed errors.", 0)
		return
	call_deferred("_build_tree")
	_info("Loaded!")

func _tree_edited() -> void:
	var root_item: Array[TreeItem] = tree.get_root().get_children()
	var addons: Array[AddonConfig] = []
	for item in root_item:
		var addon: AddonConfig = AddonConfig.new()
		addon.Name = item.get_text(0).replace(" ", "_")

		for child in item.get_children():
			var child_label: String = child.get_text(0)
			match child_label:
				"Repo":
					addon.Repo = child.get_text(1)
				"Enabled on Apply":
					addon.Enabled = child.is_checked(1)
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
	var idx: int = item.get_meta("index", -1) as int
	match id:
		AddonConfig.TREE_BUTTONS.APPLY_ALL:
			_integrate()
		AddonConfig.TREE_BUTTONS.APPLY_ONE:
			if idx == -1:
				push_error("Index %d is out of bounds, max: %d" % [idx, config.Addons.size()])
				_error("Index %d is out of bounds, max: %d" % [idx, config.Addons.size()], ERR_DOES_NOT_EXIST)
				return
			var addon: AddonConfig = config.Addons[idx]
			_info("Run integration on one addon: %s" % [addon.Name])
			_integrate_one(addon, true)
		AddonConfig.TREE_BUTTONS.DELETE_ONE:
			if idx == -1:
				push_error("Index %d is out of bounds, max: %d" % [idx, config.Addons.size()])
				_error("Index %d is out of bounds, max: %d" % [idx, config.Addons.size()], ERR_DOES_NOT_EXIST)
				return
			var addon: AddonConfig = config.Addons[idx]
			_info("Removing %s from configuration" % [ addon.Name ])
			config.Addons.remove_at(idx)
			_save_config()


func _new_addon() -> void:
	config.New()
	call_deferred("_build_tree")

func _build_tree() -> void:
	tree.clear()

	var root := tree.create_item()
	root.set_text(0, "Addons")
	root.add_button(1, integrate, AddonConfig.TREE_BUTTONS.APPLY_ALL , false, "Apply the entire addon configuration to the project")

	var tree_index: int = 0

	for addon in config.Addons:
		addon.TreeBranch(tree, root, tree_index, remove, integrate)
		tree_index += 1

func _fetch_addon(url: String, name: String, filepath: String) -> Error:
	var req: HTTPRequest = HTTPRequest.new()
	add_child(req)

	
	var request_error: Error = req.request(url)
	if request_error != OK:
		_error("Failed to download %s" % [url], request_error)
		return request_error
	
	_infoi("Awaiting %s..." % [url])

	var response: Array = await req.request_completed

	var result: int = response[0]
	var response_code: int = response[1]
	var headers: PackedStringArray = response[2]
	var body: PackedByteArray = response[3]

	if response_code != 200:
		_error("Response code (%d) while retrieving addon from upstream. Expected 200 and others unhandled." % [response_code], result)
		return result

	_successi("Fetched %s. Writing..." % [name])

	var file: FileAccess = FileAccess.open(filepath, FileAccess.WRITE)

	if !file:
		_error("Failed to create file %s" % [filepath], file.get_open_error())
		return file.get_open_error()
	
	file.store_buffer(body)
	file.close()
	return OK


func _integrate_one(addon: AddonConfig, single: bool) -> Error:
	if !addon.Enabled:
		_note("Ignoring %s (disabled)" % [addon.Name])
		return OK

	var resources: DirAccess = DirAccess.open("res://")
	var tmp_err: Error = resources.make_dir_recursive(tmp_dir)
	if tmp_err != OK:
		_error("Failed to create temp directory for integration run", tmp_err)
		return tmp_err

	if resources.dir_exists(addon.ProjectPath):
		if !addon.Update:
			_note("Skipping %s (Update On Apply: false)" % [addon.Name])
			return ERR_ALREADY_EXISTS

	_info("Integrating addon: %s" % [addon.Name])

	
	var download_name: String = "%s-%s" % [addon.Name, addon.Branch]
	var download_url: String = "%s/archive/%s.zip" % [addon.Repo, addon.Branch]
	var archive_name: String = "%s.zip" % [download_name]
	var repo_name: String = addon.Repo.rsplit("/", true, 1)[1]
	var internal_zip_prefix: String = "%s-%s" % [repo_name, addon.Branch]
	var archive_path: String = "%s/%s" % [tmp_dir, archive_name]

	if !resources.file_exists(archive_path):
		var fetch_err: Error = await _fetch_addon(download_url, archive_name, archive_path)
		if fetch_err != OK:
			return fetch_err
	
	_successi("Injecting addon [%s -> %s]" % [addon.UpstreamPath, addon.ProjectPath])

	var zip_reader: ZIPReader = ZIPReader.new()
	var zip_err: Error = zip_reader.open(archive_path)
	if zip_err != OK:
		_error("Failed to unpack %s.", zip_err)
		zip_reader.close()
		return zip_err
	
	var wrote_directory_count: int = 0
	var wrote_file_count: int = 0

	for archived_file: String in zip_reader.get_files():
		if archived_file.contains(addon.UpstreamPath):

			var internal_path: String = archived_file.trim_prefix(internal_zip_prefix).trim_prefix("/")
			var diff_path: String = internal_path.trim_prefix(addon.UpstreamPath).trim_prefix("/")
			var resource_path: String = "res://%s/%s" % [addon.ProjectPath, diff_path]

			if archived_file.ends_with("/"):		
				_infoi("Creating %s" % [resource_path])
				var mkdir_err: Error = resources.make_dir_recursive(resource_path)
				if mkdir_err != OK:
					_error("Failed to create addon dir: %s" % [resource_path], mkdir_err)
					zip_reader.close()
					return mkdir_err
				wrote_directory_count += 1
				continue
			
			var writer: FileAccess = FileAccess.open(resource_path, FileAccess.WRITE)
			writer.store_buffer(zip_reader.read_file(archived_file))
			writer.close()
			wrote_file_count += 1

	zip_reader.close()
	_infoi("Wrote %d directories & %d files." % [wrote_directory_count, wrote_file_count])

	if single:
		_clean()

	_success("Done: %s" % [addon.Name])
	return OK


func _integrate() -> void:
	_info("Beginning integration run with %d addons" % [config.Addons.size()])

	for addon in config.Addons:
		await _integrate_one(addon, false)

	_clean()
	_save_backup_config()

	_success("Done with integration run.")

func _clean() -> void:
	_note("Cleaning up res://%s..." % [tmp_dir])
	var temp_addons: DirAccess = DirAccess.open(tmp_dir)
	for file in temp_addons.get_files():
		var rem_err: Error = temp_addons.remove(file)
		if rem_err != OK:
			_error("Failed to remove temp file %s" % [file], rem_err)

	var resources: DirAccess = DirAccess.open("res://")
	var clean_err: Error = resources.remove(tmp_dir)
	if clean_err != OK:
		_error("Failed to remove temp directory", clean_err)

func _trim_zip_path_root(path: String) -> String:
	var split: Array[String] = path.split("/")
	split.remove_at(0)
	return "/".join(split)
