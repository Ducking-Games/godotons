@tool
extends Resource
class_name AddonConfig

@export var Name: String
@export var Update: bool
@export var Repo: String
@export var Branch: String
@export var UpstreamPath: String
@export var ProjectPath: String
@export var LastInjectedGitHash: String

## Prepare packs this addon configuraiton into a config section for writing
func Prepare(conf: ConfigFile) -> ConfigFile:
    conf.set_value(Name, "name", Name)
    conf.set_value(Name, "update", Update)
    conf.set_value(Name, "repo", Repo)
    conf.set_value(Name, "branch", Branch)
    conf.set_value(Name, "upstream_path", UpstreamPath)
    conf.set_value(Name, "project_path", ProjectPath)

    return conf

## Unpack creates a new AddonConfig and populates it from the given conf
func LoadFrom(conf: ConfigFile, section: String) -> void:
    Name = section
    Update = conf.get_value(section, "update")
    Repo = conf.get_value(section, "repo")
    Branch = conf.get_value(section, "branch")
    UpstreamPath = conf.get_value(section, "upstream_path")
    ProjectPath = conf.get_value(section, "project_path")