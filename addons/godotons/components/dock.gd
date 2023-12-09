@tool
extends Control

const tmp_dir: String = "addons/tmp-addons/"

var config: AddonManifest = AddonManifest.new()

@onready var tree: Tree = get_node("VBox/Tree")
@onready var remove: Texture2D = preload("res://addons/godotons/remove.png")
@onready var integrate: Texture2D = preload("res://addons/godotons/integrate.png")
@onready var pause_icon: Texture2D = preload("res://addons/godotons/pause.png")

func _enter_tree() -> void:
	Engine.register_singleton("Godotons", self)

func _exit_tree() -> void:
	Engine.unregister_singleton("Godotons")

func _ready() -> void:
	_load_config()

	tree.item_edited.connect(_tree_edited)
	tree.button_clicked.connect(_tree_clicked)
	tree.item_collapsed.connect(_tree_collapsed)
	#EditorInterface.get_resource_filesystem().sources_changed.connect(_on_sources_changed)

func _on_resources_reloaded(resources: PackedStringArray) -> void:
	if resources.has(AddonManifest.config_file):
		_load_config()

func _on_sources_changed(exist: bool) -> void:
	_load_config()

func _save_config() -> void:
	Logs._dminor("Saving godotons config...")
	var save_err: Error = config.Save()
	if save_err != OK:
		Logs._error("Failed to save config", save_err)
		return
	call_deferred("_build_tree")

func _save_backup_config() -> void:
	Logs._dminor("Saving backup godotons config...")
	var save_err: Error = config.Save(true)
	if save_err != OK:
		Logs._error("Failed to save backup", save_err)
		return

func _load_config() -> void:
	Logs._dminor("Loading config from disk...")
	config.LoadFromDisk()
	if config.Addons.size() == 0:
		Logs._error("No addons loaded. Config empty or load errored. Check pushed errors.", 0)
		return
	call_deferred("_build_tree")

func _load_backup_config() -> void:
	Logs._dminor("Loading config from backup file...")
	config.LoadFromDisk(true)
	if config.Addons.size() == 0:
		Logs._error("No addons loaded. Config empty or load errored. Check pushed errors.", 0)
		return
	call_deferred("_build_tree")

func _tree_edited() -> void:
	var root_item: Array[TreeItem] = tree.get_root().get_children()
	var addons: Array[AddonConfig] = []
	for item in root_item:
		var addon: AddonConfig = AddonConfig.new()
		addon.Name = item.get_text(0).replace(" ", "_")
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
	#_save_config()
	pass

func _new_addon() -> void:
	config.New()
	call_deferred("_build_tree")

func _build_tree() -> void:
	tree.clear()
	#tree.item_collapsed.connect(_tree_collapsed)

	var root := tree.create_item()
	root.set_text(0, "Addons")
	root.add_button(1, integrate, AddonConfig.TREE_BUTTONS.APPLY_ALL , false, "Apply the entire addon configuration to the project")

	var tree_index: int = 0

	for addon in config.Addons:
		var addon_root: TreeItem = addon.TreeBranch(tree, root, tree_index, remove, integrate, pause_icon)
		tree_index += 1

func _integrate_one(addon: AddonConfig, single: bool) -> Error:
	if !addon.Enabled:
		Logs._notice("Ignoring %s (disabled)" % [addon.Name])
		return OK

	var resources: DirAccess = DirAccess.open("res://")
	if resources == null:
		var failed: Error = DirAccess.get_open_error()
		return failed

	var tmp_err: Error = resources.make_dir_recursive(tmp_dir)
	if tmp_err != OK:
		Logs._error("Failed to create temp directory for integration run", tmp_err)
		return tmp_err

	if resources.dir_exists(addon.ProjectPath):
		if !addon.Update:
			Logs._notice("Skipping %s (Update On Apply: false)" % [addon.Name])
			return ERR_ALREADY_EXISTS

	Logs._info("Integrating addon: %s" % [addon.Name])

	var gd: GitDownloader = GitDownloader.new()
	add_child(gd)

	var commit_hash: String = await gd.get_commit_hash(addon)
	if commit_hash == "":
		return ERR_QUERY_FAILED
	Logs._infoi("Read %s:%s@%s" % [addon.Repo, addon.Branch, commit_hash])

	var file_target: String = "%s/%s.zip" % [tmp_dir, commit_hash]

	if not resources.file_exists(file_target):

		var download_error: Error = await gd.get_archive(addon, "res://%s" % [file_target])
		if download_error != OK:
			return download_error
	else:
		Logs._infoi("%s already exists - requirement met" % [file_target])

	gd.queue_free()

	# unpack zip and create temp
	Logs._infoi("Injecting [%s -> %s]" % [addon.UpstreamPath, addon.ProjectPath])
	
	var zip_reader: ZIPReader = ZIPReader.new()
	var zip_err: Error = zip_reader.open(file_target)
	if zip_err != OK:
		Logs._error("Failed to unpack: %s" % [file_target], zip_err)
		return zip_err
	
	var wrote_dir_count: int = 0
	var wrote_file_count: int = 0

	var tmp_unpack_dir: String = "%s%s" % [tmp_dir, commit_hash]
	var inject_path: String = "res://%s" % [addon.ProjectPath]

	for archived_file: String in zip_reader.get_files():
		#Logs._infoi("[zip] %s" % [archived_file])
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
			
			#Logs._infoi("Writing %s (with ZIP:%s)" % [resource_path, archived_file])
			var writer: FileAccess = FileAccess.open(resource_path, FileAccess.WRITE)
			writer.store_buffer(zip_reader.read_file(archived_file))
			# get_error() here maybe? does it reset for every op?
			writer.close()

			wrote_file_count += 1
	
	var zip_close: Error = await zip_reader.close()
	Logs._infoi("Wrote %d directories and %d files." % [wrote_dir_count, wrote_file_count])

	if resources.dir_exists(addon.ProjectPath):
		Logs._infoi("Removing %s to replace..." % [addon.ProjectPath])
		var err: Error = await _clean(addon.ProjectPath)
		if err != OK:
			Logs._error("Failed cleanup step", err)
			return err

		#var move_dir: Error = resources.rename(addon.ProjectPath, "%s-old" % [addon.ProjectPath])

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
	var x: Error = resources.get_open_error()
	if x != OK:
		Logs._error("What?", x)
	
	Logs._infoi("Moved.")

	if single:
		var clean_err: Error = await _clean()
		if clean_err != OK:
			return clean_err

		_save_backup_config()

	Logs._success("Done: %s" % [addon.Name])
	return OK


func _integrate() -> void:
	Logs._info("Beginning integration run with %d addons" % [config.Addons.size()])

	for addon in config.Addons:
		await _integrate_one(addon, false)

	var err: Error = await _clean()
	if err != OK:
		Logs._error("Failed cleanup step", err)
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
	Logs._notice("[Recursion](changing dirs) %s" % [res])
	var ch_err: Error = hero.change_dir(res)
	if ch_err != OK:
		Logs._error("Seriously failed to change directories from %s to %s" % [hero.get_current_dir(false), res], ch_err)
		return ch_err
	
	var dirs: Array = hero.get_directories()
	var files: Array = hero.get_files()

	Logs._notice("%d directories | %d files" % [dirs.size(), files.size()])

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
		Logs._notice("Removing %s" % [this_resource])
		var rm_file_err: Error = hero.remove(this_resource)
		if rm_file_err != OK:
			Logs._error("Failed to remove %s" % [this_resource], rm_file_err)
			continue

	return OK

