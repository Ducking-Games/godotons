@tool
extends Resource
class_name GodotonsConfig

var conf: ConfigFile = ConfigFile.new()

@export var Addons: Array[AddonConfig] = []

var configFile: String = "res://godotons.cfg"	

func Find(section: String) -> AddonConfig:
	var index: int = Addons.find(section)
	if index == -1:
		return null
	return Addons[index]

func BuildConfig() -> void:
	conf.clear()
	for addon in Addons:
		conf = addon.Prepare(conf)

func SaveConfig() -> void:
	BuildConfig()
	conf.save(configFile)

func LoadConfig() -> void:
	conf.clear()
	conf.load(configFile)
	Addons = []
	for section in conf.get_sections():
		var addon: AddonConfig = AddonConfig.new()
		addon.Unpack(conf, section)
		Addons.append(addon)