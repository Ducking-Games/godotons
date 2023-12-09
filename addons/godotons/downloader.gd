@tool
extends Resource
class_name AddonIntegrationStep

@export var Hash: String

func hash_matches(hash: String) -> bool:
    return true if hash==Hash else false



#https://api.github.com/repos/ephread/inkgd/commits/main

#https://github.com/owner/repo/archive/branch.zip