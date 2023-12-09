@tool
extends Resource
class_name AddonManifest

const config_file: String = "res://godotons.cfg"
const backup_file: String = "res://godotons.bkp.cfg"

var Addons: Array[AddonConfig] = []

## New adds a new empty addon to the configuration
func New() -> Error:
	var addon: AddonConfig = AddonConfig.new()
	addon.Name = GetAvailableName()
	Addons.append(addon)
	return Save()

## GetAvailableName returns an Addon name not used in Array[AddonConfig] yet
func GetAvailableName() -> String:
	var name: String = "New Addon"

	var increment: int = 0
	while GetByName(name) != null:
		name = "New Addon %d" % [increment]
		increment += 1

	return name

## GetByName returns the addon with name name if exists
func GetByName(name: String) -> AddonConfig:
	for addon in Addons:
		if addon.Name == name:
			return addon
	return null

## IndexByName returns the addon index with the name if exists
func IndexByName(name: String) -> int:
	var index: int = -1
	for addon in Addons:
		index += 1
		if addon.Name == name:
			return index
	return -1
	
## Build assembles the Array[AddonConfig] into a ConfigFile
func Build() -> ConfigFile:
	var current: ConfigFile = ConfigFile.new()
	for addon in Addons:
		current = addon.Prepare(current)
	return current

## Save the ephemeral in-memory addon configuration to disk
func Save(backup: bool = false) -> Error:
	var conf_to_save: ConfigFile = Build()
	var filepath: String = backup_file if backup else config_file
	return conf_to_save.save(filepath)

## LoadFrom builds an Array[AddonConfig] from the given ConfigFile
func LoadFrom(conf: ConfigFile) -> Array[AddonConfig]:
	var addons: Array[AddonConfig] = []

	for section in conf.get_sections():
		var addon: AddonConfig = AddonConfig.new()
		addon.LoadFrom(conf, section)
		addons.append(addon)

	return addons

## Load reads a configuration from disk and returns an Array[AddonConfig]
func Load(file_path: String) -> Array[AddonConfig]:
	var conf: ConfigFile = ConfigFile.new()
	var err: Error = conf.load(file_path)
	if err != OK:
		push_error("Failed to load config file [%s]: %d (%s)" % [file_path, err, error_string(err)])
		return []
	
	return LoadFrom(conf)

## LoadFromDisk populates the Addons from the given source target
func LoadFromDisk(backup: bool = false) -> void:
	var filepath: String = backup_file if backup else config_file
	Addons = Load(filepath)
