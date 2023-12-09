@tool
extends Control

const tmp_dir: String = "addons/tmp-addons/"

var config: AddonManifest = AddonManifest.new()

@onready var tree: Tree = get_node("VBox/Tree")
@onready var remove: Texture2D = preload("res://addons/godotons/remove.png")
@onready var integrate: Texture2D = preload("res://addons/godotons/integrate.png")
@onready var pause_icon: Texture2D = preload("res://addons/godotons/pause.png")

var config_lock: Mutex = Mutex.new()
var run_lock: Mutex = Mutex.new()

func _enter_tree() -> void:
	Engine.register_singleton("Godotons", self)

func _exit_tree() -> void:
	Engine.unregister_singleton("Godotons")

func _ready() -> void:
	_load_config()

	tree.item_edited.connect(_tree_edited)
	tree.button_clicked.connect(_tree_clicked)
	tree.item_collapsed.connect(_tree_collapsed)

func _on_resources_reloaded(resources: PackedStringArray) -> void:
	if resources.has(AddonManifest.config_file):
		_load_config()

func _save_config() -> void:
	config_lock.lock()
	Logs._dminor("Saving godotons config...")
	var save_err: Error = config.Save()
	if save_err != OK:
		Logs._error("Failed to save config", save_err)
		return
	call_deferred("_build_tree")
	config_lock.unlock()

func _save_backup_config() -> void:
	config_lock.lock()
	Logs._dminor("Saving backup godotons config...")
	var save_err: Error = config.Save(true)
	if save_err != OK:
		Logs._error("Failed to save backup", save_err)
		return
	config_lock.unlock()

func _load_config() -> void:
	config_lock.lock()
	Logs._dminor("Loading config from disk...")
	config.LoadFromDisk()
	if config.Addons.size() == 0:
		Logs._error("No addons loaded. Config empty or load errored. Check pushed errors.", 0)
		return
	call_deferred("_build_tree")
	config_lock.unlock()

func _load_backup_config() -> void:
	config_lock.lock()
	Logs._dminor("Loading config from backup file...")
	config.LoadFromDisk(true)
	if config.Addons.size() == 0:
		Logs._error("No addons loaded. Config empty or load errored. Check pushed errors.", 0)
		return
	call_deferred("_build_tree")
	config_lock.unlock()

func _tree_edited() -> void:
	var root_item: Array[TreeItem] = tree.get_root().get_children()
	var addons: Array[AddonConfig] = []
	for item in root_item:
		var addon: AddonConfig = AddonConfig.new()
		addon.Name = item.get_text(0).replace(" ", "_").replace("'", "_")
		var old_addon: AddonConfig = config.GetByName(addon.Name)
		addon.LastInjectedGitHash = old_addon.LastInjectedGitHash
		addon.Hidden = item.collapsed

		for child in item.get_children():
			var child_label: String = child.get_text(0)
			match child_label:
				"Repo":
					addon.Repo = child.get_text(1)
				"Update on Apply":
					addon.Update = child.is_checked(1)
				"Origin":
					addon.Origin = GitDownloader.upstream_name(child.get_range(1))
				"Branch":
					addon.Branch = child.get_text(1)
				"Upstream Path":
					addon.UpstreamPath = child.get_text(1)
				"Project Path":
					addon.ProjectPath = child.get_text(1)
		addon.Enabled = config.GetByName(addon.Name).Enabled if config.GetByName(addon.Name) != null else false
		addons.append(addon)
	
	config.Addons = addons
	_save_config()
	call_deferred("_build_tree")
	pass

func _tree_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int) -> void:
	Logs._dminor("Action ID: %d" % id)
	var idx: int = item.get_meta("index", -1) as int
	match id:
		AddonConfig.TREE_BUTTONS.APPLY_ALL:
			_integrate()
		AddonConfig.TREE_BUTTONS.APPLY_ONE:
			if idx == -1:
				push_error("Index %d is out of bounds, max: %d" % [idx, config.Addons.size()])
				Logs._error("Index %d is out of bounds, max: %d" % [idx, config.Addons.size()], ERR_DOES_NOT_EXIST)
				return
			_load_config()
			var addon: AddonConfig = config.Addons[idx]
			Logs._info("Run integration on one addon: %s" % [addon.Name])
			_integrate_one(addon, true)
		AddonConfig.TREE_BUTTONS.DELETE_ONE:
			if idx == -1:
				push_error("Index %d is out of bounds, max: %d" % [idx, config.Addons.size()])
				Logs._error("Index %d is out of bounds, max: %d" % [idx, config.Addons.size()], ERR_DOES_NOT_EXIST)
				return
			var addon: AddonConfig = config.Addons[idx]
			Logs._info("Removing %s from configuration" % [ addon.Name ])
			config.Addons.remove_at(idx)
			_save_config()
		AddonConfig.TREE_BUTTONS.PAUSE_ONE:
			if idx == -1:
				push_error("Index %d is out of bounds, max: %d" % [idx, config.Addons.size()])
				Logs._error("Index %d is out of bounds, max: %d" % [idx, config.Addons.size()], ERR_DOES_NOT_EXIST)
				return
			var addon: AddonConfig = config.Addons[idx]
			config.Addons[idx].Enabled = !config.Addons[idx].Enabled
			_save_config()

