@tool
extends Resource
class_name AddonConfig

enum TREE_BUTTONS { APPLY_ALL = 1000, APPLY_ONE, DELETE_ONE, UOA_ONE }

@export var Name: String
@export var Enabled: bool
@export var Update: bool
@export var Repo: String
@export var Branch: String
@export var UpstreamPath: String
@export var ProjectPath: String
@export var LastInjectedGitHash: String

## Prepare packs this addon configuraiton into a config section for writing
func Prepare(conf: ConfigFile) -> ConfigFile:
	conf.set_value(Name, "name", Name)
	conf.set_value(Name, "enabled", Enabled)
	conf.set_value(Name, "update", Update)
	conf.set_value(Name, "repo", Repo)
	conf.set_value(Name, "branch", Branch)
	conf.set_value(Name, "upstream_path", UpstreamPath)
	conf.set_value(Name, "project_path", ProjectPath)

	return conf

## Unpack creates a new AddonConfig and populates it from the given conf
func LoadFrom(conf: ConfigFile, section: String) -> void:
	Name = section
	Enabled = conf.get_value(section, "enabled", true)
	Update = conf.get_value(section, "update", true)
	Repo = conf.get_value(section, "repo")
	Branch = conf.get_value(section, "branch")
	UpstreamPath = conf.get_value(section, "upstream_path")
	ProjectPath = conf.get_value(section, "project_path")

## Branch provides a TreeItem for rendering in the dock
func TreeBranch(tree: Tree, root: TreeItem, tree_index: int, removeIcon: Texture2D, integrateIcon: Texture2D) -> void:
	var addon_root := tree.create_item()
	addon_root.set_text(0, Name)
	addon_root.add_button(1, removeIcon, TREE_BUTTONS.DELETE_ONE, false, "Delete this addon from management")
	addon_root.add_button(1, integrateIcon, TREE_BUTTONS.APPLY_ONE, false, "Apply just this addon")
	addon_root.set_editable(0, true)
	addon_root.set_meta("name", Name)
	addon_root.set_meta("index", tree_index)

	var addon_enabled := tree.create_item(addon_root)
	addon_enabled.set_text(0, "Enabled on Apply")
	addon_enabled.add_button(1, PlaceholderTexture2D.new(), TREE_BUTTONS.UOA_ONE, false, "Uncheck to skip addon entirely during apply runs.")
	addon_enabled.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
	addon_enabled.set_editable(1, true)
	addon_enabled.set_checked(1, Enabled)
	addon_enabled.set_meta("index", tree_index)

	var addon_update := tree.create_item(addon_root)
	addon_update.set_text(0, "Update on Apply")
	addon_update.add_button(1, PlaceholderTexture2D.new(), TREE_BUTTONS.UOA_ONE, false, "Uncheck to leave local copy untouched during apply runs.")
	addon_update.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
	addon_update.set_editable(1, true)
	addon_update.set_checked(1, Update)
	addon_update.set_meta("index", tree_index)

	var addon_repo := tree.create_item(addon_root)
	addon_repo.set_text(0, "Repo")
	addon_repo.set_text(1, Repo)
	addon_repo.set_editable(1, true)

	var branch_repo := tree.create_item(addon_root)
	branch_repo.set_text(0, "Branch")
	branch_repo.set_text(1, Branch)
	branch_repo.set_editable(1, true)

	var addon_upstream := tree.create_item(addon_root)
	addon_upstream.set_text(0, "Upstream Path")
	addon_upstream.set_text(1, UpstreamPath)
	addon_upstream.set_editable(1, true)

	var addon_project := tree.create_item(addon_root)
	addon_project.set_text(0, "Project Path")
	addon_project.set_text(1, ProjectPath)
	addon_project.set_editable(1, true)
