@tool
extends Resource
class_name AddonConfig

enum TREE_BUTTONS { APPLY_ALL = 1000, APPLY_ONE, DELETE_ONE, UOA_ONE, PAUSE_ONE }

@export var Name: String
@export var Enabled: bool
@export var Update: bool
@export var Origin: String
@export var OriginOverride: String
@export var Repo: String
@export var Branch: String
@export var UpstreamPath: String
@export var ProjectPath: String
@export var LastInjectedGitHash: String
@export var Hidden: bool

func Owner() -> String:
	var split: PackedStringArray = Repo.split("/")
	if len(split) < 2:
		return ""
	return split[0]

func RepoName() -> String:
	var split: PackedStringArray = Repo.split("/")
	if len(split) < 2:
		return ""
	return split[1]

func Stringify() -> String:
	var to_join: Array[String] = [
		"Name: %s\n" % [Name],
		"Enabled: %s\n" % [Enabled],
		"Update: %s\n" % [Update],
		"Origin: %s\n" % [Origin],
		"OriginOverride: %s\n" % [OriginOverride],
		"Repo: %s\n" % [Repo],
		"Branch: %s\n" % [Branch],
		"UpstreamPath: %s\n" % [UpstreamPath],
		"ProjectPath: %s\n" % [ProjectPath],
		"LastInjectedGitHash: %s\n" % [LastInjectedGitHash],
		"Hidden: %s\n" % [Hidden]
	]

	return "".join(to_join)

## Prepare packs this addon configuraiton into a config section for writing
func Prepare(conf: ConfigFile) -> ConfigFile:
	conf.set_value(Name, "name", Name)
	conf.set_value(Name, "hidden", Hidden)
	conf.set_value(Name, "enabled", Enabled)
	conf.set_value(Name, "update", Update)
	conf.set_value(Name, "origin", Origin)
	conf.set_value(Name, "origin_override", OriginOverride)
	conf.set_value(Name, "repo", Repo)
	conf.set_value(Name, "branch", Branch)
	conf.set_value(Name, "upstream_path", UpstreamPath)
	conf.set_value(Name, "project_path", ProjectPath)
	conf.set_value(Name, "last_git_hash", LastInjectedGitHash)

	return conf

## Unpack creates a new AddonConfig and populates it from the given conf
func LoadFrom(conf: ConfigFile, section: String) -> void:
	Name = section
	Hidden = conf.get_value(section, "hidden", true)
	Enabled = conf.get_value(section, "enabled", true)
	Update = conf.get_value(section, "update", true)
	Origin = conf.get_value(section, "origin", "github")
	OriginOverride = conf.get_value(section, "origin_override", "")
	Repo = conf.get_value(section, "repo", "")
	Branch = conf.get_value(section, "branch", "main")
	UpstreamPath = conf.get_value(section, "upstream_path", "")
	ProjectPath = conf.get_value(section, "project_path", "")
	LastInjectedGitHash = conf.get_value(section, "last_git_hash", "")

## Branch provides a TreeItem for rendering in the dock
func TreeBranch(tree: Tree, root: TreeItem, tree_index: int, removeIcon: Texture2D, integrateIcon: Texture2D, pauseIcon: Texture2D) -> TreeItem:
	var addon_root := tree.create_item()
	addon_root.set_text(0, Name)
	addon_root.set_collapsed_recursive(Hidden)
	addon_root.add_button(1, removeIcon, TREE_BUTTONS.DELETE_ONE, false, "Delete this addon from management")
	addon_root.add_button(1, pauseIcon, TREE_BUTTONS.PAUSE_ONE, false, "Enable/Disable this addon")
	addon_root.add_button(1, integrateIcon, TREE_BUTTONS.APPLY_ONE, false, "Apply just this addon")
	addon_root.set_editable(0, true)
	addon_root.set_meta("name", Name)
	addon_root.set_meta("index", tree_index)
	addon_root.set_custom_color(0, Color.DIM_GRAY if !Enabled else Color.WHITE)

	var addon_update := tree.create_item(addon_root)
	addon_update.set_text(0, "Update on Apply")
	addon_update.add_button(1, PlaceholderTexture2D.new(), TREE_BUTTONS.UOA_ONE, false, "Uncheck to leave local copy untouched during apply runs.")
	addon_update.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
	addon_update.set_custom_color(0, Color.DIM_GRAY if !Enabled else Color.WHITE)
	addon_update.set_editable(1, true)
	addon_update.set_checked(1, Update)
	addon_update.set_meta("index", tree_index)

	var addon_origin := tree.create_item(addon_root)
	addon_origin.set_text(0, "Origin")
	addon_origin.set_cell_mode(1, TreeItem.CELL_MODE_RANGE)
	addon_origin.set_custom_color(0, Color.DIM_GRAY if !Enabled else Color.WHITE)
	addon_origin.set_range(1, GitDownloader.upstream_index(Name))
	addon_origin.set_tooltip_text(1, "The upstream origin provider the addon is hosted on. Determines API/URLs used")
	addon_origin.set_editable(1, true)
	addon_origin.set_text(1, "github,gitlab")

	var addon_origin_override := tree.create_item(addon_root)
	addon_origin_override.set_text(0, "Origin Override")
	addon_origin_override.set_text(1, OriginOverride)
	addon_origin_override.set_custom_color(0, Color.DIM_GRAY if !Enabled else Color.WHITE)
	addon_origin_override.set_tooltip_text(1, "Override the origin URL (for enterprise/on prem installs). Must be of Origin API format.")
	addon_origin_override.set_editable(1, true)

	var addon_repo := tree.create_item(addon_root)
	addon_repo.set_text(0, "Repo")
	addon_repo.set_text(1, Repo)
	addon_repo.set_editable(1, true)
	addon_repo.set_custom_color(0, Color.DIM_GRAY if !Enabled else Color.WHITE)
	addon_repo.set_tooltip_text(1, "Upstream repo in owner/repo_name format. Ex. Ducking-Games/godotons")

	var branch_repo := tree.create_item(addon_root)
	branch_repo.set_text(0, "Branch")
	branch_repo.set_text(1, Branch)
	branch_repo.set_editable(1, true)
	branch_repo.set_custom_color(0, Color.DIM_GRAY if !Enabled else Color.WHITE)

	var addon_upstream := tree.create_item(addon_root)
	addon_upstream.set_text(0, "Upstream Path")
	addon_upstream.set_text(1, UpstreamPath)
	addon_upstream.set_editable(1, true)
	addon_upstream.set_custom_color(0, Color.DIM_GRAY if !Enabled else Color.WHITE)

	var addon_project := tree.create_item(addon_root)
	addon_project.set_text(0, "Project Path")
	addon_project.set_text(1, ProjectPath)
	addon_project.set_editable(1, true)
	addon_project.set_custom_color(0, Color.DIM_GRAY if !Enabled else Color.WHITE)

	return addon_root