func _tree_collapsed(item: TreeItem) -> void:
	var item_name: String = item.get_meta("name", "")
	var item_index: int = item.get_meta("index", -1)
	if item_name == "" or item_index == -1:
		return
	var addon: AddonConfig = config.Addons[item_index]
	addon.Hidden = item.collapsed
	_save_config()

	pass

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
		var addon_root: TreeItem = addon.TreeBranch(tree, root, tree_index, remove, integrate, pause_icon)
		tree_index += 1

## _preflight performs some pre-integration operations to determine if we should continue
## and set up the temporary directory if it doesn't exist
func _preflight(addon: AddonConfig, resources: DirAccess) -> Error:
	if !addon.Enabled:
		Logs._notice("Skipping %s (disabled)" % [addon.Name])
		return ERR_SKIP

	var tmp_err: Error = resources.make_dir_recursive(tmp_dir)
	if tmp_err != OK:
		Logs._error("Failed to create temporary directory [%s] for integration run" % [tmp_err], tmp_err)
		return tmp_err
	
	return OK

## _integrate_one performs an integration play on a single addon
func _integrate_one(addon: AddonConfig, single: bool) -> Error:
	var continuing: bool = true
	var resources: DirAccess = DirAccess.open("res://")
	if resources == null:
		var failed: Error = DirAccess.get_open_error()
		return failed

	var preflight_err: Error = _preflight(addon, resources)
	if preflight_err != OK:
		return preflight_err

	Logs._info("Integrating addon: %s" % [addon.Name])

	var gd: GitDownloader = GitDownloader.new()
	add_child(gd)

	var commit_hash: String = await gd.get_commit_hash(addon)
	if commit_hash == "":
		return ERR_QUERY_FAILED

	Logs._infoi("Found %s:%s: fetched hash [%s]" % [addon.Repo, addon.Branch, commit_hash])

	if resources.dir_exists(addon.ProjectPath):
		if addon.LastInjectedGitHash != "":
			if addon.LastInjectedGitHash == commit_hash:
				if !addon.Update:
					Logs._noticei("Addon already exists at commit hash %s and Update is false. Skipping" % [commit_hash])
					continuing = false

	if continuing:

		var file_target: String = "%s/%s.zip" % [tmp_dir, commit_hash]

		if not resources.file_exists(file_target):

			var download_error: Error = await gd.get_archive(addon, "res://%s" % [file_target])
			if download_error != OK:
				return download_error
			Logs._infoi("Fetched %s:%s@%s. Saved to %s" % [addon.Repo, addon.Branch, commit_hash, file_target])
		else:
			Logs._infoi("Already exists: [%s] - requirement met" % [file_target])

		gd.queue_free()
	
		Logs._infoi("Injecting [%s -> %s]" % [addon.UpstreamPath, addon.ProjectPath])
		
		var zip_reader: ZIPReader = ZIPReader.new()
		var zip_err: Error = zip_reader.open(file_target)
		if zip_err != OK:
			Logs._error("Failed to open zip file: %s" % [file_target], zip_err)
			return zip_err
		
		var wrote_dir_count: int = 0
		var wrote_file_count: int = 0

		var tmp_unpack_dir: String = "%s%s" % [tmp_dir, commit_hash]
		var inject_path: String = "res://%s" % [addon.ProjectPath]

		for archived_file: String in zip_reader.get_files():
			var prefix: String = "%s-%s/" % [addon.RepoName(), addon.Branch]
			var zip_path_internal: String = archived_file.trim_prefix(prefix)
		
			if !zip_path_internal.begins_with(addon.UpstreamPath):
				continue
			else:
				var trimmed: String = zip_path_internal.trim_prefix(addon.UpstreamPath).trim_prefix("/")
				var resource_path: String = "%s/%s" % [tmp_unpack_dir, trimmed]

				if zip_path_internal.ends_with("/"):
					Logs._infoi("Creating %s" % [resource_path])
					var mkdir_err: Error = resources.make_dir_recursive(resource_path)
					if mkdir_err != OK:
						zip_reader.close()
						return mkdir_err
					wrote_dir_count += 1
					continue
				
				var writer: FileAccess = FileAccess.open(resource_path, FileAccess.WRITE)
				if writer == null:
					var writer_open_err: Error = FileAccess.get_open_error()
					Logs._error("Failed to open file for writing: %s" % [resource_path], writer_open_err)
					return writer_open_err
				writer.store_buffer(zip_reader.read_file(archived_file))
				writer.close()

				wrote_file_count += 1
		
		var zip_close: Error = await zip_reader.close()
		if zip_close != OK:
			Logs._error("Failed to close zip file reference: %s" % [file_target], zip_close)

		Logs._infoi("Wrote %d directories and %d files." % [wrote_dir_count, wrote_file_count])

		if resources.dir_exists(addon.ProjectPath):
			Logs._infoi("Removing %s to replace with %s" % [addon.ProjectPath, tmp_unpack_dir])
			var err: Error = await _clean(addon.ProjectPath)
			if err != OK:
				Logs._error("Failed to remove existing addon %s during integration preparation" % [addon.ProjectPath], err)
				return err

		var mkdir_pp: Error = await resources.make_dir_recursive(addon.ProjectPath)
		if mkdir_pp != OK:
			Logs._error("Failed to make %s" % [addon.ProjectPath], mkdir_pp)


		# I know this seems counter intuitive
		# basically the docs claim it will overwrite an existing target
		# but it doesn't, it silently fails without error and halts execution
		# so we recursively create ProjectPath, then delete it to delete only
		# the last dir in the chain so that rename can take its place
		var remove_dir: Error = resources.remove(addon.ProjectPath)
		if remove_dir != OK:
			Logs._error("Failed deleting %s during preparation" % [addon.ProjectPath], remove_dir)

		Logs._infoi("Moving addon into place [res://%s/ -> %s]" % [tmp_unpack_dir, addon.ProjectPath])
		

		var rename_err: Error = resources.rename(tmp_unpack_dir, addon.ProjectPath)
		if rename_err != OK:
			return rename_err
		
		Logs._infoi("Installed addon. Cleaning up.")
		var addon_index: int = config.IndexByName(addon.Name)
		if addon_index == -1:
			Logs._error("Could not find addon being actioned! %s" % [addon.Name], ERR_DOES_NOT_EXIST)

		Logs._minori("Adding %s to addon definition" % [commit_hash])
		addon.LastInjectedGitHash = commit_hash
		Logs._minori("Added %s to %s" % [config.Addons[addon_index].LastInjectedGitHash, addon.Name])
		config.Addons[addon_index] = addon


		_save_config()

	if single:
		var clean_err: Error = await _clean()
		if clean_err != OK:
			return clean_err

		_save_backup_config()

	return OK


