@tool
extends Resource
class_name GodotonsConfig

var conf: ConfigFile = ConfigFile.new()

@export var Addons: Array[AddonConfig] = []

var configFile: String = "res://godotons.cfg"	

func BuildConfig() -> void:
	conf.clear()
	for addon in Addons:
		conf.set_value(addon.Name, "name", addon.Name)
		conf.set_value(addon.Name, "update", addon.Update)
		conf.set_value(addon.Name, "repo", addon.Repo)
		conf.set_value(addon.Name, "branch", addon.Branch)
		conf.set_value(addon.Name, "upstream_path", addon.UpstreamPath)
		conf.set_value(addon.Name, "project_path", addon.ProjectPath)

func SaveConfig() -> void:
	BuildConfig()
	conf.save(configFile)

func LoadConfig() -> void:
	conf.clear()
	conf.load(configFile)
	Addons = []
	for section in conf.get_sections():
		var addon: AddonConfig = AddonConfig.new()
		addon.Name = section
		addon.Repo = conf.get_value(section, "repo")
		addon.Update = conf.get_value(section, "update")
		addon.Branch = conf.get_value(section, "branch")
		addon.UpstreamPath = conf.get_value(section, "upstream_path")
		addon.ProjectPath = conf.get_value(section, "project_path")
		Addons.append(addon)
