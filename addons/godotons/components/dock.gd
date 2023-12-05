@tool
extends Control

var config: GodotonsConfig = GodotonsConfig.new()


@onready var list: ItemList = get_node("VBox/ItemList")
@onready var tree: Tree = get_node("VBox/Tree")
@onready var remove: Texture2D = preload("res://addons/godotons/remove.png")
@onready var integrate: Texture2D = preload("res://addons/godotons/integrate.png")

func _init() -> void:
	Engine.register_singleton("Godotons", self)

func _exit_tree() -> void:
	Engine.unregister_singleton("Godotons")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_load_config()
	tree.item_edited.connect(_edited)
	tree.button_clicked.connect(_remove_clicked)
	pass # Replace with function body.

func _save_config() -> void:
	print_rich("Saving...")
	config.SaveConfig()

func _load_config() -> void:
	print_rich("Loading...")
	config.LoadConfig()
	_build_list()
		

func _edited() -> void:
	config.Addons.clear()
	var root_item: Array[TreeItem] = tree.get_root().get_children()
	for item in root_item:
		# this should be the addon name
		var c: AddonConfig = AddonConfig.new()
		c.Name = item.get_text(0)
	
		for child in item.get_children():
			var lbl: String = child.get_text(0)
			match lbl:
				"Repo":
					c.Repo = child.get_text(1)
				"Update on Apply":
					c.Update = child.is_checked(1)
				"Branch":
					c.Branch = child.get_text(1)
				"Upstream Path":
					c.UpstreamPath = child.get_text(1)
				"Project Path":
					c.ProjectPath = child.get_text(1)

		config.Addons.append(c)

		item.get_next()
	_save_config()

func _remove_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int) -> void:
	if id == 6000:
		Integrate()
		return
	
	config.Addons.remove_at(id)
	config.SaveConfig()
	_build_list()
	

func _build_list() -> void:
	tree.clear()
	var root := tree.create_item()
	root.set_text(0, "Addons")
	root.add_button(1, integrate, 6000, false, "Apply the addon configuration to project")
	var index: int = 0
	for addon in config.Addons:
		var addon_root := tree.create_item()
		addon_root.set_text(0, addon.Name)
		addon_root.add_button(1, remove, index, false, "Remove Addon")
		addon_root.set_editable(0, true)
		
		var updateAddon := tree.create_item(addon_root)
		updateAddon.set_text(0, "Update on Apply")
		updateAddon.add_button(1, PlaceholderTexture2D.new(), 7000, false, "Uncheck to leave local copy untouched during apply runs.")
		updateAddon.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
		updateAddon.set_editable(1, true)
		updateAddon.set_checked(1, addon.Update)
		
		
		var repo := tree.create_item(addon_root)
		repo.set_text(0, "Repo")
		repo.set_text(1, addon.Repo)
		repo.set_editable(1, true)
		
		var branch := tree.create_item(addon_root)
		branch.set_text(0, "Branch")
		branch.set_text(1, addon.Branch)
		branch.set_editable(1, true)
		
		var upstream := tree.create_item(addon_root)
		upstream.set_text(0, "Upstream Path")
		upstream.set_text(1, addon.UpstreamPath)
		upstream.set_editable(1, true)
		
		var project := tree.create_item(addon_root)
		project.set_text(0, "Project Path")
		project.set_text(1, addon.ProjectPath)
		project.set_editable(1, true)
		
		index += 1
		
func _new_addon() -> void:
	var c: AddonConfig = _addon("New Addon", "", "main", "", "")
	config.Addons.append(c)
	_save_config()
	_build_list()
	
func _addon(name: String, repo: String, branch: String, repo_path: String, project_path: String) -> AddonConfig:
	var c: AddonConfig = AddonConfig.new()
	c.Name = name
	c.Update = true
	c.Repo = repo
	c.Branch = branch
	c.UpstreamPath = repo_path
	c.ProjectPath = project_path
	return c

func Integrate() -> void:
	print_rich("[color=orange]Beginning Integration Run with %d addons" % [config.Addons.size()])
	
	var client: HTTPClient = HTTPClient.new()
	
	for addon in config.Addons:
		var validate: DirAccess = DirAccess.open("res://")
		if validate.dir_exists(addon.ProjectPath):
			if !addon.Update:
				print_rich("[color=orange]Skipping %s (No Update)" % [addon.Name])
				continue
		
		print_rich("[color=green]Integrating Addon: %s[/color]" % [addon.Name])
		
		var download_url: String = "%s/archive/%s.zip" % [addon.Repo, addon.Branch]
		var req: HTTPRequest = HTTPRequest.new()
		add_child(req)
		
		var error = req.request(download_url)
		if error != OK:
			push_error("Failed to download %s:%s" % [addon.Repo, addon.Branch])
			print_rich("[color=red]Failed to download %s[/color]" % [download_url])
		
		print_rich("[color=orange]Awaiting %s...[/color]" % [addon.Name])
		var result: Array = await req.request_completed
		var response: int = result[1]
		
		var archive_name: String = "%s-%s" % [addon.Name, addon.Branch]
		var archive_path: String = "user://%s.zip" % [archive_name]
		
		if response == 200:
			print_rich("[color=green]Successfully fetched %s[/color]" % [addon.Name])
			var body: PackedByteArray = result.back()
			var file = FileAccess.open(archive_path, FileAccess.WRITE)
			
			if file:
				file.store_buffer(body)
				file.close()
				
				print_rich("[color=green]Injecting addon [source:%s -> %s]...[/color]" % [addon.UpstreamPath, addon.ProjectPath])
				var reader := ZIPReader.new()
				var err := reader.open("%s" % [archive_path])
				if err != OK:
					print_rich("[color=red]Failed to unpack %s" % [archive_path])
				
				var wrote_file_count: int = 0
				
				var dir: DirAccess = DirAccess.open("res://")
				for archived_file in reader.get_files():
					if archived_file.contains(addon.UpstreamPath):
						#print_rich("[color=blue]Found %s[/color]" % [archived_file])
						if archived_file.ends_with("/"):
							var target: String = archived_file.trim_prefix("%s-%s/" % [addon.Name, addon.Branch])
							print_rich("[color=cyan]Creating res://%s...[/color]" % [target])
							dir.make_dir_recursive("res://%s" % [target])
						else:
							var target: String = archived_file.trim_prefix("%s-%s" % [addon.Name, addon.Branch])
							var writing: FileAccess = FileAccess.open("res://%s" % [target], FileAccess.WRITE)
							writing.store_buffer(reader.read_file(archived_file))
							writing.close()
							wrote_file_count += 1
							#print_rich("[color=yellow]Wrote %s[/color]" % [target])
				print_rich("[color=green]Wrote %d files[/color]" % [wrote_file_count])
				print_rich("[color=magenta]Cleaning up %s[/color]" % [archive_path])
				var cleaner: DirAccess = DirAccess.open("user://")
				var cleaned: Error = cleaner.remove(archive_path)
				if cleaned != OK:
					print_rich("[color=red]Failed to delete user://%s.zip: %s" % [archive_name, cleaned])
				print_rich("[color=green]Done with %s[/color]" % [addon.Name])
			else:
				print_rich("[color=red]Failed to create file: %s-%s.zip" % [addon.Name, addon.Branch])
		else:
			print_rich("[color=red]Response %d in retrieving addon from upstream. Expected 200. Aborting." % [response])