func _integrate() -> void:
	Logs._info("Beginning integration run with %d addons" % [config.Addons.size()])

	run_lock.lock()
	for addon in config.Addons:
		var integrate_err: Error = await _integrate_one(addon, false)
		Logs._info("Addon %s complete: %s" % [addon.Name, error_string(integrate_err)])
	run_lock.unlock()

	var err: Error = await _clean()
	if err != OK:
		Logs._error("Failed on cleanup step", err)
	_save_backup_config()

	Logs._success("Done with integration run.")

func _clean(path: String = tmp_dir) -> Error:
	Logs._notice("Cleaning up res://%s..." % [path])
	var resources: DirAccess = DirAccess.open("res://")

	var clean: Error = _recursively_clean_directory(resources, path)
	if clean != OK:
		Logs._error("Failed to clean: %s" % [path], clean)
		return clean

	resources.change_dir("res://")
	var clean_err: Error = resources.remove("res://%s" % [path])
	if clean_err != OK:
		Logs._error("Failed to remove parent dir res://%s" % [path], clean_err)
		return clean_err
	return OK

func _recursively_clean_directory(hero: DirAccess, path: String) -> Error:
	var res: String = "%s%s" % ["" if path.begins_with("res://") else "res://", path]
	var ch_err: Error = hero.change_dir(res)
	if ch_err != OK:
		Logs._error("Failed to change directory from %s to %s" % [hero.get_current_dir(false), res], ch_err)
		return ch_err
	
	var dirs: Array = hero.get_directories()
	var files: Array = hero.get_files()

	for dir in dirs:
		var this_resource: String = "%s/%s" % [res, dir]
		Logs._notice("Cleaning out %s" % [this_resource])
		var child_err: Error = _recursively_clean_directory(hero, this_resource)
		if child_err != OK:
			Logs._error("Failed to remove child %s" % [this_resource], child_err)
			continue
		
		var rm_child_dir: Error = hero.change_dir("res://")
		if rm_child_dir != OK:
			Logs._error("Failed to move up one from %s" % [this_resource], rm_child_dir)
			continue
		
		var rm: Error = hero.remove(this_resource)
		if rm != OK:
			Logs._error("Failed to remove child dir %s" % [this_resource], rm)
			continue
		
	
	
	for file in files:
		var this_resource: String = "%s/%s" % [res, file]
		var rm_file_err: Error = hero.remove(this_resource)
		if rm_file_err != OK:
			Logs._error("Failed to remove %s" % [this_resource], rm_file_err)
			continue

	return OK

