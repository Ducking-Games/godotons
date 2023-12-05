@tool
extends Resource
class_name AddonManifest

const config_file: String = "res://godotons.cfg"
const backup_file: String = "res://godotons.bkp.cfg"

var Addons: Array[AddonConfig] = []

## GetByName returns the addon with name name if exists
func GetByName(name: String) -> AddonConfig:
    var index: int = Addons.find(name)
    if index == -1:
        return null
    return Addons[index]

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
